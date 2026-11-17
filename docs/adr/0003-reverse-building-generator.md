# 0003 Generator by reverse building

Status: accepted (2026-11-17)

## Context

A daily puzzle must be solvable, and its difficulty must be controllable per level. A random board of 2s, 3s
and 4s is almost never clearable: value counts must be multiples of the value, and even then the arrangement is
usually hopeless. Searching random boards for solvable ones would waste nearly all work on proving
unsolvability, which is the most expensive thing a solver does.

## Decision

The generator builds each puzzle backwards from an empty board (design 5.4):

- An insertion step inserts a complete exact group (or, for a chain, two groups where the second splits the
  first), then applies a reverse move (swap or reverse slide) that breaks it, giving a stable predecessor.
- A quiet step applies a reverse move that vanishes nothing forward, to make the start less "ready".
- Every step is verified by forward simulation (`apply(P, m) == C` and `P` stable); the construction only
  proposes.
- The forward moves of all steps form a known solution; its length `U` is an upper bound for par.
- Filters (stability, values present, overfull groups, band, exactness, greedy gap) then accept or reject the
  candidate; the next candidate continues the same PRNG stream, so a seed text always gives the same puzzle.

## Alternatives considered

- Random boards plus a solver as filter: almost all boards unsolvable; slow, and acceptance rates would be tiny.
  Rejected.
- Hand-made puzzles: best quality per puzzle, but not sustainable for three puzzles every day. Rejected for the
  daily stream; hand-made boards remain useful as tests.
- Reverse building without forward verification (trusting the inverse construction): the inverse of "vanish and
  fall" has edge cases (accidental joins with existing tiles, shifted tiles forming new groups); a bug there
  would ship unsolvable or different puzzles. Rejected; verification is cheap.

## Consequences

- Every shipped puzzle is solvable by construction, and the solver only has to improve on `U`.
- Value counts are automatically multiples of the value.
- Par can be lower than `U` (one move may serve two groups, chains form by accident); the trial measures
  `U - par` and the bands use the solver's par, not `U`.
- The difficulty knobs are the numbers of insertion and quiet steps, the chain chance and the board size.
- Changing the generator changes what a seed produces; published days are never regenerated (ADR 0007).
