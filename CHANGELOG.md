# Changelog

## 1.0.0 — 2026-06-10

### Added

- **Phase 1 — Phoenix scaffold**: Phoenix 1.7 application with LiveDashboard for observability
- **Phase 2 — Tunnel core**: Public URL tunnels that forward requests to local HTTP servers via `Loopback.Tunnels`
- **Phase 3 — Request capture**: ETS-based request storage with configurable capacity and automatic pruning of old entries
- **Phase 4 — Inspection UI**: Phoenix LiveView interface for browsing, searching, and filtering captured requests
- **Phase 5 — Replay engine**: Exact and modified request replay with full request/response inspection
- **Phase 6 — Programmable transformations**: Lua/Elixir sandboxed scripting engine for modifying requests in-flight via `Loopback.Transformations`
- **Phase 7 — Chaos mode**: Configurable GenServer that randomly delays, drops, or corrupts requests for resilience testing
- **Phase 8 — Webhook verification**: HMAC signature verification helpers for Stripe, GitHub, and generic webhooks

### Technical Details

- 119 tests, all passing
- Elixir ~> 1.16, Phoenix ~> 1.7, Bandit ~> 1.2
- Zero compiler warnings in production code
