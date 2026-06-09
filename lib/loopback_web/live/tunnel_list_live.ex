defmodule LoopbackWeb.TunnelListLive do
  @moduledoc """
  LiveView for listing all tunnels with request counts.
  """

  use LoopbackWeb, :live_view

  alias Loopback.Captures
  alias Loopback.Tunnels

  @impl true
  def mount(_params, _session, socket) do
    tunnels = Tunnels.list_tunnels()
    tunnel_counts = Enum.into(tunnels, %{}, &{&1.id, length(Captures.list_requests(&1.id))})

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Loopback.PubSub, "tunnels")
    end

    {:ok, assign(socket, tunnels: tunnels, tunnel_counts: tunnel_counts, page_title: "Tunnels")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-zinc-900">Tunnels</h1>
          <p class="mt-1 text-sm text-zinc-600">
            Active webhook tunnels and their captured requests.
          </p>
        </div>
      </div>

      <div class="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50">
            <tr>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-zinc-500"
              >
                ID
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-zinc-500"
              >
                Target URL
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-zinc-500"
              >
                Created
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-zinc-500"
              >
                Requests
              </th>
              <th scope="col" class="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wider text-zinc-500">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-200 bg-white">
            <%= for tunnel <- @tunnels do %>
              <tr class="hover:bg-zinc-50 transition-colors">
                <td class="whitespace-nowrap px-6 py-4 text-sm font-mono text-zinc-900">
                  <%= tunnel.id %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-600">
                  <%= tunnel.target_url %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  <%= format_datetime(tunnel.inserted_at) %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-900">
                  <span class="inline-flex items-center rounded-md bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-700">
                    <%= Map.get(@tunnel_counts, tunnel.id, 0) %>
                  </span>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-right text-sm font-medium">
                  <a
                    href={"/tunnels/#{tunnel.id}"}
                    class="text-indigo-600 hover:text-indigo-900 transition-colors"
                  >
                    Inspect
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if @tunnels == [] do %>
          <div class="px-6 py-12 text-center">
            <p class="text-sm text-zinc-500">
              No tunnels created yet. Create one in IEx with:
            </p>
            <code class="mt-2 inline-block rounded-md bg-zinc-900 px-3 py-2 text-xs font-mono text-zinc-100">
              Loopback.Tunnels.create_tunnel("http://localhost:3000")
            </code>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:request_captured, request}, socket) do
    new_counts =
      Map.update(
        socket.assigns.tunnel_counts,
        request.tunnel_id,
        1,
        &(&1 + 1)
      )

    {:noreply, assign(socket, tunnel_counts: new_counts)}
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end
end
