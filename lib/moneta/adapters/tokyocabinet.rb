require 'tokyocabinet'

module Moneta
  module Adapters
    # TokyoCabinet backend
    # @api public
    class TokyoCabinet < Memory
      # Constructor
      #
      # @param [Hash] options
      #
      # Options:
      # * :file - Database file
      # * :type - Database type (default :hdb, :bdb and :hdb possible)
      def initialize(options = {})
        file = options[:file]
        raise ArgumentError, 'Option :file is required' unless options[:file]
        if options[:type] == :bdb
          @memory = ::TokyoCabinet::BDB.new
          @memory.open(file, ::TokyoCabinet::BDB::OWRITER | ::TokyoCabinet::BDB::OCREAT)
        else
          @memory = ::TokyoCabinet::HDB.new
          @memory.open(file, ::TokyoCabinet::HDB::OWRITER | ::TokyoCabinet::HDB::OCREAT)
        end or raise @memory.errmsg(@memory.ecode)
      end

      def delete(key, options = {})
        value = load(key, options)
        if value
          @memory.delete(key)
          value
        end
      end

      def close
        @memory.close
        nil
      end
    end
  end
end