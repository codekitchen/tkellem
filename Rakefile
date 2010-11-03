require 'rubygems'
require 'rake'
require 'rspec'
require 'rspec/core/rake_task'

task :default => :spec

RSpec::Core::RakeTask.new(:spec) do |spec|
  # spec.pattern = 'spec/**/*_spec.rb'
  spec.pattern = 'spec/spec_helper.rb'
end
