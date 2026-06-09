# loopback — Implementation Plan

## Project Overview

Self-hosted webhook testing tunnel like ngrok but with replay, inspection, programmable transformations... AND a chaos mode that randomly delays, drops, or corrupts requests.

**Language:** Elixir  
**Constraint:** Hostile UI  
**Stack:** Phoenix, LiveDashboard, GenServer, Bandit

---

## Phase Breakdown

### Phase 1: Phoenix app scaffold with LiveDashboard

**Goal:** Phase 1: Phoenix app scaffold with LiveDashboard

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 2: Tunnel core — public URL → local forward

**Goal:** Phase 2: Tunnel core — public URL → local forward

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 3: Request capture and storage (ETS + persistence)

**Goal:** Phase 3: Request capture and storage (ETS + persistence)

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 4: Inspection UI (LiveView)

**Goal:** Phase 4: Inspection UI (LiveView)

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 5: Replay engine (exact + modified replays)

**Goal:** Phase 5: Replay engine (exact + modified replays)

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 6: Programmable transformations

**Goal:** Phase 6: Programmable transformations

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 7: Chaos mode GenServer (configurable probabilities)

**Goal:** Phase 7: Chaos mode GenServer (configurable probabilities)

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

### Phase 8: Webhook signature verification helpers

**Goal:** Phase 8: Webhook signature verification helpers

**Deliverables:**
- [ ] Core implementation
- [ ] Tests
- [ ] Documentation update

**Notes:**
- 

---

## Architecture Notes

### Key Decisions

- 

### Data Flow

```
[Input] → [Parse] → [Transform] → [Output]
```

### Error Handling Strategy

- 

---

## Testing Strategy

- Unit tests for core functions
- Integration tests for full pipeline
- Benchmarks for performance-critical paths

---

## Open Questions

1. 
2. 

---

*Generated for opencode sprint. Implement phase by phase. DO NOT RESEARCH. Build directly.*
