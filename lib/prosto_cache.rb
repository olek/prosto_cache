=begin
This library provides a simple way to cache model and to access this cache in some canonical way.
Any changes to the model's objects will automatically result in cache reload.
Cache reload in other ruby processes of same app will be triggered as well, but
with some delay (currently up to 60 seconds).
If the delay in cache reloading is not an option, well, this simple library will
not work for you, and you will have to use something fancier, like Memcached.

Usage:

* Add ProstoCache mixin to your model
  class YourModel < ActiveRecord::Base
    include ProstoCache

* Configure cache access keys (optional step, by default cache is accessed by key 'name')
  cache_accessor_keys %w(scope name)

* Your model must have non-nullable column updated_at, add it in migration if
  it is missing (this field is used for invalidating cache in other ruby processes).

* Access cached model object in your code like this
  Simple case of one key
    YourModel.cache[:key1]
  Case of 2 or more keys
    YourModel.cache[:key1, :key2, :key3]

* Handling of non-existing cache values.
  If cache is accessed using symbol key and value not found, it will raise BadCacheKeyError.
  If cache is accessed using string key and value not found, it will return nil.
  For complex keys type of last key component is the one taken into account.

* If you want to, you can add extra lookup helpers to the objects that relate
  to the cached object, that will allow those objects to update 'string'
  attribute, and that will result in database reference change.
    class OtherModel < ActiveRecord::Base
      belongs_to :your_model
      lookup_enum_for :your_model
    end

  This lookup was intentionally not integrated 'seamlessly' with ActiveRecord since not
  everybody would want that, and monkey-patching other library (AR) is not really
  a good thing, even if it results in a 'smoother' experience where everything works as if by magic.
=end

module ProstoCache
  class BadCacheKeyError < StandardError; end
  class BadCacheValuesError < StandardError; end

  # cache itself, contains pretty much all the logic
  class ProstoModelCache

    class ProstoHash
      extend Forwardable
      def initialize(hash = {})
        @hash = hash.each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v }
      end

      def [](key)
        raise ArgumentError unless key
        hash[key.to_sym]
      end

      def []=(key, value)
        raise ArgumentError unless key
        hash[key.to_sym] = value
      end

      def_delegators :hash, :to_s, :inspect, :keys, :values

      private

      attr_reader :hash
    end

    def self.fail_on_missing_value?(litmus)
      case litmus
      when Symbol
        true
      when String
        false
      else
        raise ArgumentError, "Unknown type of cache key #{litmus.inspect}"
      end
    end

    MAX_CACHE_LIFE = 60 # seconds

    def initialize(model_class, accessor_keys)
      raise ArgumentError, "No model class provided" unless model_class

      @model_class = model_class
      @accessor_keys = [*(accessor_keys || :name)]
    end

    def invalidate
      self.cache = self.signature = self.validated_at = nil
    end

    def [](*keys)
      unless keys.length == accessor_keys.length
        raise BadCacheKeyError, "Cached accessed by #{keys.length} keys, expected #{accessor_keys.length}"
      end

      keys.zip((1..keys.length)).inject(safe_cache) do |memo, (key, index)|
        value = memo[key]
        unless value
          if ProstoModelCache.fail_on_missing_value?(keys.last)
            raise BadCacheKeyError, key
          else
            value = ProstoHash.new unless index == keys.length
          end
        end

        value
      end
    end

    def keys
      safe_cache.keys
    end

    def values
      safe_cache.values
    end

    private

    attr_reader :model_class, :cache, :signature, :validated_at, :accessor_keys
    attr_writer :cache, :signature, :validated_at

    def safe_cache
      time = Time.now.to_i

      if cache && validated_at < time - MAX_CACHE_LIFE
        current_cache_signature = validate_cache_signature(time)
      end

      unless cache
        load_cache(time, current_cache_signature)
      end

      cache
    end

    def validate_cache_signature(time)
      query_cache_signature.tap { |current_cache_signature|
        if current_cache_signature == signature
          self.validated_at = time
        else
          invalidate
        end
      }
    end

    def load_cache(time, current_cache_signature = nil)
      fail "Can not load already loaded cache" if cache

      current_cache_signature ||= query_cache_signature

      self.cache = build_cache(model_class.all, accessor_keys)
      self.validated_at = time
      self.signature = current_cache_signature
    end


    def build_cache(objects, attributes=[])
      attributes = [*attributes]
      if attributes.empty?
        # terminal case
        raise BadCacheValuesError, "No cache entry found" if objects.nil? || objects.empty?
        raise BadCacheValuesError, "Non deterministic search result, more then one cache entry found" if objects.size > 1
        return objects.first
      else
        reduced_attributes = attributes.dup
        attribute = reduced_attributes.delete_at(0).to_sym
        # first, bucketize to reduce problem's complexity
        array_map = objects.each_with_object({}) do |o, memo|
          key = o.send(attribute).to_s
          memo[key] ||= []
          memo[key] << o
        end
        # second, recurse and build cache from those reduced buckets!
        array_map.each_with_object(ProstoHash.new) do |(attr_value, attr_bucket), memo|
          memo[attr_value] = build_cache(attr_bucket, reduced_attributes)
        end
      end
    end

    def query_cache_signature
      raw_result = ActiveRecord::Base.connection.execute(
        "select max(updated_at) as max_updated_at, max(id) as max_id, count(id) as count from #{model_class.table_name}"
      )
      array_result = case raw_result.class.name
      when 'Mysql::Result'
        [].tap { |rows| raw_result.each_hash { |h| rows << h } }
      when 'Mysql2::Result'
        [].tap { |rows| raw_result.each(:as => :hash) { |h| rows << h } }
      when 'PGresult'
        raw_result.map(&:to_hash)
      else
        fail "Result class #{raw_result.class.name} in unsupported"
      end
      array_result.map(&:symbolize_keys).first
    end
  end

  def self.included(cl)

    cl.after_save { cl.cache.invalidate }

    class << cl

      def cache
        @cache ||= ProstoModelCache.new self, @accessor_keys
      end

      def cache_accessor_keys(keys)
        @accessor_keys = keys
      end
    end
  end

  module Extensions
    def lookup_enum_for(name, enum_class=nil)
      raise ArgumentError, "No name provided" unless name
      enum_class = name.to_s.classify.constantize unless enum_class
      define_method("#{name}_with_lookup=") do |o|
        new_value = o
        unless o.is_a?(enum_class)
          new_value = o.blank? ? nil : enum_class[o.to_s]
        end
        self.send("#{name}_without_lookup=", new_value)
      end

      alias_method_chain "#{name}=", :lookup
    end
  end
end
