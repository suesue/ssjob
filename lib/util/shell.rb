# encoding: utf-8

require 'util/logging'
require 'monitor'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Shell

	class Main
		include SS::Logging::Loggable


		attr_accessor :reader
		attr_accessor :writer
		attr_accessor :error


		def initialize
			@lock = Monitor.new
			@cond = @lock.new_cond
			@interrupted = false
		end

		def start
			@lock.synchronize do
				raise unless @thread.nil?
				@thread = Thread.fork do
					do_repl
				end
			end
		end

		def stop
			@lock.synchronize do
				return if @thread.nil?
				@thread.kill
				@thread = nil
				@cond.boardcast
			end
		end

		def wait_for_all
			puts "#{self.class.name}#wait_for_all: called"
			@lock.synchronize do
				@cond.wait_until do
					@thread.nil?
				end
			end
			trace "#wait_for_all: exiting"
		end

		def do_repl( context = nil )
			#puts "#{self.class.name}#do_repl: called"
			context ||= Context.new

			context.puts name

			while !interrupted? do
				begin
					context.puts ""
					context.writer.write "[#{context.number + 1}]> "

					input = context.read_next

					next if input.empty?
					context.input_ok

					dispatch input
				rescue QuitError => e
					break
				rescue ShellError => e
					SS::Utilities::print_back_trace e, nil
#				rescue => e
#					SS::Utilities::print_back_trace e, nil
				end
			end
		end

		def interrupt
			@lock.synchronize do
				@interrupted = true
				@cond.broadcast
			end
		end

		def interrupted?
			@lock.synchronize do
				@interrupted
			end
		end

		def dispatch( input )
			if input.name == ":" or input.name[ 0 ] == ":" then
				default input
			elsif has?( input.name ) then
				get( input.name ).execute input
			elsif self.respond_to?( input.name.to_sym ) then
				self.__send__ input.name, input
			else
				context.error.puts "unknown command: #{input.name}"
			end
		end

		def has?( name )
			return false if name.nil?
			return false if @commands.nil?
			return @commands.key?( name.to_sym )
		end

		def get( name )
			return nil if name.nil?
			return nil if @commands.nil?
			return @commands[ name.to_sym ]
		end

		def add( name, command )
			raise if name.nil?
			raise if command.nil?
			raise if command.respond_to? :execute
			key = name.to_sym
			if @commands.nil? then
				@commands = Hash.new
			elsif @commands.key?( key ) then
				raise
			end
			@commands[ key ] = command
		end

		def replace( name, command )
			raise if name.nil?
			raise if command.nil?
			raise if command.respond_to? :execute
			key = name.to_sym
			if @commands.nil? then
				@commands = Hash.new
			end
			@commands[ key ] = command
		end

		def remove( name )
			raise if name.nil?
			raise if @commands.nil?
			key = name.to_sym
			raise unless @commands.key?( key )
			@commands.delete key
		end

		def names
			@commands.nil? ? []: @commands.keys
		end

		def quit( input )
			raise QuitError
		end

		def default( input )
			system input
		end

		def system( input )
			raise if input.line.nil?
			if /\A\s*:\s*(.*)[\r\n]*\z/ =~ input.line then
				#puts "#{self.class.name}#system: \"#{$1}\""
				command_line = $1
				begin
					out = `#{command_line}`
					input.context.puts out
				rescue => e
					SS::Utilities::print_back_trace e, nil
					raise ShellError
				end
			else
				raise ShellError
			end
		end

		def load( input )
			raise if input.length != 1

			begin
				load input[ 0 ]
			rescue => e
				SS::Utilities::print_back_trace e, nil
				raise ShellError
			end
		end

		def name
			"SSJob Shell"
		end

	end


	class Input
		attr_reader :number
		attr_reader :line
		attr_reader :name
		attr_reader :context


		def initialize( context, number = -1 )
			raise if context.nil?
			@context = context
			@number = number
		end

		def read( input )
			raise if input.nil?

			line = input.gets
			@line = line

			rest = line.chomp
			args = []
			while !rest.nil? do
				#puts "#{self.class.name}#read: rest = \"#{rest}\""
				case rest
				when "" then
					#puts "#{self.class.name}#read: A "
					rest = nil
					next
				when /\A\s+(.*)\z/ then
					#puts "#{self.class.name}#read: B "
					rest = $1
				else
					#puts "#{self.class.name}#read: C "
					raise unless args.empty?
				end

				case rest
				when "" then
					#puts "#{self.class.name}#read: D "
					rest = nil
				when /\A([^"\s]+)(.*)\z/ then
					#puts "#{self.class.name}#read: E #{$1}"
					args << $1
					rest = $2
				when /\A""(.*)\z/ then
					#puts "#{self.class.name}#read: F "
					args << ""
					rest = $1
				when /\A"([^"]+)"(.*)\z/ then
					#puts "#{self.class.name}#read: G #{$1}"
					args << $1
					rest = $2
				when /\A"((?:[^\"]*\")+)"(.*)\z/ then
					#puts "#{self.class.name}#read: H #{$1}"
					args << $1
					rest = $2
				else
					raise "ERROR(2): #{line}"
					#rest = nil
				end
			end

			return if args.empty?

			@name = args.shift
			@args = args

			freeze
			self
		end

		def args
			@args.nil? ? []: @args.clone
		end

		def length
			@args.nil? ? 0: @args.length
		end

		def []( index )
			if index == :name then
				@name
			elsif 0 <= index and index < length then
				@args[ index ]
			else
				raise
			end
		end

		def empty?
			@name.nil?
		end

		def each
			raise unless block_given?
			@args.each do |arg|
				yield arg
			end
			self
		end

	end


	class Context
		attr_reader :lock
		attr_reader :cond
		attr_reader :reader
		attr_reader :writer
		attr_reader :error
		attr_reader :number


		def initialize
			@lock = Monitor.new
			@cond = @lock.new_cond
			@number = 0
			@reader = STDIN
			@writer = STDOUT
			@error = STDERR
			#@lock.synchronize do
			#	reader = SS::Utilities::check_nil( @reader )
			#	writer = SS::Utilities::check_nil( @writer )
			#	error = SS::Utilities::check_nil( @error )
			#end
		end

		def read_next
			input = Input.new( self, @number )
			input.read @reader
			input
		end

		def input_ok
			@number += 1
		end

		def []( key )
			@properties ||= Hash.new
			@properties[ key ]
		end

		def []=( key, value )
			@properties ||= Hash.new
			@properties[ key ] = value
		end

		def puts( message )
			@writer.puts message
		end

	end


	class ShellError < StandardError
		attr_reader :cause


		def set_cause( error )
			return false unless @cause.nil?
			@cause = error
			true
		end

	end


	class QuitError < ShellError
	end

end
end
