module Moneta
  autoload :Builder,           'moneta/builder'
  autoload :Cache,             'moneta/cache'
  autoload :Defaults,          'moneta/mixins'
  autoload :Expires,           'moneta/expires'
  autoload :HashAdapter,       'moneta/mixins'
  autoload :IncrementSupport,  'moneta/mixins'
  autoload :Lock,              'moneta/lock'
  autoload :Logger,            'moneta/logger'
  autoload :Net,               'moneta/mixins'
  autoload :OptionMerger,      'moneta/optionmerger'
  autoload :OptionSupport,     'moneta/mixins'
  autoload :Proxy,             'moneta/proxy'
  autoload :Server,            'moneta/server'
  autoload :Shared,            'moneta/shared'
  autoload :Stack,             'moneta/stack'
  autoload :Transformer,       'moneta/transformer'
  autoload :Wrapper,           'moneta/wrapper'

  module Adapters
    autoload :ActiveRecord,    'moneta/adapters/activerecord'
    autoload :Cassandra,       'moneta/adapters/cassandra'
    autoload :Client,          'moneta/adapters/client'
    autoload :Cookie,          'moneta/adapters/cookie'
    autoload :Couch,           'moneta/adapters/couch'
    autoload :DBM,             'moneta/adapters/dbm'
    autoload :DataMapper,      'moneta/adapters/datamapper'
    autoload :File,            'moneta/adapters/file'
    autoload :Fog,             'moneta/adapters/fog'
    autoload :GDBM,            'moneta/adapters/gdbm'
    autoload :HBase,           'moneta/adapters/hbase'
    autoload :LRUHash,         'moneta/adapters/lruhash'
    autoload :LevelDB,         'moneta/adapters/leveldb'
    autoload :LocalMemCache,   'moneta/adapters/localmemcache'
    autoload :Memcached,       'moneta/adapters/memcached'
    autoload :MemcachedDalli,  'moneta/adapters/memcached/dalli'
    autoload :MemcachedNative, 'moneta/adapters/memcached/native'
    autoload :Memory,          'moneta/adapters/memory'
    autoload :Mongo,           'moneta/adapters/mongo'
    autoload :Null,            'moneta/adapters/null'
    autoload :PStore,          'moneta/adapters/pstore'
    autoload :Redis,           'moneta/adapters/redis'
    autoload :Riak,            'moneta/adapters/riak'
    autoload :SDBM,            'moneta/adapters/sdbm'
    autoload :Sequel,          'moneta/adapters/sequel'
    autoload :Sqlite,          'moneta/adapters/sqlite'
    autoload :TokyoCabinet,    'moneta/adapters/tokyocabinet'
    autoload :YAML,            'moneta/adapters/yaml'
  end

  # Create new Moneta store with default proxies
  #
  # This works in most cases if you don't want fine
  # control over the proxy stack. It uses Marshal on the
  # keys and values. Use Moneta#build if you want to have fine control!
  #
  # @param [Symbol] name Name of adapter (See Moneta::Adapters)
  # @param [Hash] options
  # @return [Moneta store] newly created Moneta store
  # @option options [Boolean/Integer] :expires Ensure that store supports expiration by inserting
  #                                            `Moneta::Expires` if the underlying adapter doesn't support it natively
  #                                            and set default expiration time
  # @option options [Boolean] :threadsafe (false) Ensure that the store is thread safe by inserting Moneta::Lock
  # @option options [Boolean/Hash] :logger (false) Add logger to proxy stack (Hash is passed to logger as options)
  # @option options [Boolean/Symbol] :compress (false) If true, compress value with zlib, or specify custom compress, e.g. :quicklz
  # @option options [Symbol] :serializer (:marshal) Serializer used for key and value, disable with nil
  # @option options [Symbol] :key_serializer (options[:serializer]) Serializer used for key, disable with nil
  # @option options [Symbol] :value_serializer (options[:serializer]) Serializer used for value, disable with nil
  # @option options [String] :prefix Key prefix used for namespacing (default none)
  # @option options All other options passed to the adapter
  #
  # Supported adapters:
  # * :HashFile (Store which spreads the entries using a md5 hash, e.g. cache/42/391dd7535aebef91b823286ac67fcd)
  # * :File (normal file store)
  # * :Memcached (Memcached store)
  # * ... (All other adapters from Moneta::Adapters)
  #
  # @api public
  def self.new(name, options = {})
    expires = options.delete(:expires)
    logger = options.delete(:logger)
    threadsafe = options.delete(:threadsafe)
    compress = options.delete(:compress)
    serializer = options.include?(:serializer) ? options.delete(:serializer) : :marshal
    key_serializer = options.include?(:key_serializer) ? options.delete(:key_serializer) : serializer
    value_serializer = options.include?(:value_serializer) ? options.delete(:value_serializer) : serializer
    transformer = { :key => [key_serializer, :prefix], :value => [value_serializer], :prefix => options.delete(:prefix) }
    transformer[:value] << (Symbol === compress ? compress : :zlib) if compress
    raise ArgumentError, 'Name must be Symbol' unless Symbol === name
    case name
    when :Sequel, :ActiveRecord, :Couch, :DataMapper
      # Sequel accept only base64 keys and values
      # FIXME: Couch should work only with :marshal but this raises an error on 1.9
      transformer[:key] << :base64
      transformer[:value] << :base64
    when :Riak
      # Riak accepts only utf-8 keys over the http interface
      # We use base64 encoding therefore.
      transformer[:key] << :base64
    when :Memcached, :MemcachedDalli, :MemcachedNative
      # Memcached supports expires already
      options[:expires] = expires if Integer === expires
      expires = false
    when :PStore, :YAML, :Null
      # For PStore and YAML only the key has to be a string
      transformer.delete(:value) if transformer[:value] == [:marshal]
    when :HashFile
      # Use spreading hashes
      transformer[:key] << :md5 << :spread
      name = :File
    when :File
      # Use escaping
      transformer[:key] << :escape
    when :Cassandra, :Redis
      # Expires already supported
      options[:expires] = expires if Integer === expires
      expires = false
    end
    build do
      use :Logger, Hash === logger ? logger : {} if logger
      use :Expires, :expires => (Integer === expires ? expires : nil) if expires
      use :Transformer, transformer
      use :Lock if threadsafe
      adapter name, options
    end
  end

  # Configure your own Moneta proxy stack!
  #
  # @return [Moneta store] newly created Moneta store
  #
  # @example Moneta builder
  #   Moneta.build do
  #     use :Expires
  #     adapter :Memory
  #   end
  #
  # @api public
  def self.build(&block)
    Builder.new(&block).build.last
  end
end
