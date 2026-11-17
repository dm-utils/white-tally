# 0004 Par: exact where feasible, bounded otherwise; what the share line shows

Status: accepted (2026-11-17)

## Context

The daily score is a move count, compared with par. In White Shift par is the exact minimum from a full
breadth-first search, which is cheap there (four moves per position). White Tally has far more moves per
position (swaps and slides, often 40 to 80), and chains can clear many tiles in one move, so no useful
admissible lower bound exists. An exact par for the hard level may be too expensive even offline. A par that
players can beat undermines its meaning; a par that is never shipped makes the levels hard to compare.

## Decision

- The solver is an iterative deepening depth-first search with a transposition table, bounded by a fixed number
  of expansions per puzzle (never by time). It starts from the generator's solution (`U` moves) and proves or
  finds anything shorter.
- If the search completes, par is exact (`exact: true`). If it hits the budget, a beam search may still find a
  shorter line; par is then the shortest line known (`exact: false`).
- Easy and medium always ship exact par. Hard ships exact par too, unless the trial (design 5.7, gate B) shows
  that exactness is not reachable within budget; only then may hard ship bounded par.
- Par, `exact`, `upper` and one solution path are stored with each precomputed puzzle.
- Share line: `White Tally #<n> · <a>/<b>/<c> moves (par <p>/<q>/<r>)`, Dutch unit `zetten`, `-` for unsolved
  levels. It shows no moves, no time, no board and no marker for bounded par.

## Alternatives considered

- Always bounded par (beam search only): cheap, but par would often be beatable, and "exactly par" would mean
  little. Rejected.
- Always exact par, shrinking boards until it fits: keeps par meaningful, but may force the hard level onto a
  board too small to be hard. Kept as the first remedy in the trial, not as an absolute rule.
- Par equals the generator's `U`: free, but often clearly beatable (one move serving two groups). Rejected.
- Time on the share line (as the proposal suggested): device and interruption dependent and not verifiable in
  phase 1; White Shift leaves it out too. Rejected.
- A spoiler-free row of tiles cleared per move (`0 5 0 3 4`): reveals the rhythm of a solution and adds noise.
  Rejected for phase 1.
- A marker such as `~` for bounded par on the share line: correct but confusing for young players. Rejected; the
  in-game result text says "below par" when it happens.

## Consequences

- Exactness is a measured property of the generator settings; the trial decides it per level and records the
  outcome in design 5.8.
- If hard ships bounded par, a player can end below par; the game says so and the share line simply shows the
  lower count.
- Build time per puzzle is bounded and machine-independent in outcome (same budget, same result).
- Later, a server can recompute or trust par from the puzzle data; the share line format stays the same.
