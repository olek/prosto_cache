=begin
This library provides a simple way to cache model and to access this cache in some canonical way.
Any changes to the model's objects will automatically result in cache reload.
Cache reload in other ruby processes of same app will be triggered as well, but with some delay (currently up to 60 seconds).
If delay in cache reloading is not an option, well, this simply library will not work for you, and you have to use something fancier, like Memcached.

Usage:
1. add ProstoCache mixin to your model
  class YourModel < ActiveRecord::Base
    include ProstoCache
2. Configure cache access keys (optional step, by default cache is accessed by key 'name')
  cache_accessor_keys %w(scope name)
3. Your model must have non-nullable column updated_at, add it in migration if it is missing (this field is used for invalidating cache in other ruby processes).
4. Access cached model object in your code like this
  Simple case of one key
    YourModel.cache[:key1]
  Case of 2 or more keys where it is known ahead of time that all parent keys exist. Looks conventional, but is unreliable because brackets operation on nill will raise an error.
    YourModel.cache[:key1][:key2][:key3]
  Case of 2 or more keys where any key may not be present in cache, and expected answer is nil. Looks so-so, but is much more reliable then previos use case.
    YourModel.cache[[:key1, :key2, :key3]]
=end

require 'hashie'

module ProstoCache
  # cache itself, contains pretty much all the logic
  class ProstoModelCache
    attr_accessor :model_class, :cache, :signature, :validated_at, :accessor_keys

    def initialize(model_class, accessor_keys)
      self.model_class = model_class
      self.accessor_keys = accessor_keys || 'name'
    end

    def invalidate
      self.cache = self.signature = self.validated_at = nil
    end

    def [](keys)
      if keys.respond_to?(:to_ary)
        keys_ary = keys.to_ary
        if keys_ary.empty?
          nil
        else
          # looks like an array of key was passed in, lets try them one after another, without failing
          keys_ary.inject(safe_cache) do |memo,key|
            break unless memo
            memo[key]
          end
        end
      else
        safe_cache[keys]
      end
    end

    def keys
      safe_cache.keys
    end

    def values
      safe_cache.values
    end

    private

    def safe_cache
      max_cache_life = 60 # seconds
      current_time = Time.now.to_i

      if cache && validated_at < current_time - max_cache_life
        current_cache_signature = query_cache_signature
        if current_cache_signature == signature
          self.validated_at = current_time
        else
          invalidate
        end
      end

      unless cache
        current_cache_signature ||= query_cache_signature

        self.cache = build_cache(model_class.all, accessor_keys)
        self.validated_at = current_time
        self.signature = current_cache_signature
      end

      return cache
    end

    def build_cache(objects, attributes=nil)
      attributes = [*attributes] if attributes
      if !attributes || attributes.empty?
        # terminal case
        raise "No cache entry found" if objects.nil? || objects.empty?
        raise "Non deterministic search result, more then one cache entry found" if objects.size > 1
        return objects.first
      else
        reduced_attributes = attributes.dup
        attribute = reduced_attributes.delete_at(0).to_sym
        array_map = objects.inject({}) do |memo, o|
          key = o.send(attribute).to_s
          memo[key] ||= []
          memo[key] << o
          memo
        end
        array_map.inject(Hashie::Mash.new) do |memo, (k, v)|
          # recursion !
          memo[k] = build_cache(v, reduced_attributes)
          memo
        end
      end
    end

    def query_cache_signature
      raw_result = ActiveRecord::Base.connection.execute "select max(updated_at) as max_updated_at, max(id) as max_id, count(id) as count from #{model_class.name.tableize}"
      raw_result.map(&:to_hash).map(&:symbolize_keys).first
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
end




