require 'bundler'
Bundler::GemHelper.install_tasks

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/*_spec.rb'
end
RSpec::Core::RakeTask.new(:rcov) do |t|
  t.rcov = true
  t.rcov_opts = ["--exclude", "spec,gems/,rubygems/"]
end

require 'yard'
YARD::Rake::YardocTask.new(:doc) do |t|
  version = Tkellem::VERSION
  t.options = ["--title", "tkellem #{version}", "--files", "LICENSE,README.md"]
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
