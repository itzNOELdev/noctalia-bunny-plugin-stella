--!nonstrict
-- Bunny — a cute bunny that lives in your bar and cycles through moods.
--
-- Each "state" (eating, playing, sleeping, ...) is a looping animation built
-- from a real GIF. The bunny sits on whichever state is current and just
-- loops it forever — it only changes state when you click it:
--   left click   → advance to the next state (wraps back to the first)
--   right click  → pause/resume the current animation
--
-- ── Adding a new state ────────────────────────────────────────────────────
-- This script has NO hardcoded list of states — it reads
-- assets/states/manifest.json at load time and cycles through whatever is
-- listed there. To add a new mood:
--   1. Drop a GIF at assets/source_gifs/<name>.gif
--   2. Run `python3 tools/build_states.py` from the plugin's repo root
--   3. Reload the widget
-- That script decomposes the GIF into a numbered PNG frame sequence plus a
-- small meta.json (frame count + timing), and regenerates manifest.json.
-- No changes to this file are ever needed. (Why not just play the GIF file
-- directly? Noctalia's widget image element only shows static images — see
-- README.md for details — so the frames are pre-extracted once at build
-- time and this script "plays" them back on a timer instead.)

noctalia.setUpdateInterval(50) -- ms per tick; state delays are usually >= 70ms

-- ── Config ────────────────────────────────────────────────────────────────
local IMAGE_HEIGHT = tonumber(barWidget.getConfig("image_height")) or 32
local PLAYBACK_SPEED = tonumber(barWidget.getConfig("playback_speed")) or 1.0
if PLAYBACK_SPEED <= 0 then PLAYBACK_SPEED = 1.0 end

-- ── Load the manifest + per-state metadata ───────────────────────────────
local states = {} -- ordered array of { id, label, frame_count, frame_delay_ms, width, height }
local stateIndex = 1

local function loadStates()
  local manifestText, err = noctalia.readFile("assets/states/manifest.json")
  if manifestText == nil then
    noctalia.notifyError("Bunny", "Could not read assets/states/manifest.json: " .. tostring(err))
    return
  end

  local manifest = noctalia.json.decode(manifestText)
  if type(manifest) ~= "table" or type(manifest.states) ~= "table" then
    noctalia.notifyError("Bunny", "assets/states/manifest.json is malformed")
    return
  end

  for _, id in ipairs(manifest.states) do
    local metaText = noctalia.readFile(string.format("assets/states/%s/meta.json", id))
    if metaText ~= nil then
      local meta = noctalia.json.decode(metaText)
      if type(meta) == "table" and type(meta.frame_count) == "number" then
        table.insert(states, {
          id = id,
          label = meta.label or id,
          frame_count = meta.frame_count,
          frame_delay_ms = meta.frame_delay_ms or 150,
          width = meta.width or 0,
          height = meta.height or 0,
        })
      end
    end
  end
end

loadStates()

-- ── Animation state ───────────────────────────────────────────────────────
local frameIndex = 0
local frameElapsedMs = 0
local paused = false

local function currentState()
  return states[stateIndex]
end

local function framePath(state, index)
  return string.format("assets/states/%s/frame_%03d.png", state.id, index)
end

local function displaySize(state)
  -- Preserve the GIF's own aspect ratio instead of stretching it into a
  -- square, since states can come from GIFs of very different proportions.
  if state.width <= 0 or state.height <= 0 then
    return IMAGE_HEIGHT, IMAGE_HEIGHT
  end
  local height = IMAGE_HEIGHT
  local width = math.floor(height * (state.width / state.height) + 0.5)
  return width, height
end

local function refreshTooltip()
  local state = currentState()
  if state == nil then
    barWidget.setTooltip("Bunny (no states found — see README.md)")
    return
  end
  if paused then
    barWidget.setTooltip(state.label .. " — paused. Right click to resume, left click to change mood")
  else
    barWidget.setTooltip(state.label .. " — left click to change mood, right click to pause")
  end
end

local function render()
  local state = currentState()
  if state == nil then
    return
  end
  local w, h = displaySize(state)
  barWidget.setImage(framePath(state, frameIndex), false, w, h)
end

refreshTooltip()
render()

local function setState(index)
  local count = #states
  if count == 0 then
    return
  end
  stateIndex = ((index - 1) % count) + 1
  frameIndex = 0
  frameElapsedMs = 0
  refreshTooltip()
  render()
end

function update()
  if paused or #states == 0 then
    return
  end

  local state = currentState()
  if state == nil or state.frame_count <= 1 then
    return
  end

  local dt = 50 -- matches noctalia.setUpdateInterval above
  frameElapsedMs += dt

  local frameMs = (state.frame_delay_ms or 150) / PLAYBACK_SPEED
  if frameMs < 16 then frameMs = 16 end

  if frameElapsedMs >= frameMs then
    frameElapsedMs -= frameMs
    frameIndex = (frameIndex + 1) % state.frame_count
    render()
  end
end

function onClick()
  setState(stateIndex + 1)
end

function onRightClick()
  paused = not paused
  refreshTooltip()
end

function onIpc(event, payload)
  if event == "next" then
    setState(stateIndex + 1)
  elseif event == "pause" then
    paused = true
    refreshTooltip()
  elseif event == "resume" then
    paused = false
    refreshTooltip()
  elseif event == "toggle_pause" then
    paused = not paused
    refreshTooltip()
  elseif event == "set_state" and type(payload) == "string" then
    for i, state in ipairs(states) do
      if state.id == payload then
        setState(i)
        break
      end
    end
  end
end
