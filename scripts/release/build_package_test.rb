# frozen_string_literal: true

require "open3"
require "pathname"
require "minitest/autorun"

class BuildPackageTest < Minitest::Test
  SCRIPT = Pathname(__dir__).join("build_package.sh").freeze

  def run_with(environment)
    Open3.capture3(ENV.to_h.merge(environment), "bash", SCRIPT.to_s)
  end

  def test_rejects_non_semver_version_before_building
    _out, error, status = run_with("VERSION" => "invalid", "BUILD_NUMBER" => "1")

    refute status.success?
    assert_includes error, "VERSION must look like 1.2.3"
  end

  def test_rejects_non_positive_build_number_before_building
    _out, error, status = run_with("VERSION" => "0.0.0", "BUILD_NUMBER" => "0")

    refute status.success?
    assert_includes error, "BUILD_NUMBER must be a positive integer"
  end

  def test_unsigned_artifact_contract_is_present
    source = SCRIPT.read

    assert_includes source, 'ZIP_NAME="Line-${VERSION}.zip"'
    assert_includes source, 'DMG_NAME="Line-${VERSION}.dmg"'
    assert_includes source, 'shasum -a 256 "$ZIP_NAME" "$DMG_NAME"'
    assert_includes source, 'ALLOW_UNSIGNED=1'
  end
end
