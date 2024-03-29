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
  s.license     = "Apache-2.0"
  s.files       = Dir.glob("lib/**/*") + %w[README.md]

  s.required_ruby_version = '>= 2.7'

  s.add_runtime_dependency("activerecord", ">= 5.1", "< 7.1")

  s.post_install_message = "The Kasket gem is deprecated and will no longer be maintained"
end
