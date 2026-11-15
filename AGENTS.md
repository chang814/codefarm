# AGENTS.md

Instructions for coding agents working on **Codefarm** (Codex CLI, Codex Bot, Cursor, and others). Humans should start with [docs/PROJECT-OVERVIEW.md](docs/PROJECT-OVERVIEW.md) (Chinese overview). Current version: **0.2.11**. Canonical tree: the maintainer's local checkout (see [docs/SOURCE.md](docs/SOURCE.md)); GitHub `chang814/codefarm` is the public mirror.

Codefarm is an original programming-farm game: players automate a farm with C++ programs, rendered in Godot 4.7.2. Player programs must look like standard C++ (`#include <bits/stdc++.h>`, `using namespace std;`, `int main()`). The UI is Chinese. The repo must not use or ship any third-party game's art, music, names, or trademarks, and docs should describe Codefarm on its own terms rather than as a version of another game.


## Source of truth

The only canonical tree is the maintainer's local checkout (`<本机仓库>` below). 云端工作副本 is a working copy. Sync from the desktop before you start, and write back when you finish. If the two copies disagree, the desktop wins. Never overwrite the desktop with an older cloud zip. `<中转目录>\` is for transfer only.

Read [docs/SOURCE.md](docs/SOURCE.md) first. Record every change in `VERSION` and all three changelogs, as below. Direction comes from `docs/PROJECT-OVERVIEW.md`, `docs/playthrough.md`, `docs/skill-tree-design.md`, `docs/endless-design.md` (plan only, do not implement until 畅 asks), and the latest `docs/review-*.md`.

Code changes go through **Codex CLI**. Codex Bot assigns the work, watches it, verifies tests, and syncs the desktop.

## Layout

```
sim/            C++ simulator (no Godot dependency)
  include/codefarm/types.hpp world.hpp interpreter.hpp
  src/world.cpp interpreter.cpp
tests/          unit tests, full playthrough, exemplar coverage
extension/      GDExtension bridge (CodefarmHost)
game/           Godot 4 project (open the game/ folder)
  scripts/main.gd skill_data.gd farm_window.gd ...
  exemplars/    reference solutions shared by the game and the tests
  fonts/ themes/ scenes/ bin/
docs/           overview, playthrough, skill tree, endless plan, research/
third_party/    godot-cpp (needed to build the extension, not in the src zip)
tools/          official Godot 4.7.2 editor binary (optional)
```

`game/exemplars/<id>.cpp` is the exact program the playthrough test runs and the exact text the in-game hint shows. Do not keep a second "display only" copy.

## Build, run, test

The simulator and unit tests do not need Godot. The game needs the GDExtension.

### Linux

```bash
cmake -S . -B build-tests -G Ninja -DCODEFARM_BUILD_EXTENSION=OFF
cmake --build build-tests
./build-tests/codefarm_tests
./build-tests/codefarm_playthrough

cmake -S . -B build -G Ninja -DCODEFARM_BUILD_EXTENSION=ON
cmake --build build

./tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script scripts/verify_headless.gd
xvfb-run -a -s "-screen 0 1440x900x24" ./tools/Godot_v4.7.2-stable_linux.x86_64 --path game --script scripts/verify_smoke.gd
```

Open the project with Godot **4.7.x** on the `game/` directory.

### Windows (畅's laptop: `<本机仓库>`)

CMake is `<CMake>\bin\cmake.exe`. The compiler is `<MinGW>`. Incremental builds go in `build-win`. **Do not write `\"` in PowerShell**; use `cmd.exe /c '...'`.

```bat
cmd.exe /c "set PATH=<MinGW>\bin;<CMake>\bin;%PATH% && cd /d <本机仓库>\build-win && cmake --build ."
cmd.exe /c "set PATH=<MinGW>\bin;%PATH% && cd /d <本机仓库> && build-win\codefarm_tests.exe"
```

