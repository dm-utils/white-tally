# White Tally - design

Status: phase 1 (digital prototype), designed, not built yet.
This document describes the game as it must be built. Decisions with their trade-offs are in `docs/adr/`;
terms are defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`.

White Tally is built on the shared base `white-kit` (Dutch calendar day, PRNG and seed hash, loading of
precomputed puzzles, attempt record base with two count modes, saved progress, share line, NL/EN texts, UI
shell, CI). The kit is designed in parallel. Everything marked **depends on white-kit** is an assumption about
the kit's interface; section 7 lists all of them. Where the kit's names differ, the behaviour in this document
is binding, not the names.

## 1. Purpose

White Tally is a daily puzzle for players aged 10 and up and adults. Every day there are three puzzles (easy,
medium, hard), identical for everyone, changing at midnight Dutch time. The board holds tiles numbered 2, 3 and
4 under gravity. A group of equal tiles vanishes only when its size is exactly its number. The player clears the
board in as few moves as possible. No new tiles ever appear.

The phase 1 prototype exists to answer four questions:

1. Can a new player apply the exact-size rule after a 30-second explanation?
2. Does the rule force counting and planning ("more is not better"), or do players just shuffle tiles?
3. Are there "aha" moments: breaking an overfull group, one move completing two groups, gravity as a tool?
4. Can the generator and solver produce three puzzles of distinct difficulty every day, with a reliable par?

Out of scope for phase 1: accounts, leaderboards, a server, art, sound, Android/Windows builds, a puzzle archive,
giving up.

## 2. Rules

### 2.1 Board and coordinates

- A rectangular board of `w x h` cells, side view, gravity pulls down. `w` is 4 to 8, `h` is 2 to 9.
- Coordinates: `x` grows to the right (`0 .. w-1`), `y` grows **upwards** (`0 .. h-1`), `(0, 0)` is the
  bottom-left cell. Cell index `i = y * w + x`. (White Shift counts `y` downwards; White Tally counts upwards
  because gravity makes the bottom row the natural origin.)
- Human notation (records, examples, tests): column letter `a, b, c, ...` for `x = 0, 1, 2, ...` and row digit
  `1, 2, 3, ...` for `y = 0, 1, 2, ...`. So `a1` is the bottom-left cell.
- Each cell is empty or holds one tile.

### 2.2 Tiles

- A tile has a value: 2, 3 or 4. Tiles never change value and are never created.
- Two cells are neighbours when they share an edge (left, right, above, below). Diagonals are not neighbours.

### 2.3 Groups

- A group is a maximal set of tiles with the same value that are connected through neighbours (a 4-connected
  component). Every tile belongs to exactly one group.
- A group is **exact** when its size equals its value (two 2s, three 3s, four 4s).
- A group is **overfull** when its size is larger than its value (for example four 3s). An overfull group does
  not vanish, and neither does any part of it.
- A group is **short** when its size is smaller than its value.

### 2.4 Moves

A move is given by a source cell `(x, y)` and a direction `d` in `R`, `L`, `U`, `D` (right, left, up, down).
The target cell is the neighbour in that direction. The first matching rule decides:

| Situation | Result |
|---|---|
| The source cell is empty | Not a move: ignored. |
| The target is outside the board | Not a move: ignored. |
| The target holds a tile with the **same** value | No-op: ignored. |
| The target holds a tile with a **different** value | **Swap**: the two tiles exchange cells. |
| The target is empty and `d` is `R` or `L` | **Slide**: the tile moves into the target cell (and then falls, 2.5). |
| The target is empty and `d` is `U` or `D` | Not a move: ignored. |

- Every swap of two different values is allowed, also one after which nothing vanishes. It counts as a move.
- A slide always changes the board (the tile ends in another column), so it always counts.
- An ignored action (not a move, or a no-op) is not counted, not recorded and does not create an undo step.
  It gives a short shake of the source tile as feedback. See ADR 0002.
- In a settled board (2.5) the cell below a tile is never empty, so `D` into an empty cell cannot occur; `U`
  into an empty cell would only lift a tile that falls straight back, so it is not a move.
- After the board is empty (solved), every action is ignored.

Canonical form (used in records, the solver and the generator, so every distinct move has one spelling):

| Move | Canonical source | Canonical direction |
|---|---|---|
| Horizontal swap | the left cell of the pair | `R` |
| Vertical swap | the lower cell of the pair | `U` |
| Slide | the moving tile | `R` or `L` |

So `D` never occurs in canonical form, `L` is always a slide, `U` is always a swap, and `R` is a swap or a slide
depending on whether the target holds a tile. Player input is converted to canonical form before it is applied
and recorded (for example a swipe down on `b2` over a tile at `b1` becomes `U` at `b1`; a swipe left on `c1`
over a tile at `b1` becomes `R` at `b1`).

### 2.5 Resolution: settle, vanish, chain

After a move the board is resolved:

1. **Settle.** Every tile falls straight down in its own column until it rests on the floor or on another tile.
   Columns become contiguous stacks from the bottom. Tiles never move sideways during settling. (After a swap
   nothing falls; after a slide the slid tile falls in its new column and the tiles above its old cell fall by
   one.)
2. **Find.** On the settled board, find all exact groups.
3. If there are none, resolution ends.
4. **Vanish.** Remove all exact groups found in step 2 at the same time. This is one **wave**.
5. Go to step 1.

Notes:

- Groups are maximal components, so two exact groups never share a tile; removing them together or one by one
  before settling gives the same board. There is no ordering question inside a wave.
- Overfull and short groups never vanish.
- A **chain** is a resolution with more than one wave: tiles that fell after a wave form a new exact group.
- Resolution always ends: every wave removes at least two tiles.
- A board after resolution is **stable**: settled and without exact groups. Every start position is stable.

### 2.6 Goal and invariants

- The puzzle is solved when the board is empty.
- A wave removes exactly `v` tiles of value `v` per exact group, so for every value `v` the number of tiles of
  value `v` modulo `v` never changes. A board can only be emptied if every value occurs a multiple of its own
  number of times. The generator guarantees this (5.4); it is necessary, not sufficient.
- No tiles are ever added. Every puzzle is a closed problem with a best solution. See ADR 0001.

### 2.7 Examples

Examples are drawn with the top row first, row numbers on the left and column letters on top; `.` is empty.
`TallyBoard.render()` produces the same rows without labels and spaces (for example `..2.`). Every example below
is also a regression test.

**Example 1 - one swap, two groups.** Board `4 x 3`, move `Rb1` (swap `b1` and `c1`).

```
start                 after the swap          after wave 1 and settling
   a b c d               a b c d                 a b c d
