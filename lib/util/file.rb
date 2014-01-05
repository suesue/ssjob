# encoding: utf-8


#
# suesue_dev@yahoo.co.jp
#
module SS
module Utilities

	class File
		attr_reader :path


		def initialize( path )
			raise if path.nil?
			@path = path
		end

		def ==( other )
			return false if other.nil?
			return false unless other.kind_of? File
			return ::File.identical?( @path, other.path )
		end

		def file?
			::File.file? @path
		end

		def directory?
			::File.directory? @path
		end

		def name
			::File.basename @path
		end

		def parent
			dir = ::File.dirname( @path )
			File.new dir
		end

		def resolve( name )
			raise if name.nil?
			File.new( ::File.join( @path, name ) )
		end

		def absolute_path
			::File.absolute_path @path
		end

		def move_to_directory( dir )
			#puts "#{self.class.name}#move_to_directory: #{@path} -> #{dir}"
			raise unless file?
			raise unless dir.directory?
			#puts "#{self.class.name}#move_to_directory: file #{@path} -> directory #{dir}"
			to = File.move_file_to_directory( @path, dir.path )
			File.new to
		end

		def glob( pattern )
			raise if pattern.nil?
			raise unless directory?

			list = nil
			Dir.glob( ::File.join( @path, pattern ) ) do |path|
				file = File.new( path )
				if block_given? then
					yield file
				else
					list ||= []
					list << file
				end
			end
			list
		end

		def read
			raise unless block_given?
			open( @path, "r" ) do |f|
				stream = Stream.new( self, f )
				yield stream
			end
		end

		# @Override
		def to_s
			@path
		end


		def self.move_file_to_directory( file, to_dir )
			#puts "#move_file_to_directory: #{file} -> #{to_dir}"
			raise if file.nil?
			raise if to_dir.nil?

			from = file
			to = ::File.join( to_dir, ::File.basename( file ) )

			::File.rename from, to
			#puts "#move_file_to_directory: #{from} -> #{to}"
			to
		end

		def self.from_URI( uri )
		end

	end


	class Stream
		attr_reader :file
		attr_reader :body


		def initialize( ss, file )
			raise if ss.nil?
			raise if file.nil?
			@file = ss
			@body = file
		end

	end

end
end
