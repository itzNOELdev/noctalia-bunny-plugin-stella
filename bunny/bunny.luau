--!nonstrict
-- Bunny — a cute pixel bunny that lives in your bar.
--
-- The bunny breathes/sways while idle, hops on its own every so often
-- (configurable in the widget settings), and reacts to clicks:
--   left click   → pause/resume (the bunny sits down and rests when paused)
--   right click  → make it hop right now
--
-- Two sprite styles are bundled — pick one in the widget settings:
--   "pixel" (Bunny)  → chunky, low-res retro pixel art
--   "plus"  (Bunny+) → the same bunny, rendered smoother/higher-res
-- Both live under assets/<style>/ with identical animation/frame naming, so
-- switching styles is just a change of asset folder.
--
-- Optional reactive mode makes the bunny hop along with your keystrokes,
-- the same way the bongocat widget reacts to typing — reads configured
-- /dev/input devices with `evtest` via noctalia.runStream (no IPC, no
-- per-keystroke process spawn). Off by default; fully decorative otherwise.

noctalia.setUpdateInterval(60) -- ms per tick

-- ── Frame tables ──────────────────────────────────────────────────────────
-- Counts must match the number of PNGs actually rendered into each style's
-- assets/<style>/ folder.
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

-- ── Config ────────────────────────────────────────────────────────────────
local BUNNY_TYPE = barWidget.getConfig("bunny_type")
if BUNNY_TYPE ~= "pixel" and BUNNY_TYPE ~= "plus" then
  BUNNY_TYPE = "pixel"
end

local function framePath(anim, index)
  return string.format("assets/%s/%s_%02d.png", BUNNY_TYPE, anim, index)
end

local AUTO_HOP = barWidget.getConfig("auto_hop")
if AUTO_HOP == nil then AUTO_HOP = true end

local HOP_MIN = tonumber(barWidget.getConfig("hop_min_seconds")) or 6
local HOP_MAX = tonumber(barWidget.getConfig("hop_max_seconds")) or 16
if HOP_MAX < HOP_MIN then HOP_MAX = HOP_MIN end

local CLICK_TO_PAUSE = barWidget.getConfig("click_to_pause")
if CLICK_TO_PAUSE == nil then CLICK_TO_PAUSE = true end

local IMAGE_SIZE = tonumber(barWidget.getConfig("image_size")) or 26

local REACTIVE_MODE = barWidget.getConfig("reactive_mode") == true
local REACTIVE_COOLDOWN_MS = tonumber(barWidget.getConfig("reactive_cooldown_ms")) or 220
if REACTIVE_COOLDOWN_MS < 0 then REACTIVE_COOLDOWN_MS = 0 end

-- ── State ─────────────────────────────────────────────────────────────────
local ANIM_IDLE = "idle"
local ANIM_SITTING = "sitting"
local ANIM_JUMP = "jump"

local currentAnim = ANIM_IDLE
local frameIndex = 0
local frameElapsedMs = 0
local paused = false
local jumping = false
local reactiveCooldownMs = 0

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
  elseif REACTIVE_MODE then
    barWidget.setTooltip("Bunny — hops as you type. Click to pause, right-click to hop")
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

-- A lighter hop trigger for reactive/typing mode: respects a short cooldown
-- so a burst of keystrokes doesn't spam restart the jump animation.
local function reactiveHop()
  if paused or not REACTIVE_MODE then return end
  if reactiveCooldownMs > 0 then return end
  reactiveCooldownMs = REACTIVE_COOLDOWN_MS
  startJump()
  render()
end

function update()
  local dt = 60 -- matches noctalia.setUpdateInterval above

  if reactiveCooldownMs > 0 then
    reactiveCooldownMs = math.max(0, reactiveCooldownMs - dt)
  end

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

  -- Auto-hop scheduling (only while idle/resting, not mid-jump). Disabled
  -- automatically when reactive mode is on, since typing already drives hops.
  if AUTO_HOP and not REACTIVE_MODE and not jumping then
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

