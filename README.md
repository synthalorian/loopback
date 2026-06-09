# loopback

> Self-hosted webhook testing tunnel like ngrok but with replay, inspection, programmable transformations... AND a chaos mode that randomly delays, drops, or corrupts requests.

**Language:** Elixir  
**Constraint:** Hostile UI  
**Stack:** Phoenix, LiveDashboard, GenServer, Bandit

---

## Features

- Public URL tunnel to local HTTP server
- Request replay and inspection UI
- Programmable transformations (Lua/Elixir scripting)
- Chaos mode: random delays, drops, corruption
- Phoenix LiveDashboard for monitoring
- Request history with search and filter
- Webhook signature verification helpers

---

## Development Plan

1. Phase 1: Phoenix app scaffold with LiveDashboard
2. Phase 2: Tunnel core — public URL → local forward
3. Phase 3: Request capture and storage (ETS + persistence)
4. Phase 4: Inspection UI (LiveView)
5. Phase 5: Replay engine (exact + modified replays)
6. Phase 6: Programmable transformations
7. Phase 7: Chaos mode GenServer (configurable probabilities)
8. Phase 8: Webhook signature verification helpers

---

## Getting Started

### Prerequisites

- Elixir toolchain

### Build

```bash
# See PLAN.md for detailed build instructions per phase
cd loopback
```

### Run

```bash
# See PLAN.md for run instructions
```

---

## Architecture

See `PLAN.md` for detailed architecture decisions and implementation notes.

---

## License

MIT
