require 'set'

module Kasket
  class Cache
    def initialize(cache_store)
      @cache_store = cache_store
    end

    def clear
      @cache_store.clear
    end

    def read(key)
      @cache_store.read(key) unless blacklisted?(key)
    end

    def read_multi(*args)
      args = args - blacklist.to_a
      @cache_store.read_multi(*args)
    end

    def write(key, value, options = {})
      @cache_store.write(key, value, options) unless blacklisted?(key)
    end

    def delete(key)
      @cache_store.delete(key) unless blacklisted?(key)
    end

    def clear_blacklist
      blacklist.clear
    end

    def add_to_blacklist(keys)
      blacklist.merge(keys)
    end

    private

    def blacklist
      Thread.current['kasket_blacklist'] ||= Set.new
    end

    def blacklisted?(key)
      blacklist.include?(key)
    end
  end
end
