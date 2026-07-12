--!nonstrict
-- Bunny — a cute bunny that lives in your bar.
--
-- Three states, each a looping/one-shot animation built from real frames:
--   idle   → default resting loop
--   sleep  → eyes closed, "z"s drifting up, looping
--   jump   → one-shot hop animation, then returns to whichever of
--            idle/sleep was active before the jump
--
--   left click   → toggle between idle and sleep
--   right click  → play the jump animation once
--
-- ── State assets ──────────────────────────────────────────────────────────
-- assets/states/manifest.json lists which state ids exist ("idle", "sleep",
-- "jump"). Each one has its own assets/states/<id>/ folder with a numbered
-- frame_NNN.png sequence plus a meta.json (frame_count, frame_delay_ms,
-- width, height). Frames are pre-rendered PNGs rather than a live GIF,
-- since Noctalia's widget image element only shows static images — this
-- script just "plays" the frame sequence back on a timer instead.
-- "idle" and "sleep" loop forever; "jump" is a one-shot sequence that plays
-- through once and then hands control back to whichever of idle/sleep was
-- active before it fired (see startJump()/update() below).

noctalia.setUpdateInterval(50) -- ms per tick; state delays are usually >= 70ms

-- ── Config ────────────────────────────────────────────────────────────────
local IMAGE_HEIGHT = tonumber(barWidget.getConfig("image_height")) or 32
local PLAYBACK_SPEED = tonumber(barWidget.getConfig("playback_speed")) or 1.0
if PLAYBACK_SPEED <= 0 then PLAYBACK_SPEED = 1.0 end

-- ── Load the manifest + per-state metadata ───────────────────────────────
local states = {} -- ordered array of { id, label, frame_count, frame_delay_ms, width, height }

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

local statesById = {}
for _, s in ipairs(states) do
  statesById[s.id] = s
end

-- ── Animation state ───────────────────────────────────────────────────────
-- moodId is the "resting" mood (idle or sleep) that's active whenever we're
-- not mid-jump. Jumping is a separate one-shot overlay: it plays through
-- once, then control returns to whichever mood was active before it fired.
local moodId = "idle"
local jumping = false
local frameIndex = 0
local frameElapsedMs = 0

local function framePath(state, index)
  return string.format("assets/states/%s/frame_%03d.png", state.id, index)
end

local function displaySize(state)
  -- Preserve each state's own aspect ratio instead of stretching it into a
  -- square, since idle/sleep/jump all have different canvas proportions.
  if state.width <= 0 or state.height <= 0 then
    return IMAGE_HEIGHT, IMAGE_HEIGHT
  end
  local height = IMAGE_HEIGHT
  local width = math.floor(height * (state.width / state.height) + 0.5)
  return width, height
end

local function activeState()
  if jumping and statesById["jump"] ~= nil then
    return statesById["jump"]
  end
  return statesById[moodId]
end

local function refreshTooltip()
  local state = activeState()
  if state == nil then
    barWidget.setTooltip("Bunny (no states found — see README.md)")
    return
  end
  if jumping then
    barWidget.setTooltip("Jump! — right click to jump again")
  elseif moodId == "sleep" then
    barWidget.setTooltip("Sleeping — left click to wake up, right click to jump")
  else
    barWidget.setTooltip("Idle — left click to sleep, right click to jump")
  end
end

local function render()
  local state = activeState()
  if state == nil then
    return
  end
  local w, h = displaySize(state)
  barWidget.setImage(framePath(state, frameIndex), false, w, h)
end

refreshTooltip()
render()

local function setMood(id)
  if statesById[id] == nil then
    return
  end
  moodId = id
  if not jumping then
    frameIndex = 0
    frameElapsedMs = 0
  end
  refreshTooltip()
  render()
end

local function startJump()
  if statesById["jump"] == nil then
    return
  end
  jumping = true
  frameIndex = 0
  frameElapsedMs = 0
  refreshTooltip()
  render()
end

function update()
  local state = activeState()
  if state == nil or state.frame_count <= 1 then
    return
  end

  local dt = 50 -- matches noctalia.setUpdateInterval above
  frameElapsedMs += dt

  local frameMs = (state.frame_delay_ms or 150) / PLAYBACK_SPEED
  if frameMs < 16 then frameMs = 16 end

  if frameElapsedMs >= frameMs then
    frameElapsedMs -= frameMs

    if jumping then
      frameIndex += 1
      if frameIndex >= state.frame_count then
        -- Jump's one-shot sequence finished — settle back into whichever
        -- mood (idle/sleep) was active before the jump.
        jumping = false
        frameIndex = 0
        refreshTooltip()
      end
    else
      frameIndex = (frameIndex + 1) % state.frame_count
    end

    render()
  end
end

function onClick()
  if jumping then
    return -- ignore mood toggles mid-jump
  end
  setMood(moodId == "idle" and "sleep" or "idle")
end

function onRightClick()
  startJump()
end

function onIpc(event, payload)
  if event == "wake" then
    setMood("idle")
  elseif event == "sleep" then
    setMood("sleep")
  elseif event == "toggle_mood" then
    if not jumping then
      setMood(moodId == "idle" and "sleep" or "idle")
    end
  elseif event == "jump" then
    startJump()
  elseif event == "set_state" and type(payload) == "string" then
    if payload == "jump" then
      startJump()
    else
      setMood(payload)
    end
  end
end
