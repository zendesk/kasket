# frozen_string_literal: true
source 'https://rubygems.org'

# dev dependencies:
gem "pry"
gem "byebug"
gem "pry-byebug"
gem "bump"
gem "minitest"
gem "minitest-rg"
gem "mocha"
gem "rake"
gem "timecop"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rubycw"

gemspec path: Bundler.root.sub('/gemfiles', '')
