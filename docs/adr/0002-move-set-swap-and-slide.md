# 0002 Move set: swap different values, slide sideways into empty cells

Status: accepted (2026-11-17)

## Context

Because tiles vanish and are never replaced, the board gets emptier during play. With swaps only, a tile that
ends up alone next to empty space can never be moved again, and many positions become dead early. The move set
also decides what counts as a move, which matters because the daily score is a move count, and it must have one
unambiguous spelling per move for records, the solver and the generator.

## Decision

- A move is either a swap of two neighbouring tiles with different values (horizontal or vertical), or a slide
  of a tile sideways into an empty neighbouring cell, after which it falls.
- A swap is allowed even when nothing vanishes; it counts.
- Ignored, not counted, not recorded: a swap of two equal values (it changes nothing), moving from an empty cell,
  moving off the board, and moving up or down into an empty cell.
- Every move has one canonical form: horizontal swap as `R` from the left cell, vertical swap as `U` from the
  lower cell, slide as `R` or `L` from the moving tile.

## Alternatives considered

- Swaps only: simpler, but tiles get stranded as the board empties and many generated puzzles would rely on
  awkward detours. Rejected.
- Only swaps that cause a vanish (as in many match games): makes the game much closer to existing titles, removes
  preparatory moves that are central to planning ("aha 2: gravity as a tool"). Rejected.
- Count an equal-value swap as a move: punishes a misread, adds no skill signal, and duplicates states in the
  solver. Rejected (same reasoning as White Shift's no-op swipe).
- Allow lifting a tile into an empty cell above: it falls straight back; a pure no-op. Rejected.

## Consequences

- Every effective move changes the board, so "a move" is the same thing for the player, the record and the
  solver.
- The branching factor rises (slides add moves), which makes exact par harder to compute (ADR 0004).
- Input handling must convert gestures to the canonical form before recording.
