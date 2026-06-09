defmodule Loopback.Webhooks do
  @moduledoc """
  Webhook signature verification helpers.

  Supports common webhook providers and generic HMAC-SHA256 verification:

  * **GitHub** – `X-Hub-Signature-256` header (`sha256=<hex>`)
  * **Stripe** – `Stripe-Signature` header (`t=<timestamp>,v1=<hex>`)
  * **Generic** – any HMAC-SHA256 signature header

  ## Examples

      # GitHub-style verification
      iex> verify_github(payload, secret, "sha256=...")
      :ok

      # Stripe-style verification
      iex> verify_stripe(payload, secret, "t=1234567890,v1=...")
      :ok

      # Generic HMAC-SHA256 header
      iex> verify_hmac_sha256(payload, secret, signature, :hex)
      :ok
  """

  alias Loopback.Webhooks.Signature

  @doc """
  Verifies a GitHub-style `X-Hub-Signature-256` signature.

  The header value must be in the form `sha256=<hex>`.

  Returns `:ok` if the signature is valid, `{:error, reason}` otherwise.
  """
  @spec verify_github(binary(), String.t(), String.t()) :: :ok | {:error, atom()}
  def verify_github(payload, secret, header) when is_binary(payload) and is_binary(secret) and is_binary(header) do
    with "sha256=" <> expected_hex <- header do
      expected = Base.decode16!(expected_hex, case: :mixed)
      actual = Signature.hmac_sha256(secret, payload)

      if Signature.secure_compare(expected, actual) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> {:error, :malformed_header}
    end
  end

  @doc """
  Verifies a Stripe-style `Stripe-Signature` header.

  The header value must be in the form `t=<unix_timestamp>,v1=<hex>`.
  Optional signed schemes (e.g. `v0=...`) are ignored.

  `tolerance` is the maximum age in seconds (default 300).  Pass `nil`
  to skip timestamp checks entirely.

  Returns `:ok` if the signature is valid and within tolerance,
  `{:error, reason}` otherwise.
  """
  @spec verify_stripe(binary(), String.t(), String.t(), non_neg_integer() | nil) ::
          :ok | {:error, atom()}
  def verify_stripe(payload, secret, header, tolerance \\ 300)

  def verify_stripe(payload, secret, header, tolerance)
      when is_binary(payload) and is_binary(secret) and is_binary(header) do
    with {:ok, timestamp, signatures} <- parse_stripe_header(header),
         :ok <- check_timestamp(timestamp, tolerance) do
      signed_payload = "#{timestamp}.#{payload}"
      expected = Signature.hmac_sha256_hex(secret, signed_payload)

      if Enum.any?(signatures, &Signature.secure_compare(&1, expected)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  @doc """
  Verifies a generic HMAC-SHA256 signature.

  `signature` may be provided as a raw binary, a hex string, or a
  base64-encoded string.  The `encoding` argument controls how the
  `signature` argument is interpreted:

  * `:raw`   – `signature` is the raw HMAC digest binary
  * `:hex`   – `signature` is a lower- or upper-case hex string
  * `:base64` – `signature` is a base64-encoded string

  Returns `:ok` if the signature is valid, `{:error, reason}` otherwise.
  """
  @spec verify_hmac_sha256(binary(), String.t(), binary() | String.t(), :raw | :hex | :base64) ::
          :ok | {:error, atom()}
  def verify_hmac_sha256(payload, secret, signature, encoding \\ :raw)

  def verify_hmac_sha256(payload, secret, signature, :raw)
      when is_binary(payload) and is_binary(secret) and is_binary(signature) do
    expected = Signature.hmac_sha256(secret, payload)

    if Signature.secure_compare(signature, expected) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def verify_hmac_sha256(payload, secret, signature, :hex)
      when is_binary(payload) and is_binary(secret) and is_binary(signature) do
    case Base.decode16(signature, case: :mixed) do
      {:ok, decoded} -> verify_hmac_sha256(payload, secret, decoded, :raw)
      :error -> {:error, :malformed_signature}
    end
  end

  def verify_hmac_sha256(payload, secret, signature, :base64)
      when is_binary(payload) and is_binary(secret) and is_binary(signature) do
    case Base.decode64(signature) do
      {:ok, decoded} -> verify_hmac_sha256(payload, secret, decoded, :raw)
      :error -> {:error, :malformed_signature}
    end
  end

  # -- Private helpers --

  defp parse_stripe_header(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.split(&1, "=", parts: 2))

    timestamp =
      case Enum.find(parts, fn [k | _] -> k == "t" end) do
        ["t", ts] -> String.to_integer(ts)
        _ -> nil
      end

    signatures =
      parts
      |> Enum.filter(fn [k | _] -> k == "v1" end)
      |> Enum.map(fn [_, sig] -> sig end)

    cond do
      is_nil(timestamp) -> {:error, :missing_timestamp}
      signatures == [] -> {:error, :missing_signature}
      true -> {:ok, timestamp, signatures}
    end
  rescue
    ArgumentError -> {:error, :malformed_header}
  end

  defp check_timestamp(_timestamp, nil), do: :ok

  defp check_timestamp(timestamp, tolerance) when is_integer(tolerance) do
    now = System.system_time(:second)

    if now - timestamp > tolerance do
      {:error, :timestamp_too_old}
    else
      :ok
    end
  end
end
