# 0005 Two counting modes: every move counts (daily), final line counts (practice)

Status: accepted (2026-11-17), decided by the owner; daily part applies from phase 2

## Context

Undo and restart are essential in White Tally: a careless move can make a position unsolvable (ADR 0001). For the
daily puzzle the count must reward planning, not trial and error. For practice, players should be able to explore
freely and still see how good their final solution is. Phase 1 only tests look and feel with a puzzle pool; strict
counting is not needed there.

## Decision

- Daily puzzles (from phase 2) use `WhiteAttempt.CountMode.EVERY_MOVE`: the count is `moves_made`, every move in
  the attempt, including moves later undone or discarded by a restart (the White Shift rule).
- Practice, and in phase 1 every pool puzzle, use `WhiteAttempt.CountMode.FINAL_ONLY`: the count is
  `line_length()`, the moves from the start position to the current position; undo lowers it by one, restart sets
  it to 0; when solved, it is the length of the final solution.
- Undo and restart are unlimited in both modes. The attempt record (ADR 0007) is identical in both; only the
  derived count differs. Both modes come from White Kit (kit ADR 0003); the screen hook `_count_mode(is_practice)`
  selects the mode.
- Final tuning of scoring follows play tests.

## Alternatives considered

- `FINAL_ONLY` for the daily puzzle too (the original proposal): every persistent player reaches par, so the
  daily score measures persistence. Rejected by the owner.
- No undo in the daily puzzle, restart only: harsh for young players, and gives the same count as `EVERY_MOVE`
  anyway. Rejected.
- `EVERY_MOVE` in practice too: discourages the free exploration practice is meant for. Rejected.

## Consequences

- The daily count is fully determined by the record: the number of move tokens.
- The practice count is determined by replaying the record (undo and restart change it).
- The UI labels the count differently per mode ("Moves" versus "Moves in solution"); until the kit supports a
  per-mode label, the game sets it in a `_refresh()` override (design 7.1, R2).
- Practice results are not saved and not shared, so the softer count cannot leak into daily comparisons.
- A server verifying a result later needs the puzzle, the record and the mode.