Copy `codefarm.windows.template_debug.x86_64.dll` plus `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, and `libwinpthread-1.dll` into `game\bin`.

**Fully quit Godot, then reopen `game`.** Never force-kill Godot. An already-open editor will not reload the extension reliably.

### Tests that must stay green

- `codefarm_tests` (1844 checks as of 0.2.11; the count must never drop). This includes:
  - `test_full_playthrough`: clears the tree from a fresh save using only player actions (buy, load an exemplar, run). No `grant_for_test` or other backdoors.
  - `test_every_node_has_exemplar`: every skill node has an exemplar that parses and runs.
- `VERIFY_OK` from `verify_headless.gd`.
- `SMOKE_OK` from `verify_smoke.gd`.
- If you edit a file in `game/exemplars/`, the playthrough test must still pass. Each exemplar adds one idea to the previous one; do not jump ahead.

## Version and changelog

Version is `major.minor.patch` in `VERSION`. Patch for small fixes; minor for large content or a new system.

Update all of these together:

1. `VERSION`
2. `game/project.godot` (`config/version`)
3. `game/scripts/main.gd` (`const VERSION`)
4. Three changelogs, each with an entry: `CHANGELOG.md`, `game/changelog.md`, and `CHANGELOG_TEXT` in `main.gd`
5. The version in `README.md` when it states the current release

## Coding conventions and known pitfalls

- **Keep the `preload(...)` calls at the very top of `game/scripts/main.gd`.** Deleting or moving them breaks class loading on Windows.
- **The window resize handle must be a child of `body`**, not a direct child of the `PanelContainer`, in `farm_window.gd`. Otherwise the whole window becomes a resize hit target and a color block comes back.
- **Godot 4.7 `CodeEdit` property names.** Use the 4.7 names (for example `gutters_draw_line_numbers`, `caret_blink`). Do not invent 3.x / 4.0 aliases.
- **Windows shells:** no `\"` in PowerShell. Prefer `cmd.exe /c '...'`.
- **Do not force-kill Godot.** Ask the user to quit it fully, then reopen.
- **Exemplar paths in tests:** do not bake a narrow-char absolute path that contains non-ASCII (e.g. a Windows path containing `桌面`) into `-D` macros. CMake writes UTF-8 byte arrays into `codefarm_paths.hpp`; `tests/playthrough.hpp` opens them with `std::filesystem` and Win32 wide APIs, and can also walk up from the cwd or the executable to the repo root. Keep that behavior if you touch test I/O.
- C++20, `-Wall -Wextra -Wpedantic`, no Godot types inside `sim/`.
- Player-facing strings are Chinese. Icon labels stay one word.
- Data-driven costs, growth, and yields belong in `types.hpp` (or a clear table), not as scattered magic numbers.

## Design rules (do not drift)

- Pain first, then the skill that cures it.
- UI: an icon plus one word; little text; no walls of explanation. Top-bar icon buttons are nearly square (about 36×36, corner radius 6) with even inset; text buttons stay wider. Window chrome buttons are square too.
- Fonts: Noto Sans CJK SC for system UI, JetBrains Mono (20px default, zoomable with Shift+wheel) for code. The default `#include` / `using` / `int main()` / `return 0` frame is edit-protected; the body stays editable.
- The farm bot is a milk-yellow bean body with black vertical-bar eyes. No screen-face. No ring under the bot. The island under the field must not be a hard-edged disk.
- Camera: left-drag on the ground pans with a little inertia; left clicks on UI never move the map; right-drag orbits 1:1; wheel zooms toward the cursor; WASD (stops on release); F recenters. The skill tree uses the same left-drag feel (6px threshold, grab cursor, short glide); a click on a node still unlocks or opens details; an open detail sheet does not pan with the tree, and the map does not pan while the tree is open.
- Run: solid triangle runs `main` once and stops; hollow triangle steps once; clicking the editor stops. Grass keeps growing after the program ends. Speed upgrades shorten successful and failed harvest swings through action_ticks(), never growth. Harvesting unripe Grass restarts its 400-tick growth at action start; other crops keep their existing failure effects. Queries cost 1 tick and do not reset growth. Opening harvest and grass growth are 400 ticks.
- Exemplars: one new concept at a time; tests and the game read the same file.

## Do not

- Push only to your own task branch (`claude/`, `codex/`, `chore/` …). Merging into `main`, releases, and repository settings need 畅's explicit approval.
- Do not open or touch the maintainer's private credentials folder on the laptop.
- Keep local paths, usernames, and machine details out of committed files; use placeholders such as `<本机仓库>`.
- Do not type passwords, OTPs, or API keys.
- Do not use test backdoors (`grant_for_test`, `set_item`, `set_grass_mature`, …) as a substitute for real play.
- Do not commit secrets, student IDs, phone numbers, or local env files.
- Do not change gameplay when the task is documentation, packaging, or a tight bugfix (0.2.3 is an example of the last).
- Do not restore a shop, make failed/query actions free, or ship UI icons without the simulator behavior.

## Collaboration

The canonical repo is `<本机仓库>`. Before a session, read `VERSION` and the latest changelog there. After a session, the desktop must have the new files.

Code is written by **Codex CLI** (ChatGPT login on both the laptop and the box) unless 畅 assigns the task to another agent directly. Codex Bot briefs Codex, supervises, runs the tests, and reports to 畅. If OpenAI is blocked, stop and say so; do not quietly switch tools. Do not start a second long-lived tree that drifts from the desktop.

Handoff: point at this file, `docs/SOURCE.md`, and `docs/PROJECT-OVERVIEW.md`. State the desktop version and the intended change, attach commands / failing logs, and require green tests plus the three changelog entries.

Syncing: copy into `<中转目录>\` first, then overlay onto `<本机仓库>` while keeping `fonts`, `third_party`, `.godot`, and `build-win`. Prefer small diffs; split large files into 3MB chunks and join with `copy /b`, then check SHA256. Do not overwrite the desktop while Godot is open.