-- ── Reactive mode: hop along with keystrokes ─────────────────────────────
-- Mirrors the bongocat widget's input reader: a single long-lived `evtest`
-- stream per configured device, parsed line by line. No permissions beyond
-- read access to the chosen /dev/input device(s) and `evtest` on PATH.
if REACTIVE_MODE then
  local function has(line, needle)
    return line:find(needle, 1, true) ~= nil
  end

  local function onEvtestLine(line)
    -- evtest prints one line per event, e.g.:
    --   Event: time 1700.0, type 1 (EV_KEY), code 57 (KEY_SPACE), value 1
    if not has(line, "EV_KEY") or has(line, "BTN_TOOL_") then
      return
    end
    if has(line, "value 1") then
      reactiveHop()
    end
  end

  local function isAllowedInputPatternByte(byte)
    return (byte >= 48 and byte <= 57) -- 0-9
        or (byte >= 65 and byte <= 90) -- A-Z
        or (byte >= 97 and byte <= 122) -- a-z
        or byte == 47 -- /
        or byte == 46 -- .
        or byte == 95 -- _
        or byte == 45 -- -
        or byte == 58 -- :
        or byte == 43 -- +
        or byte == 42 -- *
        or byte == 63 -- ?
        or byte == 91 -- [
        or byte == 93 -- ]
  end

  local function isSupportedInputPattern(pattern)
    return pattern:match("^/dev/input/event") ~= nil
        or pattern:match("^/dev/input/by%-id/") ~= nil
        or pattern:match("^/dev/input/by%-path/") ~= nil
  end

  local function validateInputPattern(pattern)
    if type(pattern) ~= "string" or pattern == "" then
      return false
    end
    if pattern:find("..", 1, true) ~= nil or not isSupportedInputPattern(pattern) then
      return false
    end
    for i = 1, #pattern do
      if not isAllowedInputPatternByte(pattern:byte(i)) then
        return false
      end
    end
    return true
  end

  local function startInputReader()
    local devices = barWidget.getConfig("input_devices")
    if devices == nil then
      noctalia.notify("Bunny", "Reactive mode is on but no input_devices are configured yet.")
      return
    end
    if type(devices) ~= "table" then
      noctalia.notifyError("Bunny", "Invalid input_devices (expected a list of /dev/input paths or globs)")
      return
    end

    local patterns = {}
    local seen = {}
    local warnedEventPath = false
    for _, pattern in ipairs(devices) do
      if not validateInputPattern(pattern) then
        noctalia.notifyError("Bunny", `Invalid input_devices entry: {tostring(pattern)}`)
        return
      end
      if pattern:match("^/dev/input/event") ~= nil and not warnedEventPath then
        warnedEventPath = true
        noctalia.notify("Bunny", "Prefer /dev/input/by-id or /dev/input/by-path; /dev/input/eventN can change.")
      end
      if seen[pattern] == nil then
        seen[pattern] = true
        table.insert(patterns, pattern)
      end
    end
    if #patterns == 0 then
      return
    end

    local executable = barWidget.getConfig("executable_path")
    if executable == nil or executable == "" then
      executable = "evtest"
    end

    if not noctalia.commandExists(executable) then
      noctalia.notifyError("Bunny", "the evtest path is invalid (" .. executable .. ") — cannot read input devices")
      return
    end

    -- single-quote for the shell so paths with spaces or metacharacters are safe
    local quotedExecutable = "'" .. executable:gsub("'", "'\''") .. "'"

    local command = "for device in " .. table.concat(patterns, " ")
      .. '; do [ -e "$device" ] || continue; ' .. quotedExecutable
      .. ' "$device" 2>/dev/null & done; wait'

    if not noctalia.runStream(command, onEvtestLine) then
      noctalia.notifyError("Bunny", "Unable to start input device reader")
    end
  end

  startInputReader()
end
