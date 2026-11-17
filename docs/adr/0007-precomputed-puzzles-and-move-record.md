# 0007 Precomputed puzzles and a three-character move-token record

Status: accepted (2026-11-17), revised 2026-11-17 for the White Kit record grammar and the phase 1 pool

## Context

Puzzles must be identical for every player (in phase 1 the same pool, later the same three puzzles per day).
Generating a puzzle includes a solver run that may take seconds to minutes on a desktop; a phone browser is
single-threaded and much slower. Later progress must survive a reload with the same count, and (with st33f-engine)
results must be verifiable by replaying them. White Shift solved both with precomputed puzzles and a
one-character-per-action record. A White Tally move needs a cell as well as a direction.

White Kit fixes the record grammar for the series (kit design 6.1, kit ADR 0003): move tokens have a fixed width
per game (`WhiteRules.move_len()`) and use only upper-case letters and digits; lower-case letters are reserved for
the kit (`z` undo, `r` restart, others ignored on replay).

## Decision

- Puzzles are generated ahead of time by `tools/build_puzzles.gd` (on `WhitePrecompute`) and loaded through
  `WhitePuzzleStore`. Phase 1 ships only a pool in `data/practice.json` (40 sets of three levels); from phase 2
  `data/daily.json` adds puzzles by date, and published days are never changed (the kit's merge refuses). Each
  puzzle stores board rows, par, `exact`, `upper` and one solution path. The game never searches.
- A move token is three characters: canonical direction letter (`R`, `L`, `U`), column letter (`A`-`H`), row
  digit (`1`-`9`), for example `RB1`. `move_len()` is 3. Undo and restart are the kit's `z` and `r`. Example
  record: `RA1zRB1LD1`.
- Writers produce canonical tokens only; `TallyBoard.apply` canonicalises, so a non-canonical token replays to the
  same result.

## Alternatives considered

- Generate on the device: deterministic, but far too slow for medium and hard on a phone, and the time would vary
  per device. Rejected.
- Lower-case column letters (`Rb1`, the first version of this ADR): closer to chess notation, but lower case is
  reserved by the kit and would be skipped on replay. Rejected.
- Cell first, then direction (`B1R`, the kit's example): equally valid; direction first keeps the token readable
  as "verb, object" and matches the canonical-form table. Either works with the kit; chosen for readability.
- One character per move (cell index and direction packed into an alphabet): shorter, but unreadable in logs and
  tests, and limited to small boards. Rejected; records are only tens of tokens long.
- Store state and count instead of a record: loses history and cannot be verified. Rejected (as in White Shift).
- Server-delivered puzzles: the right end state, but there is no backend yet. Deferred to the leaderboard phase.

## Consequences

- Instant start, no network, identical behaviour on every device.
- The repository is public, so all puzzles and solutions are readable; no issue for the pool, accepted for the
  first daily phase.
- From phase 2 someone must build days ahead; CI warns when fewer than 14 days remain.
- The record is readable (`RA1zRB1LD1`) and the daily count equals the number of move tokens.
- Boards are limited to 8 columns and 9 rows so every cell name is two characters.
- Changing the meaning of a token breaks old saves; new actions get new letters (upper case for game moves,
  lower case only through the kit).
