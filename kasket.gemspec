# frozen_string_literal: true
require './lib/kasket/version'

Gem::Specification.new do |s|
  s.name        = "kasket"
  s.version     = Kasket::VERSION
  s.authors     = ["Mick Staugaard", "Eric Chapweske"]
  s.email       = ["mick@zendesk.com"]
  s.homepage    = "http://github.com/zendesk/kasket"
  s.summary     = "A write back caching layer on active record"
  s.description = "puts a cap on your queries"
  s.license     = "Apache License Version 2.0"
  s.files       = Dir.glob("lib/**/*") + %w[README.md]

  s.required_ruby_version = '>= 2.5.0'

  s.add_runtime_dependency("activerecord", ">= 4.2", "< 7")
end
