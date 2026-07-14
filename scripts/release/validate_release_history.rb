#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "rexml/document"
require_relative "read_xcconfig_value"

ReleaseRecord = Struct.new(:tag, :version, :build, keyword_init: true)

class ReleaseHistoryPolicy
  def validate(requested_version:, requested_build:, releases:, appcast_entries:)
    requested_build_number = positive_build(requested_build, context: "Requested build")
    requested_version_components = semantic_version(requested_version, context: "Requested version")
    builds = {}

    releases.each do |release|
      expected_version = release.tag.delete_prefix("v")
      if release.version != expected_version
        raise "#{release.tag} contains VERSION #{release.version}"
      end

      existing_build_number = positive_build(release.build, context: "#{release.tag} build")
      if builds.key?(release.build)
        raise "Build #{release.build} is used by both #{builds.fetch(release.build)} and #{release.tag}"
      end
      builds[release.build] = release.tag

      if release.version == requested_version
        unless release.build == requested_build
          raise "#{release.tag} already uses build #{release.build}"
        end
        next
      end

      existing_version_components = semantic_version(release.version, context: "#{release.tag} version")
      if (existing_version_components <=> requested_version_components) >= 0
        raise "Version #{requested_version} must be newer than #{release.tag}"
      end

      if existing_build_number >= requested_build_number
        raise "Build #{requested_build} must be greater than #{release.tag} build #{release.build}"
      end

      unless appcast_entries.include?([release.version, release.build])
        raise "#{release.tag} is not yet present in appcast.xml"
      end
    end

    true
  end

  private

  def positive_build(value, context:)
    number = Integer(value, 10)
    raise "#{context} must be positive" unless number.positive?

    number
  rescue ArgumentError
    raise "#{context} must be a positive integer"
  end

  def semantic_version(value, context:)
    parts = value.split(".")
    unless parts.length == 3 && parts.all? { |part| part.match?(/\A\d+\z/) }
      raise "#{context} must contain three numeric components"
    end

    parts.map { |part| Integer(part, 10) }
  end
end

class ReleaseHistoryLoader
  def releases
    capture("git", "tag", "--list", "v[0-9]*").lines(chomp: true).reject(&:empty?).map do |tag|
      contents = capture("git", "show", "#{tag}:Line/Config.xcconfig")
      reader = XCConfigReader.new("#{tag}:Line/Config.xcconfig", contents: contents)
      ReleaseRecord.new(
        tag: tag,
        version: reader.fetch("VERSION"),
        build: reader.fetch("BUILD_NUMBER")
      )
    end
  end

  def appcast_entries(path)
    document = REXML::Document.new(File.read(path))
    channel = REXML::XPath.first(document, "/rss/channel")
    raise "Appcast is missing /rss/channel" unless channel

    channel.elements.to_a("item").map do |item|
      [child_text(item, "sparkle:shortVersionString"), child_text(item, "sparkle:version")]
    end
  end

  private

  def capture(*command)
    output, error, status = Open3.capture3(*command)
    raise "#{command.join(' ')} failed: #{error.strip}" unless status.success?

    output
  end

  def child_text(element, expanded_name)
    element.elements.to_a.find { |child| child.expanded_name == expanded_name }&.text
  end
end

if $PROGRAM_NAME == __FILE__
  loader = ReleaseHistoryLoader.new
  ReleaseHistoryPolicy.new.validate(
    requested_version: ENV.fetch("APP_VERSION"),
    requested_build: ENV.fetch("APP_BUILD"),
    releases: loader.releases,
    appcast_entries: loader.appcast_entries(ENV.fetch("APPCAST_PATH", "appcast.xml"))
  )
  puts "Release tags, build numbers, and appcast history are consistent."
end
