
module RelativePath
  class RelativePathNotFound < Exception; end

  # Find a file relative to anywhere in our load path
  def self.find(subpath, ignore_missing=nil)
    return subpath if subpath[0..0] == "/" # absolutely!
    $LOAD_PATH.each do |dir|
      path = File.join(dir, subpath)
      return File.expand_path(path) if File.exist?(path)
    end
    raise(RelativePathNotFound, "Can't find #{subpath} in [\n  #{$LOAD_PATH.join("\n  ")}\n]") \
      unless ignore_missing
    nil
  end
end
