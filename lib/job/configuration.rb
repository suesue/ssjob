# encoding: utf-8

require 'job/standard_io'
require 'util/macro'
require 'util/logging'
require 'rbconfig'
require 'uri'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class Configuration
		include SS::Logging::Loggable

		DEFAULT_CONCURRENT = 8


		attr_reader :name
		attr_reader :level


		def initialize( config, level = -1 )
			raise if config.nil?
			@not_macro = config
			@level = level
			@enabled = false
			reload level
		end

		# @Override
		#def initialize_copy
		#end

		def reload( level = -1 )
			trace "#reload: called"
			load( @not_macro ) if level < 0 or 0 < level
			load2( @config ) if level < 0 or 1 < level
			load3( @config ) if level < 0 or 2 < level
			self
		end

		def load( config )
			trace "#load: called"
			raise if config.nil?

			#reset

			config = SS::Utilities::MacroHash.new( @top, config, @bottom )
			@top = config.top
			@bottom = config.bottom
			@config = config

			@name = config[ "name" ]
			@enabled = config[ "enabled" ]

			if !config[ "command" ].nil? then
				@command = config[ "command" ]
			elsif !config[ "script" ].nil? then
				script = config[ "script" ]
				@command = "#{RbConfig.ruby} #{script}"
			else
				raise "command not defined"
			end
			@arguments = config[ "arguments" ]
			value = config[ "max_concurrent" ]
			@max_concurrent = value.nil? ? DEFAULT_CONCURRENT: value.to_i

			@check_per_execute = config[ "check_per_execute" ].nil? ? true: config[ "check_per_execute" ]
			@selector_class = config[ "selector_class" ]
			@invoker_class = config[ "invoker_class" ]

			self
		end

		def load2( config )
			trace "#load2: called"
			raise if config.nil?

			#read_target_directory config
			read_directory_path( config, "preprocess_directory" ) do |dir|
				@preprocess_dir = dir
				@name = File.dirname( dir.path ) if @name.nil?
			end

			read_directory_path( config, "postprocess_directory" ) do |dir|
				@postprocess_directory = dir
			end

			read_directory_path( config, "processing_directory" ) do |dir|
				@processing_directory = dir
			end

			self
		end

		def load3( config )
			trace "#load3: called"
			raise if config.nil?

			@standard_io = StandardIO.new( config )

			self
		end

		def read_target_directory( config )
			read_directory_path( config, "target_directory" ) do |dir|
				self.target_directory = dir
			end
		end

		def target_directory=( dir )
			debug "#target_directory: dir = #{dir}"

			preprocess_dir = dir.resolve( "preprocess" )
			debug "#target_directory: preprocess_dir = #{preprocess_dir}"
			raise "preprocess directory #{preprocess_dir} not directory" unless preprocess_dir.directory?

			processing_dir = dir.resolve( "processing" )
			debug "#target_directory: processing_dir = #{processing_dir}"
			raise "processing directory #{processing_dir.path} not directory" unless processing_dir.directory?

			postprocess_dir = dir.resolve( "postprocess" )
			debug "#target_directory: postprocess_dir = #{postprocess_dir}"
			raise "postprocess directory #{postprocess_dir} not directory" unless postprocess_dir.directory?

			@preprocess_dir = preprocess_dir
			@processing_dir = processing_dir
			@postprocess_dir = postprocess_dir

			@name = dir.name if @name.nil?
		end

		def read_directory_path( config, key )
			dir = nil
			value = config[ key ]
			debug "#read_directory_path: key = #{key} -> value = #{value}"
			unless value.nil? then
				dir = SSFile.new( value )
				raise "#{key} #{dir} not directory" unless dir.directory?
				yield dir if block_given?
			end
			dir
		end

		def reset
			trace "#reset: called"
			@config = nil
			@name = nil
			@enabled = false
			@preprocess_dir = nil
			@processing_dir = nil
			@postprocess_dir = nil
			@invoker_class = nil
			@selector_class = nil
			@check_per_execute = nil
			@command = nil
			@arguments = nil
			@max_concurrent = nil
			@standard_io = nil
			self
		end

		def check
			raise "not configured" if @config.nil?
			raise "not configured correctly: name not set" if @name.nil?
			raise "not configured correctly: command not set" if @command.nil?
			raise "not configured correctly: preprocess_dir not set" if @preprocess_dir.nil?
			raise "not configured correctly: #{@preprocess_dir} not directory" unless @preprocess_dir.directory?
			self
		end

		def []( key )
			trace "#[]: called"

			if @config.nil? then
				level = -1
				case key
				when :name, :enabled, :command, :arguments, :max_concurrent, :check_per_execute, :selector_class, :invoker_class then
					level = 1
				when :preprocess_dir, :processing_dir, :postprocess_dir then
					level = 2
				when :standard_io then
					level = 3
				else
					level = 0
				end
				reload level
			end

			case key
			when :name then
				@name
			when :enabled then
				@enabled
			when :preprocess_dir then
				@preprocess_dir
			when :processing_dir then
				@processing_dir
			when :postprocess_dir then
				@postprocess_dir
			when :selector_class then
				@selector_class
			when :invoker_class then
				@invoker_class
			when :check_per_execute then
				@check_per_execute
			when :command then
				@command
			when :arguments then
				@arguments
			when :max_concurrent then
				@max_concurrent
			when :standard_io then
				@standard_io
			else
				@config[ key ]
			end
		end

		def []=( key, value )
			case key
			when :enabled then
				@enabled = value
			else
				raise
			end
		end

		def copy
			trace "#copy: called"
			config = Configuration.new( @not_macro, @level )
			config.set_top @top.clone unless @top.nil?
			config.set_bottom @bottom.clone unless @bottom.nil?
			config
		end

		def top
			trace "#top: called"
			reload( 1 ) if @config.nil?
			@config.top
		end

		def set_top( hash )
			@top = hash
		end

		def bottom
			trace "#bottom: called"
			reload( 1 ) if @config.nil?
			@config.bottom
		end

		def set_bottom( hash )
			@bottom = hash
		end

	end

end
end
