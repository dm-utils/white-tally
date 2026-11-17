# White Tally - design

Status: phase 1 (look and feel) designed, not built yet. Later phases are designed in outline and marked
**[later]**; they are not built in phase 1.
This document describes the game as it must be built. Decisions with their trade-offs are in `docs/adr/`;
terms are defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`.

White Tally is built on the shared base White Kit (`dm-utils/white-kit`, installed as a git submodule at
`res://addons/white_kit/`, design in that repository's `docs/design.md`). The kit provides the Dutch calendar day
(`WhiteDaily`), seed hash (`WhiteSeed`), PRNG (`WhiteRng`), puzzle loading (`WhitePuzzleStore`), the rules
interface (`WhiteRules`), the attempt with two count modes (`WhiteAttempt`), saved progress (`WhiteProgress`),
texts (`WhiteText`), share line and clock formatting (`WhiteFormat`), theme and shared screen (`WhiteTheme`,
`WhiteUi`, `WhiteDayScreen`), test runner (`WhiteTestRunner`), precompute skeleton (`WhitePrecompute`) and the CI
template. Section 7 lists exactly what White Tally uses and the kit changes it asks for.

## 1. Purpose and phases

White Tally is a puzzle game for players aged 10 and up and adults, intended to become a daily puzzle. The board
holds tiles numbered 2, 3 and 4 under gravity. A group of equal tiles vanishes only when its size is exactly its
number. The player clears the board in as few moves as possible. No new tiles ever appear.

### 1.1 Phase 1: look and feel

Phase 1 tests how the game looks and feels. It answers:

1. Can a new player apply the exact-size rule after a 30-second explanation?
2. Does the rule force counting and planning ("more is not better"), or do players just shuffle tiles?
3. Are there "aha" moments: breaking an overfull group, one move completing two groups, gravity as a tool?
4. Are tiles, groups, swaps, falls, vanishing and chains easy to read and pleasant to watch, on a phone and on a
   PC?

In scope:

- Playable puzzles in three levels (easy, medium, hard) from a precomputed pool (6.3), not tied to dates.
- Free choice: level tabs, Next (next level, after hard the next set), Undo, Restart.
- Controls for touch, mouse and keyboard (10.4).
- Animations of swap, slide, fall, vanish and chain (10.2).
- Readability of tiles and groups (10.1).
- Moves and par shown simply (3.1); no strict scoring.
- Dutch and English.
- Web version on GitHub Pages at https://play.whitetally.steefbeest.nl.
- The rules engine, generator and solver needed to fill the pool (section 5), with a light trial (5.7).

Out of scope for phase 1 (designed below where marked **[later]**): binding puzzles to dates, the first day and
puzzle numbers, the share line, the final counting rules for the daily puzzle, saved daily progress, the full
generator trial with strict gates, accounts, leaderboards, a server, art, sound, Android/Windows builds, a puzzle
archive, giving up.

### 1.2 Later phases

See section 12. The next phase (phase 2) turns the pool into a daily puzzle: three puzzles per Dutch calendar day,
identical for everyone, with puzzle numbers, a share line and the daily count rule (every move counts).

## 2. Rules

### 2.1 Board and coordinates

- A rectangular board of `w x h` cells, side view, gravity pulls down. `w` is 2 to 8, `h` is 2 to 9 (generated
  boards are larger; small sizes occur in tests and examples).
- Coordinates: `x` grows to the right (`0 .. w-1`), `y` grows **upwards** (`0 .. h-1`), `(0, 0)` is the
  bottom-left cell. Cell index `i = y * w + x`. (White Shift counts `y` downwards; White Tally counts upwards
  because gravity makes the bottom row the natural origin.)
- Cell names (records, examples, tests): column letter `A, B, C, ...` for `x = 0, 1, 2, ...` and row digit
  `1, 2, 3, ...` for `y = 0, 1, 2, ...`. So `A1` is the bottom-left cell. Upper case only, because move tokens
  may only use upper-case letters and digits (kit rule, ADR 0007).
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
- An ignored action (not a move, or a no-op) is not counted, not recorded and does not create an undo step
  (`WhiteRules.apply` returns `null`). The board view shows a short shake of the source tile. See ADR 0002.
- In a settled board (2.5) the cell below a tile is never empty, so `D` into an empty cell cannot occur; `U`
  into an empty cell would only lift a tile that falls straight back, so it is not a move.
