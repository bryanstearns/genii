require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'ruby-debug'
require 'mocha'


[File.join(File.dirname(__FILE__), '..', 'lib', 'genii'),
 File.dirname(__FILE__)].each do |path|
  path = File.expand_path(path)
  unless $LOAD_PATH.include?(path)
    # puts "test/helper: $LOAD_PATH << #{path}"
    $LOAD_PATH.unshift(path)
  end
end

require 'initializers'

class Test::Unit::TestCase
end