3  2 . . .            3  2 . . .              3  . . . .
2  3 4 . .            2  3 4 . .              2  . . . .
1  3 2 3 2            1  3 3 2 2              1  2 4 . .
```

After the swap the 3s at `a1`, `a2`, `b1` form a group of three (exact) and the 2s at `c1`, `d1` a group of two
(exact). Both vanish in the same wave. `a3` falls to `a1`, `b2` falls to `b1`. No further wave.

**Example 2 - overfull, and one slide completing two groups.** Board `4 x 2`, move `Rb2` (slide `b2` right).

```
start                 after the slide         after wave 1 and settling
   a b c d               a b c d                 a b c d
2  . 2 . 2            2  . . 2 2              2  . . . .
1  2 2 3 3            1  2 2 3 3              1  . . 3 3
```

At the start the 2s at `a1`, `b1`, `b2` form a group of three: overfull, nothing vanishes. The slide takes `b2`
out of it; it lands on `c1`. Now `a1`, `b1` is an exact pair and `c2`, `d2` is an exact pair (`b1` and `c2`
touch only diagonally). Both vanish. The two 3s remain (short group).

**Example 3 - chain.** Board `3 x 3`, move `Ra2` (swap `a2` and `b2`).

```
start           after the swap   wave 1, settle   wave 2, settle
   a b c           a b c            a b c            a b c
3  3 . .        3  3 . .         3  . . .         3  . . .
2  4 2 .        2  2 4 .         2  . 4 .         2  . . .
1  2 3 3        1  2 3 3         1  3 3 3         1  . 4 .
```

Wave 1: the 2s at `a1`, `a2` vanish; `a3` falls to `a1`. Wave 2: the 3s at `a1`, `b1`, `c1` vanish; `b2` falls
to `b1`.

**Example 4 - slide out of the middle of a stack.** Board `2 x 3`, move `Ra2`.

```
start       result
   a b         a b
3  3 .      3  . .
2  2 .      2  3 .
1  4 .      1  4 2
```

The 2 slides into the empty `b2` and falls to `b1`; the 3 above its old cell falls to `a2`.

**Example 5 - a complete puzzle (par 2).** Board `4 x 3`.

```
   a b c d
3  . . . .
2  . . 2 .
1  3 2 3 3
```

Solution `Rb1 Ld1`: the swap makes `c1`, `c2` an exact pair of 2s (they vanish; column `c` empties), leaving
`3 3 . 3` on row 1; sliding `d1` left lands it on `c1` and the three 3s vanish. Another solution of length 2 is
`Lc2 Ra1`. No single move empties the board, so par is 2. Section 5.4 shows how the generator builds this
puzzle.

**Example 6 - no move left.** Board `6 x 2`.

```
   a b c d e f
