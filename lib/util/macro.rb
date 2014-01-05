# encoding: utf-8


#
# suesue_dev@yahoo.co.jp
#
module SS
module Utilities

	module Macro
		attr_accessor :tokenizer


#		def initialize( hash = nil )
#			unless hash.nil? then
#				raise unless hash.respond_to? :[]
#				@hash = hash
#			end
#		end
#
#		def []( index )
#			raise if self.equal?( @hash )
#			get index, @hash
#		end

		def get( key, *hashes )
			#puts "#{self.class.name}#get: key = #{key}"
			return nil if hashes.nil? or hashes.empty?

			value = value_of( key, hashes[ 0 ] )
			#puts "#{self.class.name}#get: -> raw text = #{value}"
			begin
				expand key, value, *hashes
			rescue => e
				fail e, key, value, *hashes
			end
		end

		def value_of( key, hash )
			raise if hash.nil?
			raise unless hash.respond_to? :[]
			hash[ key ]
		end

		def fail( e, key, value, *hashes )
			#puts e.backtrace
			value
		end

		def expand( key, text, *hashes )
			#puts "#{self.class.name}#expand: key = #{key}"
			#puts "#{self.class.name}#expand: text = #{text}"
			return text if hashes.nil? or hashes.empty?

			@tokenizer ||= Tokenizer.new
			tokens = @tokenizer.tokenize( text )
			return text if tokens.nil?

			expanded = ""
			tokens.each do |token|
				#raise if !key.nil? and token.raw == key
				expanded << token.text( *hashes )
			end

			expanded
		end

	end


	class Tokenizer

		def tokenize( text )
			return nil if text.nil?
			return nil unless text.kind_of? String

			e_flag = false # escape flag; \x
			p_flag = false # escape or change-mode flag; %x
			x_flag = false # macro mode flag; %{x}
			r_flag = false # script mode flag; %{{x}}; eval as Ruby code
			buffer = ""
			tokens = []
			text.chars do |c|
				if e_flag then
					# \ escaping
					case c
						# t, r, n, b > special characters
					when "t" then
						buffer << "\t"
					when "r" then
						buffer << "\r"
					when "n" then
						buffer << "\n"
					when "b" then
						buffer << "\b"
					else
						# others > as-is characters (include \ itself)
						buffer << c
					end
					e_flag = false # escaping end
					next
				end

				if p_flag then
					# % escaping or changing-mode
					case c
					when "{" then
						if x_flag then
							# '{' cannot escaped by % (in macro mode)
							raise
						elsif r_flag then
							# '{' cannot escaped by % (in script mode)
							raise
						else
							# change mode from simple to macro
							tokens << Token.new( buffer ) unless buffer == "" # flush characters as simple text
							buffer = "" # clear buffer
							# %{ .... macro mode from here (or perhaps script mode)
							x_flag = true
						end
					when "}", "\\" then
						# '}', '\' cannot escaped by %
						raise
					else
						# others > as-is characters
						buffer << c
					end
					p_flag = false # escaping or changing-mode end
					next
				end

				# script mode
				if r_flag then
					case c
					when "\\" then
						# escape next 1 character
						e_flag = true
					when "%" then
						# escape next 1 character
						p_flag = true
					when "{" then
						# %{{{ ... ? NG!
						raise
					when "}" then
						tokens << ScriptToken.new( buffer )
						buffer = nil
						r_flag = false
					else
						buffer << c
					end
					next
				end

				# macro mode
				if x_flag then
					case c
					when "\\" then
						# escape next 1 character
						e_flag = true
					when "%" then
						# escape next 1 character
						p_flag = true
					when "{" then
						# change mode from macro to (macro &) script
						r_flag = true
					when "}" then
						tokens << MarkedToken.new( buffer ) unless buffer.nil? # flush characters as macro text
						buffer = "" # clear buffer
						x_flag = false # change mode from macro to simple
					else
						buffer << c
					end
					next
				end

				# simple mode
				case c
				when "\\" then
					# escape next 1 character
					e_flag = true
				when "%" then
					# escape next 1 character
					p_flag = true
				when "{", "}" then
					# naked (not escaped by \) '{', '}' not allowed
					raise
				else
					# other character simply appended
					buffer << c
				end
			end

			tokens << Token.new( buffer ) unless buffer == ""

			# all flags must be off at end
			raise if e_flag or p_flag or x_flag or r_flag

			tokens
		end

	end


	class Token

		def initialize( text )
			#puts "#{self.class.name}#initialize: text = #{text}"
			raise if text.nil?
			raise if text.empty?
			@text = text
		end

		def text( *hashes )
			#puts "#{self.class.name}#text: text = #{@text}"
			@text
		end

		def raw
			#puts "#{self.class.name}#raw: text = #{@text}"
			@text
		end

	end


	class MarkedToken < Token

		def text( *hashes )
			#puts "#{self.class.name}#text: text = #{@text}"
			return @text if hashes.nil?
			return @text if hashes.empty?
			#puts "#{self.class.name}#text: text = #{@text}"
			hashes.each do |hash|
				#puts "#{self.class.name}#text: hash = #{hash}"
				return "#{hash[@text]}" if hash.key?( @text )
				#puts "#{self.class.name}#text: \"#{@text}\" next"
			end
			#puts "#{self.class.name}#text: \"#{@text}\" not found"
			"%{#{@text}}"
		end

	end


	class ScriptToken < Token

		def text( *hashes )
			#puts "#{self.class.name}#text: called"
			binding = nil
			hashes.each do |hash|
				if hash.key?( :binding ) then
					binding = hash[ :binding ]
					break
				end
			end
			begin
				unless binding.nil? then
					#puts "#{self.class.name}#text: context found"
					result = eval @text, binding
				else
					#puts "#{self.class.name}#text: context not found"
					result = eval @text
				end
				"#{result}"
			rescue => e
				#Utilities.print_back_trace e, "#{self.class.name}#text: error %{{#{@text}}}"
				@text
			end
		end

	end


