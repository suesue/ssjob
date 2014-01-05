# encoding: utf-8


#
# suesue_dev@yahoo.co.jp
#
module SS
module Event

	class Listener

		def listen( event )
			yield event if block_given?
		end

	end

	class Event
		attr_reader :source
		attr_reader :category
		attr_reader :type


		def initialize( source, category, type, parameters = nil )
			raise if source.nil?
			raise if category.nil?
			raise if type.nil?
			@source = source
			@category = category
			@type = type.to_sym
			@parameters = parameters
		end

		def []=( key )
			@parameters.nil? ? nil: @parameters[ key ]
		end

	end

	module Support

		def add_listener( listener = nil, &proc )
			if listener.nil? then
				if block_given? then
					@listeners ||= []
					@listeners << proc
				else
					# both not given !
					return
				end
			else
				if block_given? then
					# both given !
					raise
				else
					@listeners ||= []
					@listeners << listener
				end
			end
		end

		def remove_listener( listener )
			return if listener.nil?
			return if @listeners.nil?
			@listeners.delete listener
		end

		def fire_event_of( category, event_type, parameters = nil )
			fire_event( Event.new( self, category, event_type, parameters ) ) unless @listeners.nil? or @listeners.empty?
		end

		def fire_event( event )
			return if event.nil?
			return if @listeners.nil?
			@listeners.each do |listener|
#				if listener.proc? then
#					listener.call event
#				elsif defined? listener.listen then
				if defined? listener.listen then
					listener.listen event
				else
					listen_event_by listener, event
				end
			end
		end

		def listen_event_by( listener, event )
		end

	end

end
end