2  . . . . . .
1  2 2 2 2 2 2
```

Every swap is between equal values (no-op), no tile has an empty cell beside it, and `U` into an empty cell is
not a move. The board cannot change: a dead end (2.8).

### 2.8 Dead ends

- A position is a **dead end** when the board is not empty and there is no move (no swap of different values and
  no slide).
- The game checks this after every move, undo and restart (cheap: one pass over the board). In a dead end the
  message line says so (10.5); undo and restart stay available. Nothing else changes: the count is not affected
  and nothing is recorded.
- Positions that still have moves but can no longer be cleared are **not** detected or reported in phase 1.
  Proving that requires a search that is too slow for a phone. See ADR 0006.

## 3. Counting, undo, restart and par

### 3.1 Two count modes

| Mode | Used for | Count |
|---|---|---|
| Every move counts (`ALL_MOVES`) | Daily puzzles | Every move made in the attempt, including moves later undone or discarded by a restart. |
| Final line counts (`FINAL_LINE`) | Practice sets | The number of moves on the current line from the start position: undo lowers it by one, restart sets it to 0. When solved, it is the length of the solution the player ended with. |

- Undo returns to the position before the last move. Restart returns to the start position and clears the undo
  history (undo cannot go back across a restart).
- Undo and restart are allowed in both modes, without limit. They are only possible when there is history and
  the puzzle is not solved; otherwise they are ignored and not recorded.
- The record (section 8) is the same in both modes; only the count derived from it differs. The kit's attempt
  base provides both modes (**depends on white-kit**). See ADR 0005.

### 3.2 Par

- Par is the fewest moves found by the solver (5.5). For most puzzles par is proven minimal (`exact` true); only
  if the trial decides so (5.7, gate B) may the hard level ship puzzles whose par is a best-found upper bound
  (`exact` false). See ADR 0004.
- A solved attempt is "exactly par" when the count equals par, "below par" when the count is lower (possible
  only when `exact` is false), otherwise "+N".
- The prototype shows par during play (as in White Shift; whether it stays visible is a phase 2 decision).

## 4. Levels

Each level has its own generator parameters (`TallyGenerator.LEVELS`). The values below are the **starting
values for the trial** (5.7); the developer adjusts them within the stated ranges and records the outcome in
5.8.

| Parameter | Easy (0) | Medium (1) | Hard (2) | Allowed range in the trial |
|---|---|---|---|---|
| Board `w x h` | 5x6 | 6x6 | 6x7 | 5x6, 6x6, 6x7, 7x7 |
| Insertion steps `I` | 3-4 | 5-6 | 7-9 | +-2 on either bound |
| Quiet steps `Q` | 0-1 | 1-2 | 2-3 | 0-4 |
| Chain insertion chance | 0.0 | 0.2 | 0.3 | 0.0-0.5 |
| Different values present (at least) | 2 | 3 | 3 | fixed |
| Overfull groups at start (at least) | 1 | 1 | 1 | 0-2 |
| Greedy gap (5.6) | none | 1 | 2 | none-3 |
| Par band | 3-5 | 5-8 | 8-12 | bands may share at most their end value |
| Candidates tried | 400 | 600 | 900 | up to 3000 |
| Solver budget (expansions) | 100 000 | 300 000 | 1 000 000 | up to 3 000 000 |

- The upper bound `U` of a candidate is `I + Q` (one reverse move per step). Par is at most `U`.
- The bands are provisional; phase 2 tunes them after play testing.

## 5. Rules engine, generator and solver

All code in this section lives in `sim/`, is pure (no nodes, no floats, no time, no `user://`) and is shared by
the game, the build tools and the tests.

### 5.1 State

- A state is a `PackedByteArray` of length `w * h`, index `i = y * w + x`, value `0` (empty), `2`, `3` or `4`.
- Board size is not part of the state; it belongs to the `TallyBoard` instance.
- States are used directly as `Dictionary` keys (solver transposition table): Godot 4 hashes and compares packed
  arrays by content. A test asserts that two equal arrays built separately hit the same key.

### 5.2 Moves in code

- Move code: `m = i * 4 + d` with `i` the canonical source cell index and `d` in `R = 0, L = 1, D = 2, U = 3`
  (the same direction codes as White Shift).
- Move token (records, `path`): direction letter, column letter, row digit, for example `Rb1`, `Ld1`, `Ua3`.
  `TallyBoard.token(m)` and `TallyBoard.parse_token(s)` convert. The board limit `w <= 8`, `h <= 9` keeps every
  token at exactly three characters.

### 5.3 `TallyBoard`

```
class_name TallyBoard extends RefCounted
var w: int
var h: int
static func create(w: int, h: int) -> TallyBoard
func from_rows(rows: PackedStringArray) -> PackedByteArray   # rows top first, chars ".234"
func render(state: PackedByteArray) -> String                # rows top first, joined with "\n"
func canonical(state, x: int, y: int, d: int) -> int         # canonical move code, or -1 if ignored (2.4)
func legal_moves(state) -> PackedInt32Array                  # all canonical moves, ascending move code
func apply(state, m: int) -> PackedByteArray                 # move + full resolution (fast version)
func apply_reference(state, m: int) -> PackedByteArray       # move + full resolution (straightforward version)
func apply_traced(state, m: int) -> Dictionary               # result plus animation steps (below)
func resolve(state) -> PackedByteArray                       # settle + waves
func settle(state) -> PackedByteArray
func exact_groups(state) -> Array[PackedInt32Array]          # cell indices per exact group
func groups(state) -> Array[PackedInt32Array]                # all groups (for overfull counting and joins)
func is_stable(state) -> bool                                # settled and no exact group
func is_dead_end(state) -> bool                              # not empty and legal_moves is empty
func count_tiles(state) -> int
func token(m: int) -> String
func parse_token(s: String) -> int                           # -1 if malformed or off the board
```

- `apply()` is the fast version: it flood-fills only from cells that changed (the moved cells, and after a wave
  every cell that fell), and a flood fill stops as soon as it exceeds 4 cells (such a group can never be exact).
- `apply_reference()` settles and scans every group on the whole board each wave.
- Both must return identical states for every stable state and every canonical move; the tests enforce this on
  random states. Every rule change keeps them in agreement.
- Random stable states for tests: fill each column from the bottom with a random height and random values, then
  `resolve()`.
- `apply_traced()` returns `{"state": result, "steps": [...]}`, steps in order:
  `{"kind": "swap", "a": i, "b": j}` or `{"kind": "slide", "from": i, "to": j}` (`to` is the cell the tile slid
  into, before falling), then per settle `{"kind": "fall", "moves": [[from, to], ...]}` (omitted if nothing
  falls), per wave `{"kind": "vanish", "cells": [...]}`. Its `state` must equal `apply()`.

### 5.4 Generator: reverse building (`TallyGenerator`)

The generator starts from an empty board and builds the puzzle backwards, so every puzzle is solvable by
construction and the number of reverse steps is an upper bound `U` for par. See ADR 0003.

