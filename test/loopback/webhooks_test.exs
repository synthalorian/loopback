defmodule Loopback.WebhooksTest do
  use ExUnit.Case, async: true

  alias Loopback.Webhooks
  alias Loopback.Webhooks.Signature

  describe "Signature.hmac_sha256/2" do
    test "computes deterministic digest" do
      secret = "my-secret"
      payload = ~s({"event": "push"})

      sig1 = Signature.hmac_sha256(secret, payload)
      sig2 = Signature.hmac_sha256(secret, payload)

      assert sig1 == sig2
      assert is_binary(sig1)
      assert byte_size(sig1) == 32
    end

    test "different secrets produce different digests" do
      payload = ~s({"event": "push"})

      sig1 = Signature.hmac_sha256("secret-a", payload)
      sig2 = Signature.hmac_sha256("secret-b", payload)

      assert sig1 != sig2
    end

    test "different payloads produce different digests" do
      secret = "my-secret"

      sig1 = Signature.hmac_sha256(secret, ~s({"a": 1}))
      sig2 = Signature.hmac_sha256(secret, ~s({"a": 2}))

      assert sig1 != sig2
    end
  end

  describe "Signature.hmac_sha256_hex/2" do
    test "returns lower-case hex string" do
      sig = Signature.hmac_sha256_hex("secret", "payload")
      assert sig == String.downcase(sig)
      assert String.length(sig) == 64
    end
  end

  describe "Signature.hmac_sha256_base64/2" do
    test "returns base64 string" do
      sig = Signature.hmac_sha256_base64("secret", "payload")
      assert {:ok, _decoded} = Base.decode64(sig)
    end
  end

  describe "Signature.secure_compare/2" do
    test "returns true for equal binaries" do
      assert Signature.secure_compare("abc", "abc")
    end

    test "returns false for different binaries" do
      refute Signature.secure_compare("abc", "abd")
    end

    test "returns false for different lengths" do
      refute Signature.secure_compare("abc", "ab")
    end
  end

  describe "verify_github/3" do
    test "accepts a valid GitHub signature" do
      payload = ~s({"action": "opened"})
      secret = "webhook-secret"
      hex = Signature.hmac_sha256_hex(secret, payload)
      header = "sha256=#{hex}"

      assert :ok = Webhooks.verify_github(payload, secret, header)
    end

    test "rejects an invalid signature" do
      payload = ~s({"action": "opened"})
      secret = "webhook-secret"
      header = "sha256=0000000000000000000000000000000000000000000000000000000000000000"

      assert {:error, :invalid_signature} = Webhooks.verify_github(payload, secret, header)
    end

    test "rejects a malformed header" do
      payload = ~s({"action": "opened"})
      secret = "webhook-secret"

      assert {:error, :malformed_header} = Webhooks.verify_github(payload, secret, "badheader")
      assert {:error, :malformed_header} = Webhooks.verify_github(payload, secret, "")
    end
  end

  describe "verify_stripe/4" do
    test "accepts a valid Stripe signature" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      timestamp = System.system_time(:second) - 10
      signed_payload = "#{timestamp}.#{payload}"
      sig = Signature.hmac_sha256_hex(secret, signed_payload)
      header = "t=#{timestamp},v1=#{sig}"

      assert :ok = Webhooks.verify_stripe(payload, secret, header)
    end

    test "rejects an invalid signature" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      timestamp = System.system_time(:second)
      header = "t=#{timestamp},v1=0000000000000000000000000000000000000000000000000000000000000000"

      assert {:error, :invalid_signature} = Webhooks.verify_stripe(payload, secret, header)
    end

    test "rejects a missing timestamp" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      header = "v1=abc123"

      assert {:error, :missing_timestamp} = Webhooks.verify_stripe(payload, secret, header)
    end

    test "rejects a missing signature" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      header = "t=1234567890"

      assert {:error, :missing_signature} = Webhooks.verify_stripe(payload, secret, header)
    end

    test "rejects an old timestamp within tolerance" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      # 400 seconds ago, default tolerance is 300
      timestamp = System.system_time(:second) - 400
      signed_payload = "#{timestamp}.#{payload}"
      sig = Signature.hmac_sha256_hex(secret, signed_payload)
      header = "t=#{timestamp},v1=#{sig}"

      assert {:error, :timestamp_too_old} = Webhooks.verify_stripe(payload, secret, header)
    end

    test "accepts an old timestamp when tolerance is nil" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"
      timestamp = 1_000_000_000
      signed_payload = "#{timestamp}.#{payload}"
      sig = Signature.hmac_sha256_hex(secret, signed_payload)
      header = "t=#{timestamp},v1=#{sig}"

      assert :ok = Webhooks.verify_stripe(payload, secret, header, nil)
    end

    test "rejects a malformed header" do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test_secret"

      assert {:error, :missing_timestamp} = Webhooks.verify_stripe(payload, secret, "not_a_header")
      assert {:error, :malformed_header} = Webhooks.verify_stripe(payload, secret, "t=abc,v1=def")
    end
  end

  describe "verify_hmac_sha256/4" do
    test "accepts a valid raw signature" do
      payload = "hello"
      secret = "secret"
      sig = Signature.hmac_sha256(secret, payload)

      assert :ok = Webhooks.verify_hmac_sha256(payload, secret, sig, :raw)
    end

    test "accepts a valid hex signature" do
      payload = "hello"
      secret = "secret"
      sig = Signature.hmac_sha256_hex(secret, payload)

      assert :ok = Webhooks.verify_hmac_sha256(payload, secret, sig, :hex)
    end

    test "accepts a valid base64 signature" do
      payload = "hello"
      secret = "secret"
      sig = Signature.hmac_sha256_base64(secret, payload)

      assert :ok = Webhooks.verify_hmac_sha256(payload, secret, sig, :base64)
    end

    test "rejects an invalid signature" do
      payload = "hello"
      secret = "secret"

      assert {:error, :invalid_signature} =
               Webhooks.verify_hmac_sha256(payload, secret, <<0::256>>, :raw)
    end

    test "rejects a malformed hex signature" do
      payload = "hello"
      secret = "secret"

      assert {:error, :malformed_signature} =
               Webhooks.verify_hmac_sha256(payload, secret, "not-hex!", :hex)
    end

    test "rejects a malformed base64 signature" do
      payload = "hello"
      secret = "secret"

      assert {:error, :malformed_signature} =
               Webhooks.verify_hmac_sha256(payload, secret, "!!!", :base64)
    end

    test "defaults to raw encoding" do
      payload = "hello"
      secret = "secret"
      sig = Signature.hmac_sha256(secret, payload)

      assert :ok = Webhooks.verify_hmac_sha256(payload, secret, sig)
    end
  end
end
