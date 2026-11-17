# 0005 Two counting modes: every move counts (daily), final line counts (practice)

Status: accepted (2026-11-17), decided by the owner

## Context

Undo and restart are essential in White Tally: a careless move can make a position unsolvable (ADR 0001). For the
daily puzzle the count must reward planning, not trial and error. For practice, players should be able to explore
freely and still see how good their final solution is.

## Decision

- Daily puzzles use `ALL_MOVES`: every move in the attempt counts, including moves later undone or discarded by
  a restart (the White Shift rule).
- Practice sets use `FINAL_LINE`: only the moves on the current line count; undo lowers the count by one,
  restart sets it to 0; when solved, the count is the length of the final solution.
- Undo and restart are unlimited in both modes. The attempt record (ADR 0007) is identical in both; only the
  derived count differs. Both modes come from the white-kit attempt base.

## Alternatives considered

- `FINAL_LINE` for the daily puzzle too (the original proposal): every persistent player reaches par, so the
  daily score measures persistence. Rejected by the owner.
- No undo in the daily puzzle, restart only: harsh for young players, and gives the same count as `ALL_MOVES`
  anyway. Rejected.
- `ALL_MOVES` in practice too: discourages the free exploration practice is meant for. Rejected.

## Consequences

- The daily count is fully determined by the record: the number of move tokens.
- The practice count is determined by replaying the record (undo and restart change it).
- The UI labels the count differently per mode ("Moves" versus "Moves in solution").
- Practice results are not saved and not shared, so the softer count cannot leak into daily comparisons.
