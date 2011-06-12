# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tkellem/version"

Gem::Specification.new do |s|
  s.name        = %q{tkellem}
  s.version     = Tkellem::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Palmer"]
  s.email       = ["brian@codekitchen.net"]
  s.homepage    = %q{http://github.com/codekitchen/tkellem}
  s.summary     = %q{IRC bouncer with multi-client support}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.default_executable = %q{tkellem}
  s.require_paths = ["lib"]

  s.add_dependency "eventmachine", "~> 0.12.10"
  s.add_dependency "daemons", "~> 1.1.0"
  s.add_dependency "json"
  s.add_dependency "activerecord", "~> 3.0.0"

  s.add_development_dependency "rspec", "~> 2.5"
  s.add_development_dependency "rcov"
  s.add_development_dependency "yard"
end

