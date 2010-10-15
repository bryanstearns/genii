require File.dirname(__FILE__) + '/helper'

class TestUsersAndGroups < Test::Unit::TestCase
  include UsersAndGroups

  context "When looking up a user" do
    should "find one by symbol" do
      assert_equal 3, get_uid(:sys)
    end

    should "find one by string" do
      assert_equal 1, get_uid("daemon")
    end

    should "not find a nonexistant one" do
      assert_equal nil, get_uid("jimmyhoffa")
    end
  end

  context "When looking up a group" do
    should "find one by symbol" do
      assert_equal 2, get_gid(:bin)
    end

    should "find one by string" do
      assert_equal 0, get_gid("root")
    end

    should "not find a nonexistant one" do
      assert_equal nil, get_gid("illuminati")
    end
  end
end