#	module Overlay
#
#		def []( index )
#			key?( index ) ? super( index ): @hash[ index ]
#		end
#
#	end
#
#
#	class OverlayHash < Hash
#		include Overlay
#
#
#		def initialize( hash )
#			raise if hash.nil?
#			raise unless hash.respond_to? :[]
#			@hash = hash
#		end
#
#	end
#
#
#	class MacroHash < Hash
#		alias [] _get
#
#		include Macro
#
#		# @Override Hash#[]
#		def []( index )
#			get index, self
#		end
#
#		# @Override Macro#value_of
#		def value_of( key, values )
#			values._get key
#		end
#
#	end


	class MacroHash
		include Macro


		attr_reader :top
		attr_reader :middle
		attr_reader :bottom


		def initialize( top, macroful, bottom )
			raise if macroful.nil?
			@bottom = bottom.nil? ? Hash.new: bottom
			@middle = macroful
			@top = top.nil? ? Hash.new: top
		end

		def []( index )
			#puts "#{self.class.name}#[]: index = #{index}"
			#puts "#{self.class.name}#[]: \"#{index}\" found in <top>" if @top.key?( index )
			return @top[ index ] if @top.key?( index )
			#puts "#{self.class.name}#[]: \"#{index}\" not found in <top>"
			#puts "#{self.class.name}#[]: \"#{index}\" found in <middle>" if @middle.key?( index )
			return get( index, @middle, @bottom ) if @middle.key?( index )
			#puts "#{self.class.name}#[]: \"#{index}\" not found in <middle>"
			#puts "#{self.class.name}#[]: \"#{index}\" found in <bottom>" if @bottom.key?( index )
			return @bottom[ index ]
		end

	end


	def self.print_back_trace( e, message = nil )
		return if e.nil?
		puts "#{message}" unless message.nil?
		puts "error caused by #{e}"
		e.backtrace.each do |frame|
			puts "\t#{frame}"
		end
	end

	def self.check_nil( object )
		raise if object.nil?
		object
	end

end
end
