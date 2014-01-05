# encoding: utf-8

require 'job/file_selector'
require 'util/logging'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class DefaultFileSelector < FileSelector
		include SS::Logging::Loggable


		def select( target_directory )
			debug "#select: #{target_directory}"
			target_directory.glob( "*" ) do |file|
				next if file.name == Tube::CONFIGURATION_FILE_NAME
				debug "#select: #{file} selected"
				yield file
				debug "#select: #{target_directory} any more?"
				return self if @config[ :check_per_execute ]
			end
			debug "#select: #{target_directory} no more"
			return nil
		end

		def configure( config )
			@config = config
		end

	end

end
end
