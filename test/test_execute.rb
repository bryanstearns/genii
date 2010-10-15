require File.dirname(__FILE__) + '/helper'

class TestExecute < Test::Unit::TestCase
  include Execute

  context "When executing a command" do
    should "capture output" do
      assert_equal "foo", execute("echo foo").to_s
    end

    should "yield output" do
      results = []
      execute("echo foo; echo bar").each do |line|
        results << line
      end
      assert_equal ["foo", "bar"], results
    end

    should "raise on error by default" do
      assert_raises Execute::Error do
        execute("bogus_command")
      end
    end

    should "return status if ignoring errors" do
      assert_equal 5, execute("exit 5", :ignore_error => true).status
    end
  end
end
