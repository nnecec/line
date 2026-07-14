# frozen_string_literal: true

require "minitest/autorun"
require "rexml/document"
require "tempfile"
require_relative "read_xcconfig_value"
require_relative "update_appcast"
require_relative "validate_appcast_version"
require_relative "validate_release_history"
require_relative "verify_sparkle_key_pair"

class AppcastUpdaterTest < Minitest::Test
  EMPTY_APPCAST = <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <title>Line</title>
        <description>Latest Line releases.</description>
        <language>en</language>
      </channel>
    </rss>
  XML

  def test_inserts_release_into_empty_appcast
    with_appcast(EMPTY_APPCAST) do |path|
      updater(path: path).update

      items = items_at(path)
      assert_equal 1, items.length
      assert_equal "42", child_text(items.first, "sparkle:version")
      assert_equal "1.4.4", child_text(items.first, "sparkle:shortVersionString")
    end
  end

  def test_preserves_older_items_and_inserts_new_release_first
    previous = EMPTY_APPCAST.sub(
      "</channel>",
      <<~XML.chomp
        <item>
          <title>Version 1.4.3</title>
          <sparkle:version>41</sparkle:version>
          <sparkle:shortVersionString>1.4.3</sparkle:shortVersionString>
        </item>
      </channel>
      XML
    )

    with_appcast(previous) do |path|
      updater(path: path).update

      items = items_at(path)
      assert_equal 2, items.length
      assert_equal "1.4.4", child_text(items[0], "sparkle:shortVersionString")
      assert_equal "1.4.3", child_text(items[1], "sparkle:shortVersionString")
    end
  end

  def test_replaces_same_version_instead_of_duplicating_it
    with_appcast(EMPTY_APPCAST) do |path|
      updater(path: path).update
      first_result = File.binread(path)
      updater(path: path).update

      assert_equal 1, items_at(path).length
      assert_equal first_result, File.binread(path)
    end
  end

  def test_rejects_same_build_for_a_different_version
    existing = appcast_item(version: "1.4.3", build: "42")

    with_appcast(existing) do |path|
      error = assert_raises(RuntimeError) { updater(path: path).update }
      assert_equal "Build 42 is already used by version 1.4.3", error.message
    end
  end

  def test_rejects_build_older_than_existing_release
    existing = appcast_item(version: "1.4.3", build: "43")

    with_appcast(existing) do |path|
      error = assert_raises(RuntimeError) { updater(path: path).update }
      assert_equal "Build 42 must be greater than existing build 43", error.message
    end
  end

  def test_rejects_same_version_with_a_different_build
    existing = appcast_item(version: "1.4.4", build: "41")

    with_appcast(existing) do |path|
      error = assert_raises(RuntimeError) { updater(path: path).update }
      assert_equal "Version 1.4.4 already uses build 41", error.message
    end
  end

  def test_rejects_non_https_release_url
    with_appcast(EMPTY_APPCAST) do |path|
      error = assert_raises(RuntimeError) do
        updater(path: path, release_url: "http://example.com/Line.zip")
      end
      assert_equal "Release URL must use HTTPS", error.message
    end
  end

  def test_rejects_wrong_sparkle_namespace
    invalid_appcast = EMPTY_APPCAST.sub(
      "http://www.andymatuschak.org/xml-namespaces/sparkle",
      "https://example.com/not-sparkle"
    )

    with_appcast(invalid_appcast) do |path|
      error = assert_raises(RuntimeError) { updater(path: path).update }
      assert_equal "Appcast has an invalid Sparkle XML namespace", error.message
    end
  end

  private

  def updater(path:, release_url: "https://github.com/nnecec/Line/releases/download/v1.4.4/Line.zip")
    AppcastUpdater.new(
      path: path,
      version: "1.4.4",
      build: "42",
      minimum_system_version: "26.0",
      release_url: release_url,
      signature: "signed-value",
      asset_length: "1024",
      publication_date: "Mon, 13 Jul 2026 12:00:00 +0000"
    )
  end

  def with_appcast(contents)
    Tempfile.create(["appcast", ".xml"]) do |file|
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  def appcast_item(version:, build:)
    EMPTY_APPCAST.sub(
      "</channel>",
      <<~XML.chomp
        <item>
          <title>Version #{version}</title>
          <sparkle:version>#{build}</sparkle:version>
          <sparkle:shortVersionString>#{version}</sparkle:shortVersionString>
        </item>
      </channel>
      XML
    )
  end

  def items_at(path)
    document = REXML::Document.new(File.read(path))
    REXML::XPath.match(document, "/rss/channel/item")
  end

  def child_text(element, expanded_name)
    element.elements.to_a.find { |child| child.expanded_name == expanded_name }&.text
  end
