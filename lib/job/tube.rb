# encoding: utf-8

require 'job/yaml_configuration'
require 'job/default_file_selector'
require 'job/default_invoker'
require 'util/event'
require 'util/logging'
require 'monitor'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class Tube
		include SS::Logging::Loggable
		include SS::Event::Support

		CONFIGURATION_FILE_NAME = ".configuration.yaml"


		attr_reader :config


		def initialize( file = nil )
			@lock = Monitor.new
			configure_by_file( file ) unless file.nil?
		end

		def configure_by_file( file )
			raise unless stopped? { @config = nil }
			raise "#{file} not directory" unless file.directory?

			file.resolve( CONFIGURATION_FILE_NAME ).read do |stream|
				config = YAMLConfiguration.new( stream, 0 )
				debug "#configure: #{stream.file} loaded"
				configure config
			end
		end

		def configure( config )
			@lock.synchronize do
				@config = config
			end
		end

		def configured?
			@lock.synchronize do
				!@config.nil?
			end
		end

		def start
			trace "#start: entered"
			fire_event_of Tube, :starting
			@lock.synchronize do
				raise unless @thread.nil?

				config = @config.copy.reload( 2 ).check

				@thread = Thread.fork do
					debug "#start: thread forked"
					failed = true
					target_directory = nil
					begin
						target_directory = config[ :preprocess_dir ]
						debug "Tube[ #{name} ] executing... @ #{target_directory}"
						execute config
						failed = false
						fire_event_of Tube, :done
						debug "Tube[ #{name} ] done @ #{target_directory}"
					rescue #=> e
						error "Tube[ #{name} ] fallen @ #{target_directory}"
						puts e.backtrace
					ensure
						debug "Tube[ #{name} ] after all @ #{target_directory}"
						fire_event_of Tube, :errored if failed
						@lock.synchronize do
							@thread = nil
						end
					end
				end
				debug "#start: thread fork done"
			end
			fire_event_of Tube, :started
			trace "#start: exiting"
		end

		def stop
			@lock.synchronize do
				raise if @thread.nil?
				while @thread.alive? do
					Thread.kill @thread
					sleep_on_check_alive
				end
				@thread = nil
			end
		end

		def sleep_on_check_alive
			sleep 1
		end

		def started?
			@lock.synchronize do
				if !@thread.nil? and @thread.alive? then
					yield if block_given?
					true
				else
					false
				end
			end
		end

		def stopped?
			@lock.synchronize do
				if @thread.nil? or !@thread.alive? then
					yield if block_given?
					true
				else
					false
				end
			end
		end

		def execute( config = nil )
			tid = thread_id
			target_directory = config[ :preprocess_dir ] unless config.nil?
			trace "#execute: [#{tid}] #{name} @ #{target_directory}"
			if config.nil? then
				@lock.synchronize do
					config = @config
				end
			end
			raise if config.nil?

			#puts "#{self.class.name}#execute: config.bottom = #{config.bottom}"
			config.bottom[ "parent_process_id" ] = $$
			config.bottom[ "parent_thread_id" ] = tid 
			#puts "#{self.class.name}#execute: config.bottom = #{config.bottom}"
			selector = create_object( config, config[ :selector_class ], "DefaultFileSelector", "selector" )

			result = nil
			threads = []
			n = 0
			ll = Monitor.new
			cc = ll.new_cond
			while true do
				debug "#execute: [#{tid}] begin"
				ll.synchronize do
					while threads.length >= config[ :max_concurrent ] do
						debug "#execute: [#{tid}] waiting (1)..."
						cc.wait
						debug "#execute: [#{tid}] broken (1)"
					end
				end

				m = 0
				barrier = true
				result = selector.select( target_directory ) do |file|
					debug "#execute: [#{tid}] selection #{n}-#{m}"
					thread = Thread.fork do
						ctid = "0x#{Thread.current.object_id.to_s(16).rjust(16,'0')}"
						debug "#execute: [#{tid}->#{ctid}] file = #{file}"
						config_c = config.copy.reload( 2 ).check
						#puts "#{self.class.name}#execute: config_c.bottom = #{config_c.bottom}"
						config_c.bottom[ "thread_id" ] = ctid 
						#puts "#{self.class.name}#execute: config_c.bottom = #{config_c.bottom}"

						to = nil
						ll.synchronize do
							debug "#execute: [#{tid}->#{ctid}] #{threads.length} threads before adding"
							to = file.move_to_directory( config_c[ :processing_dir ] )
							threads << Thread.current
							barrier = false
							cc.signal
							debug "#execute: [#{tid}->#{ctid}] signal sent"
						end

						begin
							work_on to, config_c
						ensure
							ll.synchronize do
								threads.delete Thread.current
								debug "#execute: [#{tid}->#{ctid}] #{threads.length} threads after deleted"
								cc.signal
								debug "#execute: [#{tid}->#{ctid}] signal sent"
							end
						end
					end
					m += 1
				end

				break if result.nil?

				ll.synchronize do
					while barrier do
						debug "#execute: [#{tid}] waiting (2)..."
						cc.wait
						debug "#execute: [#{tid}] broken (2)"
					end
				end
				n += 1
			end

			threads.each do |thread|
				trace "#execute: [#{tid}] waiting thread #{thread_id(thread)}"
				thread.join
			end

			trace "#execute: [#{tid}] exiting"
		end

		def work_on( file, config )
			trace "#work_on: #{file}"
			invoker = create_object( config, config[ :invoker_class ], "DefaultInvoker", "invoker" )
			begin
				invoker.invoke config[ :command ], file, config[ :arguments ]
			ensure
				file.move_to_directory config[ :postprocess_dir ]
			end
		end

		def create_object( config, class_name, default_class_name, type )
			unless class_name.nil? then
				object = eval "#{class_name}.new"
			else
				object = eval "#{default_class_name}.new"
			end
			debug "#create_object: #{type} = #{object.class.name}"

			if defined? object.configure then
				debug "#create_object: configure #{type}"
				object.configure config
			end

			object
		end

		def name
			@lock.synchronize do
				raise "tube not configured yet" if @config.nil?
				@config.name
			end
		end

		def enabled?
			@lock.synchronize do
				raise "tube not configured yet" if @config.nil?
				@config[ :enabled ]
			end
		end

		def enable
			@lock.synchronize do
				raise "tube not configured yet" if @config.nil?
				@config[ :enabled ] = true
			end
		end

		def disable
			@lock.synchronize do
				raise "tube not configured yet" if @config.nil?
				@config[ :enabled ] = false
			end
		end

		def target_directory
			@lock.synchronize do
				raise "tube not configured yet" if @config.nil?
				@config[ :preprocess_dir ]
			end
		end
		
		def thread_id( thread = Thread.current )
			"0x#{thread.object_id.to_s(16).rjust(16,'0')}"
		end

	end

end
end
