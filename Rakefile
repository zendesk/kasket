# frozen_string_literal: true
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'wwtd/tasks'
require 'bump/tasks'

unless RUBY_PLATFORM == "java"
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task default: 'wwtd:local'
