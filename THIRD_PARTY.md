# Third-party components

This project is proprietary (see [LICENSE](LICENSE)). It includes or adapts the
following third-party work, which remains under its own license.

## godot-gameplay-abilities (GGA)

- Location: `godot/addons/gameplay-abilities/`
- Author: Paolo Roth (OctoD)
- Source: https://github.com/OctoD/godot-gameplay-abilities
- License: MIT — Copyright (c) 2021 Paolo Roth
- The vendored copy ships without a license file; the MIT text below applies.
- Web (`wasm32`) binaries were additionally built by us from upstream source
  (`6d1ce71`) with Emscripten 4.0.20 and godot-cpp branch `4.5`, single-precision
  and single-threaded to match Godot's `web_dlink_nothreads_*` templates — see
  `docs/web-build.md`. The `.gdextension` file references them via a
  `web.wasm32.single.debug` entry.
- Vendored snapshot: predates upstream `6d1ce71` (2026-01-19), which renamed the upstream
  `linux`/`windows` binary paths — our `.gdextension` paths and shipped binaries match each
  other, so no action is needed; re-vendor in the Phase LAST engine upgrade (`docs/plan.md`).

## godot_gameplay_attributes (GGA)

- Location: `godot/addons/gameplay-attributes/`
- Author: Paolo Roth (OctoD)
- Source: https://github.com/OctoD/godot_gameplay_attributes
- License: MIT — Copyright (c) Paolo Roth; the vendored copy ships without a license file,
  the MIT text below applies.
- The macOS arm64 binaries were built by us from upstream source (scons, godot-cpp
  `godot-4.5-stable`, `compatibility_minimum = 4.4`) per `docs/plan.md` Phase 0; the other
  platform binaries are vendored from upstream.
- Web (`wasm32`) binaries were likewise built by us from upstream source
  (`97225bd`) with Emscripten 4.0.20 and godot-cpp branch `4.5`, single-precision
  and single-threaded — see `docs/web-build.md`.
- Vendored snapshot: upstream master at review time `97225bd` (2025-09-30, includes the
  reparenting fix); re-vendor in the Phase LAST engine upgrade (`docs/plan.md`).

## gdUnit4

- Location: `godot/addons/gdUnit4/`
- Source: https://github.com/MikeSchulze/gdUnit4
- License: MIT — Copyright (c) 2023 Mike Schulze
- Full text: `godot/addons/gdUnit4/LICENSE`

## Drag and Drop

- Location: `godot/addons/drag_and_drop/`
- Author: Cashew OldDew
- License: CC0 1.0 Universal (public domain dedication)
- Stated in `godot/addons/drag_and_drop/README.md`; the vendored copy does not
  include the license file it references.

## GDQuest — finite state machine

- Location: `godot/src/player/states/state.gd`, `godot/src/player/states/state_machine.gd`
- Adapted from GDQuest's finite state machine tutorial
- Source: https://school.gdquest.com/courses/godot_2d_secrets_godot_3/design_patterns/finite_state_machine
- License: MIT — Copyright (c) GDQuest, Nathan Lovato

## Godot Engine

- Not included in this repository; the project is built with Godot Engine 4.6.
- Source: https://godotengine.org
- License: MIT — Copyright (c) 2014-present Godot Engine contributors,
  Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

## MIT License

Applies to the components listed as MIT above, each under its own copyright
notice as stated in its section.

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
