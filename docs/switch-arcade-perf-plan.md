# Switch Arcade — Web Build Performance Plan

Improving the DIY arcade setup documented in
[GianiStatie/swtich-arcade](https://github.com/GianiStatie/swtich-arcade)
(RetroPie/L4T Linux brain, web builds served in Chromium kiosk, pulled from itch.io).

## Context & goals

- Contributors ship **one HTML5 zip** (Unity WebGL, Godot web, plain JS — engine-agnostic).
- Games run on the Switch's L4T Linux side in Chromium kiosk; contributors must **not**
  have to install toolchains, devkits, or export extra platforms.
- Goals: use the hardware (Tegra X1: 4× Cortex-A57 + Maxwell GPU) at full potential,
  keep the export process as easy as it is today (single HTML5 zip).

## Why "convert the HTML build to native" isn't a thing

A web build is not just WASM. It is WASM + the browser-side JS glue
(Emscripten runtime: WebGL context negotiation, FS shims, audio workers, etc.).
AOT-compiling the `.wasm` to ARM64 would still require re-implementing every
browser-side import the game calls — that's a browser, not a script. There is no
general-purpose HTML→native translator; the web build *is* the portable contract.

## Plan (implemented host-side in `switch-arcade`, zero changes for contributors)

All items must gracefully fall back to today's behavior if anything fails.

### 1. Full hardware unlock — `scripts/arcade-perf-mode.sh`

Already: nvpmodel + CPU governor to performance.
Add + verify (log results to a file, add to troubleshooting docs):

- GPU devfreq governor to `performance` / max freq (probe the actual devfreq path
  at runtime — differs per L4T build).
- EMC/memory clock maxed for the session.

### 2. Smart local server (COOP/COEP + caching)

Upgrade the per-game serving (extend `exit-server.py` or a companion server) to send:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- gzip/brotli content-encoding
- Range request support (big `.paks`), sensible cache headers

Effect: builds that ship **threaded WASM** (Unity with the threads option,
Godot 4.x web builds with threading enabled) actually spread across all 4 cores.
Zero contributor change required; costs ~40 lines.

Additional serving requirements discovered in research:

- Serve `.wasm` as **`application/wasm`** — a wrong MIME type disables V8's
  streaming/startup optimizations for WebAssembly (Godot docs note the same for
  web exports).
- Precompress at sync time (gzip/brotli sidecar files for Godot `.wasm`/`.pck`
  and Unity `.br` outputs) and send the matching `Content-Encoding` headers.
  itch.io does not compress on the fly, so local precompression is what makes
  both engines' big assets load fast — engine-agnostic, no contributor effort.
- Unity builds: support their Brotli/Gzip formats with Decompression Fallback
  off (contributors are instructed to disable fallback in the
  [contributor checklist](contributor-performance-checklist.md)).

### 3. Chromium launch tuning — `scripts/launch-web-game.sh`

Test/enable, keep flags that measure well:

- `--disable-gpu-vsync` (arcades don't care about tearing)
- Compare `--use-angle=gl` vs `--use-angle=gl-egl`
- Optional: `--canvas-oop-rasterization`
- Keep: `--disable-gpu-watchdog`, persistent `~/.cache/arcade/` profile/cache
- New: **per-game flag overrides** via `itch-games.yaml`
  (`chromium_flags: [...]` in the game's entry)
- `--autoplay-policy=no-user-gesture-required` — removes the "click to enable
  audio" splash screen requirement for every engine

### 4. Sync v2 + optional native tier — `scripts/sync-itch-games.sh`

The optional "build for the system" tier, done so nobody is forced to maintain it:

- For each game in `itch-games.yaml`, look for native upload uploads by naming
  convention via the existing itch API path:
  - `<slug>-linux-arm64.zip` (also try `aarch64` variant)
- If present → extract, `chmod +x`, generate an ES `.sh` entry that execs the
  binary directly (no browser involved; ES already allows `.sh` entries).
- If absent → today's web/Chromium path, unchanged.

Maintenance reality: the cabinets run **one** native target (Linux ARM64). Engine
support is built-in, not a matrix:

- **Godot 4**: "Linux ARM64" export preset, templates ship with the engine.
- **Unity 2021.2+**: "Linux ARM64 (IL2CPP)" target.
- **Plain JS/Phaser/anything else**: no native variant needed — web only.

Native games can call the exit server directly (fixes the Godot web QUIT-button
limitation) and Start+Select force-quit still works either way.

### 5. Cache warm-up — new `scripts/warmup-games.sh`

After each sync, auto-launch each new game once for ~30–45 s, then kill it:

- Pre-fills the shared **shader cache** (eliminates the mid-load stall players
  see on first launch) and the **V8/WASM code cache**.
- Must run on-screen (real GL; xvfb won't warm the Tegra driver) — treat as a
  maintenance-window step, documented.

### 6. Docs

Update `web-games-setup.md` / `README`:

- Optional native upload naming convention.
- Engine notes so single-zip contributors can opt into threads where supported
  (Unity Player Settings toggle, Godot web threading toggle).
- Mark items 1–3 as "do once per cabinet".

## Risks / to verify on hardware

- Exact GPU devfreq + EMC paths for the L4T build (probe at runtime).
- Whether itch upload naming metadata is enough to auto-detect native uploads.
- `--disable-gpu-vsync` stability; best ANGLE mode per engine.
- Godot/Unity threaded-WASM stability per engine version.

## Open

- Implementation in `switch-arcade` repo (scripts + config + deploy doc).
- Contributor-side guidance lives in
  [contributor-performance-checklist.md](contributor-performance-checklist.md) —
  a shareable, link-ready checklist for people exporting games
  (itch page blurb / link, covering the input contract, engine-specific export
  settings for Godot 4 and Unity, and the exit-endpoint pattern).