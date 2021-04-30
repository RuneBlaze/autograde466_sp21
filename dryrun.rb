#!/usr/bin/env ruby
require 'json'
require_relative 'autograder.rb'
run_tests "../eulerian_blast/myblast"
$res[:output] = $output.string
puts $res[:output]
$res[:tests].map{|it| it[:output]}.each do |e|
    puts e
end