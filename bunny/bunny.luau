--!nonstrict
-- Bunny — a cute pixel bunny that lives in your bar.
--
-- The bunny breathes/sways while idle, hops on its own every so often
-- (configurable in the widget settings), and reacts to clicks:
--   left click   → pause/resume (the bunny sits down and rests when paused)
--   right click  → make it hop right now
--
-- Frames were rendered offline (see assets/) from the same jump/settle/breathe
-- motion curves as the reference bongocat-style bar pet, applied to a small
-- pixel-art bunny sprite instead of a font. Each animation is a short list of
-- pre-rendered PNGs; update() just steps through them on a timer, the same
-- way bongocat steps through font glyphs.

noctalia.setUpdateInterval(60) -- ms per tick

-- ── Frame tables ──────────────────────────────────────────────────────────
-- Counts must match the number of PNGs actually rendered into assets/.
local FRAME_COUNTS = {
  idle = 14,
  sitting = 12,
  jump = 16,
}

-- How long each frame of a given animation is shown, in ms. Chosen so the
-- full loop roughly matches the source motion's timing (idle ~2.6s,
-- sitting ~2.4s, jump ~1.1s).
local FRAME_MS = {
  idle = 190,
  sitting = 200,
  jump = 70,
}

local function framePath(anim, index)
  return string.format("assets/%s_%02d.png", anim, index)
end

-- ── Config ────────────────────────────────────────────────────────────────
local AUTO_HOP = barWidget.getConfig("auto_hop")
if AUTO_HOP == nil then AUTO_HOP = true end

local HOP_MIN = tonumber(barWidget.getConfig("hop_min_seconds")) or 6
local HOP_MAX = tonumber(barWidget.getConfig("hop_max_seconds")) or 16
if HOP_MAX < HOP_MIN then HOP_MAX = HOP_MIN end

local CLICK_TO_PAUSE = barWidget.getConfig("click_to_pause")
if CLICK_TO_PAUSE == nil then CLICK_TO_PAUSE = true end

local IMAGE_SIZE = tonumber(barWidget.getConfig("image_size")) or 26

-- ── State ─────────────────────────────────────────────────────────────────
local ANIM_IDLE = "idle"
local ANIM_SITTING = "sitting"
local ANIM_JUMP = "jump"

local currentAnim = ANIM_IDLE
local frameIndex = 0
local frameElapsedMs = 0
local paused = false
local jumping = false

local function randomHopDelaySeconds()
  return HOP_MIN + math.random() * (HOP_MAX - HOP_MIN)
end

local hopTimerMs = 0
local nextHopInMs = randomHopDelaySeconds() * 1000

local function restingAnim()
  return paused and ANIM_SITTING or ANIM_IDLE
end

local function setAnim(anim)
  if currentAnim ~= anim then
    currentAnim = anim
    frameIndex = 0
    frameElapsedMs = 0
  end
end

local function render()
  barWidget.setImage(framePath(currentAnim, frameIndex), false, IMAGE_SIZE, IMAGE_SIZE)
end

local function refreshTooltip()
  if paused then
    barWidget.setTooltip("Bunny is resting — click to wake it up")
  else
    barWidget.setTooltip("Bunny — click to pause, right-click to make it hop")
  end
end

refreshTooltip()
render()

local function startJump()
  if paused then return end
  jumping = true
  setAnim(ANIM_JUMP)
  hopTimerMs = 0
  nextHopInMs = randomHopDelaySeconds() * 1000
end

function update()
  local dt = 60 -- matches noctalia.setUpdateInterval above

  if paused then
    -- Still animate the sitting pose gently while paused.
    frameElapsedMs += dt
    local ms = FRAME_MS[currentAnim] or 150
    if frameElapsedMs >= ms then
      frameElapsedMs -= ms
      frameIndex = (frameIndex + 1) % FRAME_COUNTS[currentAnim]
      render()
    end
    return
  end

  -- Auto-hop scheduling (only while idle/resting, not mid-jump).
  if AUTO_HOP and not jumping then
    hopTimerMs += dt
    if hopTimerMs >= nextHopInMs then
      startJump()
    end
  end

  -- Advance the current animation.
  frameElapsedMs += dt
  local ms = FRAME_MS[currentAnim] or 150
  if frameElapsedMs >= ms then
    frameElapsedMs -= ms
    frameIndex += 1

    local count = FRAME_COUNTS[currentAnim]
    if frameIndex >= count then
      if currentAnim == ANIM_JUMP then
        -- Landed: go back to idle/resting.
        jumping = false
        setAnim(restingAnim())
      else
        frameIndex = 0
      end
    end
    render()
  end
end

function onClick()
  if not CLICK_TO_PAUSE then
    -- Clicking still makes it hop when pause-on-click is disabled.
    startJump()
    render()
    return
  end

  paused = not paused
  jumping = false
  setAnim(restingAnim())
  refreshTooltip()
  render()
end

function onRightClick()
  startJump()
  render()
end

function onIpc(event, payload)
  if event == "pause" then
    paused = true
    jumping = false
    setAnim(ANIM_SITTING)
    refreshTooltip()
    render()
  elseif event == "resume" then
    paused = false
    jumping = false
    setAnim(ANIM_IDLE)
    refreshTooltip()
    render()
  elseif event == "toggle" then
    onClick()
  elseif event == "hop" then
    startJump()
    render()
  end
end
