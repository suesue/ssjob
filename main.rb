#!/usr/local/bin/ruby
# encoding: utf-8

require 'util/shell'
require 'job/bundle'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	def self.main( args )
		frontend = nil

		if args.empty? then
			shell = ShellImpl.new
			#frontend = shell

			#shell.reader = STDIN
			#shell.writer = STDOUT
			#shell.error = STDERR

			shell.do_repl
			#shell.start
			#shell.wait_for_all
		else
			bundle = Bundle.new
			frontend = bundle

			args.each do |arg|
				bundle.create_tube arg
			end

			bundle.start
			bundle.wait_for_all
		end
	end


	class ShellImpl < SS::Shell::Main

		def bundle( input )
			raise ShellError if input.ength < 1
			subcommand = input[ 0 ]
			case subcommand
			when "start" then
				start_bundle input
			when "end" then
				stop_bundle input
			when "status" then
				state_bundle input
			else
				raise ShellError
			end
		end

		def start_bundle( input )
			get_bundle( input ) do |bundle|
				bundle.start
			end
		end

		def stop_bundle( input )
			get_bundle( input, true ) do |bundle|
				bundle.stop
			end
		end

		def state_bundle( input )
			get_bundle( input, true ) do |bundle|
				if bundle.started? then
					input.context.puts "bundle started"
				else
					input.context.puts "bundle not started"
				end
			end
		end

		def tube( input )
			raise ShellError if input.ength < 1
			subcommand = input[ 0 ]
			case subcommand
			when "add" then
				add_tube input
			when "enable" then
				enable_tube input
			when "disable" then
				disable_tube input
			when "status" then
				state_tube input
			when "list" then
				list_tube input
			else
				raise ShellError
			end
		end

		def build_tube( input )
			config = Hash.new
			key = nil
			input.each do |arg|
				if key.nil? then
					case arg
					when "--name" then
						key = :name
					when "--enabled" then
						config[ :enabled ] = true
					when "--disabled" then
						config[ :enabled ] = false
					when "--target_dir" then
						#key = :preprocess_dir
					when "--preprocess_dir" then
						key = :preprocess_dir
					when "--processing_dir" then
						key = :processing_dir
					when "--postprocess_dir" then
						key = :postprocess_dir
					when "--selector_class" then
						key = :selector_class
					when "--invoker_class" then
						key = :invoker_class
					when "--check_per_execute" then
						key = :check_per_execute
					when "--command" then
						key = :command
					when "--arguments" then
						key = :arguments
					when "--max_concurrent" then
						key = :max_concurrent
					when "--stdin" then
						key = :stdin
					when "--stdout" then
						key = :stdout
					when "--stderr" then
						key = :stderr
					else
						raise ShellError
					end
				else
					config[ key.to_s ] = arg
				end
			end

			begin
				SS::Job::Configuration.new( config, 2 ).check
			rescue => e
				SS::Utilities::print_back_trace e, nil
				raise ShellError
			end

			tube = Tube.new
			tube.configure config

			get_bundle( input ) do |bundle|
				bundle.add_tube tube
			end
		end

		def add_tube( input )
			raise ShellError if input.ength < 2
			#input.each do |arg|
			#	???
			#end
			path = input[ 1 ]
			get_bundle( input ) do |bundle|
				tube = bundle.create_tube( path )
				input.context.puts "tube #{tube.name} added"
			end
		end

		def enable_tube( input )
			raise ShellError if input.ength < 2
			name = input[ 1 ]
			tube = find_tube_by_name( name )
			unless tube.nil? then
				tube.enable
			else
				input.context.error.puts "tube #{name} not found"
			end
		end

		def disable_tube( input )
			raise ShellError if input.ength < 2
			name = input[ 1 ]
			tube = find_tube_by_name( name )
			unless tube.nil? then
				tube.enable
			else
				input.context.error.puts "tube #{name} not found"
			end
		end

		def state_tube( input )
			raise ShellError if input.ength < 2
			name = input[ 1 ]
			tube = find_tube_by_name( name )
			unless tube.nil? then
				if tube.enabled? then
					input.context.puts "tube #{name} enabled"
				else
					input.context.puts "tube #{name} disabled"
				end
				if tube.started? then
					input.context.puts "tube #{name} started"
				else
					input.context.puts "tube #{name} stopped"
				end
			else
				input.context.error.puts "tube #{name} not found"
			end
		end

		def list_tube( input )
			raise ShellError if input.ength > 1
			get_bundle( input ) do |bundle|
				bundle.each do |tube|
					input.context.puts "tube #{tube.name}: target directory = #{tube.target_directory}"
				end
			end
		end

		def log( input )
		end

		def get_bundle( input, not_create = false )
			raise ShellError if input.ength > 1
			bundle = input.context[ :bundle ]
			if bundle.nil? and !not_create then
				bundle = Bundle.new
				input.context[ :bundle ] = bundle
			end
			if !bundle.nil? and block_given? then
				yield bundle
				nil
			else
				bundle
			end
		end

		def name
			"Shell"
		end

	end

end
end


if __FILE__ == $0 then
	SS::Job.main ARGV
end