```
static func generate(seed_text: String, level: int) -> Dictionary
# returns {"board": TallyBoard, "start": PackedByteArray, "par", "exact", "upper", "path": PackedInt32Array,
#          "tried": int, "fallback": bool}
```

**Input.** A seed text (6.1) and a level. The seed text is hashed to an integer seed that drives the kit's PRNG
(**depends on white-kit**). The generator never uses Godot's `RandomNumberGenerator` or global random functions.

**Candidate loop.** For `t = 0 .. candidates - 1` (the PRNG stream simply continues, so the result for a seed is
deterministic):

1. Draw `I` and `Q` uniformly from the level's ranges. Make a step list: one insertion step first, then the
   remaining `I - 1` insertion steps and `Q` quiet steps in PRNG-shuffled order (Fisher-Yates with the kit PRNG).
2. `C := empty board`; `path := []`. Execute the steps in order (below). Each executed step yields a predecessor
   `P` and a forward move `m` with `apply(P, m) == C`; set `C := P` and prepend `m` to `path`.
   A step is retried up to 50 times (each retry draws fresh random choices); if all fail, the candidate is
   rejected.
3. Apply the filters (5.6) to the final `C` (the start position).

**Insertion step.** With the level's chain chance do a chain insertion, otherwise a single insertion.

- *Single insertion.* Draw a value `v` in {2, 3, 4} (uniform) and insert one group of `v` tiles of value `v`
  into `C`, giving `X` (below). Require: the inserted tiles form exactly one group in `X` (exact, no other tile
  of value `v` joined), and `resolve(X) == C`.
- *Chain insertion.* Insert a group `G2` into `C` giving `Y` (same requirements as a single insertion), then insert
  a group `G1` into `Y` giving `X`. Require: in `X` the tiles of `G2` no longer form an exact group (the insertion
  of `G1` pushed part of it up), `G1` forms an exact group, and `resolve(X) == C`. Forward this is a chain: `G1`
  vanishes, tiles fall, `G2` re-forms and vanishes.
- *Breaking reverse move.* From `X`, pick a reverse move (below) giving `P` and forward move `m`, with `P` stable
  and `apply(P, m) == C`.

**Inserting a group** of `v` tiles into a board `B` (shapes are column-convex: one vertical run per column):

1. Draw the number of columns `k` uniformly in `1 .. min(v, w)`, a start column `c0` uniformly in `0 .. w - k`,
   and run lengths `r_0 .. r_{k-1}` as a uniform random composition of `v` into `k` positive parts (choose
   `k - 1` distinct cut points in `1 .. v - 1`).
2. For each column `c = c0 + j` in order, draw the run's bottom `y0_c` uniformly among the values in
   `0 .. height_B(c)` that keep `height_B(c) + r_j <= h` and, for `j > 0`, overlap the previous run vertically:
   `y0_c <= y0_prev + r_prev - 1` and `y0_c + r_j - 1 >= y0_prev`. If no value fits, the insertion fails.
3. In column `c`, the tiles of `B` at heights `>= y0_c` move up by `r_j`; the run fills `y0_c .. y0_c + r_j - 1`
   with value `v`. Columns stay contiguous stacks.
4. Verify by forward simulation as required by the step. The construction only proposes; `resolve()` decides.

**Reverse moves** from a board `X` towards a required forward result `T`. All candidates are enumerated in a fixed
order (source cell index ascending, then `R`, `L`, `U`; reverse slides by `x'`, then `x`, then `y` ascending);
the PRNG picks one uniformly among the valid ones:

- *Reverse swap.* For each canonical swap of two different values in `X`: `P` = `X` with the two tiles
  exchanged; the forward move is the same swap.
- *Reverse slide.* For each column `x'` with `height_X(x') >= 1` and each neighbour column `x = x' +- 1` with
  `height_X(x) + 1 <= h`: take the top tile of `x'`; for each `y` in `max(0, height_X(x') - 1) .. height_X(x)`:
  `P` = `X` without that tile, with the tile inserted into column `x` at height `y` (tiles at heights `>= y` in
  column `x` move up by one). The forward move is the slide from `(x, y)` towards `x'` (`R` if `x' = x + 1`,
  else `L`).
- Valid: `P` is stable and `apply(P, m) == T`.

For an insertion step `X` is the board with the inserted group(s) and `T = C`. For a quiet step `X = C` and
`T = C`, with the extra requirement `P != C` (nothing vanishes forward; quiet steps make the start less "ready"
without adding tiles). There are no quiet steps on an empty board, which is why the first step is an insertion.

**Example (Example 5 in 2.7, built backwards).**

```
empty         insert 3s       reverse slide    insert 2s        reverse swap
              (X)             (P)              (X)              (P = start)
. . . .       . . . .         . . . .          . . . .          . . . .
. . . .       . . . .         . . . .          . . 2 .          . . 2 .
. . . .       3 3 3 .         3 3 . 3          3 3 2 3          3 2 3 3
                              forward: Ld1                      forward: Rb1
```

`path = Rb1 Ld1`, `U = 2`.

**Fallback.** If no candidate passes all filters, return the candidate nearest to the par band (smallest distance
of par to the band; ties: `exact` true first, then fewer tiles), as in White Shift. The build tool reports every
fallback; a fallback in the shipped data is allowed but must be listed in the build output.

### 5.5 Solver (`TallySolver`)

