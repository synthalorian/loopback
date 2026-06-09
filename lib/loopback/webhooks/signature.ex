defmodule Loopback.Webhooks.Signature do
  @moduledoc """
  Low-level signature computation helpers for webhook verification.

  Provides HMAC-SHA256 and hex/base64 encoding utilities used by the
  higher-level `Loopback.Webhooks` verification API.
  """

  @doc """
  Computes the HMAC-SHA256 of `payload` using `secret`.

  Returns the raw binary digest.
  """
  @spec hmac_sha256(String.t(), binary()) :: binary()
  def hmac_sha256(secret, payload) when is_binary(secret) and is_binary(payload) do
    :crypto.mac(:hmac, :sha256, secret, payload)
  end

  @doc """
  Computes the HMAC-SHA256 hex digest of `payload` using `secret`.

  Returns a lower-case hex string.
  """
  @spec hmac_sha256_hex(String.t(), binary()) :: String.t()
  def hmac_sha256_hex(secret, payload) when is_binary(secret) and is_binary(payload) do
    secret
    |> hmac_sha256(payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Computes the HMAC-SHA256 base64 digest of `payload` using `secret`.
  """
  @spec hmac_sha256_base64(String.t(), binary()) :: String.t()
  def hmac_sha256_base64(secret, payload) when is_binary(secret) and is_binary(payload) do
    secret
    |> hmac_sha256(payload)
    |> Base.encode64()
  end

  @doc """
  Constant-time comparison of two binary strings to prevent timing attacks.
  """
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and
      :crypto.hash_equals(left, right)
  end
end
