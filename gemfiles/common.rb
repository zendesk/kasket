# frozen_string_literal: true
source 'https://rubygems.org'

gem 'mysql2', '~> 0.5'

# dev dependencies:
gem "pry",         "~> 0.13.1"
gem "byebug",      "~> 11.1"
gem "pry-byebug",  "= 3.9.0"
gem "bump",        "~> 0.10"
gem "minitest",    "~> 5.1"
gem "minitest-rg", "~> 5.2"
gem "mocha",       "~> 1.13"
gem "rake",        "~> 13"
gem "timecop",     "~> 0.9"
gem "rubocop",     "~> 1.5.0"
gem "rubocop-performance", "~> 1.10.2"
gem "rubocop-rubycw",      "~> 0.1.6"

gemspec path: Bundler.root.sub('/gemfiles', '')
