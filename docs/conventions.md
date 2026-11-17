# Conventions

How code, tests, data and branches are handled in this repository. The design is in `docs/design.md`. These
conventions follow White Shift; differences are marked.

## Engine and layout

- Godot 4.7.2, GDScript only, pinned in `project.godot` and CI. Use the same version on every machine.
- Renderer: GL Compatibility (works on the web and on older phones). Web export single-threaded.
- Shared code comes from white-kit (day, PRNG and seed hash, puzzle loading, attempt base, progress, share line,
  texts, UI shell, CI). Do not copy kit code into `sim/` or `ui/`; if the kit lacks something, report it rather
  than working around it. How the kit is included (addon folder, version pin) follows the kit's own README
  (depends on white-kit).

| Folder | Content |
|---|---|
| `sim/` | Rules, solver, generator, attempt. No scenes, no nodes, no UI. |
| `ui/` | Board view (`board_view.gd`) and game-specific texts. Depends on `sim/` and the kit, never the other way round. |
| `tools/` | Headless scripts (`extends SceneTree`) for building and measuring puzzles. |
| `data/` | Precomputed puzzles shipped with the game (`daily.json`, `practice.json`). |
| `tests/` | Headless test runner and tests. |
| `build/` | Local output (exports, generated puzzle files). Ignored by git. |

## GDScript style

- Godot style guide: tabs for indentation, `snake_case` for functions and variables, `PascalCase` for classes and
  enums, `UPPER_CASE` for constants and enum values. Keep lines within 120 characters.
- Static typing everywhere: typed parameters and return types, `:=` for inferred locals, typed arrays where
  practical.
- Members and functions that are internal to a class start with `_`.
- Global classes have the prefix `Tally` (`TallyBoard`, `TallySolver`, `TallyGenerator`, `TallyAttempt`,
  `TallyBoardView`). Classes in `sim/` extend `RefCounted` and mostly expose static functions or small instances
  (`TallyBoard` holds `w` and `h`).
- `sim/` code must not use scenes, nodes, input, rendering, time or `user://`. It may use `JSON` and
  `FileAccess` on `res://`.
- Hot paths (move resolution, solver, generator) work on `PackedByteArray` states and flat cell indices, not on
  objects.
- Every rule change keeps `TallyBoard.apply()` and `TallyBoard.apply_reference()` in agreement.
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. Comments and
  identifiers are in English.
- Player-facing texts live in the string tables (kit or `ui/`), in Dutch and English; no texts hard-coded
  elsewhere.
- No credentials, keys or personal data in the repository.

## Coordinates (differs from White Shift)

- `x` to the right, `y` **upwards**, `(0, 0)` bottom-left, cell index `y * w + x`.
- Human notation: column letter + row digit, `a1` bottom-left. Board text (`render()`, `board.rows`) lists the
  top row first.
- The board view converts to screen coordinates; nothing else in the code uses screen orientation.

## Determinism

- The generator must give the same puzzle for the same seed text on every machine. Use only the kit PRNG seeded
  from the seed text; never Godot's `RandomNumberGenerator` or the global random functions in `sim/`.
- No floats in rules, solver or generator. Chances (for example the chain chance) are compared as integers
  (`prng.range(0, 99) < 30`).
- Search limits are counts (expansions, candidates, retries), never time.
- Seed texts are fixed: `white-tally|<YYYY-MM-DD>|<level>` and `white-tally-practice|<i>|<level>`; trial seeds
  `white-tally-trial|<n>|<level>`.
- Changing `TallyGenerator` or `TallySolver` changes what a seed produces. Puzzles already in `data/` are not
  regenerated; a change only applies to days built afterwards.

## Tests

- Run headless. After a fresh clone, or after adding or renaming a `class_name`, import first so the class cache
  exists:

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://tests/run_tests.tscn
```

- The runner (`tests/run_tests.gd`) calls each `test_*` function, records results with `check(ok, what)`,
  prints `tests: N passed, M failed` and exits with code 1 on any failure. CI uses that exit code.
- `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Tests cover `sim/` directly (no UI). Boards for rule tests are built from rows with `TallyBoard.from_rows()`
  and compared with `render()`.
- Every example in design 2.7 is a test.
- Every shipped puzzle in `data/` is re-checked by the tests (parses, stable, path clears the board in par
  moves, par in band). Full re-solving is done with `tools/build_puzzles.gd --verify`, not in CI.
- UI is checked with the debug screenshot mode (`-- --shot=<png> ...`, see design 10.4); screenshots are not
  committed.

## Puzzle data

- Measure the generator before and after changing it:

```bash
godot --headless --path . -s res://tools/measure.gd -- --seeds=200
```

- Build daily puzzles ahead with the precompute tool; it writes a fresh file and does not append:

```bash
godot --headless --path . -s res://tools/build_puzzles.gd -- --from=YYYY-MM-DD --days=30 --out=build/daily.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 --start=0 --out=build/practice.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --verify=build/daily.json
```

- Merge new days into `data/daily.json` without changing existing dates; run the tests and `--verify` before
  committing.
- Keep at least 14 days ahead; CI warns below that.

## Git and CI

- `develop` is the working branch; every push to `develop` runs CI and publishes the play version at
  https://play.whitetally.steefbeest.nl. `main` is protected and is updated through pull requests only; CI runs
  on those pull requests.
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main`. Do not commit build output (`build/` is ignored).
