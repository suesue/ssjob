require 'rubygems'


Gem::Specification.new do |spec|
	spec.platform = Gem::Platform::RUBY
	spec.name = "SSJob"
	spec.summary = "file based job"
	spec.description = "Job"
	spec.author = "suesue"
	spec.email = "suesue_dev@yahoo.co.jp"
	spec.files = [ "main.rb", "LICENSE" ] + Dir.glob( "lib/job/*.rb" ) + Dir.glob( "lib/util/*.rb" )
	spec.version = "0.1.0"
end