- After the board is empty (solved), every action is ignored (the kit's attempt enforces this).

Canonical form (used in records, the solver and the generator, so every distinct move has one spelling):

| Move | Canonical source | Canonical direction |
|---|---|---|
| Horizontal swap | the left cell of the pair | `R` |
| Vertical swap | the lower cell of the pair | `U` |
| Slide | the moving tile | `R` or `L` |

So `D` never occurs in canonical form, `L` is always a slide, `U` is always a swap, and `R` is a swap or a slide
depending on whether the target holds a tile. Player input is converted to canonical form before it is played
(for example a swipe down on `B2` over a tile at `B1` becomes `U` at `B1`; a swipe left on `C1` over a tile at
`B1` becomes `R` at `B1`).

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

**Example 1 - one swap, two groups.** Board `4 x 3`, move `RB1` (swap `B1` and `C1`).

```
start                 after the swap          after wave 1 and settling
   A B C D               A B C D                 A B C D
3  2 . . .            3  2 . . .              3  . . . .
2  3 4 . .            2  3 4 . .              2  . . . .
1  3 2 3 2            1  3 3 2 2              1  2 4 . .
```

After the swap the 3s at `A1`, `A2`, `B1` form a group of three (exact) and the 2s at `C1`, `D1` a group of two
(exact). Both vanish in the same wave. `A3` falls to `A1`, `B2` falls to `B1`. No further wave.

**Example 2 - overfull, and one slide completing two groups.** Board `4 x 2`, move `RB2` (slide `B2` right).

```
start                 after the slide         after wave 1 and settling
   A B C D               A B C D                 A B C D
2  . 2 . 2            2  . . 2 2              2  . . . .
1  2 2 3 3            1  2 2 3 3              1  . . 3 3
```

At the start the 2s at `A1`, `B1`, `B2` form a group of three: overfull, nothing vanishes. The slide takes `B2`
out of it; it lands on `C1`. Now `A1`, `B1` is an exact pair and `C2`, `D2` is an exact pair (`B1` and `C2`
touch only diagonally). Both vanish. The two 3s remain (short group).

**Example 3 - chain.** Board `3 x 3`, move `RA2` (swap `A2` and `B2`).

```
start           after the swap   wave 1, settle   wave 2, settle
   A B C           A B C            A B C            A B C
3  3 . .        3  3 . .         3  . . .         3  . . .
2  4 2 .        2  2 4 .         2  . 4 .         2  . . .
1  2 3 3        1  2 3 3         1  3 3 3         1  . 4 .
```

Wave 1: the 2s at `A1`, `A2` vanish; `A3` falls to `A1`. Wave 2: the 3s at `A1`, `B1`, `C1` vanish; `B2` falls
to `B1`.

**Example 4 - slide out of the middle of a stack.** Board `2 x 3`, move `RA2`.

```
start       result
   A B         A B
3  3 .      3  . .
2  2 .      2  3 .
1  4 .      1  4 2
```

The 2 slides into the empty `B2` and falls to `B1`; the 3 above its old cell falls to `A2`.

**Example 5 - a complete puzzle (par 2).** Board `4 x 3`.

```
   A B C D
3  . . . .
2  . . 2 .
1  3 2 3 3
```

Solution `RB1 LD1`: the swap makes `C1`, `C2` an exact pair of 2s (they vanish; column `C` empties), leaving
`3 3 . 3` on row 1; sliding `D1` left lands it on `C1` and the three 3s vanish. Another solution of length 2 is
`LC2 RA1`. No single move empties the board, so par is 2. Section 5.4 shows how the generator builds this
puzzle.

**Example 6 - no move left.** Board `6 x 2`.

```
   A B C D E F
2  . . . . . .
1  2 2 2 2 2 2
```

Every swap is between equal values (no-op), no tile has an empty cell beside it, and `U` into an empty cell is
not a move. The board cannot change: a dead end (2.8).

### 2.8 Dead ends

- A position is a **dead end** when the board is not empty and there is no move (no swap of different values and
  no slide).
- The game checks this whenever the screen refreshes (cheap: one pass over the board). In a dead end the message
  line shows the dead-end text (10.5); undo and restart stay available. Nothing else changes: the count is not
  affected and nothing is recorded.
- Positions that still have moves but can no longer be cleared are **not** detected or reported in phase 1.
  Proving that requires a search that is too slow for a phone. See ADR 0006.

## 3. Counting, undo, restart and par

### 3.1 Phase 1: simple counting

- Every puzzle is played as a kit practice attempt (`WhiteAttempt.CountMode.FINAL_ONLY`): the counter shows the
  moves from the start position to the current position (`line_length()`); undo lowers it by one, restart sets it
  to 0. Par is shown next to it. When the board is empty the message line shows the count, par and the clock.
- Undo and restart are unlimited. They are only possible when there is history and the puzzle is not solved;
  otherwise they are ignored and not recorded.
- Nothing is strict in phase 1: no score is kept across puzzles, nothing is shared, and a puzzle can be replayed
  at will with Restart.

### 3.2 [later] Daily counting

Decided by the owner for the daily puzzle (ADR 0005), built in phase 2:

| Mode | Used for | Count (`count()`) |
|---|---|---|
| `EVERY_MOVE` | Daily puzzles | `moves_made`: every move made in the attempt, including moves later undone or discarded by a restart. |
| `FINAL_ONLY` | Practice | `line_length()`: moves on the current line; when solved, the length of the solution the player ended with. |

The record (section 8) is the same in both modes; only the count differs. The screen hook
`_count_mode(is_practice)` returns `FINAL_ONLY` when `is_practice`, else `EVERY_MOVE`. Final tuning of scoring
follows play tests.

### 3.3 Par

- Par is the fewest moves found by the solver (5.5). `exact` true means proven minimal; `exact` false means a
  best-found upper bound (allowed in phase 1 for any level; see 5.7 and ADR 0004).
- When `exact` is false a player can finish below par; the solved message then simply shows a count lower than
  par.
- Par is shown during play (as in White Shift; whether it stays visible is decided later).

## 4. Levels

Each level has its own generator parameters (`TallyGenerator.LEVELS`). The values below are the **starting
values**; the developer adjusts them in the trial (5.7) within the stated ranges and records the outcome in 5.9.

| Parameter | Easy (0) | Medium (1) | Hard (2) | Allowed range |
|---|---|---|---|---|
| Board `w x h` | 5x6 | 6x6 | 6x7 | 5x6, 6x6, 6x7, 7x7 |
| Insertion steps `I` | 3-4 | 5-6 | 7-9 | +-2 on either bound |
| Quiet steps `Q` | 0-1 | 1-2 | 2-3 | 0-4 |
| Chain insertion chance (percent) | 0 | 20 | 30 | 0-50 |
| Different values present (at least) | 2 | 3 | 3 | fixed |
| Overfull groups at start (at least) | 1 | 1 | 1 | 0-2 |
| Greedy gap (5.6) | none | 1 | 2 | none-3 |
| Par band | 3-5 | 5-8 | 8-12 | bands may share at most their end value |
| Candidates tried | 400 | 600 | 900 | up to 3000 |
| Solver budget (expansions) | 100 000 | 300 000 | 1 000 000 | up to 3 000 000 |

- The upper bound `U` of a candidate is `I + Q` (one reverse move per step). Par is at most `U`.
- The bands are provisional; later phases tune them after play testing.

## 5. Rules engine, generator and solver

All code in this section lives in `sim/`, is pure (no nodes, no floats, no time, no `user://`) and is shared by
the game, the build tools and the tests.

### 5.1 State

- A state is a `PackedByteArray` of length `w * h`, index `i = y * w + x`, value `0` (empty), `2`, `3` or `4`.
- Board size and start position belong to the `TallyBoard` instance, not to the state.
- States are used directly as `Dictionary` keys (solver transposition table): Godot 4 hashes and compares packed
  arrays by content. A test asserts that two equal arrays built separately hit the same key.

### 5.2 Moves in code

- Move code: `m = i * 4 + d` with `i` the source cell index and `d` in `R = 0, L = 1, D = 2, U = 3` (the same
  direction codes as White Shift). Any direction is a valid code; a **canonical** code is one in the form of 2.4.
- Move token (records, `path`): exactly three characters - direction letter, column letter, row digit - for
  example `RB1`, `LD1`, `UA3`. Only `[A-Z0-9]`, as the kit requires (`WhiteRules.move_len() == 3`). The board
  limit `w <= 8`, `h <= 9` keeps every cell name at two characters.

### 5.3 `TallyBoard` (`sim/board.gd`)

`TallyBoard extends WhiteRules` (kit 5.6). It holds the board size and the start position and implements both
the kit interface and the fast functions used by the solver and generator.

```
class_name TallyBoard extends WhiteRules
var w: int
var h: int
var start: PackedByteArray

static func create(w: int, h: int) -> TallyBoard                 # empty start
static func from_dict(d: Dictionary) -> TallyBoard               # {"n": [w, h], "rows": [...]}, see 6.3
func to_dict(state: PackedByteArray) -> Dictionary               # inverse of from_dict for a given state
func from_rows(rows: PackedStringArray) -> PackedByteArray       # rows top first, chars ".234"
func render(state: PackedByteArray) -> String                    # rows top first, joined with "\n"

# White Kit interface (WhiteRules)
func start_state() -> Variant                                    # start
func apply(state: Variant, move: Variant) -> Variant             # canonicalise; null if ignored, else step()
func is_solved(state: Variant) -> bool                           # no tile left
func move_len() -> int                                           # 3
func encode_move(move: Variant) -> String                        # code -> "RB1"
func decode_move(token: String) -> Variant                       # "RB1" -> code; null if malformed or off the board

# Rules
func canonical(state, m: int) -> int        # canonical code of m in this state, or -1 if ignored (2.4)
func legal_moves(state) -> PackedInt32Array # all canonical codes, ascending
func step(state, m: int) -> PackedByteArray             # legal canonical move + full resolution (fast version)
func step_reference(state, m: int) -> PackedByteArray   # same result, straightforward version
func step_traced(state, m: int) -> Dictionary           # result plus animation steps (below)
func resolve(state) -> PackedByteArray                  # settle + waves
func settle(state) -> PackedByteArray
func groups(state) -> Array[PackedInt32Array]           # all groups (overfull counting, joins in the view)
func exact_groups(state) -> Array[PackedInt32Array]
func is_stable(state) -> bool                           # settled and no exact group
func is_dead_end(state) -> bool                         # not empty and legal_moves is empty
func count_tiles(state) -> int
```

- `apply(state, move)`: `c = canonical(state, move)`; return `null` when `c == -1`, else `step(state, c)`. It
  never modifies its argument (kit rule). Because it canonicalises, a non-canonical token in a record (for
  example `DB2`) replays to the same result as its canonical form; writers still produce canonical tokens only
  (8.1).
- `step()` is the fast version: it flood-fills only from cells that changed (the moved cells, and after a wave
  every cell that fell), and a flood fill stops as soon as it exceeds 4 cells (such a group can never be exact).
- `step_reference()` settles and scans every group on the whole board each wave.
- Both must return identical states for every stable state and every canonical move; the tests enforce this on
  random states. Every rule change keeps them in agreement.
- Random stable states for tests: fill each column from the bottom with a random height and random values (with a
  seeded `WhiteRng`), then `resolve()`.
- `step_traced()` returns `{"state": result, "steps": [...]}`, steps in order:
  `{"kind": "swap", "a": i, "b": j}` or `{"kind": "slide", "from": i, "to": j}` (`to` is the cell the tile slid
  into, before falling), then per settle `{"kind": "fall", "moves": [[from, to], ...]}` (omitted if nothing
  falls), per wave `{"kind": "vanish", "cells": [...]}`. Its `state` must equal `step()`.

There is no `TallyAttempt` class: the game uses `WhiteAttempt` directly with a `TallyBoard` as rules.

### 5.4 Generator: reverse building (`TallyGenerator`, `sim/generator.gd`)

The generator starts from an empty board and builds the puzzle backwards, so every puzzle is solvable by
construction and the number of reverse steps is an upper bound `U` for par. See ADR 0003.

```
static func generate(seed_value: int, level: int) -> Dictionary
# returns {"board": TallyBoard (start set), "par": int, "exact": bool, "upper": int,
#          "path": PackedInt32Array, "tried": int, "fallback": bool}
static func to_json(result: Dictionary) -> Dictionary   # the puzzle object of 6.3
```

**Input.** A 64-bit seed (6.1) and a level. The generator creates `WhiteRng.new(seed_value)` and draws only from
it (`range_int`, `shuffle`); it never uses `RandomNumberGenerator`, `randi`, `randf` or `next_float`. Percent
chances are drawn as `rng.range_int(0, 99) < percent`.

**Candidate loop.** For `t = 0 .. candidates - 1` (the PRNG stream simply continues, so the result for a seed is
deterministic):

1. Draw `I` and `Q` with `range_int` from the level's ranges. Make a step list: one insertion step first, then the
   remaining `I - 1` insertion steps and `Q` quiet steps in an order shuffled with `rng.shuffle`.
2. `C := empty board`; `path := []`. Execute the steps in order (below). Each executed step yields a predecessor
   `P` and a forward move `m` with `step(P, m) == C`; set `C := P` and prepend `m` to `path`.
   A step is retried up to 50 times (each retry draws fresh random choices); if all fail, the candidate is
   rejected.
3. Apply the filters (5.6) to the final `C` (the start position).

**Insertion step.** With the level's chain chance do a chain insertion, otherwise a single insertion.

- *Single insertion.* Draw a value `v` in {2, 3, 4} (`range_int(2, 4)`) and insert one group of `v` tiles of value
  `v` into `C`, giving `X` (below). Require: the inserted tiles form exactly one group in `X` (exact, no other tile
  of value `v` joined), and `resolve(X) == C`.
- *Chain insertion.* Insert a group `G2` into `C` giving `Y` (same requirements as a single insertion), then insert
  a group `G1` into `Y` giving `X`. Require: in `X` the tiles of `G2` no longer form an exact group (the insertion
  of `G1` pushed part of it up), `G1` forms an exact group, and `resolve(X) == C`. Forward this is a chain: `G1`
  vanishes, tiles fall, `G2` re-forms and vanishes.
- *Breaking reverse move.* From `X`, pick a reverse move (below) giving `P` and forward move `m`, with `P` stable
  and `step(P, m) == C`.

**Inserting a group** of `v` tiles into a board `B` (shapes are column-convex: one vertical run per column):

1. Draw the number of columns `k` in `1 .. min(v, w)`, a start column `c0` in `0 .. w - k`, and run lengths
   `r_0 .. r_{k-1}` as a random composition of `v` into `k` positive parts (shuffle the list `1 .. v - 1`, take the
   first `k - 1` as cut points, sort them).
2. For each column `c = c0 + j` in order, draw the run's bottom `y0_c` uniformly among the values in
   `0 .. height_B(c)` that keep `height_B(c) + r_j <= h` and, for `j > 0`, overlap the previous run vertically:
   `y0_c <= y0_prev + r_prev - 1` and `y0_c + r_j - 1 >= y0_prev`. If no value fits, the insertion fails.
3. In column `c`, the tiles of `B` at heights `>= y0_c` move up by `r_j`; the run fills `y0_c .. y0_c + r_j - 1`
   with value `v`. Columns stay contiguous stacks.
4. Verify by forward simulation as required by the step. The construction only proposes; `resolve()` decides.

**Reverse moves** from a board `X` towards a required forward result `T`. All candidates are enumerated in a fixed
order (source cell index ascending, then `R`, `L`, `U`; reverse slides by `x'`, then `x`, then `y` ascending);
`range_int` picks one uniformly among the valid ones:

- *Reverse swap.* For each canonical swap of two different values in `X`: `P` = `X` with the two tiles
  exchanged; the forward move is the same swap.
- *Reverse slide.* For each column `x'` with `height_X(x') >= 1` and each neighbour column `x = x' +- 1` with
  `height_X(x) + 1 <= h`: take the top tile of `x'`; for each `y` in `max(0, height_X(x') - 1) .. height_X(x)`:
  `P` = `X` without that tile, with the tile inserted into column `x` at height `y` (tiles at heights `>= y` in
  column `x` move up by one). The forward move is the slide from `(x, y)` towards `x'` (`R` if `x' = x + 1`,
  else `L`).
- Valid: `P` is stable and `step(P, m) == T`.

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
                              forward: LD1                      forward: RB1
```

`path = RB1 LD1`, `U = 2`.

**Fallback.** If no candidate passes all filters, return the candidate nearest to the par band (smallest distance
of par to the band; ties: `exact` true first, then fewer tiles), as in White Shift, with `fallback = true`. The
puzzle JSON then carries `"fallback": true` and the build output shows it (6.4).

### 5.5 Solver (`TallySolver`, `sim/solver.gd`)

```
static func solve(board: TallyBoard, state: PackedByteArray, upper_path: PackedInt32Array,
		max_expansions: int) -> Dictionary
# returns {"par": int, "exact": bool, "path": PackedInt32Array, "expansions": int, "capped": bool}
static func beam(board: TallyBoard, state: PackedByteArray, width: int, max_depth: int) -> PackedInt32Array
static func greedy(board: TallyBoard, state: PackedByteArray, max_moves: int) -> Dictionary
# returns {"solved": bool, "moves": int, "path": PackedInt32Array}
```

`solve` is an iterative deepening depth-first search with a transposition table:

1. Replay `upper_path` with `step`; it must empty the board. `U := len(upper_path)`.
2. For `d = 1 .. U - 1`: depth-first search for a line of at most `d` moves that empties the board.
   - At a node with remaining depth `r`: if the board is empty, success. If `r == 0`, fail. If the table holds
     `table[state] >= r`, fail (already proven not clearable within `r` moves).
   - Expanding a node (generating its children) is allowed only while `expansions < max_expansions`; each
     expansion adds one. Otherwise the search stops as capped.
   - Children: `legal_moves(state)`, each applied with `step()`. Order: more tiles removed first, ties by
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
5. **[later]** `exact` is true (phase 2 decides per level through gate B in 5.8; phase 1 accepts bounded par).
6. Greedy gap: `greedy` does not solve the puzzle in fewer than `par + gap` moves (a greedy failure passes).
   Level "none" skips this filter.

### 5.7 Phase 1 trial: enough playable puzzles per level

Before UI work the developer builds `TallyBoard`, `TallySolver` and `TallyGenerator` with their tests, then the
headless tool `tools/measure.gd`, and runs a light trial. Its only goal is a pool of playable puzzles in three
recognisably different levels.

- M1 throughput: `step()` calls per second on random stable 6x7 boards with 20-28 tiles; solver expansions per
  second.
- M2 per level, 50 seeds (`WhiteSeed.fnv1a64("white-tally-trial|<n>|<level>")`, `n = 0 .. 49`): candidates tried,
  fallback count, tiles at start, `U`, par, share of `exact`, build time per puzzle (median, max).

Done when, for every level:

| Check | Requirement | If not met |
|---|---|---|
| P1 | At least 40 of 50 seeds give a non-fallback puzzle. | Adjust `I`, `Q`; then lower the overfull minimum; then the greedy gap. |
| P2 | Median par strictly increases easy < medium < hard. | Shift bands or `I`/`Q`. |
| P3 | Building the pool (6.3, 40 sets) takes at most 2 hours on a desktop. | Lower solver budgets (par may then be bounded). |

Adjust only within the ranges of section 4. If the checks cannot be met within the ranges, stop and report to the
project lead.

### 5.8 [later] Full trial for the daily puzzle

Before puzzles are bound to dates (phase 2), the trial is repeated with 200 seeds per level and M3 (build time for
60 days = 180 puzzles), with these gates in order:

| Gate | Requirement | If not met |
|---|---|---|
| A | Easy and medium: at least 95% of accepted puzzles have `exact = true` within budget. | Raise the budget (max 3 000 000), then reduce the board (6x6 to 5x6) or lower the band. |
| B | Hard: at least 80% `exact` within budget and solver p95 at most 120 s. | Hard ships bounded par (filter 5 relaxed for hard only). |
| C | At least 20% of candidates accepted per level (accepted / tried). | Adjust `I`, `Q`; then the overfull minimum; then the greedy gap. |
| D | Median par strictly increases easy < medium < hard, and median hard >= p75 medium. | Shift bands or `I`/`Q`. |
| E | M3 at most 2 hours. | Lower budgets while keeping gates A and B. |

### 5.9 Trial results

To be filled in by the developer after the phase 1 trial: the final level table and the M1-M2 figures with checks
P1-P3. This is the only section of this document the developer edits.

## 6. Precomputed puzzles

### 6.1 Seeds

- Game id `white-tally`. Pool seed `WhiteSeed.practice("white-tally", i, level)` (seed text
  `white-tally-practice|<i>|<level>`), FNV-1a 64-bit.
- **[later]** Daily seed `WhiteSeed.daily("white-tally", date, level)` (seed text `white-tally|<YYYY-MM-DD>|<level>`).
- A seed only reproduces a puzzle with the same generator code; the puzzle JSON is the portable form.

### 6.2 Why precomputed

The solver can take minutes per hard puzzle on a desktop; a phone browser is far slower. Puzzles are built ahead
of time and shipped; the game only loads, never searches. See ADR 0007.

### 6.3 Files and format

- Phase 1: one pool, `data/practice.json`: `{"<i>": [easy, medium, hard]}`, 40 sets (the kit's practice file
  format). There is no `data/daily.json` in phase 1.
- **[later]** `data/daily.json`: `{"<YYYY-MM-DD>": [easy, medium, hard]}`, built ahead from the first day.
- Loaded with `WhitePuzzleStore.new("res://data/daily.json", "res://data/practice.json", convert)` (a missing
  daily file simply has no days); `convert` turns a raw puzzle into
  `{"board": TallyBoard.from_dict(raw.board), "par", "exact", "upper", "path"}` (path as a `PackedInt32Array` of
  codes).
- Puzzle object (this one is Example 5):

```json
{
  "board": {"n": [4, 3], "rows": ["....", "..2.", "3233"]},
  "par": 2,
  "exact": true,
  "upper": 2,
  "path": "RB1LD1"
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
| `fallback` | Present and `true` only for a fallback puzzle (5.4) |

### 6.4 Build tools

- `tools/build_puzzles.gd` extends `WhitePrecompute` (kit 5.14): `_game_id()` returns `"white-tally"`;
  `_generate(seed_value, level)` returns `TallyGenerator.to_json(TallyGenerator.generate(seed_value, level))`;
  `_summary(puzzles)` prints ` par <list> exact <list> upper <list>` and ` FALLBACK` when any puzzle has
  `fallback`. Phase 1 uses `--practice=40 --start=0 --out=...`; the date commands and `--merge` are for later.
- `tools/verify_puzzles.gd` (game tool, `extends SceneTree`): `--file=<json>` re-solves every puzzle with its
  level's budget and checks `par`, `exact` and that `path` empties the board; prints one line per key and exits
  1 on any mismatch.
- `tools/measure.gd`: the trial (5.7).

### 6.5 Game constants

`sim/game.gd`, `class_name TallyGame`: `GAME_ID := "white-tally"`, `DAILY := "res://data/daily.json"`,
`PRACTICE := "res://data/practice.json"`, and `store()` returning one lazily created `WhitePuzzleStore` with the
converter of 6.3. **[later]** `FIRST_DAY`: the date of puzzle `#1`, chosen when puzzles are bound to dates; not
set in phase 1 (the kit screen still needs a value for `_first_day()`, see 10.3).

### 6.6 Known trade-off

The repository is public, so all puzzles and a solution for each are readable. No issue for phase 1; from the
leaderboard phase the server provides the daily seed or puzzle.

## 7. White Kit usage

White Tally pins a tagged kit release (first `v0.1.0`) as a submodule at `addons/white_kit`. Names below are the
kit's (kit design sections in brackets). Items marked **[later]** are not used in phase 1.

| # | Need | Kit part | How White Tally uses it |
|---|---|---|---|
| K1 | Dutch calendar day, puzzle number | `WhiteDaily` (5.2) | **[later]** Through `WhiteDayScreen`; `_first_day()` returns `TallyGame.FIRST_DAY`. |
| K2 | PRNG and seed hash | `WhiteRng`, `WhiteSeed` (5.3, 5.4) | Generator: `WhiteRng.new(seed_value)`, `range_int`, `shuffle`. Seeds via `WhiteSeed.practice` (later also `daily`). Tests and trial: `WhiteRng.new(n)`, `WhiteSeed.fnv1a64(text)`. |
| K3 | Puzzle loading | `WhitePuzzleStore` (5.5) | `TallyGame.store()` with the converter of 6.3. |
| K4 | Rules interface, attempt, record, count modes | `WhiteRules`, `WhiteAttempt` (5.6, 5.7, 6.1) | `TallyBoard extends WhiteRules`, `move_len() == 3`, tokens `[A-Z0-9]{3}`. Phase 1: `WhiteAttempt.new(board, FINAL_ONLY)`. **[later]** `EVERY_MOVE` for daily puzzles. |
| K5 | Saved progress | `WhiteProgress` (5.8) | Phase 1: only the language (practice attempts are not saved). **[later]** daily records. |
| K6 | Share line, clock | `WhiteFormat` (5.10) | Phase 1: clock in the solved message. **[later]** share line. |
| K7 | Texts NL/EN | `WhiteText` (5.9) | `_texts()` returns the game table (10.6), overriding kit defaults. |
| K8 | Screen | `WhiteDayScreen`, `WhiteTheme`, `WhiteUi` (5.11, 5.12) | `ui/main.gd` (`extends WhiteDayScreen`) implements the hooks in 10.3; the board view is `TallyBoardView`. |
| K9 | Tests, precompute, CI | `WhiteTestRunner` (5.13), `WhitePrecompute` (5.14), `templates/ci.yml` (7.4) | `tests/run_tests.gd extends WhiteTestRunner`; `tools/build_puzzles.gd extends WhitePrecompute`; CI copied from the template with `--min-checks`. |

### 7.1 Kit changes requested

None blocks the build; each has an interim solution that works with kit `v0.1.0`. When the kit adds them (a MINOR
version), White Tally moves to the hooks and drops the interim code.

| # | Request | Why | Interim with kit v0.1.0 |
|---|---|---|---|
| R1 | A hook for the message line while playing, for example `_play_message(a: WhiteAttempt) -> String`, used when the attempt is not solved and `moves_made > 0`; default `""`. | The dead-end notice (2.8, ADR 0006). | `ui/main.gd` overrides `_refresh()`: call `super()`, then, when a puzzle is shown, not solved and `board.is_dead_end(a.state)`, set `message.text = WhiteText.t("dead_end")`. |
| R2 | A count label per mode, for example an optional text key `count_final` used in `FINAL_ONLY` (falling back to `count`). | Practice counts only the current line ("Moves in solution"). | Same `_refresh()` override: in practice set `counter.text = WhiteText.t("count_final") % a.count()`. |
| R3 | A pool-only mode: a hook such as `_start_in_practice() -> bool` (open practice instead of the day, hide the mode button). | Phase 1 has no daily puzzles; the day view would only show "no puzzle". | `ui/main.gd` overrides `_open_day()` to call `_open_practice()`, and the `_refresh()` override hides `mode_btn`. |

## 8. Attempt and record

The game uses `WhiteAttempt` with `TallyBoard` as rules: current state, undo history, `moves_made`,
`line_length()`, `count()` by mode, and the record.

### 8.1 Record format

The record follows the kit grammar (kit 6.1):

| Entry | Meaning |
|---|---|
| Move token: `R`, `L` or `U` + column letter + row digit | A move in canonical form (2.4), e.g. `RB1`. Three characters, upper case. |
| `z` | Undo. |
| `r` | Restart. |

- The board view and `_key_move` always pass canonical codes to the screen (10.4), so `encode_move` writes
  canonical tokens. `apply` canonicalises anyway, so a replayed non-canonical token still gives the right result.
- Ignored actions (2.4) and impossible undo/restart are never written (kit behaviour).
- Replaying a record from the start position (`apply_record`) rebuilds the exact attempt (state, history,
  `moves_made`, `line_length()`).
- Example on Example 5: `RA1zRB1LD1` = swap at `A1`, undo, swap at `B1`, slide at `D1`; solved.
  `FINAL_ONLY` count 2 (phase 1); `EVERY_MOVE` count 3 (daily, later).

In phase 1 the record is used by the kit's debug mode (`--keys`) and in tests. **[later]** It is the save format
for daily progress and the replay format for server-side verification. See ADR 0007.

### 8.2 Time

The kit screen keeps the clock per level: it starts at the first move, stops when solved or when the player
switches level. Informational only.

## 9. Saved progress

Phase 1: the kit saves only the language (practice attempts are never saved), in `user://progress.json`.
**[later]** Daily progress through `WhiteDayScreen` and `WhiteProgress`: per date one entry per level
`{"record", "time_ms", "solved"}`, written after every action and replayed on opening a day.

## 10. User interface

Godot 4.7.2, GL Compatibility renderer, portrait 720x1280 design size (stretch `canvas_items`, aspect
`expand`). All drawing in code (`_draw`), no image assets. Colours and fonts of the screen come from
`WhiteTheme`; White Tally adds only the board view and its tile colours. Look, animation and controls are the
core of phase 1.

### 10.1 Look

Abstract, flat and calm, in the series style.

| Element | Presentation |
|---|---|
| Board | Flat rectangle, faint grid lines, slightly lighter than `WhiteTheme.BG`. |
| Tile | Flat rounded square (corner radius 18% of the cell, gap 8% of the cell). No gradients, gloss, outlines or shadows. |
| Value 2 | Blue `#4C7FD6`, two pips on the diagonal (top-left, bottom-right). |
| Value 3 | Orange `#E3943A`, three pips on the diagonal. |
| Value 4 | Teal `#3FA58A`, four pips in the corners. |
| Pips | Dark `#1C1F24` at 85% opacity, diameter 16% of the cell. The pip count is the primary signal; colour is secondary (colour-blind safe). |
| Joins | Two neighbouring tiles with the same value are joined across the gap by a bar in the tile colour, 40% of the cell wide, so a group reads as one shape and diagonal contact visibly does not join. |
| Selection / keyboard cursor | A 4 px outline in `WhiteTheme.ACCENT` around the cell (selection solid, cursor dashed). |

Look-alike risk (ADR 0001): no candy, sweets, gems, fruit or jewel shapes; no sparkles, particles, explosions,
screen shake, flashes, combo texts or score pop-ups; no lives, boosters or level maps. Tiles are pips on flat
squares; a vanish is a quiet fade.

All sizes, colours and timings in 10.1 and 10.2 are constants at the top of `ui/board_view.gd`, so they can be
tuned after the look-and-feel test without touching logic.

### 10.2 Animation

- Swap: both tiles exchange places in 120 ms. Slide: the tile glides sideways in 100 ms, then falls.
- Fall: constant speed 16 cells/s (as White Shift), all falling tiles together.
- Vanish: the group fades out while shrinking to 70% in 180 ms; 60 ms pause before the next settle. Nothing else
  marks a chain.
- The view keeps the state it currently shows. In `_view_update(a)`: if the record ends with a move token, decode
  it and animate `step_traced(shown_state, code)`; after undo or restart (record ends with `z` or `r`) show
  `a.state` at once. The attempt is updated immediately; the animation is presentation only. A new move during an
  animation first jumps the animation to its end. Move animations do not set `_replaying`; only Best route does.
- Ignored action: the source tile shakes sideways (3 cycles, 4 px, 150 ms in total), drawn by the view; the screen
  is not involved.

### 10.3 Screen (`ui/main.gd extends WhiteDayScreen`)

Phase 1 uses the kit screen in practice mode only: title and language button (mode button hidden, R3), subtitle
with the set number, three level tabs (solved levels show their count), counter, par and clock, the board, message
line, buttons Undo, Restart, Best route (when solved), Next. The session starts at a random set (kit); the tabs
choose a level freely; Next goes to the next level and after hard to the next set. Share is not shown (kit: not in
practice).

Hooks implemented by White Tally:

| Hook | White Tally |
|---|---|
| `_game_id()` | `TallyGame.GAME_ID` |
| `_game_title()` | `"WHITE TALLY"` |
| `_first_day()` | Phase 1: a placeholder (today's date via `WhiteDaily.today()`), only because the kit requires a value; never shown. **[later]** `TallyGame.FIRST_DAY`. |
| `_texts()` | `TallyStrings.TEXT` (10.6, `ui/strings.gd`) |
| `_load_day(date)` | Phase 1: `[]`. **[later]** `TallyGame.store().day(date)` |
| `_load_practice(index)` | `TallyGame.store().practice_set(index)` |
| `_practice_count()` | `TallyGame.store().practice_count()` |
| `_count_mode(is_practice)` | `FINAL_ONLY` if `is_practice`, else `EVERY_MOVE` |
| `_new_attempt(puzzle, mode)` | `WhiteAttempt.new(puzzle.board, mode)` |
| `_make_view()` | a `TallyBoardView`; its signal `move_chosen(code)` connected to `_on_move` |
| `_view_show(a)` | `view.show_attempt(a)` (no animation) |
| `_view_clear()` | `view.clear()` |
| `_view_update(a)` | `view.update_attempt(a)` (10.2) |
| `_extra_buttons()` | `[best_btn]` (Best route: animates the puzzle's `path` from the start position without changing the attempt; sets `_replaying` while it runs) |
| `_hint_text()` | `t("hint")` |
| `_key_move(event)` | keyboard handling of 10.4; returns a canonical code or null |
| `_on_debug_extra()` | `--best`: start Best route |

Plus the interim overrides of `_open_day()` and `_refresh()` (7.1).

### 10.4 Input

- **Swipe (touch and mouse drag):** press on a tile and drag. The direction is the dominant axis of the drag; the
  move fires as soon as the drag reaches 40% of a cell, or on release if it reached at least 24 px. A press on an
  empty cell does nothing.
- **Tap-tap (touch and mouse click):** tap a tile to select it. Tap an orthogonal neighbour (tile or empty cell)
  to make the move in that direction; tap the selected tile again to deselect; tap any other tile to select that
  one instead; tap outside the board to deselect. Selection is cleared after every move, undo and restart.
- **Keyboard** (`_key_move`; Z/Backspace undo and R restart are handled by the kit screen first): arrow keys or
  WASD move the cursor (starts at `A1`) and return null. Space or Enter grabs the tile under the cursor (shown as
  selected) and returns null. With a grab, the next arrow/WASD returns the move in that direction and releases the
  grab; the cursor then goes to the cell the grabbed tile occupies after resolution (for a slide: where it
  landed), or stays put if that tile vanished. Esc releases the grab.
- Every gesture becomes a raw code `(x, y, d)`; the view converts it with `board.canonical(state, code)`. If the
  result is -1 the view shakes the tile and emits nothing; otherwise it emits `move_chosen(canonical code)`.
  `_key_move` does the same conversion and returns null for an ignored move (after triggering the shake).
- Debug screenshot mode is the kit's: `-- --shot=<png> --practice [--level=N] [--keys=RB1zLD1] [--lang=en]
  [--best]` (`--keys` takes a record).

### 10.5 Messages

| When | Message line |
|---|---|
| No move made yet (`moves_made == 0`) | `hint` |
| Solved | `solved` with count, par and clock, plus `perfect` when count equals par (kit) |
| Not solved, dead end (2.8) | `dead_end` (R1 / `_refresh()` override) |
| Otherwise | empty |

### 10.6 Texts (`ui/strings.gd`, `class_name TallyStrings`, Dutch default)

Keys overriding or extending the kit defaults (`%d`/`%s` as in the kit). Kit keys not listed keep the kit's
default texts.

| Key | Dutch | English |
|---|---|---|
| `count` | Zetten: %d | Moves: %d |
| `count_final` | Zetten in oplossing: %d | Moves in solution: %d |
| `solved` | Leeg in %d zetten (par %d) · %s | Cleared in %d moves (par %d) · %s |
| `perfect` | Precies par! | Exactly par! |
| `hint` | Wissel of schuif stenen. Een groep verdwijnt als hij precies zo groot is als zijn getal. | Swap or slide tiles. A group vanishes when its size equals its number. |
| `dead_end` | Geen zet meer mogelijk. Neem terug of begin opnieuw. | No move left. Undo or restart. |
| `best_route` | Beste route | Best route |
| `share_line` | White Tally #%d · %s zetten (par %s) | White Tally #%d · %s moves (par %s) |

### 10.7 [later] Share line

`White Tally #12 · 7/11/16 moves (par 6/10/15)` (Dutch `zetten`), unsolved levels as `-`, built by the kit
(`WhiteFormat.day_line`). No moves, no time (confirmed by the owner), no board. Daily only. See ADR 0004.

## 11. Build and deployment

- `.github/workflows/ci.yml` copied from the kit template (kit 7.4): checkout with submodules, kit pin check,
  `setup-godot` (4.7.2), import, kit tests, game tests with `--min-checks=<N>`, Web export (release,
  single-threaded) as artifact, Pages deploy on `develop`. The puzzles-left step only runs when
  `data/daily.json` exists, so it is inactive in phase 1.
- Export preset `exclude_filter="tests/*,tools/*,addons/white_kit/tests/*,addons/white_kit/tools/*"`.
- On `develop` (not on pull requests) the Web build is published to GitHub Pages at
  https://play.whitetally.steefbeest.nl (custom domain via a DNS record in the existing zone).
- No Android or Windows builds in phase 1. Cost: none (public repository). No `LICENSE` file (all rights
  reserved).

## 12. Roadmap

| Phase | Content |
|---|---|
| 1 | Look and feel: rules, generator, solver, a precomputed pool in three levels, controls, animations, readability, NL/EN, play version. |
| 2 | Daily puzzle: three puzzles per Dutch calendar day, first day and puzzle numbers, share line, `EVERY_MOVE` counting, saved daily progress, full trial (5.8). |
| 3 | Tuning from play tests: levels, bands, scoring, par visibility, dead-end reporting. |
| 4 | Version 1 finish: look, sound, statistics, Android. |
| 5 | st33f-engine: daily seed from the server, puzzle results, leaderboards, friends, one account on several devices. |
| 6 | Competitions; player feedback triage. |

From phase 5 results are submitted as attempt records plus count mode, which the server replays to verify the
count. st33f-engine is a separate backend; this repository only depends on its public interface once that phase
starts. Accounts for players aged 10-15 require the owner's approval before phase 5 starts.

## 13. Acceptance criteria

### 13.1 Phase 1

Rules (`TallyBoard`)
- Examples 1-6 in 2.7 give exactly the shown boards (compared with `render()`).
- Equal-value swaps, moves from an empty cell, moves off the board and `U`/`D` into an empty cell: `canonical()`
  returns -1 and `apply()` returns `null`.
- Canonicalisation as in 2.4 (`D` on `B2` over `B1` gives `U` at `B1`; `L` on `C1` over a tile at `B1` gives `R`
  at `B1`; `L` on `C2` into an empty `B2` stays `L` at `C2`).
- For 10 000 random (stable state, legal move) pairs: the result of `step()` is stable, `step()` equals
  `step_reference()`, and `step_traced()["state"]` equals `step()`; `apply()` does not modify its argument.
- Example 3 through `step_traced()` yields exactly two `vanish` steps.
- For every value `v`, `count(v) mod v` is unchanged by any move; the tile count never increases.
- `is_dead_end` is true for Example 6 and false for the starts of Examples 1-5.
- `encode_move()` and `decode_move()` round-trip every move code on an 8x9 board; every token matches
  `^[RLUD][A-H][1-9]$`; `decode_move` returns null for `rb1`, `XB1`, `RJ1`, `RB0` and for a cell off the board.
- A `PackedByteArray` built twice with equal content finds the same `Dictionary` entry.
- `from_dict(to_dict(state))` round-trips a board and state.

Generator and solver
- `generate(seed_value, level)` called twice gives identical rows, par, exact, upper and path.
- Every generated start is stable, value counts are multiples of the value, replaying `path` empties the board
  in exactly `par` moves, and `par <= upper`.
- On Example 5 with `upper_path = RB1 LD1`: `solve` returns par 2, `exact` true, and a path that empties the
  board; with `max_expansions = 0` it returns `capped` true, `exact` false, par 2.
- On 20 small boards (`w <= 4`, `h <= 3`, at most 8 tiles, built by the generator with a test level) the solver's
  par equals a plain breadth-first search over all reachable states (test-only helper).
- No file in `sim/` uses `RandomNumberGenerator`, `randi(`, `randf(`, `randomize(` or `next_float` (grep in the
  tests or CI).
- Trial checks P1-P3 (5.7) are met and recorded in 5.9.

Pool
- Every puzzle in `data/practice.json` converts through the store; its start is stable; value counts are
  multiples; `par` lies in the level band unless `fallback` is set; `path` empties the board in exactly `par`
  moves. The pool has 40 sets of three.
- `tools/verify_puzzles.gd` confirms par and exact for every pool puzzle (run locally before committing data).

Attempt and record (`WhiteAttempt` with `TallyBoard`, `FINAL_ONLY`)
- Undo lowers the count by one, restart sets it to 0; `moves_made` counts everything.
- Record `RA1zRB1LD1` on Example 5: solved, count 2 (and 3 in `EVERY_MOVE`).
- Ignored actions change neither count nor record; impossible undo/restart are not recorded.
- `apply_record` of a record reproduces state, record, `moves_made` and `count()`; a non-canonical token such as
  `DB2` replays to the same state as its canonical form.
- After solving every action is ignored.

UI and deployment (manual or screenshot)
- The game opens directly on a pool set (no "no puzzle" screen, no mode button); tabs switch levels; Next goes to
  the next level and after hard to the next set.
- Swipe, tap-tap and keyboard each perform the moves of Examples 1-4 on the example boards; records written from
  the UI contain only canonical tokens; an ignored move shakes the tile and changes nothing.
- Swap, slide, fall, vanish and chain animations follow 10.2; a chain shows its waves one after another; a move
  during an animation snaps the animation to its end.
- Groups are visibly joined; diagonal contact shows no join; the three values are distinguishable in greyscale.
- No particles, flashes, screen shake or pop-up texts on vanish or chains.
- The counter reads `count_final`, par is shown, and the solved message shows count, par and clock.
- The dead-end message appears in Example 6 and disappears after undo.
- Dutch and English both complete; the language choice survives a reload.
- CI on `develop` is green (kit pin check, kit tests, game tests) and https://play.whitetally.steefbeest.nl loads
  and plays in a phone browser and on a PC.

### 13.2 [later] Phase 2

- `EVERY_MOVE`: undo and restart never lower the count; record `RA1zRB1LD1` on Example 5 counts 3.
- Every date from the first day through the last built date is present in `data/daily.json` with three puzzles;
  `exact` as decided by gates A-B.
- After a reload, a partly played day shows the same position, count and record.
- The share line equals `White Tally #<n> · a/b/c moves (par p/q/r)` with `-` for unsolved levels, in both
  languages.
- Without a puzzle for today the kit's no-puzzle message shows and practice works.

## 14. Open points

- Phase 2: the first day (`FIRST_DAY`), final scoring rules, full trial gates.
- Later: whether par stays visible during play; whether dead ends beyond "no move left" are reported (ADR 0006);
  whether value 5 is added.
- Kit requests R1-R3 (7.1); until then the interim overrides.
- The trial (5.7) may change board sizes and bands within the stated ranges; outside them is an architect
  decision.
