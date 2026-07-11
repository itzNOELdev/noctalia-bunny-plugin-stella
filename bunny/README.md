# Bunny

Bunny adds a bar widget with a cute bunny that loops through moods — eating,
playing, sleeping, or whatever moods you've added — each one a small looping
animation built from a real GIF.

## Plugin

| Field | Value |
| --- | --- |
| ID | `stella/bunny` |
| Entry | Bar widget: `bunny` |

## Usage

Add the `bunny` widget to a bar from Noctalia's widget picker.

- **Left click** — move to the next mood (wraps back to the first).
- **Right click** — pause/resume the current animation.

Whichever mood is current just loops forever on its own — the bunny never
changes mood by itself, only when you click it.

No external tools or device permissions are required; it's a fully
self-contained, pre-rendered animation.

## Why GIFs aren't played directly

Noctalia's widget image APIs (`barWidget.setImage`, `ui.image`) only display
static images — there's no built-in "play this animated GIF" control. So each
source GIF is decomposed **once, at build time** into a numbered PNG frame
sequence plus a small timing file, and `bunny.luau` steps through those
frames on a timer at runtime. From the user's point of view it still just
looks like the GIF looping — the frame extraction is an invisible build step,
never something you do by hand per-launch.

## Adding a new mood

This is the entire process — no Luau code, no new settings, no manifest to
edit by hand:

1. Drop a GIF at `assets/source_gifs/<name>.gif` (the filename becomes the
   mood's internal id, e.g. `grooming.gif` → `grooming`).
2. From the plugin's repo root, run:
   ```sh
   python3 tools/build_states.py
   ```
   (needs Pillow: `pip install Pillow --break-system-packages`)
3. Reload the widget (or restart Noctalia).

The script extracts every frame of the GIF to
`assets/states/<name>/frame_NNN.png`, writes `assets/states/<name>/meta.json`
(frame count, average per-frame delay, and the GIF's pixel dimensions so its
aspect ratio is preserved in the bar), and regenerates
`assets/states/manifest.json` — the ordered list `bunny.luau` reads at load
time to know which moods exist and in what order to cycle them (alphabetical
by filename). Removing a GIF from `source_gifs/` and re-running the script
also removes its generated state automatically.

Want a nicer display name than the auto-generated Title Case of the
filename? Add an entry to the small `OVERRIDES` dict at the top of
`tools/build_states.py`, e.g.:
```python
OVERRIDES = {
    "eating": {"label": "Snack time"},
}
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `image_height` | int | 32 | Height of the bunny in the bar, in pixels. Width is derived per-mood from that mood's own GIF aspect ratio, so nothing gets stretched. |
| `playback_speed` | double | 1.0 | Multiplier applied to every mood's frame timing. |

## Runtime controls

```sh
noctalia msg plugin stella/bunny:bunny focused next
noctalia msg plugin stella/bunny:bunny focused pause
noctalia msg plugin stella/bunny:bunny focused resume
noctalia msg plugin stella/bunny:bunny focused toggle_pause
noctalia msg plugin stella/bunny:bunny focused set_state eating
```

## CREDITS

- Bunny GIFs supplied by the plugin author.
