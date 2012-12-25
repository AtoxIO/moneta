module Moneta
  # Combines two stores. One is used as cache, the other as backend.
  #
  # @example Add `Moneta::Cache` to proxy stack
  #   Moneta.build do
  #     use(:Cache) do
  #      backend { adapter :File, :dir => 'data' }
  #      cache { adapter :Memory }
  #     end
  #   end
  #
  # @api public
  class Cache
    include Defaults

    # @api private
    class DSL
      def initialize(options, &block)
        @cache, @backend = options[:cache], options[:backend]
        instance_eval(&block)
      end

      def backend(store = nil, &block)
        raise 'Backend already set' if @backend
        raise ArgumentError, 'Only argument or block allowed' if store && block
        @backend = store || Moneta.build(&block)
      end

      def cache(store = nil, &block)
        raise 'Cache already set' if @cache
        raise ArgumentError, 'Only argument or block allowed' if store && block
        @cache = store || Moneta.build(&block)
      end

      def result
        [@cache, @backend]
      end
    end

    attr_reader :cache, :backend

    def initialize(options = {}, &block)
      @cache, @backend = DSL.new(options, &block).result
    end

    def key?(key, options = {})
      @cache.key?(key, options) || @backend.key?(key, options)
    end

    def load(key, options = {})
      value = @cache.load(key, options)
      if value == nil
        value = @backend.load(key, options)
        @cache.store(key, value, options) if value != nil
      end
      value
    end

    def store(key, value, options = {})
      @cache.store(key, value, options)
      @backend.store(key, value, options)
    end

    def increment(key, amount = 1, options = {})
      @cache.delete(key, options)
      @backend.increment(key, amount, options)
    end

    def delete(key, options = {})
      @cache.delete(key, options)
      @backend.delete(key, options)
    end

    def clear(options = {})
      @cache.clear(options)
      @backend.clear(options)
      self
    end

    def close
      @cache.close
      @backend.close
    end
  end
end
