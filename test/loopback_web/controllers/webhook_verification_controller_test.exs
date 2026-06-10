defmodule LoopbackWeb.WebhookVerificationControllerTest do
  use LoopbackWeb.ConnCase, async: false

  alias Loopback.Captures
  alias Loopback.Captures.ETS
  alias Loopback.Webhooks.Signature

  setup do
    ETS.clear()
    :ok
  end

  describe "POST /api/verify-webhook" do
    test "verifies a valid GitHub signature", %{conn: conn} do
      payload = ~s({"action": "opened"})
      secret = "github-secret"
      sig = Signature.hmac_sha256_hex(secret, payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"x-hub-signature-256", "sha256=#{sig}"}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "github",
          "secret" => secret
        })

      assert json_response(conn, 200) == %{"valid" => true}
    end

    test "rejects an invalid GitHub signature", %{conn: conn} do
      payload = ~s({"action": "opened"})
      secret = "github-secret"

      request =
        build_captured_request(
          body: payload,
          headers: [{"x-hub-signature-256", "sha256=0000000000000000000000000000000000000000000000000000000000000000"}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "github",
          "secret" => secret
        })

      assert json_response(conn, 400) == %{
               "valid" => false,
               "error" => "signature does not match"
             }
    end

    test "verifies a valid Stripe signature", %{conn: conn} do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test"
      timestamp = System.system_time(:second) - 10
      signed_payload = "#{timestamp}.#{payload}"
      sig = Signature.hmac_sha256_hex(secret, signed_payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"stripe-signature", "t=#{timestamp},v1=#{sig}"}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "stripe",
          "secret" => secret
        })

      assert json_response(conn, 200) == %{"valid" => true}
    end

    test "rejects an expired Stripe signature", %{conn: conn} do
      payload = ~s({"id": "evt_123"})
      secret = "whsec_test"
      # 400 seconds ago, beyond default 300s tolerance
      timestamp = System.system_time(:second) - 400
      signed_payload = "#{timestamp}.#{payload}"
      sig = Signature.hmac_sha256_hex(secret, signed_payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"stripe-signature", "t=#{timestamp},v1=#{sig}"}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "stripe",
          "secret" => secret
        })

      assert json_response(conn, 400) == %{
               "valid" => false,
               "error" => "signature timestamp is too old"
             }
    end

    test "verifies a valid generic hex signature", %{conn: conn} do
      payload = "hello world"
      secret = "generic-secret"
      sig = Signature.hmac_sha256_hex(secret, payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"x-signature", sig}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "generic",
          "secret" => secret
        })

      assert json_response(conn, 200) == %{"valid" => true}
    end

    test "verifies a valid generic base64 signature", %{conn: conn} do
      payload = "hello world"
      secret = "generic-secret"
      sig = Signature.hmac_sha256_base64(secret, payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"x-signature", sig}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "generic",
          "secret" => secret,
          "encoding" => "base64"
        })

      assert json_response(conn, 200) == %{"valid" => true}
    end

    test "verifies with custom header name", %{conn: conn} do
      payload = "hello world"
      secret = "generic-secret"
      sig = Signature.hmac_sha256_hex(secret, payload)

      request =
        build_captured_request(
          body: payload,
          headers: [{"x-custom-sig", sig}]
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "generic",
          "secret" => secret,
          "header" => "x-custom-sig"
        })

      assert json_response(conn, 200) == %{"valid" => true}
    end

    test "returns 404 when request does not exist", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => "nonexistent",
          "provider" => "github",
          "secret" => "secret"
        })

      assert json_response(conn, 404) == %{"error" => "request not found"}
    end

    test "returns 400 for missing provider", %{conn: conn} do
      request = build_captured_request(body: "test")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "secret" => "secret"
        })

      assert json_response(conn, 400) == %{
               "valid" => false,
               "error" => "missing provider parameter"
             }
    end

    test "returns 400 for unknown provider", %{conn: conn} do
      request = build_captured_request(body: "test")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "unknown",
          "secret" => "secret"
        })

      assert json_response(conn, 400) == %{
               "valid" => false,
               "error" => "unknown provider (expected github, stripe, or generic)"
             }
    end

    test "returns 400 for missing signature header", %{conn: conn} do
      request = build_captured_request(body: "test", headers: [])

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/verify-webhook", %{
          "request_id" => request.id,
          "provider" => "github",
          "secret" => "secret"
        })

      assert json_response(conn, 400) == %{
               "valid" => false,
               "error" => "request is missing the expected signature header"
             }
    end
  end

  defp build_captured_request(opts) do
    body = Keyword.get(opts, :body, "")
    headers = Keyword.get(opts, :headers, [{"accept", "application/json"}])

    conn = %Plug.Conn{
      method: "POST",
      path_info: ["webhooks"],
      query_string: "",
      req_headers: headers,
      assigns: %{raw_body: body}
    }

    Captures.capture_request(conn, "tunnel-1")
  end
end
