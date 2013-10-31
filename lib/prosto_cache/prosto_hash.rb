module ProstoCache
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

    def keys(init = nil)
      @keys = @keys || init || hash.keys
    end

    def values(init = nil)
      @values = @values || init || hash.values
    end

    def_delegators :hash, :to_s, :inspect

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
end
