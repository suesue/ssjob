# encoding: utf-8

require 'util/logging'
require 'rbconfig'
require 'uri'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class StandardIO
		include SS::Logging::Loggable

		attr_reader :stdin
		attr_reader :stdout
		attr_reader :stderr


		def initialize( config )
			@stdin = URI.parse( config[ "stdin" ] ) unless config[ "stdin" ].nil?
			@stdout = URI.parse( config[ "stdout" ] ) unless config[ "stdout" ].nil?
			@stderr = URI.parse( config[ "stderr" ] ) unless config[ "stderr" ].nil?
		end

		def reopen
			debug "#reopen: stdin  = #{@stdin}"
			debug "#reopen: stdout = #{@stdout}"
			debug "#reopen: stderr = #{@stderr}"
			raise if standard_in? @stdout
			raise if standard_in? @stderr
			raise if standard_err? @stdout and standard_out? @stderr
			raise if standard_out? @stdin
			raise if standard_err? @stdin
			debug "#reopen: no rejected"

			reopen_io STDIN, @stdin, false unless standard_in? @stdin

			if standard_out? @stderr then
				debug "#reopen: reconnect STDOUT to stderr"
				if @stdout.nil? or standard_out? @stdout then
				else
					reopen_io STDOUT, @stdout
				end
				$stderr = STDOUT
				return
			end

			if standard_err? @stdout then
				debug "#reopen: reconnect STDERR to stdout"
				if @stderr.nil? or standard_err? @stderr then
				else
					reopen_io STDERR, @stderr
				end
				$stdout = STDERR
				return
			end

			reopen_io STDOUT, @stdout
			reopen_io STDERR, @stderr
		end

		def standard_in?( uri )
			standard_io? uri, "STDIN", "0"
		end

		def standard_out?( uri )
			standard_io? uri, "STDOUT", "1"
		end

		def standard_err?( uri )
			standard_io? uri, "STDERR", "2"
		end

		def standard_io?( uri, name, fd )
			trace "#standard_io?: uri = #{uri}, name = #{name}, fd = #{fd}"
			return false if uri.nil?
			return false unless uri.scheme == "stream"
			return false if uri.opaque.nil?

			debug "#standard_io?: URI opaque = #{uri.opaque}"
			case uri.opaque.upcase
			when name then
				debug "#standard_io?: match with name: #{name}"
				return true
			when fd then
				debug "#standard_io?: match with FD: #{fd}"
				return true
			else
				debug "#standard_io?: not match"
				return false
			end
		end

		def reopen_io( io, uri, out = true )
			trace "#reopen_io: io = #{io}, uri = #{uri}, out = #{out}"
			raise if io.nil?
			return if uri.nil?

			stream = open_uri( uri, out )
			unless stream.nil? then
				io.reopen stream
			end
		end

		def open_uri( uri, out = true )
			trace "#open_uri: uri = #{uri}, out = #{out}"
			return if uri.nil?
			debug "#open_uri: uri -> { scheme = #{uri.scheme}, user info. = #{uri.userinfo}, host = #{uri.host}, port = #{uri.port}, registry = #{uri.registry}, path = #{uri.path}, opaque = #{uri.opaque}, query = #{uri.query}, fragment = #{uri.fragment} }"

			flag = out ? "w": "r"
			case uri.scheme
			when "stream"
				fd = uri.path.nil? ? uri.opaque: uri.path
#				stream = IO.new( fd.to_i, flag )
				warn "#open_uri: NOT IMPLEMENTED CORRECTLY"
				stream = IO.new( fd.to_i )
			when "file"
				path = uri.path.nil? ? uri.opaque: uri.path
				stream = open( path, flag )
			else
				raise "#{uri}"
			end

			stream
		end

	end

end
end
