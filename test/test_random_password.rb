require File.dirname(__FILE__) + '/helper'

class TestRandomPassword < Test::Unit::TestCase
  should "Generate random passwords of the right size" do
    assert (RandomPassword::MIN_PASSWORD_SIZE .. RandomPassword::MAX_PASSWORD_SIZE)\
           .include?(RandomPassword.create.length)
  end
end
