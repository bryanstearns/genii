#!/usr/bin/ruby
#
# Insert something before, after, or replacing a line that matches a pattern in a file, or
# just at the end.
#
# (This file is derived from a command-line tool I'd previously written and open-sourced;
#  pursuant to my own license terms, here's its license)
#
#  The MIT License
#
#  Copyright (c) 2008-2010 Bryan Stearns
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

class Munger
  OPTIONS = [:mode, :pattern, :tag, :content, :content_path, :input, :input_path, :output, :output_path, :path, :verbose]
  attr_accessor *(OPTIONS + [:start_tag, :end_tag])

  def self.munge(options={})
    content = raw_or_path(options, :content, :content_path)
    input = raw_or_path(options, :input, :input_path)
    munger = Munger.new(options)
    output = munger.run(input, content)
    raw_or_path(options, :output, :output_path, output)
  end

  def initialize(options)
    self.mode = options[:mode] || :append
    self.pattern = Regexp.compile(options[:pattern]) unless mode == :append
    self.tag = options[:tag] || ''
    self.verbose = options[:verbose]

    if verbose
      settings = OPTIONS.map {|attr| "#{attr} = #{eval "#{attr}.inspect"}" }
      puts settings.join(', ')
    end
  end

  def run(input, content)
    startTag = tag + " (genii start)"
    endTag = tag + " (genii end)"
    content = [startTag, content.rstrip, endTag].join("\n")

    result = []
    skipping = nil
    needMatch = [:before, :replace, :after].include? mode
    input.split("\n").each do |l|
      if skipping
        if l == endTag
          puts "Done skipping: #{l}" if verbose
          skipping = nil
          result << content if mode == :replace
        else
          puts "Skipping: #{l}" if verbose
        end
      elsif l == startTag
        puts "Start skipping: #{l}" if verbose
        skipping = true
      else
        matched = needMatch && pattern.match(l)
        if mode == :before && matched
          puts "Matched (before): inserting before #{l}" if verbose
          result << content
          needMatch = nil
        end
        if mode == :replace && matched
          puts "Matched (replace): replacing #{l}" if verbose
          result << content
          needMatch = nil
        else
          puts "Using existing line #{l}" if verbose
          result << l
        end
        if mode == :after && matched
          puts "Matched (after): inserting after #{l}" if verbose
          result << content
          needMatch = nil
        end
      end
    end

    if mode == :append
      puts "Appending..." if verbose
      result << content
    end

    result << "" # make sure we end with a newline
    result.join("\n")
  end

private
  def self.raw_or_path(options, raw_sym, raw_path_sym, to_write=:read)
    raw_value = options.delete(raw_sym)
    raw_path_value = options.delete(raw_path_sym)
    raw_path_value ||= options[:path]
    data = raw_value || begin
      if raw_path_value == '-'
        to_write == :read ? STDIN.read : STDOUT.write(to_write)
      elsif to_write == :read
        File.open(raw_path_value, 'r') {|f| f.read }
      else
        FU.write!(raw_path_value, to_write) \
          if raw_path_value
        to_write
      end
    end
  end
end

if $0 == __FILE__
  require 'rubygems'
  require 'ruby-debug'
  require 'test/unit'
  require 'optparse'

  class MungeTool
    def initialize
      @content = OptionParser.new do |opts|
        opts.banner = "Usage: munge <options> CONTENT"
        opts.on("--before PATTERN", "Insert before the line matching PATTERN") {|@pattern| set_mode(:before) }
        opts.on("--after PATTERN", "Insert after the line matching PATTERN") {|@pattern| set_mode(:after) }
        opts.on("--replace PATTERN", "Replace the line matching PATTERN") {|@pattern| set_mode(:replace) }
        opts.on("--append", "Append to the file") { set_mode(:append) }

        opts.on("--tag TAG", "Mark our insertion with this TAG") {|@tag|}
        opts.on("--input INPUT", "The filename to read (and write back to, if no --output specified); '-' for stdin") \
                {|@inputPath|}
        opts.on("--output OUTPUT", "The filename to write; '-' for stdin") {|@outputPath|}
        opts.on("--content CONTENT", "A file from which to read the content to insert; '-' for stdin") \
                {|@contentPath|}
        opts.on("--test", "Test behavior") {|@test|}
        opts.on("-v", "--verbose", "Increase verbosity") {|@verbose|}
      end.parse!
      if @test
        require 'test/unit/ui/console/testrunner'
        puts "test result = #{Test::Unit::UI::Console::TestRunner.run(MungerTest)}"
        exit 0
      end
      set_mode(:append) unless @mode
      abort "No --input path specified" unless @inputPath
      abort "Can't specify --content with CONTENT" if (@content != nil && @contentPath != nil)
      abort "No content specified" unless (@content || @contentPath)

      options = Munger::OPTIONS.inject({}) do |h, option|
        options[option] = instance_variable_get("@#{option}") rescue nil
      end
      Munger.munge(options)
    end

    def set_mode(new_mode)
      abort("Only one --before|--after|--replace|--append allowed") if @mode
      @mode = new_mode
    end
  end

  class MungerTest < Test::Unit::TestCase
    def my_assert_equal(expected, was)
      assert expected == was, "--- Expected:\n#{expected}\n--- Was:\n#{was}"
    end

    def setup
      @verbose = nil
      @text = """Existing line number one
Existing line number two
Existing line number three
"""
    end

    def test_before
      @text = Munger.munge(:mode => :before, :pattern => "line number one",
                           :tag => "# BeforeOneTest", :input => @text,
                           :content => "This goes before line one",
                           :verbose => @verbose)
      my_assert_equal \
        """# BeforeOneTest (genii start)
This goes before line one
# BeforeOneTest (genii end)
Existing line number one
Existing line number two
Existing line number three
""", @text

      @text = Munger.munge(:mode => :before, :pattern => "line number two",
                           :tag => "# BeforeTwoTest", :input => @text,
                           :content => "This goes before line two",
                           :verbose => @verbose)
      my_assert_equal \
        """# BeforeOneTest (genii start)
This goes before line one
# BeforeOneTest (genii end)
Existing line number one
# BeforeTwoTest (genii start)
This goes before line two
# BeforeTwoTest (genii end)
Existing line number two
Existing line number three
""", @text
    end

    def test_after
      @text = Munger.munge(:mode => :after, :pattern => "line number three",
                           :tag => "# AfterThreeTest", :input => @text,
                           :content => "This goes after line three",
                           :verbose => @verbose)
      my_assert_equal \
        """Existing line number one
Existing line number two
Existing line number three
# AfterThreeTest (genii start)
This goes after line three
# AfterThreeTest (genii end)
""", @text

      @text = Munger.munge(:mode => :after, :pattern => "line number three",
                           :tag => "# AfterThreeTest", :input => @text,
                           :content => "New stuff for after line three",
                           :verbose => @verbose)
      my_assert_equal \
        """Existing line number one
Existing line number two
Existing line number three
# AfterThreeTest (genii start)
New stuff for after line three
# AfterThreeTest (genii end)
""", @text
    end

    def test_append
      @text = Munger.munge(:mode => :append, :tag => "# AppendTest",
                           :input => @text,
                           :content => "This is some stuff to append",
                           :verbose => @verbose)
      my_assert_equal \
        """Existing line number one
Existing line number two
Existing line number three
# AppendTest (genii start)
This is some stuff to append
# AppendTest (genii end)
""", @text

      @text = Munger.munge(:mode => :append, :tag => "# AppendTest",
                           :input => @text,
                           :content => "New stuff to append",
                           :verbose => @verbose)
      my_assert_equal \
        """Existing line number one
Existing line number two
Existing line number three
# AppendTest (genii start)
New stuff to append
# AppendTest (genii end)
""", @text
    end
  end

  begin
    MungeTool.new
  rescue SystemExit
    raise
  rescue Exception => e
    puts "Exception: #{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    exit 1
  end
end

