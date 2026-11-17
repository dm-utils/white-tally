# 0006 Dead ends: report only when no move is left

Status: accepted (2026-11-17)

## Context

Because no tiles are added, a player can reach a position from which the board can no longer be cleared. Some
of these positions have no move at all (for example a full bottom row of equal tiles). Others still allow moves
but are hopeless. Telling the player saves frustration, especially for young players, but proving that a position
is hopeless requires a search, and the game must not search on a phone (ADR 0007). A notice also gives away
information.

## Decision

- After every move, undo and restart the game checks whether the board is non-empty and has no legal move. If so,
  the message line says "No move left. Undo or restart." Nothing else changes.
- Positions that still have moves but cannot be cleared are not detected or reported in phase 1.

## Alternatives considered

- Never report: in a no-move position nothing reacts to input except shakes, which looks like a bug. Rejected.
- Prove unsolvability with a bounded search on the device (for example when few tiles remain): costs seconds on
  a phone browser, the outcome depends on a budget (sometimes "unknown"), and it acts as an oracle that tells the
  player a move was a mistake. Rejected for phase 1; reconsidered in phase 2 with play-test data.
- Precompute dead positions: the number of reachable positions is far too large. Rejected.

## Consequences

- The check is one pass over the board and always correct when it fires.
- Players can still wander in hopeless positions without being told; undo and restart are always visible.
- Phase 2 play tests should note how often players get stuck without noticing.
