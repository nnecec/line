#!/usr/bin/env ruby
# frozen_string_literal: true

class XCConfigReader
  def initialize(path, contents: nil)
    @path = path
    @lines = contents ? contents.lines : File.readlines(path)
  end

  def fetch(key)
    matches = @lines.filter { |line| line.match?(/^\s*#{Regexp.escape(key)}\s*=/) }
    raise "Missing #{key} in #{@path}" if matches.empty?
    raise "Duplicate #{key} in #{@path}" if matches.length > 1

    value = matches.first.split("=", 2).last.strip
      .sub(%r{\s+//.*\z}, "")
      .strip
      .gsub("$()", "")
    raise "Empty #{key} in #{@path}" if value.empty?

    value
  end
end

puts XCConfigReader.new(ARGV.fetch(0)).fetch(ARGV.fetch(1)) if $PROGRAM_NAME == __FILE__
