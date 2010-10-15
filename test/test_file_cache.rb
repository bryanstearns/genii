require File.dirname(__FILE__) + '/helper'

class TestFileCache < Test::Unit::TestCase
  should "hash a file" do
    # This file is Deployer's public key
    path = File.dirname(__FILE__) + "/others/hash_test"
    assert_equal "d6e41e304942fbfe0288502b4dc09308e235198b",
                 FileCache.file_hash(path)
  end

  should "hash a string" do
    assert_equal "37c4f3843ebc392e937a837ce851574f2eea9860",
                 FileCache.string_hash("Bryan Stearns")
  end

  should "return nil when hashing a nonexistant file" do
    assert_nil FileCache.file_hash('/bogus_filename')
  end

  should "make a path to where we'll store an original" do
    path = "/etc/ssh/sshd_config"
    Time.stubs(:now).returns(Time.local(2008, 4, 3, 12, 57, 19))
    assert_equal \
      "/var/cache/genii/original_files/etc/ssh/080403125719.sshd_config",
      FileCache.original_path(path)
  end

  should "make a path to where we'll store a hash" do
    path = "/etc/ssh/sshd_config"
    assert_equal \
      "/var/cache/genii/hashes/etc/ssh/sshd_config",
      FileCache.hash_path(path)
  end
end
