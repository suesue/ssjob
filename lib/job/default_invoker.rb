# encoding: utf-8

require 'job/invoker'
require 'util/logging'


#
# suesue_dev@yahoo.co.jp
#
module SS
module Job

	class DefaultInvoker < Invoker
		include SS::Logging::Loggable


		def invoke( command, target_file, arguments )
			trace "#invoke: command = #{command}, target_file = #{target_file}, arguments = #{arguments}"
			child_pid = fork do
				debug "#invoke: child #{$$}/ forked"
				#debug "#invoke: config.bottom = #{@config.bottom}"
				@config.bottom[ :binding ] = binding
				#@config.bottom[ "target_file_path" ] = target_file.path
				#@config.bottom[ "target_file_name" ] = target_file.name
				@config.bottom[ "process_id" ] = $$
				#debug "#invoke: config.bottom = #{@config.bottom}"
				config = @config.copy.reload( 3 ).check
				#debug "#invoke: config.bottom = #{config.bottom}"
				command2 = config[ :command ]
				arguments2 = config[ :arguments ]

				info "#{command2} #{arguments2}"

				config[ :standard_io ].reopen
				exec "#{command2} #{arguments2}"
			end
			info "#invoke: parent #{$$}/ child #{child_pid} forked"
			Process.waitpid child_pid

			exit_status = $?
			info "#invoke: parent #{$$}/ child #{child_pid} done by exit code #{exit_status.exitstatus}"
			if exit_status.exitstatus != 0 then
				# error !
				raise "child process #{child_pid} exited by #{exit_status.exitstatus}"
			end
		end

		def configure( config )
			@config = config
		end

	end

end
end
