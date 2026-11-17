# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets.

| Term | Meaning |
|---|---|
| All moves count (`ALL_MOVES`) | Count mode of daily puzzles: every move in the attempt counts, including undone and restarted ones. |
| Attempt (`TallyAttempt`) | One player's go at one puzzle: current state, undo history, count, time and record. Built on the white-kit attempt base. |
| Beam search (`TallySolver.beam`) | Fallback search that keeps the best few states per depth; used only when the exact search hits its budget. |
| Best route | The stored solution (`path`), shown as an animation after solving. Prototype aid. |
| Board (`TallyBoard`) | Board size plus the rules: moves, settling, vanishing. The tiles themselves are in the state. |
| Breaking reverse move | The reverse move in an insertion step that turns the inserted exact group into a stable predecessor. |
| Canonical move | The single spelling of a move: horizontal swap as `R` from the left cell, vertical swap as `U` from the lower cell, slide as `R` or `L` from the moving tile. |
| Chain | A resolution with more than one wave: tiles that fell form a new exact group. |
| Chain insertion | Generator step that inserts two groups so that, forward, one vanishes and the fall completes the other. |
| Daily set | The three puzzles (easy, medium, hard) of one Dutch calendar day, the same for everyone. |
| Dead end | A non-empty board without any move. Reported on the message line. |
| Dutch calendar day | The date in the Netherlands (CET/CEST); decides which daily set is current. From white-kit. |
| Exact group | A group whose size equals its value. Vanishes. |
| Exact par (`exact`) | Par proven minimal because the solver's search completed within budget. |
| Expansion | One solver step: generating the children of one position. The solver budget counts expansions. |
| Final line counts (`FINAL_LINE`) | Count mode of practice sets: only the moves on the current line count; undo lowers, restart resets. |
| Greedy gap | Filter: the greedy bot must not solve the puzzle in fewer than par plus this number of moves. |
| Greedy (`TallySolver.greedy`) | A bot that always plays the move removing the most tiles and gives up when none removes anything. |
| Group | A maximal set of 4-connected tiles with the same value. |
| Ignored action | Input that is not a move or is a no-op (for example swapping equal values). Not counted, not recorded. |
| Insertion step | Generator step: insert an exact group backwards, then apply a breaking reverse move. |
| Join | The bar drawn between two neighbouring tiles of the same value, so groups read as one shape. |
| Level | Easy (0), medium (1) or hard (2); each has its own board size, generator settings and par band. |
| Move | A swap or a slide. Every move changes the board and counts. |
| Move token | Three characters for one canonical move in records and paths: direction, column letter, row digit (`Rb1`). |
| Overfull group | A group larger than its value. Does not vanish. |
| Par | The fewest moves found by the solver; exact unless the puzzle says `exact: false`. |
| Par band | The range of par a generated puzzle must fall in for its level. |
| Practice set | Three puzzles from `data/practice.json`, not tied to a date, counted with `FINAL_LINE`, not saved. |
| Precomputed puzzles | Puzzles generated ahead of time by `tools/build_puzzles.gd` and shipped in `data/`. |
| Puzzle number | Day count of a daily set; `#1` is 2026-11-19. |
| Quiet step | Generator step: a reverse move after which, forward, nothing vanishes. |
| Record | The token string of an attempt: move tokens, `z` undo, `r` restart. Save format and future replay format. |
| Replay | Rebuilding an attempt by applying its record to the start position. |
| Resolution | What follows a move: settle, then waves of vanishing exact groups with settling in between, until stable. |
| Restart | Back to the start position; clears the undo history. Does not lower the count in `ALL_MOVES`. |
| Reverse building | The generator method: start from an empty board and build the puzzle backwards with verified reverse steps. |
| Reverse slide | Generator operation: move the top tile of a column back into a neighbouring column so that a forward slide recreates the board. |
| Seed text | The text hashed into a generator seed: `white-tally\|<date>\|<level>` or `white-tally-practice\|<i>\|<level>`. |
| Settle | Let every tile fall straight down in its column until it rests on the floor or another tile. |
| Share line | One line with the day's counts and pars, without the solution, e.g. `White Tally #12 · 7/11/16 moves (par 6/10/15)`. |
| Short group | A group smaller than its value. Does not vanish. |
| Slide | Move a tile sideways into an empty neighbouring cell; it then falls. |
| Solver (`TallySolver`) | Iterative deepening search with a transposition table that computes par and a solution path. |
| Stable | Settled and without exact groups. Every start position and every position after a move is stable. |
| State | `PackedByteArray` of `w * h` cells, value 0 (empty), 2, 3 or 4, index `y * w + x` with `y` upwards. |
| Swap | Exchange two neighbouring tiles with different values. |
| Tile | A square with value 2, 3 or 4, shown as pips in the value's colour. |
| Trial | The measurement run (`tools/measure.gd`) that fixes level settings and decides exact or bounded par before the UI is built. |
| Undo | Back to the position before the last move. Does not lower the count in `ALL_MOVES`; lowers it by one in `FINAL_LINE`. |
| Upper bound (`upper`, `U`) | Number of reverse steps the generator used; the length of a known solution and a maximum for par. |
| Wave | One round of removing all exact groups at the same time. |
| white-kit | The shared base of the White puzzle games (day, PRNG, puzzle loading, attempt base, progress, share line, texts, UI shell, CI). |
