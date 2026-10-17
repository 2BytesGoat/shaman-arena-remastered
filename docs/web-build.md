# Web (HTML5) build — why it failed and how it runs now

Verified 2026-10-17 with Godot **4.6.3** (Steam build, Windows): both a debug
and a release web export boot, load both GDExtensions and play in Chromium.

## Symptom

The exported page loaded, the engine booted, but the canvas stayed empty with
just the `VersionLabel` (`v0.3.0`) drawn. No visible error on the page; the
browser console (F12) showed the cause.

## Root cause

Everything gameplay-related comes from the two vendored GDExtensions
(`gameplay-abilities` → `Ability`, `RuntimeAbility`, `AbilityContainer`;
`gameplay-attributes` → `Attribute`, `AttributeSet`, `AttributeContainer`).
GDExtensions are native code and must be compiled per platform — and the web
export additionally needs the **Extensions Support** export option, because
the default web templates are built without GDExtension support:

```
ERROR: No GDExtension library found for current OS and architecture (web.wasm32)
       in configuration file: res://addons/gameplay-abilities/godot-gameplay-abilities.gdextension
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
```

Without those classes every gameplay script fails to parse and the main scene
cannot be instantiated:

```
SCRIPT ERROR: Parse Error: Could not find type "AttributeContainer" (res://src/player/player.gd:15)
ERROR: Scene instance is missing.
ERROR: Failed loading scene: res://main.tscn.
```

## What was changed

- `godot/export_presets.cfg`: `variant/extensions_support=true`
  (**Extensions Support** in the editor). Keep `variant/thread_support=false`.
- Both `.gdextension` files: added `web.wasm32.single.debug` and
  `web.wasm32.single.release` entries pointing at the new
  `web/*.nothreads.wasm` libraries.
- `godot/addons/*/web/`: web `wasm32` libraries, built by us (see below).

The web libraries must be **single precision** and **single-threaded** to match
the official `web_dlink_nothreads_*` templates; the build system encodes that in
the file name (`…web.template_debug.wasm32.nothreads.wasm`). The feature-tag keys
in `[libraries]` are matched by the engine (entry with the most matching tags
wins), so `web.wasm32.single.debug` only matches a matching engine build.

## Rebuilding the web libraries

Toolchain — versions matter, because Extensions Support uses WebAssembly
dynamic linking ("dlink") and the side module must match the engine template:

- **Emscripten 4.0.20** (`emsdk install 4.0.20 && emsdk activate 4.0.20`) — the
  version the official Godot 4.6.3 web templates were built with. See
  `Build configuration: Emscripten 4.0.20 …` in the browser console.
- **SCons 4.x** (`pip install scons`).
- **godot-cpp branch `4.5`** (`git clone -b 4.5 --depth 1
  https://github.com/godotengine/godot-cpp`), checked out inside each extension
  source tree as `godot-cpp/` (upstream pins the `4.4` branch via submodule; the
  vendored platform binaries were built against `godot-4.5-stable`).

```sh
# in the extension checkout (godot-cpp/ present)
scons target=template_debug   platform=web arch=wasm32 precision=single threads=no
scons target=template_release platform=web arch=wasm32 precision=single threads=no lto=none
```

Notes:

- Build **one extension at a time**. Two concurrent `-j12` release builds
  exhausted the 16 GB dev machine (`0xC0000017` = out of memory, then
  `0x40010004` process terminated). `-j6` plus `lto=none` is comfortable; SCons
  is incremental, so a killed build resumes.
- Products (copy into the matching `godot/addons/*/web/` directory):
  - GGA: `bin/web/godot-gameplay-abilities.web.template_{debug,release}.wasm32.nothreads.wasm`
  - GGAS: `bin/web/godot_gameplay_attributes.web.template_{debug,release}.wasm32.nothreads.wasm`
- Sources: upstream `OctoD/godot-gameplay-abilities@6d1ce71` and
  `OctoD/godot_gameplay_attributes@97225bd` (same snapshots as the vendored
  desktop binaries).

## Exporting

Editor: *Project → Export…*, preset **index.html (Web)**, keep *Extensions
Support* ticked, then **Export Project**. Headless equivalent:

```sh
godot --headless --path godot --export-debug   "index.html" builds/index.html
godot --headless --path godot --export-release "index.html" builds/index.html
```

`godot/builds/` is git-ignored. Even a release export is large: the dlink side
module is ~39 MB uncompressed (debug and release templates are close in size),
so enable server-side gzip/brotli compression when hosting — wasm compresses to
roughly a quarter.

## Running a build locally

The dlink web export is cross-origin isolated, so the server must send
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`. `file://` and plain
`python -m http.server` both fail (the page loads, the engine never starts).

```sh
python tools/serve_web.py          # serves godot/builds on http://127.0.0.1:8060
```

## Hosting

The same two headers are required by the host. Hosts that cannot set response
headers (e.g. itch.io) need **Progressive Web App > Enable** in the export
preset, which installs a service worker that simulates the headers — this is
also why `pwa/ensure_cross_origin_isolation_headers` should stay enabled.

## Known limitations

- Web exports always use the **Compatibility** (WebGL 2) renderer. Godot has no
  WebGPU support, so the project's Forward+ setting is silently downgraded; no
  setting change is needed (or possible).
- No threads (`variant/thread_support=false`), so audio uses the Web Audio
  "Sample" playback mode: no AudioEffects, reverb or doppler on web.
- Web libraries are vendored for **both** debug and release
  (`web.wasm32.single.debug` / `.release`). Upstream GGA only ships web debug
  binaries, so the release libraries come from our own build; re-run the recipe
  above when re-vendoring upstream.
- `godot/addons/gameplay-abilities/web/` also contains two older upstream wasm
  files (`*.template_debug.wasm32.wasm`, `*.double.*`). They were built with an
  older toolchain (Emscripten 3.1.62, Godot 4.4-era) and are not referenced by
  the `.gdextension` file anymore; left in place as the vendored snapshot.
