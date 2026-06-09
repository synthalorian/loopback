defmodule LoopbackWeb.TunnelDetailLive do
  @moduledoc """
  LiveView for inspecting captured requests for a specific tunnel.
  """

  use LoopbackWeb, :live_view

  alias Loopback.Captures
  alias Loopback.Replay
  alias Loopback.Transformations
  alias Loopback.Tunnels

  @impl true
  def mount(%{"id" => tunnel_id}, _session, socket) do
    tunnel = Tunnels.get_tunnel(tunnel_id)
    requests = Captures.list_requests(tunnel_id)
    script = if tunnel, do: Transformations.get_script(tunnel_id), else: nil

    if connected?(socket) and tunnel != nil do
      Phoenix.PubSub.subscribe(Loopback.PubSub, "tunnel:#{tunnel_id}")
    end

    {:ok,
     assign(socket,
       tunnel: tunnel,
       tunnel_id: tunnel_id,
       requests: requests,
       selected_request: List.first(requests),
       page_title: if(tunnel, do: "Tunnel #{tunnel.id}", else: "Tunnel Not Found"),
       replay_mode: false,
       replay_result: nil,
       replay_error: nil,
       transform_script: script || "",
       transform_mode: false,
       transform_error: nil,
       transform_success: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @tunnel == nil do %>
        <div class="rounded-xl border border-zinc-200 bg-white p-12 text-center shadow-sm">
          <h2 class="text-lg font-semibold text-zinc-900">Tunnel not found</h2>
          <p class="mt-2 text-sm text-zinc-600">
            The tunnel <code class="font-mono text-zinc-800"><%= @tunnel_id %></code> does not exist.
          </p>
          <a
            href="/tunnels"
            class="mt-6 inline-flex items-center rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 transition-colors"
          >
            Back to Tunnels
          </a>
        </div>
      <% else %>
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-3">
              <a href="/tunnels" class="text-sm text-zinc-500 hover:text-zinc-900 transition-colors">
                ← Tunnels
              </a>
            </div>
            <h1 class="mt-2 text-2xl font-bold tracking-tight text-zinc-900">
              Tunnel <%= @tunnel.id %>
            </h1>
            <p class="mt-1 text-sm text-zinc-600">
              Forwarding to <span class="font-mono text-zinc-800"><%= @tunnel.target_url %></span>
            </p>
          </div>
          <div class="text-right">
            <span class="inline-flex items-center rounded-md bg-emerald-50 px-2 py-1 text-xs font-medium text-emerald-700 ring-1 ring-inset ring-emerald-600/20">
              <%= length(@requests) %> requests
            </span>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div class="lg:col-span-1">
            <div class="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
              <div class="border-b border-zinc-200 bg-zinc-50 px-4 py-3">
                <h2 class="text-sm font-semibold text-zinc-900">Requests</h2>
              </div>
              <div class="max-h-[600px] overflow-y-auto">
                <%= if @requests == [] do %>
                  <div class="px-4 py-8 text-center">
                    <p class="text-sm text-zinc-500">No requests captured yet.</p>
                    <p class="mt-1 text-xs text-zinc-400">
                      Send a request to <code class="font-mono">/t/<%= @tunnel.id %>/...</code>
                    </p>
                  </div>
                <% else %>
                  <div class="divide-y divide-zinc-100">
                    <%= for request <- @requests do %>
                      <button
                        phx-click="select_request"
                        phx-value-id={request.id}
                        class={[
                          "w-full px-4 py-3 text-left transition-colors hover:bg-zinc-50",
                          @selected_request && @selected_request.id == request.id && "bg-indigo-50 hover:bg-indigo-100"
                        ]}
                      >
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <span class={[
                              "inline-flex rounded px-1.5 py-0.5 text-xs font-semibold",
                              method_color(request.method)
                            ]}>
                              <%= request.method %>
                            </span>
                            <span class="text-sm font-medium text-zinc-900 truncate max-w-[140px]">
                              <%= request.path %>
                            </span>
                          </div>
                          <%= if request.response_status do %>
                            <span class={[
                              "text-xs font-medium",
                              status_color(request.response_status)
                            ]}>
                              <%= request.response_status %>
                            </span>
                          <% end %>
                        </div>
                        <div class="mt-1 text-xs text-zinc-500">
                          <%= format_datetime(request.inserted_at) %>
                        </div>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="lg:col-span-2">
            <div class="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
              <%= if @selected_request do %>
                <div class="border-b border-zinc-200 bg-zinc-50 px-4 py-3">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-semibold text-zinc-900">Request Detail</h2>
                    <div class="flex items-center gap-2">
                      <button
                        phx-click="replay_exact"
                        class="inline-flex items-center rounded-md bg-emerald-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-emerald-500 transition-colors"
                      >
                        Replay
                      </button>
                      <button
                        phx-click="toggle_replay_mode"
                        class="inline-flex items-center rounded-md bg-indigo-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-indigo-500 transition-colors"
                      >
                        Modify & Replay
                      </button>
                      <span class="text-xs text-zinc-500 font-mono"><%= @selected_request.id %></span>
                    </div>
                  </div>
                </div>
                <div class="divide-y divide-zinc-100">
                  <div class="px-4 py-4">
                    <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                      General
                    </h3>
                    <div class="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <span class="text-zinc-500">Method:</span>
                        <span class="ml-1 font-medium text-zinc-900"><%= @selected_request.method %></span>
                      </div>
                      <div>
                        <span class="text-zinc-500">Path:</span>
                        <span class="ml-1 font-mono text-zinc-900"><%= @selected_request.path %></span>
                      </div>
                      <div>
                        <span class="text-zinc-500">Time:</span>
                        <span class="ml-1 text-zinc-900"><%= format_datetime(@selected_request.inserted_at) %></span>
                      </div>
                      <%= if @selected_request.query_string do %>
                        <div class="col-span-2">
                          <span class="text-zinc-500">Query:</span>
                          <span class="ml-1 font-mono text-zinc-900"><%= @selected_request.query_string %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="px-4 py-4">
                    <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                      Request Headers
                    </h3>
                    <div class="space-y-1 text-sm">
                      <%= for {name, value} <- @selected_request.headers do %>
                        <div class="font-mono text-xs">
                          <span class="text-indigo-600"><%= name %>:</span>
                          <span class="text-zinc-700"><%= value %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <%= if @selected_request.body do %>
                    <div class="px-4 py-4">
                      <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                        Request Body
                      </h3>
                      <pre class="overflow-x-auto rounded-lg bg-zinc-900 p-3 text-xs text-zinc-100 font-mono"><%= Phoenix.HTML.raw(format_body(@selected_request.body)) %></pre>
                    </div>
                  <% end %>

                  <%= if @selected_request.response_status do %>
                    <div class="px-4 py-4">
                      <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                        Response
                      </h3>
                      <div class="text-sm mb-2">
                        <span class="text-zinc-500">Status:</span>
                        <span class={["ml-1 font-medium", status_color(@selected_request.response_status)]}>
                          <%= @selected_request.response_status %>
                        </span>
                      </div>
                      <%= if @selected_request.response_headers do %>
                        <div class="space-y-1 text-sm mb-3">
                          <%= for {name, value} <- @selected_request.response_headers do %>
                            <div class="font-mono text-xs">
                              <span class="text-indigo-600"><%= name %>:</span>
                              <span class="text-zinc-700"><%= value %></span>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                      <%= if @selected_request.response_body do %>
                        <pre class="overflow-x-auto rounded-lg bg-zinc-900 p-3 text-xs text-zinc-100 font-mono"><%= Phoenix.HTML.raw(format_body(@selected_request.response_body)) %></pre>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="px-4 py-12 text-center">
                  <p class="text-sm text-zinc-500">Select a request to view details.</p>
                </div>
              <% end %>

              <%= if @replay_mode do %>
                <div class="border-t border-zinc-200 px-4 py-4">
                  <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                    Modify & Replay
                  </h3>
                  <form phx-submit="replay_modified" class="space-y-3">
                    <div class="grid grid-cols-2 gap-3">
                      <div>
                        <label class="block text-xs font-medium text-zinc-700">Method</label>
                        <input
                          type="text"
                          name="method"
                          value={@selected_request && @selected_request.method}
                          class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm text-sm"
                        />
                      </div>
                      <div>
                        <label class="block text-xs font-medium text-zinc-700">Path</label>
                        <input
                          type="text"
                          name="path"
                          value={@selected_request && @selected_request.path}
                          class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm text-sm"
                        />
                      </div>
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-zinc-700">Query String</label>
                      <input
                        type="text"
                        name="query_string"
                        value={@selected_request && @selected_request.query_string || ""}
                        class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm text-sm"
                      />
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-zinc-700">Body</label>
                      <textarea
                        name="body"
                        rows="3"
                        class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm text-sm font-mono"
                      ><%= @selected_request && @selected_request.body || "" %></textarea>
                    </div>
                    <div class="flex items-center gap-2">
                      <button
                        type="submit"
                        class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-xs font-semibold text-white shadow-sm hover:bg-indigo-500 transition-colors"
                      >
                        Send Replay
                      </button>
                      <button
                        type="button"
                        phx-click="toggle_replay_mode"
                        class="inline-flex items-center rounded-md bg-zinc-100 px-3 py-2 text-xs font-semibold text-zinc-700 shadow-sm hover:bg-zinc-200 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                </div>
              <% end %>

              <%= if @replay_result do %>
                <div class="border-t border-zinc-200 px-4 py-4">
                  <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-3">
                    Replay Result
                  </h3>
                  <div class="text-sm mb-2">
                    <span class="text-zinc-500">Status:</span>
                    <span class={["ml-1 font-medium", status_color(@replay_result.response_status)]}>
                      <%= @replay_result.response_status %>
                    </span>
                  </div>
                  <%= if @replay_result.response_body do %>
                    <pre class="overflow-x-auto rounded-lg bg-zinc-900 p-3 text-xs text-zinc-100 font-mono"><%= Phoenix.HTML.raw(format_body(@replay_result.response_body)) %></pre>
                  <% end %>
                  <button
                    phx-click="clear_replay_result"
                    class="mt-2 inline-flex items-center rounded-md bg-zinc-100 px-2 py-1 text-xs font-semibold text-zinc-700 shadow-sm hover:bg-zinc-200 transition-colors"
                  >
                    Dismiss
                  </button>
                </div>
              <% end %>

              <%= if @replay_error do %>
                <div class="border-t border-zinc-200 px-4 py-4">
                  <div class="rounded-md bg-rose-50 p-3">
                    <p class="text-sm text-rose-700"><%= @replay_error %></p>
                  </div>
                  <button
                    phx-click="clear_replay_result"
                    class="mt-2 inline-flex items-center rounded-md bg-zinc-100 px-2 py-1 text-xs font-semibold text-zinc-700 shadow-sm hover:bg-zinc-200 transition-colors"
                  >
                    Dismiss
                  </button>
                </div>
              <% end %>

              <!-- Transformation Script Section -->
              <div class="border-t border-zinc-200 px-4 py-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                    Programmable Transformation
                  </h3>
                  <button
                    phx-click="toggle_transform_mode"
                    class="inline-flex items-center rounded-md bg-amber-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-amber-500 transition-colors"
                  >
                    <%= if @transform_mode, do: "Cancel", else: if(@transform_script != "", do: "Edit Script", else: "Add Script") %>
                  </button>
                </div>

                <%= if not @transform_mode do %>
                  <%= if @transform_script != "" do %>
                    <div class="rounded-lg bg-zinc-900 p-3">
                      <pre class="overflow-x-auto text-xs text-zinc-100 font-mono"><%= @transform_script %></pre>
                    </div>
                    <div class="mt-2 flex items-center gap-2">
                      <span class="inline-flex items-center rounded-md bg-emerald-50 px-2 py-1 text-xs font-medium text-emerald-700 ring-1 ring-inset ring-emerald-600/20">
                        Active
                      </span>
                      <button
                        phx-click="delete_transform"
                        class="text-xs text-rose-600 hover:text-rose-800 font-medium"
                      >
                        Delete
                      </button>
                    </div>
                  <% else %>
                    <p class="text-sm text-zinc-500">No transformation script configured.</p>
                    <p class="mt-1 text-xs text-zinc-400">
                      Scripts modify requests before forwarding. The script receives a <code class="font-mono">ctx</code> map and must return a map with <code class="font-mono">method</code>, <code class="font-mono">path</code>, <code class="font-mono">query_string</code>, <code class="font-mono">headers</code>, and <code class="font-mono">body</code>.
                    </p>
                  <% end %>
                <% end %>

                <%= if @transform_mode do %>
                  <form phx-submit="save_transform" class="space-y-3">
                    <div>
                      <label class="block text-xs font-medium text-zinc-700">Script</label>
                      <textarea
                        name="script"
                        rows="8"
                        class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm text-sm font-mono"
                      ><%= @transform_script %></textarea>
                    </div>
                    <div class="rounded-md bg-zinc-50 p-2">
                      <p class="text-xs text-zinc-600">
                        <span class="font-semibold">Available in script:</span>
                        <code class="font-mono text-zinc-800">ctx</code> (map with method, path, query_string, headers, body),
                        <code class="font-mono text-zinc-800">Jason</code>,
                        <code class="font-mono text-zinc-800">String</code>,
                        <code class="font-mono text-zinc-800">Map</code>,
                        <code class="font-mono text-zinc-800">Enum</code>, etc.
                      </p>
                    </div>
                    <div class="flex items-center gap-2">
                      <button
                        type="submit"
                        class="inline-flex items-center rounded-md bg-amber-600 px-3 py-2 text-xs font-semibold text-white shadow-sm hover:bg-amber-500 transition-colors"
                      >
                        Save Script
                      </button>
                      <button
                        type="button"
                        phx-click="test_transform"
                        class="inline-flex items-center rounded-md bg-zinc-100 px-3 py-2 text-xs font-semibold text-zinc-700 shadow-sm hover:bg-zinc-200 transition-colors"
                      >
                        Test
                      </button>
                    </div>
                  </form>
                <% end %>

                <%= if @transform_error do %>
                  <div class="mt-3 rounded-md bg-rose-50 p-3">
                    <p class="text-sm text-rose-700"><%= @transform_error %></p>
                  </div>
                <% end %>

                <%= if @transform_success do %>
                  <div class="mt-3 rounded-md bg-emerald-50 p-3">
                    <p class="text-sm text-emerald-700"><%= @transform_success %></p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("select_request", %{"id" => request_id}, socket) do
    request = Captures.get_request(request_id)
    {:noreply, assign(socket, selected_request: request, replay_result: nil, replay_error: nil)}
  end

  @impl true
  def handle_event("replay_exact", _params, socket) do
    case do_replay(socket, %{}) do
      {:ok, request} ->
        {:noreply, assign(socket, replay_result: request, replay_error: nil, replay_mode: false)}

      {:error, reason} ->
        {:noreply, assign(socket, replay_error: error_message(reason), replay_result: nil)}
    end
  end

  @impl true
  def handle_event("toggle_replay_mode", _params, socket) do
    {:noreply, assign(socket, replay_mode: !socket.assigns.replay_mode, replay_result: nil, replay_error: nil)}
  end

  @impl true
  def handle_event("replay_modified", params, socket) do
    modifications = %{
      method: Map.get(params, "method"),
      path: Map.get(params, "path"),
      query_string: nilify_empty(Map.get(params, "query_string")),
      body: nilify_empty(Map.get(params, "body"))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    case do_replay(socket, modifications) do
      {:ok, request} ->
        {:noreply, assign(socket, replay_result: request, replay_error: nil, replay_mode: false)}

      {:error, reason} ->
        {:noreply, assign(socket, replay_error: error_message(reason), replay_result: nil)}
    end
  end

  @impl true
  def handle_event("clear_replay_result", _params, socket) do
    {:noreply, assign(socket, replay_result: nil, replay_error: nil)}
  end

  @impl true
  def handle_event("toggle_transform_mode", _params, socket) do
    {:noreply,
     assign(socket,
       transform_mode: !socket.assigns.transform_mode,
       transform_error: nil,
       transform_success: nil
     )}
  end

  @impl true
  def handle_event("save_transform", %{"script" => script_text}, socket) do
    tunnel_id = socket.assigns.tunnel_id

    # Validate by testing with a sample context
    sample_ctx = %{
      method: "GET",
      path: "/test",
      query_string: nil,
      headers: [{"accept", "application/json"}],
      body: nil
    }

    case Transformations.transform(tunnel_id, sample_ctx) do
      {:ok, _} when socket.assigns.transform_script == "" and script_text == "" ->
        {:noreply, assign(socket, transform_error: "Script cannot be empty", transform_success: nil)}

      _ ->
        :ok = Transformations.set_script(tunnel_id, script_text)

        {:noreply,
         assign(socket,
           transform_script: script_text,
           transform_mode: false,
           transform_error: nil,
           transform_success: "Transformation script saved."
         )}
    end
  end

  @impl true
  def handle_event("delete_transform", _params, socket) do
    tunnel_id = socket.assigns.tunnel_id
    :ok = Transformations.delete_script(tunnel_id)

    {:noreply,
     assign(socket,
       transform_script: "",
       transform_mode: false,
       transform_error: nil,
       transform_success: "Transformation script deleted."
     )}
  end

  @impl true
  def handle_event("test_transform", %{"script" => script_text}, socket) do
    sample_ctx = %{
      method: "POST",
      path: "/webhooks/github",
      query_string: "foo=bar",
      headers: [{"content-type", "application/json"}, {"x-signature", "abc123"}],
      body: ~s({"event": "push"})
    }

    # Temporarily evaluate without saving
    case Loopback.Transformations.Script.execute(script_text, sample_ctx) do
      {:ok, result} ->
        formatted =
          result
          |> Map.take([:method, :path, :query_string, :headers, :body])
          |> Jason.encode!(pretty: true)

        {:noreply,
         assign(socket,
           transform_error: nil,
           transform_success: "Test passed. Result:\n#{formatted}"
         )}

      {:error, reason} ->
        {:noreply, assign(socket, transform_error: "Test failed: #{reason}", transform_success: nil)}
    end
  end

  defp do_replay(socket, modifications) do
    if socket.assigns.selected_request do
      Replay.replay_request(socket.assigns.selected_request.id, modifications)
    else
      {:error, :no_request_selected}
    end
  end

  defp nilify_empty(""), do: nil
  defp nilify_empty(value), do: value

  defp error_message(:not_found), do: "Request not found."
  defp error_message(:no_request_selected), do: "No request selected."
  defp error_message(other), do: "Replay failed: #{inspect(other)}"

  @impl true
  def handle_info({:request_captured, request}, socket) do
    if socket.assigns.tunnel && request.tunnel_id == socket.assigns.tunnel.id do
      requests = [request | socket.assigns.requests]
      selected = socket.assigns.selected_request || request

      {:noreply, assign(socket, requests: requests, selected_request: selected)}
    else
      {:noreply, socket}
    end
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        Jason.encode!(decoded, pretty: true)

      {:error, _} ->
        body
    end
  end

  defp format_body(body), do: inspect(body)

  defp method_color(method) do
    case method do
      "GET" -> "bg-emerald-100 text-emerald-700"
      "POST" -> "bg-blue-100 text-blue-700"
      "PUT" -> "bg-amber-100 text-amber-700"
      "PATCH" -> "bg-amber-100 text-amber-700"
      "DELETE" -> "bg-rose-100 text-rose-700"
      _ -> "bg-zinc-100 text-zinc-700"
    end
  end

  defp status_color(status) when is_integer(status) do
    cond do
      status < 300 -> "text-emerald-600"
      status < 400 -> "text-amber-600"
      status < 500 -> "text-rose-600"
      true -> "text-red-700"
    end
  end

  defp status_color(_), do: "text-zinc-600"
end
