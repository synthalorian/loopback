defmodule LoopbackWeb.TunnelDetailLive do
  @moduledoc """
  LiveView for inspecting captured requests for a specific tunnel.
  """

  use LoopbackWeb, :live_view

  alias Loopback.Captures
  alias Loopback.Tunnels

  @impl true
  def mount(%{"id" => tunnel_id}, _session, socket) do
    tunnel = Tunnels.get_tunnel(tunnel_id)
    requests = Captures.list_requests(tunnel_id)

    if connected?(socket) and tunnel != nil do
      Phoenix.PubSub.subscribe(Loopback.PubSub, "tunnel:#{tunnel_id}")
    end

    {:ok,
     assign(socket,
       tunnel: tunnel,
       tunnel_id: tunnel_id,
       requests: requests,
       selected_request: List.first(requests),
       page_title: if(tunnel, do: "Tunnel #{tunnel.id}", else: "Tunnel Not Found")
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
                    <span class="text-xs text-zinc-500 font-mono"><%= @selected_request.id %></span>
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
    {:noreply, assign(socket, selected_request: request)}
  end

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
