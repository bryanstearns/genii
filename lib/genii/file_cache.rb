require 'digest/sha1'

class FileCache
  # A singleton manager of files
  #
  # We store original versions of files we've modified here, with their
  # original path concat'd onto this
  ORIGINAL_DIR = "/var/cache/genii/original_files"

  # We record hashes of the files we've seen here:
  HASH_DIR = "/var/cache/genii/hashes"

  HASH_BUFFER_SIZE = 16384

  def initialize
  end

  def self.file_hash(path)
    # Hash this file
    return nil unless File.exist?(path)
    calculate_hash do |hasher|
      begin
        File.open(path, 'r') do |f|
          while (!f.eof) do
            hasher.update(f.readpartial(HASH_BUFFER_SIZE))
          end
        end
      rescue
        return nil
      end
    end
  end

  def self.string_hash(content)
    calculate_hash {|hasher| hasher.update(content) }
  end

  def self.original_path(path)
    File.join(FileCache::ORIGINAL_DIR, File.dirname(path),
              "#{Time.now.strftime("%y%m%d%H%M%S")}.#{File.basename(path)}")
  end

  def self.hash_path(path)
    File.join(FileCache::HASH_DIR, File.expand_path(path)[1..-1])
  end

private
  def self.calculate_hash(&block)
    hash_function = Digest::SHA1.new
    yield hash_function
    hash_function.hexdigest
  end
end
