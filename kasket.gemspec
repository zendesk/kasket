require './lib/kasket/version'

Gem::Specification.new do |s|
  s.name        = "kasket"
  s.version     = Kasket::Version::STRING
  s.authors     = ["Mick Staugaard", "Eric Chapweske"]
  s.email       = ["mick@zendesk.com"]
  s.homepage    = "http://github.com/zendesk/kasket"
  s.summary     = "A write back caching layer on active record"
  s.description = "puts a cap on your queries"
  s.license     = "Apache License Version 2.0"

  s.add_runtime_dependency("activerecord", ">= 3.2", "< 5.1")

  s.add_development_dependency("rake")
  s.add_development_dependency("bundler")
  s.add_development_dependency("mocha")
  s.add_development_dependency("wwtd")
  s.add_development_dependency("minitest")
  s.add_development_dependency("minitest-rg")
  s.add_development_dependency("timecop")

  s.files        = Dir.glob("lib/**/*") + %w(README.md)
end
