# Conventions

How code, tests, data and branches are handled in this repository. The design is in `docs/design.md`. These
conventions follow White Shift; differences are marked.

## Engine and layout

- Godot 4.7.2, GDScript only, pinned in `project.godot` and CI. Use the same version on every machine.
- Renderer: GL Compatibility (works on the web and on older phones). Web export single-threaded.
- White Kit is a git submodule at `addons/white_kit`, pinned to a tagged release (CI checks the pin). Clone with
  `--recurse-submodules`, or run `git submodule update --init` after a plain clone. Never edit files under
  `addons/white_kit` in this repository; kit changes are requested from the kit (design 7.1) and arrive by
  updating the pin:

```bash
git -C addons/white_kit fetch --tags
git -C addons/white_kit checkout v<new>
git add addons/white_kit
# run the tests, then commit: chore: update White Kit to v<new>
```

| Folder | Content |
|---|---|
| `sim/` | Rules (`TallyBoard`), solver, generator, game constants and puzzle store (`TallyGame`). No scenes, no nodes, no UI. |
| `ui/` | Main screen (`main.gd`, extends `WhiteDayScreen`), board view (`board_view.gd`), texts (`strings.gd`). Depends on `sim/` and the kit, never the other way round. |
| `tools/` | Headless scripts: `build_puzzles.gd` (extends `WhitePrecompute`), `verify_puzzles.gd`, `measure.gd`. |
| `data/` | Precomputed puzzles shipped with the game: the pool `practice.json` (phase 1); `daily.json` from phase 2. |
| `tests/` | Headless test runner (extends `WhiteTestRunner`) and tests. |
| `addons/white_kit/` | White Kit (submodule). |
| `build/` | Local output (exports, generated puzzle files). Ignored by git. |

There is no `LICENSE` file: all rights reserved.

## GDScript style

- Godot style guide: tabs for indentation, `snake_case` for functions and variables, `PascalCase` for classes and
  enums, `UPPER_CASE` for constants and enum values. Keep lines within 120 characters.
- Static typing everywhere: typed parameters and return types, `:=` for inferred locals, typed arrays where
  practical. Kit interface methods keep the kit's `Variant` signatures.
- Members and functions that are internal to a class start with `_` (kit hooks also start with `_`).
- Global classes have the prefix `Tally` (`TallyBoard`, `TallySolver`, `TallyGenerator`, `TallyGame`,
  `TallyBoardView`, `TallyStrings`). Kit classes have the prefix `White`; do not declare `White*` names here.
- `sim/` code must not use scenes, nodes, input, rendering, time or `user://`. It may use `JSON` and
  `FileAccess` on `res://`, and kit `core/` classes.
- Hot paths (move resolution, solver, generator) work on `PackedByteArray` states and integer move codes, not on
  objects.
- Every rule change keeps `TallyBoard.step()` and `TallyBoard.step_reference()` in agreement.
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. Comments and
  identifiers are in English.
- Player-facing texts live in `ui/strings.gd` (`TallyStrings.TEXT`, Dutch and English), registered through the
  kit; no texts hard-coded elsewhere.
- Look-and-feel values (sizes, colours, timings) are named constants at the top of `ui/board_view.gd`.
- No credentials, keys or personal data in the repository.

## Coordinates and notation (differs from White Shift)

- `x` to the right, `y` **upwards**, `(0, 0)` bottom-left, cell index `y * w + x`.
- Cell names: upper-case column letter + row digit, `A1` bottom-left. Move tokens: direction + cell, `RB1`.
  Upper case only (kit record grammar); lower-case letters in a record are kit actions (`z`, `r`).
- Board text (`render()`, `board.rows`) lists the top row first.
- The board view converts to screen coordinates; nothing else in the code uses screen orientation.

## Determinism

- The generator must give the same puzzle for the same seed on every machine. Use only `WhiteRng` seeded from
  the seed (`range_int`, `shuffle`); never `RandomNumberGenerator`, `randi`, `randf`, `randomize` or
  `WhiteRng.next_float` in `sim/`.
- No floats in rules, solver or generator. Percent chances: `rng.range_int(0, 99) < percent`.
- Search limits are counts (expansions, candidates, retries), never time.
- Seeds: `WhiteSeed.practice("white-tally", i, level)` for the pool; trial seeds
  `WhiteSeed.fnv1a64("white-tally-trial|<n>|<level>")`; [later] `WhiteSeed.daily("white-tally", date, level)`.
- Changing `TallyGenerator` or `TallySolver`, or updating the kit across a MAJOR version of `WhiteRng`, changes
  what a seed produces. In phase 1 the pool may be rebuilt freely; from phase 2 published days are never
  regenerated.

## Tests

- Run headless. After a fresh clone, or after adding or renaming a `class_name`, import first so the class cache
  exists:

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://addons/white_kit/tests/run_kit_tests.tscn
timeout 300 godot --headless --path . res://tests/run_tests.tscn -- --min-checks=<N>
```

- `tests/run_tests.gd` extends `WhiteTestRunner`: tests run in `_run()`, results via `check(ok, what)`, output
  `tests: N passed, M failed`, exit code 1 on any failure or when fewer than `--min-checks` checks ran. CI uses the
  same `N` as the workflow's `--min-checks`; raise it when tests are added.
- `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Tests cover `sim/` directly; boards for rule tests are built with `TallyBoard.from_rows()` and compared with
  `render()`. Every example in design 2.7 is a test. Attempt tests use `WhiteAttempt` with a `TallyBoard`.
- Every shipped puzzle in `data/` is re-checked by the tests (converts, stable, path clears the board in par
  moves, par in band). Full re-solving is done with `tools/verify_puzzles.gd`, not in CI.
- UI is checked with the kit's debug screenshot mode (`-- --shot=<png> --practice ...`, design 10.4);
  screenshots are not committed.

## Puzzle data

- Measure the generator before and after changing it (phase 1 trial, design 5.7):

```bash
godot --headless --path . -s res://tools/measure.gd -- --seeds=50
```

- Phase 1: build and verify the pool, then copy it to `data/`:

```bash
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 --start=0 --out=build/practice.json
godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=build/practice.json
```

- [later] Daily puzzles: build ahead, verify, then merge (merge adds new keys only and refuses to change a
  published one); keep at least 14 days ahead (CI warns below that):

```bash
godot --headless --path . -s res://tools/build_puzzles.gd -- --from=YYYY-MM-DD --days=30 --out=build/daily.json
godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=build/daily.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --merge=build/daily.json --into=data/daily.json
```

- Run the tests and the verify tool before committing data.

## Git and CI

- `develop` is the working branch; every push to `develop` runs CI and publishes the play version at
  https://play.white-tally.steefbeest.nl. `main` is protected and is updated through pull requests only; CI runs
  on those pull requests.
- `.github/workflows/ci.yml` comes from the kit template (`addons/white_kit/templates/ci.yml`).
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main`. Do not commit build output (`build/` is ignored).
