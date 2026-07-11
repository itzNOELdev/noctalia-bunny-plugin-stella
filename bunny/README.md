# Bunny

Bunny adds a bar widget with a cute pixel-art bunny that breathes, sways,
rests, and hops — a calmer, purely decorative cousin of Bongo Cat.

## Plugin

| Field | Value |
| --- | --- |
| ID | `stella/bunny` |
| Entry | Bar widget: `bunny` |

## Usage

Add the `bunny` widget to a bar from Noctalia's widget picker.

- **Left click** — pause the bunny (it sits down and rests) or wake it back up.
- **Right click** — make it hop immediately.

No external tools, permissions, or device access are required — the bunny is
fully self-contained pre-rendered sprite animation, driven purely by a timer.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `auto_hop` | `bool` | `true` | Let the bunny hop on its own every so often. |
| `hop_min_seconds` | `double` | `6` | Shortest time between automatic hops. |
| `hop_max_seconds` | `double` | `16` | Longest time between automatic hops. |
| `click_to_pause` | `bool` | `true` | Left click pauses/resumes the bunny. When off, left click hops instead. |
| `image_size` | `int` | `26` | Size (px) of the bunny sprite in the bar. |

## IPC

The widget accepts simple runtime controls:

```sh
noctalia msg plugin stella/bunny:bunny focused pause
noctalia msg plugin stella/bunny:bunny focused resume
noctalia msg plugin stella/bunny:bunny focused toggle
noctalia msg plugin stella/bunny:bunny focused hop
```

## Animation

The bunny cycles through short sequences of pre-rendered PNG frames:

- `idle` — gentle breathing sway while resting on the bar (default state).
- `sitting` — a settled, low pose used while paused.
- `jump` — a full hop arc (squash → launch → apex → land) triggered by the
  auto-hop timer or a right click.

The motion curves (squash/stretch scale, arc height, timing) were adapted from
a bongocat-style HTML/CSS reference animation and baked into the sprite
frames in `assets/`, so the widget itself only needs to step through images
on a timer — no runtime image transforms required.

## CREDITS

- Sprite and animation frames created for this plugin, with motion timing
  inspired by a bongocat-style bar-pet reference animation.
