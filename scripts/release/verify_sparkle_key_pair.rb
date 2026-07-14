#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "openssl"

class SparkleKeyPairVerifier
  PRIVATE_KEY_PREFIX = ["302e020100300506032b657004220420"].pack("H*").freeze
  KEY_LENGTH = 32

  def verify(private_key:, expected_public_key:)
    private_seed = decode_key(private_key, name: "Sparkle private key")
    expected_public = decode_key(expected_public_key, name: "Sparkle public key")
    signing_key = OpenSSL::PKey.read(PRIVATE_KEY_PREFIX + private_seed)
    derived_public = signing_key.raw_public_key

    unless OpenSSL.fixed_length_secure_compare(derived_public, expected_public)
      raise "Sparkle private key does not match SPARKLE_PUBLIC_ED_KEY"
    end

    true
  rescue OpenSSL::PKey::PKeyError
    raise "Sparkle private key is not a valid Ed25519 seed"
  end

  private

  def decode_key(value, name:)
    decoded = Base64.strict_decode64(value.strip)
    raise "#{name} must decode to #{KEY_LENGTH} bytes" unless decoded.bytesize == KEY_LENGTH

    decoded
  rescue ArgumentError
    raise "#{name} must be strict base64"
  end
end

if $PROGRAM_NAME == __FILE__
  SparkleKeyPairVerifier.new.verify(
    private_key: $stdin.read,
    expected_public_key: ENV.fetch("SPARKLE_PUBLIC_ED_KEY")
  )
  puts "Sparkle signing key matches the configured public key."
end
