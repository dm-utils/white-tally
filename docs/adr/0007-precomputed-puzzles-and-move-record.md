# 0007 Precomputed puzzles and a move-token attempt record

Status: accepted (2026-11-17)

## Context

Every player must get the same three puzzles each day. Generating a puzzle includes a solver run that may take
seconds to minutes on a desktop; a phone browser is single-threaded and much slower. Progress must survive a
reload with the same count, and later (with st33f-engine) results must be verifiable by replaying them. White
Shift solved both with precomputed puzzles and a one-character-per-action record; White Tally moves need a cell
as well as a direction.

## Decision

- Puzzles are generated ahead of time by `tools/build_puzzles.gd` and shipped in `data/daily.json` and
  `data/practice.json`, loaded through the white-kit puzzle loader. Each puzzle stores board rows, par, `exact`,
  `upper` and one solution path. The game never searches. Published days are never regenerated.
- The attempt record is a string of tokens: a move is three characters (canonical direction letter, column
  letter, row digit, for example `Rb1`); `z` is undo, `r` is restart. Ignored actions are not written. The kit's
  attempt base stores, replays and counts it.

## Alternatives considered

- Generate on the device at day start: deterministic, but far too slow for medium and hard on a phone, and the
  time would vary per device. Rejected.
- One character per move (cell index and direction packed into a 64-character alphabet): shorter, but unreadable
  in logs and tests, and limited to small boards. Rejected; records are only tens of tokens long.
- Store state and count instead of a record: loses history and cannot be verified. Rejected (as in White Shift).
- Server-delivered puzzles: the right end state, but phase 1 has no backend. Deferred to the leaderboard phase.

## Consequences

- Instant start, no network, identical behaviour on every device.
- The repository is public, so future puzzles and solutions are readable in advance; accepted for phase 1.
- Someone must build days ahead; CI warns when fewer than 14 days remain.
- The record is readable (`Ra1zRb1Ld1`) and the daily count equals the number of move tokens.
- The kit's record base must support multi-character move tokens (depends on white-kit). Changing the meaning of
  a token breaks old saves; new actions get new letters.
