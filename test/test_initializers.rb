require File.dirname(__FILE__) + '/helper'

class TestInitializers < Test::Unit::TestCase
  should "classify a string" do
    assert_equal "MumboJumbo", "mumbo_jumbo".classify
  end

  should "constantize a string" do
    assert_equal Regexp::MULTILINE, "Regexp::MULTILINE".constantize
  end

  context "when parsing a URL with to_uri" do
    should "work with normal URLs" do
      uri = "http://foo.com/bar".to_uri
      assert_equal "foo.com", uri.host
      assert_equal "http", uri.scheme
      assert_equal 80, uri.port
      assert_equal "/bar", uri.path
    end

    should "normalize-away www." do
      uri = "http://www.foo.com/bar".to_uri
      assert_equal "foo.com", uri.host
    end

    should "autodetect port for https URLs" do
      uri = "https://foo.com/bar".to_uri
      assert_equal "https", uri.scheme
      assert_equal 443, uri.port
    end

    should "normalize an empty path to '/' with or without the trailing slash" do
      ["https://foo.com/", "https://foo.com"].each do |url|
        assert_equal '/', url.to_uri.path
      end
    end
  end
end
