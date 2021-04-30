#!/usr/bin/env ruby
require 'json'
require_relative 'autograder.rb'
run_tests "../eulerian_blast/myblast"
puts JSON.generate($res)