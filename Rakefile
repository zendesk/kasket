# frozen_string_literal: true
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'bump/tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

# Pushing to rubygems is handled by a github workflow
ENV["gem_push"] = "false"

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

task default: 'test'
