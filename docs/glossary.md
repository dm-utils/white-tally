# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets. Terms shared by the
whole series (attempt, record, count mode, progress file, seed text, ...) are defined in White Kit's glossary
(`addons/white_kit/docs/glossary.md`); they are repeated here only where White Tally adds something. Terms marked
[later] belong to phases after phase 1.

| Term | Meaning |
|---|---|
| Attempt (`WhiteAttempt`) | One player's go at one puzzle, from White Kit, with a `TallyBoard` as rules. |
| Beam search (`TallySolver.beam`) | Fallback search that keeps the best few states per depth; used only when the exact search hits its budget. |
| Best route | The stored solution (`path`), shown as an animation after solving. Prototype aid. |
| Board (`TallyBoard`) | Board size, start position and the rules (moves, settling, vanishing); implements `WhiteRules`. |
| Breaking reverse move | The reverse move in an insertion step that turns the inserted exact group into a stable predecessor. |
| Canonical move | The single spelling of a move: horizontal swap as `R` from the left cell, vertical swap as `U` from the lower cell, slide as `R` or `L` from the moving tile. |
| Cell name | Upper-case column letter plus row digit, `A1` bottom-left. |
| Chain | A resolution with more than one wave: tiles that fell form a new exact group. |
| Chain insertion | Generator step that inserts two groups so that, forward, one vanishes and the fall completes the other. |
| Count | The number shown: `line_length()` in phase 1 and practice (`FINAL_ONLY`); [later] `moves_made` for daily puzzles (`EVERY_MOVE`). |
| Daily set | [later] The three puzzles (easy, medium, hard) of one Dutch calendar day, the same for everyone. |
| Dead end | A non-empty board without any move. Reported on the message line. |
| Every move counts (`EVERY_MOVE`) | [later] Kit count mode of daily puzzles: every move in the attempt counts, including undone and restarted ones. |
| Exact group | A group whose size equals its value. Vanishes. |
| Exact par (`exact`) | Par proven minimal because the solver's search completed within budget. |
| Expansion | One solver step: generating the children of one position. The solver budget counts expansions. |
| Fallback | The generator's nearest candidate when none fits the level; marked `"fallback": true` in the puzzle. |
| Final solution only (`FINAL_ONLY`) | Kit count mode of phase 1 and practice: only the moves from the start to the current position count; undo lowers, restart resets. |
| First day (`TallyGame.FIRST_DAY`) | [later] The date of puzzle `#1`; chosen when puzzles are bound to dates. |
| Game id | `white-tally`; first part of the seed texts. |
| Greedy gap | Filter: the greedy bot must not solve the puzzle in fewer than par plus this number of moves. |
| Greedy (`TallySolver.greedy`) | A bot that always plays the move removing the most tiles and gives up when none removes anything. |
| Group | A maximal set of 4-connected tiles with the same value. |
| Ignored action | Input that is not a move or is a no-op (for example swapping equal values). `apply` returns `null`; not counted, not recorded. |
| Insertion step | Generator step: insert an exact group backwards, then apply a breaking reverse move. |
| Join | The bar drawn between two neighbouring tiles of the same value, so groups read as one shape. |
| Level | Easy (0), medium (1) or hard (2); each has its own board size, generator settings and par band. |
| Look and feel | Phase 1: playable pool puzzles to test controls, animations, readability and the core rule; no date binding or strict scoring. |
| Move | A swap or a slide. Every move changes the board and counts. |
| Move code | Integer `cell index * 4 + direction` (`R=0, L=1, D=2, U=3`); the move value passed to the kit. |
| Move token | Three upper-case characters for one move in records and paths: direction, column letter, row digit (`RB1`). |
| Overfull group | A group larger than its value. Does not vanish. |
| Par | The fewest moves found by the solver; exact unless the puzzle says `exact: false`. |
| Par band | The range of par a generated puzzle must fall in for its level. |
| Pool | The precomputed puzzles of phase 1: 40 sets of three levels in `data/practice.json`, played as kit practice sets. |
| Practice set | One set of three puzzles from `data/practice.json`, not tied to a date, counted with `FINAL_ONLY`, not saved. |
| Precomputed puzzles | Puzzles generated ahead of time by `tools/build_puzzles.gd` and shipped in `data/`. |
| Puzzle number | [later] Day count of a daily set, counted from the first day. |
| Quiet step | Generator step: a reverse move after which, forward, nothing vanishes. |
| Record | Kit action string: move tokens, `z` undo, `r` restart, e.g. `RA1zRB1LD1`. Debug and test format in phase 1; [later] save and replay format. |
| Resolution | What follows a move: settle, then waves of vanishing exact groups with settling in between, until stable. |
| Reverse building | The generator method: start from an empty board and build the puzzle backwards with verified reverse steps. |
| Reverse slide | Generator operation: move the top tile of a column back into a neighbouring column so that a forward slide recreates the board. |
| Settle | Let every tile fall straight down in its column until it rests on the floor or another tile. |
| Share line | [later] One line with the day's counts and pars, without the solution or time, e.g. `White Tally #12 · 7/11/16 moves (par 6/10/15)`. |
| Short group | A group smaller than its value. Does not vanish. |
| Slide | Move a tile sideways into an empty neighbouring cell; it then falls. |
| Solver (`TallySolver`) | Iterative deepening search with a transposition table that computes par and a solution path. |
| Stable | Settled and without exact groups. Every start position and every position after a move is stable. |
| State | `PackedByteArray` of `w * h` cells, value 0 (empty), 2, 3 or 4, index `y * w + x` with `y` upwards. |
| Swap | Exchange two neighbouring tiles with different values. |
| Tile | A square with value 2, 3 or 4, shown as pips in the value's colour. |
| Trial | The measurement run (`tools/measure.gd`): light in phase 1 (enough playable puzzles per level), [later] full with gates before date binding. |
| Upper bound (`upper`, `U`) | Number of reverse steps the generator used; the length of a known solution and a maximum for par. |
| Wave | One round of removing all exact groups at the same time. |
| White Kit | The shared base of the White puzzle games, a submodule at `addons/white_kit`. |
