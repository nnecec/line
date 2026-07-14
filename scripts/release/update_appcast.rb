#!/usr/bin/env ruby
# frozen_string_literal: true

require "rexml/document"
require "rexml/formatters/pretty"
require "tempfile"
require "uri"
require_relative "validate_appcast_version"

class AppcastUpdater
  REQUIRED_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"

  def self.from_environment
    new(
      path: ENV.fetch("APPCAST_PATH", "appcast.xml"),
      version: ENV.fetch("APP_VERSION"),
      build: ENV.fetch("APP_BUILD"),
      minimum_system_version: ENV.fetch("MINIMUM_SYSTEM_VERSION"),
      release_url: ENV.fetch("RELEASE_URL"),
      signature: ENV.fetch("ED_SIGNATURE"),
      asset_length: ENV.fetch("ASSET_LENGTH"),
      publication_date: ENV.fetch("PUB_DATE")
    )
  end

  def initialize(path:, version:, build:, minimum_system_version:, release_url:, signature:, asset_length:, publication_date:)
    @path = path
    @version = version
    @build = build
    @minimum_system_version = minimum_system_version
    @release_url = release_url
    @signature = signature
    @asset_length = asset_length
    @publication_date = publication_date
    validate!
  end

  def update
    AppcastVersionPolicy.new.validate(path: @path, version: @version, build: @build)
    document = REXML::Document.new(File.read(@path))
    unless document.root&.namespace("sparkle") == REQUIRED_NAMESPACE
      raise "Appcast has an invalid Sparkle XML namespace"
    end

    channel = REXML::XPath.first(document, "/rss/channel")
    raise "Appcast is missing /rss/channel" unless channel

    remove_existing_version(channel)
    insert_new_item(channel)
    write_atomically(document)
  end

  private

  def validate!
    raise "Version must look like 1.4.4" unless @version.match?(/\A\d+(\.\d+){2}\z/)
    raise "Build must be numeric" unless @build.match?(/\A\d+\z/)
    raise "Asset length must be numeric" unless @asset_length.match?(/\A\d+\z/)
    raise "Sparkle signature is empty" if @signature.empty?

    uri = URI.parse(@release_url)
    raise "Release URL must use HTTPS" unless uri.is_a?(URI::HTTPS) && uri.host
  end

  def remove_existing_version(channel)
    channel.elements.to_a("item").each do |item|
      build = child_text(item, "sparkle:version")
      version = child_text(item, "sparkle:shortVersionString")
      channel.delete_element(item) if build == @build && version == @version
    end
  end

  def child_text(element, expanded_name)
    element.elements.to_a.find { |child| child.expanded_name == expanded_name }&.text
  end

  def insert_new_item(channel)
    item = REXML::Element.new("item")
    add_text_element(item, "title", "Version #{@version}")
    add_text_element(item, "pubDate", @publication_date)
    add_text_element(item, "sparkle:version", @build)
    add_text_element(item, "sparkle:shortVersionString", @version)
    add_text_element(item, "sparkle:minimumSystemVersion", @minimum_system_version)

    description = item.add_element("description")
    description.add(REXML::CData.new("<p>See the GitHub release notes for details.</p>"))

    enclosure = item.add_element("enclosure")
    enclosure.add_attribute("url", @release_url)
    enclosure.add_attribute("type", "application/octet-stream")
    enclosure.add_attribute("sparkle:edSignature", @signature)
    enclosure.add_attribute("length", @asset_length)

    first_item = channel.elements.to_a("item").first
    first_item ? channel.insert_before(first_item, item) : channel.add_element(item)
  end

  def add_text_element(parent, name, value)
    parent.add_element(name).text = value
  end

  def write_atomically(document)
    formatter = REXML::Formatters::Pretty.new(2)
    formatter.compact = true
    output = String.new
    formatter.write(document, output)
    output << "\n"

    Tempfile.create(["appcast", ".xml"], File.dirname(@path)) do |file|
      file.write(output)
      file.flush
      File.rename(file.path, @path)
    end
  end
end

AppcastUpdater.from_environment.update if $PROGRAM_NAME == __FILE__
