require 'rubygems'
require 'rake'
require 'rspec'
require 'rspec/core/rake_task'

task :default => :spec

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/*_spec.rb'
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'tkellem'
    gem.summary = 'IRC bouncer with multi-client support'
    gem.email = 'brian@codekitchen.net'
    gem.homepage = 'http://github.com/codekitchen/tkellem'
    gem.authors = ['Brian Palmer']
    gem.add_dependency 'eventmachine'
    gem.executables = %w(tkellem)
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  # om nom nom
end