end

class SparkleKeyPairVerifierTest < Minitest::Test
  PRIVATE_SEED = ["9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"].pack("H*")
  PUBLIC_KEY = ["d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"].pack("H*")

  def test_accepts_matching_ed25519_key_pair
    assert SparkleKeyPairVerifier.new.verify(
      private_key: Base64.strict_encode64(PRIVATE_SEED),
      expected_public_key: Base64.strict_encode64(PUBLIC_KEY)
    )
  end

  def test_rejects_mismatched_public_key
    error = assert_raises(RuntimeError) do
      SparkleKeyPairVerifier.new.verify(
        private_key: Base64.strict_encode64(PRIVATE_SEED),
        expected_public_key: Base64.strict_encode64("x" * 32)
      )
    end

    assert_equal "Sparkle private key does not match SPARKLE_PUBLIC_ED_KEY", error.message
  end

  def test_rejects_invalid_private_key_encoding
    error = assert_raises(RuntimeError) do
      SparkleKeyPairVerifier.new.verify(
        private_key: "not base64",
        expected_public_key: Base64.strict_encode64(PUBLIC_KEY)
      )
    end

    assert_equal "Sparkle private key must be strict base64", error.message
  end
end

class XCConfigReaderTest < Minitest::Test
  def test_preserves_base64_padding_and_removes_comment
    with_xcconfig("SPARKLE_PUBLIC_ED_KEY = YQ== // public key\n") do |path|
      assert_equal "YQ==", XCConfigReader.new(path).fetch("SPARKLE_PUBLIC_ED_KEY")
    end
  end

  def test_expands_empty_xcconfig_placeholder_in_url
    with_xcconfig("SPARKLE_FEED_URL = https:/$()/example.com/appcast.xml\n") do |path|
      assert_equal "https://example.com/appcast.xml", XCConfigReader.new(path).fetch("SPARKLE_FEED_URL")
    end
  end

  def test_rejects_duplicate_keys
    with_xcconfig("VERSION = 1.0.0\nVERSION = 2.0.0\n") do |path|
      error = assert_raises(RuntimeError) { XCConfigReader.new(path).fetch("VERSION") }
      assert_match(/Duplicate VERSION/, error.message)
    end
  end

  private

  def with_xcconfig(contents)
    Tempfile.create(["Config", ".xcconfig"]) do |file|
      file.write(contents)
      file.flush
      yield file.path
    end
  end
end

class ReleaseHistoryPolicyTest < Minitest::Test
  def test_accepts_monotonic_build_after_all_releases_reach_appcast
    assert policy.validate(
      requested_version: "1.4.4",
      requested_build: "43",
      releases: [release("v1.4.3", "1.4.3", "42")],
      appcast_entries: [["1.4.3", "42"]]
    )
  end

  def test_rejects_release_missing_from_appcast
    error = assert_raises(RuntimeError) do
      policy.validate(
        requested_version: "1.4.4",
        requested_build: "43",
        releases: [release("v1.4.3", "1.4.3", "42")],
        appcast_entries: []
      )
    end

    assert_equal "v1.4.3 is not yet present in appcast.xml", error.message
  end

  def test_rejects_build_not_greater_than_release_history
    error = assert_raises(RuntimeError) do
      policy.validate(
        requested_version: "1.4.4",
        requested_build: "42",
        releases: [release("v1.4.3", "1.4.3", "42")],
        appcast_entries: [["1.4.3", "42"]]
      )
    end

    assert_equal "Build 42 must be greater than v1.4.3 build 42", error.message
  end

  def test_allows_same_release_recovery_before_appcast_merge
    assert policy.validate(
      requested_version: "1.4.4",
      requested_build: "43",
      releases: [release("v1.4.4", "1.4.4", "43")],
      appcast_entries: []
    )
  end

  def test_rejects_semantic_version_rollback_even_with_higher_build
    error = assert_raises(RuntimeError) do
      policy.validate(
        requested_version: "1.4.4",
        requested_build: "100",
        releases: [release("v1.5.0", "1.5.0", "42")],
        appcast_entries: [["1.5.0", "42"]]
      )
    end

    assert_equal "Version 1.4.4 must be newer than v1.5.0", error.message
  end

  private

  def policy
    ReleaseHistoryPolicy.new
  end

  def release(tag, version, build)
    ReleaseRecord.new(tag: tag, version: version, build: build)
  end
end