```
static func solve(board: TallyBoard, state: PackedByteArray, upper_path: PackedInt32Array,
		max_expansions: int) -> Dictionary
# returns {"par": int, "exact": bool, "path": PackedInt32Array, "expansions": int, "capped": bool}
static func beam(board: TallyBoard, state: PackedByteArray, width: int, max_depth: int) -> PackedInt32Array
static func greedy(board: TallyBoard, state: PackedByteArray, max_moves: int) -> Dictionary
# returns {"solved": bool, "moves": int, "path": PackedInt32Array}
```

`solve` is an iterative deepening depth-first search with a transposition table:

1. Replay `upper_path`; it must empty the board. `U := len(upper_path)`.
2. For `d = 1 .. U - 1`: depth-first search for a line of at most `d` moves that empties the board.
   - At a node with remaining depth `r`: if the board is empty, success. If `r == 0`, fail. If the table holds
     `table[state] >= r`, fail (already proven not clearable within `r` moves).
   - Expanding a node (generating its children) is allowed only while `expansions < max_expansions`; each
     expansion adds one. Otherwise the search stops as capped.
   - Children: `legal_moves(state)`, each applied with `apply()`. Order: more tiles removed first, ties by
     ascending move code. With `r == 1` only children that are empty are considered.
   - On failure store `table[state] = r` (keep the larger value). The table is kept across iterations. At
     4 000 000 entries it stops accepting new entries (still correct, only slower).
   - The first success gives `par = d`, `path` = that line, `exact = true`.
3. If every `d < U` failed without capping: `par = U`, `path = upper_path`, `exact = true`.
4. If capped: `exact = false`; run `beam(board, state, 200, U - 1)`; if it returns a solution shorter than `U`,
   that is `path`, else `upper_path`; `par = len(path)`.

`beam`: breadth-first by depth, keeping per depth the `width` best distinct states, ordered by fewest tiles, then
by order of first discovery (parents in kept order, children in move-code order). Returns the first emptying
line found, or an empty array.

`greedy` plays the move that removes the most tiles (ties: lowest move code). When no move removes anything it
gives up (`solved = false`). It also stops after `max_moves` (the generator uses `3 * U`).

All limits are counts, never time, so the result is identical on every machine.

### 5.6 Filters

A candidate is accepted when all of the following hold. The cheap checks run before the solver:

1. The start position is stable and not empty; every value occurs a multiple of its number of times.
2. `U >= band minimum` (otherwise par cannot reach the band).
3. The number of different values and the number of overfull groups meet the level's minimums (section 4).

Then `solve` with the level's budget, then:

4. Par lies in the band.
5. `exact` is true, unless the trial (5.7, gate B) allowed bounded par for the level.
6. Greedy gap: `greedy` does not solve the puzzle in fewer than `par + gap` moves (a greedy failure passes).
   Level "none" skips this filter.

### 5.7 Trial: to run before building the UI

The developer first builds `TallyBoard`, `TallySolver` and `TallyGenerator` with their tests, then the headless
tool `tools/measure.gd`, and runs it before any UI work (as with White Shift).

Measurements:

- M1 throughput: `apply()` calls per second on random stable 6x7 boards with 20-28 tiles; solver expansions per
  second.
- M2 per level, 200 seeds (seed texts `white-tally-trial|<n>|<level>`, `n = 0 .. 199`): candidates tried until
  accepted, fallback count, tiles at start, `U`, par, `U - par`, share of `exact`, solver expansions and time
  (median, p95, max), greedy outcome, overfull groups at start, share of puzzles whose `path` contains a chain.
- M3 build time for 60 days (180 puzzles), single thread, desktop.

Gates, decided in this order. Adjust only parameters within the allowed ranges of section 4:

| Gate | Requirement | If not met |
|---|---|---|
| A | Easy and medium: at least 95% of accepted puzzles have `exact = true` within budget. | Raise the budget (max 3 000 000), then reduce the board (6x6 to 5x6) or lower the band. |
| B | Hard: at least 80% `exact` within budget and solver p95 at most 120 s. | Hard ships bounded par (filter 5 relaxed for hard only). Record this in 5.8. |
| C | At least 20% of candidates accepted per level (accepted / tried). | Adjust `I`, `Q`; then lower the overfull minimum; then the greedy gap. |
| D | Median par strictly increases easy < medium < hard, and median hard >= p75 medium. | Shift bands or `I`/`Q`. |
| E | M3 at most 2 hours. | Lower budgets while keeping gates A and B. |

If a gate cannot be met within the allowed ranges, stop and report to the project lead; rule changes are an
architect decision, not a tuning step.

### 5.8 Trial results

To be filled in by the developer after the trial: the final level table, the M1-M3 figures and the outcome of
gates A-E. This is the only section of this document the developer edits.

## 6. Precomputed puzzles

### 6.1 Seeds

- Daily puzzle: seed text `white-tally|<YYYY-MM-DD>|<level>` (level `0`, `1`, `2`).
- Practice set: `white-tally-practice|<i>|<level>`.
- The seed text is hashed with the kit's seed hash (**depends on white-kit**; White Shift used FNV-1a 64-bit over
  UTF-8). A seed only reproduces a puzzle with the same generator code; the puzzle JSON is the portable form.

### 6.2 Why precomputed

The solver needs up to minutes per hard puzzle on a desktop; a phone browser is far slower. Puzzles are built
ahead of time and shipped; the game only loads, never searches. See ADR 0007.

### 6.3 Files and format

- `data/daily.json`: `{"<YYYY-MM-DD>": [easy, medium, hard]}`. Built for 60 days from the first day (6.5).
- `data/practice.json`: `{"<i>": [easy, medium, hard]}`, 40 sets. The game picks a set by its position in the
  file.
