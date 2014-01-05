# encoding: utf-8


#
# suesue_dev@yahoo.co.jp
#
module SS
module Logging

	class Priority
		attr_reader :level
		attr_reader :name


		def initialize( name, level )
			@name = name
			@level = level
		end

		def canonicalize
			case @name
				when TRACE.name then
					return TRACE
				when DEBUG.name then
					return DEBUG
				when INFO.name then
					return INFO
				when WARN.name then
					return WARN
				when ERROR.name then
					return ERROR
				when FATAL.name then
					return FATAL
			end
			case @level
				when TRACE.level then
					return TRACE
				when DEBUG.level then
					return DEBUG
				when INFO.level then
					return INFO
				when WARN.level then
					return WARN
				when ERROR.level then
					return ERROR
				when FATAL.level then
					return FATAL
			end
			return self
		end

		def <=>( other )
			@level <=> other.level
		end

		#@Override
		def to_s
			"Priority [ name = #{@name}, level = #{@level} ]"
		end


		TRACE = Priority.new( :trace, -10000 )
		DEBUG = Priority.new( :debug, 0 )
		INFO = Priority.new( :info, 100 )
		WARN = Priority.new( :warn, 500 )
		ERROR = Priority.new( :error, 1000 )
		FATAL = Priority.new( :fatal, 10000 )
	end


	class DefaultLogger
		attr_accessor :key
		attr_accessor :threshold


		def initialize( key = nil, threshold = nil )
			@key = key
			@threshold = to_not_null( threshold )
		end

		def configure( config )
			raise if config.nil?
		end

		def log( priority, message, error = nil )
			#puts "threshold: #{@threshold}, message level: #{to_not_null(priority)} => result: #{(to_not_null(priority)<=>@threshold)}"
			if enabled?( priority ) then
				text = format( priority, message, error )
				puts text
				puts error.backtrace if error.respond_to? :backtrace
			end
		end

		def format( priority, message, error )
			SS::Logging::format priority, message, error
		end

		def to_not_null( priority )
			priority.nil? ? Priority::INFO: priority
		end

		def enabled?( priority )
			( to_not_null( priority ) <=> to_not_null( @threshold ) ) >= 0
		end

	end


	module Loggable
		attr_reader :logger

		#@name


		def trace( message = nil, error = nil )
			do_log( Priority::TRACE, message, error )
		end

		def debug( message = nil, error = nil )
			do_log( Priority::DEBUG, message, error )
		end

		def info( message = nil, error = nil )
			do_log( Priority::INFO, message, error )
		end

		alias log info

		def warn( message = nil, error = nil )
			do_log( Priority::WARN, message, error )
		end

		def error( message = nil, error = nil )
			do_log( Priority::ERROR, message, error )
		end

		def fatal( message = nil, error = nil )
			do_log( Priority::FATAL, message, error )
		end

		def do_log( priority, message = nil, error = nil )
			priority = Priority::INFO if priority.nil?

			if block_given? then
				message = yield priority, message, error
			else
				message = format( priority, message, error )
			end

			unless @logger.nil? then
				@logger.log priority, message, error
			else
				do_puts message
				do_puts error unless error.nil?
			end
		end

		def log_name
			@name.nil? ? self.class.name: @name
		end

		def format( priority, message, error )
			SS::Logging::format priority, message, error
		end

		def do_puts( message )
			puts message
		end

	end


	def self.format( priority, message, error )
		"#{priority.name} [#{log_name}] #{message}"
	end


end
end
