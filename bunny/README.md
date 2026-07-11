# Bunny

Bunny adds a bar widget with a cute pixel-art bunny that breathes, sways,
rests, and hops — a calmer, purely decorative cousin of Bongo Cat. It can
also be switched into a reactive mode that hops along with your typing.

## Plugin

| Field | Value |
| --- | --- |
| ID | `stella/bunny` |
| Entry | Bar widget: `bunny` |

## Usage

Add the `bunny` widget to a bar from Noctalia's widget picker.

- **Left click** — pause the bunny (it sits down and rests) or wake it back up.
- **Right click** — make it hop immediately.

By default no external tools, permissions, or device access are required —
the bunny is a fully self-contained pre-rendered sprite animation, driven
purely by a timer. Reactive mode (off by default) opts in to reading a
keyboard device, see [Reactive mode](#reactive-mode) below.

## Bunny styles

Pick a look in the widget settings (`bunny_type`):

- **Bunny** (`pixel`) — chunky, low-resolution retro pixel art.
- **Bunny+** (`plus`) — the exact same bunny and animations, rendered
  smoother and at a higher effective resolution.

Both styles ship the same three animations and frame counts, so switching
between them mid-use doesn't change timing or behavior — only how pixelated
the sprite looks.

## Reactive mode

Turn on `reactive_mode` to make the bunny hop each time you press a key,
instead of hopping on a random timer. It reuses the same input-reading
approach as the Bongo Cat widget:

- Requires `evtest` on `PATH` (or a custom path via `executable_path`).
- Requires at least one device configured in `input_devices`, using stable
  `/dev/input/by-id/` or `/dev/input/by-path/` entries where possible —
  `/dev/input/eventN` names can change after device or kernel updates.
- Requires read permission on the selected device(s), typically by adding
  your user to the `input` group and logging in again.
- A short cooldown (`reactive_cooldown_ms`, default 220ms) prevents fast
  typing from spamming the jump animation back-to-back.

When `reactive_mode` is on, the automatic random-timer hopping (`auto_hop`)
is disabled, since typing already drives the bunny. Left click / right
click / IPC controls keep working exactly as before.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `bunny_type` | `select` | `pixel` | Sprite style: `pixel` (Bunny) or `plus` (Bunny+). |
| `auto_hop` | `bool` | `true` | Let the bunny hop on its own every so often. Hidden while reactive mode is on. |
| `hop_min_seconds` | `double` | `6` | Shortest time between automatic hops. |
| `hop_max_seconds` | `double` | `16` | Longest time between automatic hops. |
| `click_to_pause` | `bool` | `true` | Left click pauses/resumes the bunny. When off, left click hops instead. |
| `image_size` | `int` | `26` | Size (px) of the bunny sprite in the bar. |
| `reactive_mode` | `bool` | `false` | Hop along with keystrokes instead of a random timer. |
| `reactive_cooldown_ms` | `int` | `220` | Minimum time between typing-triggered hops. |
| `input_devices` | `string_list` | `[]` | Keyboard device paths/globs read with `evtest`. Required for reactive mode. |
| `executable_path` | `file` | `evtest` | Path to the input reader executable. |

## IPC

The widget accepts simple runtime controls:

```sh
noctalia msg plugin stella/bunny:bunny focused pause
noctalia msg plugin stella/bunny:bunny focused resume
noctalia msg plugin stella/bunny:bunny focused toggle
noctalia msg plugin stella/bunny:bunny focused hop
```

## Animation

The bunny cycles through short sequences of pre-rendered PNG frames, kept in
sync across both styles:

- `idle` — gentle breathing sway while resting on the bar (default state).
- `sitting` — a settled, low pose used while paused.
- `jump` — a full hop arc (crouch → launch → apex → land → settle) triggered
  by the auto-hop timer, a keystroke in reactive mode, or a right click.

Each style's frames live in its own folder (`assets/pixel/`, `assets/plus/`)
with identical animation names and frame counts, so the widget only needs to
pick a folder and step through images on a timer — no runtime image
transforms required.

## CREDITS

- Sprite and animation frames created for this plugin.
- Reactive-mode input reading adapted from the Bongo Cat widget's `evtest`
  stream reader pattern.
