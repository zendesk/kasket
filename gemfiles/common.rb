source 'https://rubygems.org'

gem 'activerecord-jdbcmysql-adapter', '~> 1.2', platforms: :jruby
gem 'byebug', platforms: :ruby

gemspec path: Bundler.root.sub('/gemfiles', '')