- Loading uses the kit's puzzle loader; the per-puzzle object is game-specific (**depends on white-kit**).
- Puzzle object (this one is Example 5):

```json
{
  "board": {"n": [4, 3], "rows": ["....", "..2.", "3233"]},
  "par": 2,
  "exact": true,
  "upper": 2,
  "path": "Rb1Ld1"
}
```

| Field | Meaning |
|---|---|
| `board.n` | `[w, h]` |
| `board.rows` | `h` strings of `w` characters `.234`, top row first (the same as `render()`) |
| `par` | Fewest moves found by the solver |
| `exact` | `true` if par is proven minimal |
| `upper` | `U`, the generator's number of reverse steps |
| `path` | One solution of length `par`, as concatenated three-character move tokens |

### 6.4 Build tool

`tools/build_puzzles.gd` (headless, `extends SceneTree`) writes a fresh file for a date range or a range of
practice sets; it never appends. New days are built to `build/` and merged into `data/daily.json`; published days
are never regenerated. It prints per puzzle: date or set, level, par, exact, upper, candidates tried, fallback.
`--verify=<file>` re-solves every puzzle in a file and checks par and exact.

### 6.5 First day

Puzzle `#1` is 2026-11-19 (the planned first publication). If the play version goes live later, numbering still
starts at that date; change the constant only before the first publication.

### 6.6 Known trade-off

The repository is public, so future puzzles and a solution for each are readable in advance. Accepted for the
prototype (nothing to win); from the leaderboard phase the server provides the daily seed or puzzle.

## 7. white-kit dependencies

Every assumption about the kit, in one place. If the kit offers it differently, adapt the call and keep the
behaviour.

| # | Kit part | What White Tally needs (depends on white-kit) |
|---|---|---|
| K1 | Dutch calendar day | Current puzzle date in the Netherlands (CET/CEST) from the device clock, no network; puzzle number from a first-day constant (6.5). |
| K2 | PRNG and seed hash | Integer PRNG with explicit 32-bit masking, identical on all platforms: next integer, uniform integer in a range, shuffle. Seed hash from a seed text. |
| K3 | Puzzle loading | Load `data/daily.json` and `data/practice.json` from `res://`; hand the per-puzzle `Dictionary` to the game unchanged; report "no puzzle for this date". |
| K4 | Attempt record base | History of states, undo, restart, solved flag, time; record as a sequence of tokens where the game supplies move tokens (three characters here) and the kit uses `z` (undo) and `r` (restart); count modes `ALL_MOVES` and `FINAL_LINE`; replay from start position plus record. The game supplies `apply(state, token)` returning the new state or null (ignored) and `is_solved(state)`. |
| K5 | Saved progress | Per date, per level: `record`, `time_ms`, `solved`; plus the language. Replay on load. Practice not saved. |
| K6 | Share line | Builder for `<title> #<n> · <a>/<b>/<c> <unit> (par <p>/<q>/<r>)` with `-` for unsolved levels; copy to clipboard. |
| K7 | Texts | NL/EN string tables with game-specific keys (10.6); language choice saved; Dutch default. |
| K8 | UI shell | Header with mode (Today/Practice) and language buttons, subtitle, three level tabs, status line (count, par, clock), slot for the game's board view, message line, button row, "no puzzle today" screen, theme colours. |
| K9 | CI | Headless tests, remaining-days check (warn below 14), Web export (release, single-threaded), publish `develop` to GitHub Pages with a custom domain. |

If the kit's record base cannot hold multi-character move tokens, do not improvise another encoding: report it to
the project lead, because it changes ADR 0007.

## 8. Attempt and record

