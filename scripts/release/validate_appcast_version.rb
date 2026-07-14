#!/usr/bin/env ruby
# frozen_string_literal: true

require "rexml/document"

class AppcastVersionPolicy
  def validate(path:, version:, build:)
    requested_build = parse_build(build, context: "Requested build")
    document = REXML::Document.new(File.read(path))
    channel = REXML::XPath.first(document, "/rss/channel")
    raise "Appcast is missing /rss/channel" unless channel

    channel.elements.to_a("item").each do |item|
      existing_build = child_text(item, "sparkle:version")
      existing_version = child_text(item, "sparkle:shortVersionString")
      raise "Existing appcast item is missing its version or build" unless existing_build && existing_version

      existing_build_number = parse_build(existing_build, context: "Existing build #{existing_build.inspect}")
      next if existing_version == version && existing_build == build

      if existing_version == version
        raise "Version #{version} already uses build #{existing_build}"
      end
      if existing_build == build
        raise "Build #{build} is already used by version #{existing_version}"
      end
      if existing_build_number >= requested_build
        raise "Build #{build} must be greater than existing build #{existing_build}"
      end
    end

    true
  end

  private

  def parse_build(value, context:)
    number = Integer(value, 10)
    raise "#{context} must be positive" unless number.positive?

    number
  rescue ArgumentError
    raise "#{context} must be a positive integer"
  end

  def child_text(element, expanded_name)
    element.elements.to_a.find { |child| child.expanded_name == expanded_name }&.text
  end
end

if $PROGRAM_NAME == __FILE__
  AppcastVersionPolicy.new.validate(
    path: ENV.fetch("APPCAST_PATH", "appcast.xml"),
    version: ENV.fetch("APP_VERSION"),
    build: ENV.fetch("APP_BUILD")
  )
  puts "Appcast version and build are monotonic."
end
