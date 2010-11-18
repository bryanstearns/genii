require 'fileutils'
require 'uri'

class String
  def classify
    # Fake ActiveSupport's classify:
    # murky_soup --> MurkySoup
    self.downcase.split('_').map do |word|
      word[0..0].upcase + word[1..-1]
    end.join
  end

  def underscore
    # The opposite of #classify
    # MurkySoup --> murky_soup
    # Lifted from ActiveSupport's, but changed so that :: turns into __
    word = self.dup
    word.gsub!(/::/, '__') # was --> '/'
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end

  def constantize
    # Fake ActiveSupport's constantize
    names = self.split('::')
    constant = Object
    names.each do |name|
      constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end

  def to_uri
    # Turn this string into a normalized URI:
    # - make sure an empty path is "/"
    # - get rid of "www."
    result = URI.parse(self)
    result.path = "/" if result.path == ""
    result.host = $1 if result.host =~ /^www\.(.*)$/
    result
  end

  def elided(max_length=15)
    # "This is a very long string!" --> "This is a [+16]"
    return self if self.length <= max_length
    "#{self[0..max_length-5]}[+#{self.size - max_length}]"
  end
end


class Hash
  # Merges self with another hash, recursively;
  # array elements are NOT merged too.
  def deep_merge!(other)
    other.each_pair do |k,v|
      if self[k].is_a?(Hash) and other[k].is_a?(Hash)
        self[k].deep_merge!(other[k])
#      elsif self[k].is_a?(Array) and other[k].is_a?(Array)
#        self[k] += other[k]
      else
        self[k] = other[k]
      end
    end
  end

  # Return a copy of this hash with symbolized keys
  def symbolize_keys
    self.inject({}) do|h, (key, value)|
      new_key = key.is_a?(String) ? key.to_sym : key
      new_value = value.is_a?(Hash) ? value.symbolize_keys : value
      h[new_key] = new_value
      h
    end
  end

  # Like the above, but changes symbol keys to strings
  def stringize_keys
    self.inject({}) do|h, (key, value)|
      new_key = key.is_a?(Symbol) ? key.to_s : key
      new_value = value.is_a?(Hash) ? value.stringize_keys : value
      h[new_key] = new_value
      h
    end
  end
end

class Object
  def try(method)
    send method if respond_to? method
  end

  def self.array_first(a)
    a.each do |x|
      result = yield x
      return result if result
    end
    nil
  end

  def self.const_missing(name, in_module=nil)
    @looked_for ||= {}
    str_name = name.to_s
    raise NameError, "Class not found: #{name}" if @looked_for[str_name]
    @looked_for[str_name] = 1
    file = str_name.underscore
    # gonna_load = array_first($LOAD_PATH) {|p| path = "#{p}/#{file}.rb"; File.exist?(path) && path}
    # puts "requiring #{file} from #{gonna_load.inspect}:\n  #{$LOAD_PATH.join("\n  ")}"
    require file
    klass = (in_module || Object).const_get(name)
    return klass if klass
    raise NameError, "Class not found: #{name}"
  end
end

module Features; end
def Features.const_missing(name)
  Object.const_missing(name, Features)
end

include Log

