source "https://rubygems.org"

gem "mysql2", "~> 0.3.0", platforms: :ruby
gem "activerecord-jdbcmysql-adapter", "~> 1.2", platforms: :jruby
gem 'mocha', git: 'https://github.com/zendesk/mocha.git', branch: "eac/alias_method_fix" # https://github.com/freerange/mocha/pull/202
gem 'byebug', platforms: :ruby
