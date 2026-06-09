defmodule LoopbackWeb.WebhookVerificationController do
  @moduledoc """
  API endpoint for verifying webhook signatures.

  Accepts a captured request id, provider type, and secret, then
  validates the signature header(s) against the stored request body.
  """

  use LoopbackWeb, :controller

  alias Loopback.Captures
  alias Loopback.Webhooks

  @doc """
  POST /api/verify-webhook

  Request body:
    * "request_id" - the captured request to verify
    * "provider"   - "github", "stripe", or "generic"
    * "secret"     - the webhook secret
    * "header"     - (optional) header name for generic verification (default "x-signature")
    * "encoding"   - (optional) "hex", "base64", or "raw" for generic verification (default "hex")
    * "tolerance"  - (optional) tolerance in seconds for Stripe (default 300, null to disable)

  Response:
    200 OK    - %{valid: true}
    400 Bad   - %{valid: false, error: "..."}
    404 Not   - %{error: "request not found"}
  """
  def verify(conn, params) do
    with {:ok, request} <- fetch_request(params),
         {:ok, provider} <- fetch_provider(params),
         {:ok, secret} <- fetch_secret(params) do
      result = do_verify(request, provider, secret, params)

      case result do
        :ok ->
          conn
          |> put_status(:ok)
          |> json(%{valid: true})

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{valid: false, error: format_error(reason)})
      end
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "request not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: format_error(reason)})
    end
  end

  defp fetch_request(%{"request_id" => request_id}) do
    case Captures.get_request(request_id) do
      nil -> {:error, :not_found}
      request -> {:ok, request}
    end
  end

  defp fetch_request(_), do: {:error, :missing_request_id}

  defp fetch_provider(%{"provider" => provider}) when provider in ["github", "stripe", "generic"] do
    {:ok, String.to_atom(provider)}
  end

  defp fetch_provider(%{"provider" => _}), do: {:error, :unknown_provider}
  defp fetch_provider(_), do: {:error, :missing_provider}

  defp fetch_secret(%{"secret" => secret}) when is_binary(secret) and secret != "" do
    {:ok, secret}
  end

  defp fetch_secret(_), do: {:error, :missing_secret}

  defp do_verify(request, :github, secret, _params) do
    header_value = get_header(request.headers, "x-hub-signature-256")

    case header_value do
      nil -> {:error, :missing_signature_header}
      value -> Webhooks.verify_github(request.body || "", secret, value)
    end
  end

  defp do_verify(request, :stripe, secret, params) do
    header_value = get_header(request.headers, "stripe-signature")
    tolerance = parse_tolerance(params["tolerance"])

    case header_value do
      nil -> {:error, :missing_signature_header}
      value -> Webhooks.verify_stripe(request.body || "", secret, value, tolerance)
    end
  end

  defp do_verify(request, :generic, secret, params) do
    header_name = params["header"] || "x-signature"
    encoding = parse_encoding(params["encoding"])
    header_value = get_header(request.headers, header_name)

    case header_value do
      nil -> {:error, :missing_signature_header}
      value -> Webhooks.verify_hmac_sha256(request.body || "", secret, value, encoding)
    end
  end

  defp get_header(headers, name) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == String.downcase(name) end)
    |> case do
      {_, value} -> value
      nil -> nil
    end
  end

  defp parse_tolerance(nil), do: 300
  defp parse_tolerance(""), do: 300

  defp parse_tolerance(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> 300
    end
  end

  defp parse_tolerance(value) when is_integer(value), do: value

  defp parse_encoding(nil), do: :hex
  defp parse_encoding("hex"), do: :hex
  defp parse_encoding("base64"), do: :base64
  defp parse_encoding("raw"), do: :raw
  defp parse_encoding(_), do: :hex

  defp format_error(:invalid_signature), do: "signature does not match"
  defp format_error(:malformed_header), do: "signature header is malformed"
  defp format_error(:malformed_signature), do: "signature is malformed"
  defp format_error(:missing_timestamp), do: "signature header is missing timestamp"
  defp format_error(:missing_signature), do: "signature header is missing signature"
  defp format_error(:timestamp_too_old), do: "signature timestamp is too old"
  defp format_error(:missing_signature_header), do: "request is missing the expected signature header"
  defp format_error(:missing_request_id), do: "missing request_id parameter"
  defp format_error(:missing_provider), do: "missing provider parameter"
  defp format_error(:unknown_provider), do: "unknown provider (expected github, stripe, or generic)"
  defp format_error(:missing_secret), do: "missing secret parameter"
  defp format_error(other), do: to_string(other)
end
