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
  s.license       = 'MIT'

  s.add_dependency "eventmachine-le", "~> 1.1.6"
  s.add_dependency "activerecord", "~> 4.0.1"
  s.add_dependency "sqlite3", "~> 1.3.3"
  s.add_dependency "rails-observers", "~> 0.1.1"
  s.add_dependency "tzinfo"
  s.add_dependency "geoip", "~> 1.3.2"
end