`TallyAttempt` (on the kit's attempt base) holds one player's attempt at one puzzle: current state, undo
history, count (by mode), time and the record.

### 8.1 Record format

The record is a string of tokens, in order:

| Token | Meaning |
|---|---|
| `R`, `L` or `U` + column letter + row digit | A move in canonical form (2.4), e.g. `Rb1`. |
| `z` | Undo. |
| `r` | Restart. |

- Parsing: read a character; if it is `R`, `L`, `U` or `D`, it and the next two characters form a move token;
  if it is `z` or `r`, it is an action; anything else is skipped. A `D` token is applied with the input rules of
  2.4 (converted to canonical form); writers always write canonical tokens. A move token that is ignored under
  2.4 is skipped.
- Ignored actions (2.4) and impossible undo/restart are never written.
- Replaying a record from the start position rebuilds the exact attempt (state, history, both counts).
- Example on Example 5: `Ra1zRb1Ld1` = swap at `a1`, undo, swap at `b1`, slide at `d1`; solved.
  `ALL_MOVES` count 3 (daily), `FINAL_LINE` count 2 (practice).

The record is the save format and the intended replay format for later server-side verification. See ADR 0007.

### 8.2 Time

`time_ms` runs while a level is on screen, from its first move, and stops when solved or when the player switches
level or mode. Informational only; not part of the score and not on the share line.

## 9. Saved progress

Via the kit (K5), file `user://progress.json`, per date three entries `{"record", "time_ms", "solved"}`, plus the
language. Written after every move, undo, restart and level switch. On opening a day the records are replayed.
`solved` is derived; replay is authoritative. Practice attempts are not saved. Debug screenshot runs save nothing.

## 10. User interface

Godot 4.7.2, GL Compatibility renderer, portrait 720x1280 design size (stretch `canvas_items`, aspect
`expand`). All drawing in code (`_draw`), no image assets. The screen layout comes from the kit shell (K8); White
Tally provides the board view (`ui/board_view.gd`, class `TallyBoardView`).

### 10.1 Look

Abstract, flat and calm, in the White Shift style (same background, board and text colours via the kit theme).

| Element | Presentation |
|---|---|
| Board | Flat rectangle, faint grid lines, slightly lighter than the background. |
| Tile | Flat rounded square (corner radius 18% of the cell, gap 8% of the cell). No gradients, gloss, outlines or shadows. |
| Value 2 | Blue `#4C7FD6`, two pips on the diagonal (top-left, bottom-right). |
| Value 3 | Orange `#E3943A`, three pips on the diagonal. |
| Value 4 | Teal `#3FA58A`, four pips in the corners. |
| Pips | Dark `#1C1F24` at 85% opacity, diameter 16% of the cell. The pip count is the primary signal; colour is secondary (colour-blind safe). |
| Joins | Two neighbouring tiles with the same value are joined across the gap by a bar in the tile colour, 40% of the cell wide, so a group reads as one shape and diagonal contact visibly does not join. |
| Selection / keyboard cursor | A 4 px light outline around the cell (selection solid, cursor dashed). |

Look-alike risk (ADR 0001): no candy, sweets, gems, fruit or jewel shapes; no sparkles, particles, explosions,
screen shake, flashes, combo texts or score pop-ups; no lives, boosters or level maps. Tiles are pips on flat
squares; a vanish is a quiet fade.

### 10.2 Animation

- Swap: both tiles exchange places in 120 ms. Slide: the tile glides sideways in 100 ms, then falls.
- Fall: constant speed 16 cells/s (as White Shift), all falling tiles together.
- Vanish: the group fades out while shrinking to 70% in 180 ms; 60 ms pause before the next settle. Nothing else
  marks a chain.
- Animations come from `apply_traced()`. The simulation state is updated immediately; the animation is only
  presentation. A new input during an animation first jumps the animation to its end, then is handled.
- Ignored action: the source tile shakes sideways (3 cycles, 4 px, 150 ms in total).

### 10.3 Screen

Top to bottom (kit shell): title with mode button (Today/Practice) and language button (NL/EN); subtitle (puzzle
number and date, or practice set); three level tabs (solved levels show their count); status line with count,
par and clock; the board; a message line; buttons.

- Buttons while playing: Undo, Restart. After solving: Best route (animates the stored `path` from the start
  position without changing the attempt; input ignored meanwhile), Share result (daily only), Next.
- Opening a day selects the first unsolved level.
- Practice: three levels from one practice set; Next on the hard level opens the next set; the start set is random
  per session (UI randomness, not the generator PRNG).
- Prototype-only aids, to be reviewed in phase 2: visible par, Best route, Practice.

### 10.4 Input

- **Swipe (touch and mouse drag):** press on a tile and drag. The direction is the dominant axis of the drag; the
  move fires as soon as the drag reaches 40% of a cell, or on release if it reached at least 24 px. A press on an
  empty cell does nothing.
- **Tap-tap (touch and mouse click):** tap a tile to select it. Tap an orthogonal neighbour (tile or empty cell)
  to make the move in that direction; tap the selected tile again to deselect; tap any other tile to select that
  one instead; tap outside the board to deselect. Selection is cleared after every move, undo and restart.
- **Keyboard:** arrow keys or WASD move the cursor (starts at `a1`). Space or Enter grabs the tile under the
  cursor (shown as selected); the next arrow/WASD makes the move in that direction and releases the grab; the
  cursor then goes to the cell the grabbed tile occupies after resolution (for a slide: where it landed), or
  stays put if that tile vanished. Esc releases the grab. Z or Backspace: undo. R: restart.
- All inputs are converted to canonical moves (2.4) before they are applied and recorded.
- Debug screenshot mode (as White Shift): `-- --shot=<png> [--date=YYYY-MM-DD] [--practice] [--level=N]
  [--record=Rb1zLd1] [--lang=en] [--best]`.

### 10.5 Messages

| When | Message line |
|---|---|
| Before the first move | `hint` |
| Solved | `solved_par`, `solved_over` or `solved_under` |
| Dead end (2.8) | `dead_end` |
| Otherwise | empty |

### 10.6 Texts (Dutch default)

| Key | Dutch | English |
|---|---|---|
| `title` | White Tally | White Tally |
| `mode_today` | Vandaag | Today |
| `mode_practice` | Oefenen | Practice |
| `level_0` / `level_1` / `level_2` | Makkelijk / Middel / Moeilijk | Easy / Medium / Hard |
| `count_daily` | Zetten: {n} | Moves: {n} |
| `count_practice` | Zetten in oplossing: {n} | Moves in solution: {n} |
| `par` | Par: {p} | Par: {p} |
| `hint` | Wissel of schuif stenen. Een groep verdwijnt als hij precies zo groot is als zijn getal. | Swap or slide tiles. A group vanishes when its size equals its number. |
| `solved_par` | Leeg in {n} zetten. Precies par. | Cleared in {n} moves. Exactly par. |
| `solved_over` | Leeg in {n} zetten (par {p}, +{d}). | Cleared in {n} moves (par {p}, +{d}). |
| `solved_under` | Leeg in {n} zetten, onder par ({p}). | Cleared in {n} moves, below par ({p}). |
| `dead_end` | Geen zet meer mogelijk. Neem terug of begin opnieuw. | No move left. Undo or restart. |
| `undo` / `restart` | Terug / Opnieuw | Undo / Restart |
| `best_route` / `share` / `next` | Beste route / Deel resultaat / Volgende | Best route / Share result / Next |
| `unit` | zetten | moves |

In practice mode `count_practice` replaces `count_daily`; the solved messages use the practice count.

### 10.7 Share line

`White Tally #12 · 7/11/16 moves (par 6/10/15)` (Dutch unit `zetten`), unsolved levels as `-`, built with the
kit's share builder (K6). No moves, no time, no board. Daily only. See ADR 0004.

## 11. Build and deployment

- CI from the kit template (K9) on pushes to `develop` and `main`, pull requests to `main` and manual runs:
  Godot 4.7.2 (verified download, cached), `--import`, headless tests, remaining daily days (warn below 14),
  Web export (release, single-threaded) as artifact.
- On `develop` (not on pull requests) the Web build is published to GitHub Pages at
  https://play.whitetally.steefbeest.nl (custom domain via a DNS record in the existing zone).
- No Android or Windows builds in phase 1. Cost: none (public repository).

## 12. Roadmap

| Phase | Content |
|---|---|
| 1 | Digital prototype: rules, generator, solver, three daily puzzles, practice, abstract look, play version. |
| 2 | Tuning from play tests: levels, bands, par visibility, dead-end reporting. |
| 3 | Version 1 finish: look, sound, statistics, Android. |
| 4 | st33f-engine: daily seed from the server, puzzle results, leaderboards, friends, one account on several devices. |
| 5 | Competitions; player feedback triage. |

From phase 4 results are submitted as attempt records that the server replays to verify the count. st33f-engine
is a separate backend; this repository only depends on its public interface once that phase starts. Accounts
for players aged 10-15 require the owner's approval before phase 4 starts.

## 13. Acceptance criteria

Rules (`TallyBoard`)
- Examples 1-6 in 2.7 give exactly the shown boards (compared with `render()`).
- Equal-value swaps, moves from an empty cell, moves off the board and `U`/`D` into an empty cell leave the state
  unchanged and `canonical()` returns -1 for them.
- Input maps to canonical form as in 2.4 (`D` on `b2` over `b1` gives `U` at `b1`; `L` on `c1` over a tile at
  `b1` gives `R` at `b1`; `L` on `c2` into an empty `b2` stays `L` at `c2`).
- For 10 000 random (stable state, legal move) pairs: the result of `apply()` is stable, `apply()` equals
  `apply_reference()`, and `apply_traced()["state"]` equals `apply()`.
- Example 3 through `apply_traced()` yields exactly two `vanish` steps.
- For every value `v`, `count(v) mod v` is unchanged by any move; the tile count never increases.
- `is_dead_end` is true for Example 6 and false for the starts of Examples 1-5.
- `token()` and `parse_token()` round-trip every move code on an 8x9 board.
- A `PackedByteArray` built twice with equal content finds the same `Dictionary` entry.

Generator and solver
- `generate(seed_text, level)` called twice gives identical rows, par, exact, upper and path.
- Every generated start is stable, value counts are multiples of the value, replaying `path` empties the board
  in exactly `par` moves, and `par <= upper`.
- On Example 5 with `upper_path = Rb1 Ld1`: `solve` returns par 2, `exact` true, and a path that empties the
  board; with `max_expansions = 0` it returns `capped` true, `exact` false, par 2.
- On 20 small boards (`w <= 4`, `h <= 3`, at most 8 tiles, built by the generator with a test level) the solver's
  par equals a plain breadth-first search over all reachable states (test-only helper).
- Same seed text and budget give the same output in two runs (no dependence on time or machine).

Shipped puzzles
- Every puzzle in `data/daily.json` and `data/practice.json` parses; its start is stable; value counts are
  multiples; `par` lies in the level band (fallbacks listed by the build tool excepted); `path` empties the board
  in exactly `par` moves; `exact` is true unless 5.8 records that hard ships bounded par.
- Every date from the first day (6.5) through the last built date is present with three puzzles.
- `tools/build_puzzles.gd --verify` confirms par and exact for every shipped puzzle (run locally before
  committing data; CI only checks the points above, to stay within CI time).

Attempt, counting and record
- `ALL_MOVES`: undo and restart never lower the count. `FINAL_LINE`: undo lowers it by one, restart sets it to 0.
- Record `Ra1zRb1Ld1` on Example 5: solved, `ALL_MOVES` count 3, `FINAL_LINE` count 2.
- Ignored actions change neither count nor record; impossible undo/restart are not recorded.
- Replaying a record reproduces state, history, both counts and record.
- After solving every action is ignored.
- The share line has the format of 10.7 with `-` for unsolved levels, in both languages.

UI and deployment (manual or screenshot)
- Swipe, tap-tap and keyboard each perform the moves of Examples 1-4 on the example boards.
- Groups are visibly joined; diagonal contact shows no join; the three values are distinguishable in greyscale.
- No particles, flashes, screen shake or pop-up texts on vanish or chains.
- After a reload, a partly played day shows the same position, count and record.
- The dead-end message appears in Example 6 and disappears after undo.
- Without a puzzle for today the kit's no-puzzle message shows and practice works.
- CI on `develop` is green and https://play.whitetally.steefbeest.nl loads and plays in a phone browser.

## 14. Open points

- Phase 2: whether par stays visible during play; whether dead ends beyond "no move left" are reported
  (ADR 0006); whether value 5 is added.
- The trial (5.7) may change board sizes and bands within the stated ranges; outside them is an architect
  decision.
