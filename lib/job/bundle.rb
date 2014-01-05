# encoding: utf-8

require 'job/tube'
require 'util/file'
require 'util/event'
require 'util/logging'
require 'monitor'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class Bundle < SS::Event::Listener
		include SS::Logging::Loggable

		#@tubes
		#@started


		def initialize
			@lock = Monitor.new
			@cond = @lock.new_cond
			@tubes = []
			@running_tubes = []
			@started = false
		end

		# @override SS::Event::Listener
		def listen( event )
			return if event.nil?
			debug "#listen: event [ #{event.category}/#{event.type} ] arrived from #{event.source}"
			tube = event.source
			@lock.synchronize do
				case event.type
				when :done then
					@tubes.delete tube
					@cond.broadcast
				when :errored then
					@tubes.delete tube
					@cond.broadcast
				end
			end
		end

		def create_tube( path )
			file = SS::Utilities::File.new( path )
			tube = Tube.new( file )
			add_tube tube
		end

		def add_tube( tube )
			tube.add_listener self

			@lock.synchronize do
				if @started and tube.configured? then
					start_tube tube
					@running_tubes << tube
				else
					@tubes << tube
				end
			end

			tube
		end

		def find_tube_by_name( name )
			each do |tube|
				if tube == name then
					if block_given? then
						yield tube
						return nil
					else
						return tube
					end
				end
			end
			nil
		end

		def configure_tubes( config )
			raise if config.nil?
			@lock.synchronize do
				@tubes.each do |tube|
					tube.configure config
				end
			end
		end

		def start
			flag = nil
			@lock.synchronize do
				raise if @started
				flag = true
				@started = flag
				tubes = @tubes
				@tubes = []
				tubes.each do |tube|
					next unless tube.enabled?
					start_tube tube
					@running_tubes << tube
				end
			end
			flag
		end

		def start_tube( tube )
			raise if tube.nil?
			debug "#start_tube: starting Tube[ #{tube.name} ]"
			tube.start
			info "Tube[ #{tube.name} ] started @ #{tube.config[:preprocess_dir].absolute_path}"
		end

		def stop
			@lock.synchronize do
				#return nil unless @started
				running_tubes = @running_tubes
				@running_tubes = []
				running_tubes.each do |tube|
					tube.stop
				end
			end
		end

		def started?
			@lock.synchronize do
				return @started
			end
		end

		def wait_for_all
			trace "#wait_for_all: entered"
			@lock.synchronize do
				@cond.wait_until do
					@running_tubes.empty?
				end
			end
			trace "#wait_for_all: exiting"
		end

		def each
			return nil unless block_given?
			@lock.synchronize do
				#return nil unless @started
				@tubes.each do |tube|
					yield tube
				end
			end
			return self
		end

		def duplicated?( path )
			check_directory( path ) > 1
		end

		def existed?( path )
			check_directory( path ) > 0
		end

		def check_directory( path )
			dir = SS::Utilities::File.new( path )
			count = 0
			@lock.synchronize do
				@tubes.each do |tube|
					count.succ if tube.target_directory == dir
				end
			end
			count
		end

		def check_name( name )
			count = 0
			@lock.synchronize do
				@tubes.each do |tube|
					count.succ if tube.name == name
				end
			end
			count
		end

	end

end
end
