# frozen_string_literal: true
source 'https://rubygems.org'

gem 'activerecord-jdbcmysql-adapter', '~> 1.2', platforms: :jruby
gem 'byebug', platforms: :ruby
gem 'rubocop', '~> 0.49.1', platforms: :ruby

gemspec path: Bundler.root.sub('/gemfiles', '')
