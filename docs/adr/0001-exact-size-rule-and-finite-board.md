# 0001 Exact-size rule on a finite board

Status: accepted (2026-11-17)

## Context

White Tally needs one core rule that a player aged 10 and up understands in 30 seconds and that stays
interesting for adults. The obvious genre reference is the swap-and-match game, where any group of three or more
vanishes, new tiles drop in from the top and "more is better". Copying that gives a game that feels familiar,
depends on luck (the refill) and has no best solution, which makes a fair daily puzzle impossible. It also carries
a look-alike risk with well-known commercial titles.

## Decision

- Tiles show 2, 3 or 4. A group (4-connected tiles of equal value) vanishes only when its size is exactly its
  value. Overfull groups stay, and so does every part of them.
- After a vanish tiles fall; new exact groups vanish in further waves (chains). All exact groups of one moment
  vanish together.
- No tiles are ever added. The goal is an empty board in as few moves as possible.
- Presentation is abstract: numbers as pips on flat squares, quiet fades, no reward effects (design 10.1).

## Alternatives considered

- "Size at least the value" (classic matching with numbers): players never need to count or break groups; the
  main "aha" (breaking an overfull group) disappears. Rejected.
- Refill from the top: endless play and score chasing, but random, no best solution, and much closer to existing
  games. Rejected.
- Only one value per wave, or a fixed order of vanishing: adds a rule players must learn without adding depth;
  simultaneous vanishing has no ambiguity because groups never overlap. Rejected.
- Values up to 5 or 6: more counting effort per move on a phone screen; may return in phase 2. Rejected for
  phase 1.

## Consequences

- Every puzzle is a closed problem with a best solution, which suits a daily puzzle and later leaderboards.
- For each value the tile count modulo the value is invariant; a puzzle can only be cleared if each count is a
  multiple of its value. The generator guarantees this (ADR 0003).
- Positions can become unsolvable after a careless move (dead ends); undo and restart are therefore essential
  (ADR 0005, ADR 0006).
- The player must count, which is the intended skill; the UI joins equal neighbours visually but never shows
  group sizes.
- The look-alike risk is handled by the rule (exact size, no refill, no forced match) and by the abstract look.
