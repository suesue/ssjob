# encoding: utf-8

require 'job/configuration'
require 'yaml'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class YAMLConfiguration < Configuration
		attr_reader :file


		def initialize( stream, level = -1 )
			raise if stream.nil?

			self.target_directory = stream.file.parent
			config = YAML.load( stream.body )
			#read_target_directory config
			@file = stream.file

			super config, level
		end

		# @Override
		#def initialize_copy
		#end

		# @Override
		def copy
			trace "#copy: called"
			@file.read do |stream|
				config = YAMLConfiguration.new( stream, @level )
				config.set_top @top.clone unless @top.nil?
				config.set_bottom @bottom.clone unless @bottom.nil?
				return config
			end
		end

	end

end
end
