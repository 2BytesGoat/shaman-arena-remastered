# Arena tile performance — what staggered, and what fixed it

The arena is one `TileMapLayer` that repaints its boundary every shrink step (16 px off the
horizontal semi-axis every 3 s). On the arcade web build (single-threaded WASM in Chromium on a
Tegra X1) that repaint staggered for **~0.5 s per step**. This is how the repaint works now and
why every piece of it is load-bearing. Cell counts below are measured from
`Arena.repaint_rows` (a throwaway `godot --headless --path godot -s …` script that prints the
plan's row/cell counts); frame timings still have to come from the cabinet (no frame-time harness
in-repo yet).

## Why a tile repaint is expensive here

Verified against the 4.6.3 sources (`scene/2d/tile_map_layer.cpp/.h`), because none of this is
obvious from GDScript:

- `set_cell` early-outs when the source/atlas/alternative did not change — but the GDScript
  loop, the call and the hash lookup are still paid. On WASM that dominates.
- **A dirty quadrant is rebuilt whole.** `_rendering_update_dirty_quadrants()` frees the
  quadrant's canvas items and re-emits *every* cell in it (after sorting the cells). One edited
  cell pays for up to `rendering_quadrant_size²` cells of work (default 16 → 256).
- **Y-sorting makes the quadrant a whole row.** With `y_sort_enabled` (which is what keeps the
  isometric tile overlaps right — turning it off breaks them, owner-verified) the quadrant key
  is the cell's Y (`quadrant_coords = canvas_items_position * 100`), so every row of the layer
  is one canvas item spanning the layer's full width. One edited cell therefore re-emits
  `field width` cells (117 at r=800), and `rendering_quadrant_size` is ignored in that mode.
- **Animated tiles multiply the commands.** Every liquid cell is animated (3 frames), so it
  emits one texture quad plus one `canvas_item_add_animation_slice()` per frame, and in
  `RANDOM_START_TIMES` mode also a per-cell `Array` hash + RNG at rebuild time.
- **Physics quadrants rebuild the same way.** A dirty physics quadrant (`physics_quadrant_size`,
  default 16) frees its body and re-merges every cell's collision polygons in it.

So the cost of a repaint is roughly `changed rows × field width` for rendering plus
`dirty physics quadrants × quadrant size²` for physics — not the number of cells that changed.
The old code made that worse by repainting the play area's whole bounding rectangle
(10 759 `set_cell` calls at r=800 for the ~630 cells that actually changed, screen-circle era).

## What was changed

1. **Ring-only plan — `Arena.repaint_rows()`.** The repaint is planned from the distance annulus
   that actually changes (`[min(radius), max(radius + edge)]`): only cells whose kind flips are
   queued, bucketed by row, so the drain has a natural unit of work. One step at r=800 changes
   **304 cells in 94 rows**; the bounding rectangle holds **5 459**.
2. **Frame-budgeted drain — `Arena.shrink_rows_per_frame` (12).** `shrink()` queues the plan and
   `_process` applies 12 rows per frame, so a step dirties ~12 row canvas items per frame
   (~1.4k cells re-emitted) instead of ~94 at once, and the ring catches up over ~0.1–0.3 s
   (invisible next to the 3 s step). The drain is idle — `set_process(false)` — whenever nothing
   is pending. `reset()` (between rounds, no burn waiting on it) and tests call `flush_repaint()`
   to apply the rest immediately; a `shrink()`/`reset()` landing mid-drain flushes first, so the
   painted state is always the last fully applied one.
3. **`physics_quadrant_size = 8`** on the arena (`arena.tscn`). A dirty physics quadrant re-merges
   all of its cells' polygons, so halving the quadrant size cuts that bill 4× against a modest
   growth in the field's total shape count. `4` is the next step if a cabinet run asks for it.
4. **The ellipse metric halved the work as a side effect.** The play area is the 2:1 iso ellipse
   (`SHAPE_SQUASH_SQ`), so the ring, the field and the physics field are half what the old
   screen circle needed: field 53 703 → **27 027** cells, painted once in `_ready()` and never
   repainted (the ring only ever touches its annulus).

What did *not* change: the shrink pacing (16 px per 3 s), the warning band and its tile
alternative, the burn (the liquid tiles' physics layer 32), and the whole public arena API
(`reset/shrink/start_shrink/stop_shrink/is_shrinking/radius_changed`).

## Guardrails

`tests/m5/test_arena.gd` pins the parts that are easy to break while "optimising":

- `test_repaint_plan_is_exactly_the_changed_ring` — the plan equals a brute-force scan of every
  changed cell (five scenarios, including the real r=800 step) and plans no cell twice. A missing
  cell leaves a stale tile; an extra one pays a whole row rebuild.
- `test_repaint_plan_touches_only_the_ring` — 200–600 cells at r=800 against the 5 459-cell
  rectangle; if this ever creeps back up the frame budget is pointless.
- `test_shrink_ring_drains_over_frames` / `test_shrink_ring_drains_from_the_frame_loop` — the
  drain is bounded and is driven by `_process`, not only by tests pumping it.
- `test_reset_while_draining_restores_the_exact_play_area` — a reset mid-drain applies the pending
  ring first and ends exactly on `classify`.
- `tests/phase0/test_layer_contract.gd` — the tile set stays iso/32×16, the liquid keeps its
  3-frame animation and its layer-32 diamond.

## Rejected: cutting the tiles to a smooth oval

A fragment mask (`godot/assets/shaders/arena_mask.gdshader`, parked and unreferenced) clipped the
floor art to the exact ellipse and the liquid to its outside, so the edge was perfectly smooth.
It worked (and the same trick could make the boundary cost nothing at all), but the cut slices the
water art into a dark, scalloped fringe along the shore, which read worse than the tiles' own
whole-diamond edge. Parked, not wired — it is the hook if a smooth overlay boundary is ever
wanted. (If it is revived: `MODEL_MATRIX` is a vertex-stage built-in for `canvas_item` shaders —
compute the arena-space position in `vertex()` and pass it through a varying.)

## Next levers if the cabinet still stutters

- `physics_quadrant_size = 4` on the arena (per-quadrant polygon merges again 4× cheaper).
- Trim `FIELD_MARGIN` or draw the far liquid as a repeating backdrop: the field paint is the
  remaining one-time load cost (27k cells + their shapes).
- The parked mask/overlay path above: with the visuals driven by a uniform and the burn by a
  distance query (an `Arena.is_liquid_at()` would have to be added, and the tile hazard retire),
  no cell would change during a round at all.
