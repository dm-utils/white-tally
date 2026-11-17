# 0004 Par: exact where feasible, bounded otherwise; what the share line shows

Status: accepted (2026-11-17); revised 2026-11-17 for the phase 1 look-and-feel scope

## Context

The score is a move count, compared with par. In White Shift par is the exact minimum from a full breadth-first
search, which is cheap there (four moves per position). White Tally has far more moves per position (swaps and
slides, often 40 to 80), and chains can clear many tiles in one move, so no useful admissible lower bound exists.
An exact par for the hard level may be too expensive even offline. A par that players can beat undermines its
meaning in a daily comparison; for a look-and-feel test it matters much less.

## Decision

- The solver is an iterative deepening depth-first search with a transposition table, bounded by a fixed number
  of expansions per puzzle (never by time). It starts from the generator's solution (`U` moves) and proves or
  finds anything shorter.
- If the search completes, par is exact (`exact: true`). If it hits the budget, a beam search may still find a
  shorter line; par is then the shortest line known (`exact: false`).
- Phase 1 (look and feel, pool only): bounded par is accepted for every level; the `exact` flag is stored and
  measured but not required.
- From the daily puzzle (phase 2): easy and medium ship exact par; hard ships exact par too, unless the full trial
  (design 5.8, gate B) shows that exactness is not reachable within budget.
- Par, `exact`, `upper` and one solution path are stored with each precomputed puzzle.
- Share line (phase 2): `White Tally #<n> · <a>/<b>/<c> moves (par <p>/<q>/<r>)`, Dutch unit `zetten`, `-` for
  unsolved levels. It shows no moves, no time (confirmed by the owner), no board and no marker for bounded par.

## Alternatives considered

- Always bounded par (beam search only): cheap, but par would often be beatable, and "exactly par" would mean
  little in a daily comparison. Rejected for the daily puzzle; effectively allowed in phase 1.
- Always exact par, shrinking boards until it fits: keeps par meaningful, but may force the hard level onto a
  board too small to be hard. Kept as the first remedy in the full trial, not as an absolute rule.
- Par equals the generator's `U`: free, but often clearly beatable (one move serving two groups). Rejected.
- Time on the share line (as the proposal suggested): device and interruption dependent and not verifiable;
  White Shift leaves it out too. Rejected, confirmed by the owner.
- A spoiler-free row of tiles cleared per move (`0 5 0 3 4`): reveals the rhythm of a solution and adds noise.
  Rejected.
- A marker such as `~` for bounded par on the share line: correct but confusing for young players. Rejected.

## Consequences

- Exactness is a measured property of the generator settings; the phase 1 trial records it (design 5.9), the
  phase 2 trial decides it per level.
- With bounded par a player can end below par; the solved message simply shows the lower count.
- Build time per puzzle is bounded and machine-independent in outcome (same budget, same result).
- Later, a server can recompute or trust par from the puzzle data; the share line format stays the same.
