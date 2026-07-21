-- outloud — read any selected text aloud, in any app · https://github.com/EloiGils/outloud
--
--   ⌥⌘L read selection · ⌥⌘K stop · ⌥⌘H search history
--   Floating HUD: − speed + · ⏸ exact pause · 🔁 replay · ✕ close
--   🔊 menu bar icon: recent readings, search, and settings
--
-- Install: copy to ~/.hammerspoon/outloud.lua and add require("outloud") to init.lua

-- ============================== configuration ==============================

local OUTLOUD = "/opt/homebrew/bin/outloud"
if not hs.fs.attributes(OUTLOUD) then OUTLOUD = "/usr/local/bin/outloud" end

local HOTKEY_READ = { { "cmd", "alt" }, "l" }
local HOTKEY_STOP = { { "cmd", "alt" }, "k" }
local HOTKEY_HISTORY = { { "cmd", "alt" }, "h" }

-- language/voice options shown in the menu bar (Kokoro voices)
local VOICE_MENU = {
  { label = "Español · Dora",        lang = "e", voice = "ef_dora" },
  { label = "Español · Alex",        lang = "e", voice = "em_alex" },
  { label = "Español · Santa",       lang = "e", voice = "em_santa" },
  { label = "English (US) · Heart",  lang = "a", voice = "af_heart" },
  { label = "English (US) · Adam",   lang = "a", voice = "am_adam" },
  { label = "English (UK) · Emma",   lang = "b", voice = "bf_emma" },
  { label = "Français · Siwis",      lang = "f", voice = "ff_siwis" },
  { label = "Italiano · Sara",       lang = "i", voice = "if_sara" },
  { label = "Italiano · Nicola",     lang = "i", voice = "im_nicola" },
  { label = "Português · Dora",      lang = "p", voice = "pf_dora" },
  { label = "हिन्दी · Alpha",          lang = "h", voice = "hf_alpha" },
}

-- =============================== i18n =====================================

local es = tostring(hs.host.locale.current()):sub(1, 2) == "es"
local T = {
  no_selection = es and "No hay texto seleccionado" or "No text selected",
  reading = es and "Leyendo…" or "Reading…",
  no_readings = es and "Sin lecturas todavía" or "No readings yet",
  search = es and "Buscar en historial…" or "Search history…",
  search_ph = es and "Buscar en el historial de lecturas…" or "Search your reading history…",
  stop = es and "Parar lectura" or "Stop reading",
  speed = es and "Velocidad" or "Speed",
  voice = es and "Voz" or "Voice",
  chars = es and "caracteres" or "characters",
  ready = es and "outloud listo: ⌥⌘L lee · ⌥⌘K para · ⌥⌘H historial"
             or "outloud ready: ⌥⌘L read · ⌥⌘K stop · ⌥⌘H history",
}

-- ============================== state ======================================

local HIST = os.getenv("HOME") .. "/Library/Application Support/Outloud/history.jsonl"

local readTask = nil
local paused = false
local hud = nil

-- persisted settings (migrates from the pre-release "lector.*" keys if present)
local speed = hs.settings.get("outloud.speed") or hs.settings.get("aloud.speed") or hs.settings.get("lector.velocidad") or 1.3
local lang = hs.settings.get("outloud.lang") or hs.settings.get("aloud.lang") or hs.settings.get("lector.idioma") or "a"
local voice = hs.settings.get("outloud.voice") or hs.settings.get("aloud.voice") or hs.settings.get("lector.voz") or nil

local EL_STATUS, EL_SPEED, EL_PAUSE = 2, 3, 4

-- ============================ helpers ======================================

local function excerpt(text, n)
  text = text:gsub("%s+", " ")
  local cut = utf8.offset(text, n + 1)
  if cut then return text:sub(1, cut - 1) .. "…" end
  return text
end

local function history(n)
  local f = io.open(HIST, "r")
  if not f then return {} end
  local lines = {}
  for line in f:lines() do table.insert(lines, line) end
  f:close()
  local entries = {}
  for i = #lines, math.max(1, #lines - n + 1), -1 do
    local ok, e = pcall(hs.json.decode, lines[i])
    if ok and e and e.text then table.insert(entries, e) end
  end
  return entries
end

local function shortDate(iso) -- "2026-07-21T15:30:12" → "21/07 15:30"
  local m, d, hh, mm = iso:match("%d+-(%d+)-(%d+)T(%d+):(%d+)")
  if not m then return iso end
  return d .. "/" .. m .. " " .. hh .. ":" .. mm
end

-- =============================== HUD =======================================

local function closeHUD()
  if hud then
    hud:delete()
    hud = nil
  end
end

local function outloudCmd(...)
  hs.task.new(OUTLOUD, nil, { ... }):start()
end

local function stopReading()
  paused = false
  if readTask then
    readTask:terminate()
    readTask = nil
  end
  outloudCmd("--stop")
  closeHUD()
end

-- set speed (0.5-3.0): applies live, persists, refreshes the HUD
local function setSpeed(v)
  speed = math.max(0.5, math.min(3.0, math.floor(v * 4 + 0.5) / 4))
  hs.settings.set("outloud.speed", speed)
  outloudCmd("--speed-live", tostring(speed))
  if hud then hud[EL_SPEED].text = tostring(speed) .. "×" end
end

local function nudgeSpeed(delta)
  setSpeed(speed + delta)
end

local function showHUD(text)
  closeHUD()
  local f = hs.screen.mainScreen():frame()
  local w, h = 400, 46
  hud = hs.canvas.new({ x = f.x + (f.w - w) / 2, y = f.y + 10, w = w, h = h })
  hud[1] = { type = "rectangle", action = "fill",
             fillColor = { red = 0.09, green = 0.09, blue = 0.11, alpha = 0.93 },
             roundedRectRadii = { xRadius = 14, yRadius = 14 } }
  hud[EL_STATUS] = { type = "text", text = "🔊 " .. excerpt(text, 20), textSize = 13,
                     textColor = { white = 1, alpha = 0.9 },
                     frame = { x = 16, y = 14, w = 180, h = 20 } }
  hud[EL_SPEED] = { id = "vel", type = "text", text = tostring(speed) .. "×", textSize = 12,
                    textColor = { white = 1, alpha = 0.95 }, textAlignment = "center",
                    frame = { x = 222, y = 15, w = 48, h = 20 } }
  hud[EL_PAUSE] = { id = "pause", type = "text", text = "⏸", textSize = 17,
                    frame = { x = 304, y = 11, w = 28, h = 26 }, trackMouseDown = true }
  hud[5] = { id = "replay", type = "text", text = "🔁", textSize = 15,
             frame = { x = 336, y = 12, w = 28, h = 26 }, trackMouseDown = true }
  hud[6] = { id = "minus", type = "text", text = "−", textSize = 17,
             textColor = { white = 1, alpha = 0.85 }, textAlignment = "center",
             frame = { x = 198, y = 11, w = 24, h = 26 }, trackMouseDown = true }
  hud[7] = { id = "plus", type = "text", text = "+", textSize = 17,
             textColor = { white = 1, alpha = 0.85 }, textAlignment = "center",
             frame = { x = 270, y = 11, w = 24, h = 26 }, trackMouseDown = true }
  hud[8] = { id = "close", type = "text", text = "✕", textSize = 15,
             textColor = { white = 1, alpha = 0.7 },
             frame = { x = 368, y = 12, w = 22, h = 26 }, trackMouseDown = true }
  hud:mouseCallback(function(_, event, id)
    if event ~= "mouseDown" then return end
    if id == "minus" then
      nudgeSpeed(-0.25)
    elseif id == "plus" then
      nudgeSpeed(0.25)
    elseif id == "pause" then
      if paused then
        outloudCmd("--resume")
        paused = false
        hud[EL_PAUSE].text = "⏸"
      else
        outloudCmd("--pause")
        paused = true
        hud[EL_PAUSE].text = "▶"
      end
    elseif id == "replay" then
      outloudCmd("--replay")
      paused = false
      hud[EL_PAUSE].text = "⏸"
    elseif id == "close" then
      stopReading()
    end
  end)
  hud:level(hs.canvas.windowLevels.overlay)
  hud:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  hud:clickActivating(false)
  hud:show()
end

-- launch outloud with args, managing the HUD and the active task
local function launch(args, hudText)
  paused = false
  if readTask then
    readTask:terminate()
    readTask = nil
  end
  local t
  t = hs.task.new(OUTLOUD, function()
    -- only close the HUD if this task is still the active one
    if readTask == t then
      closeHUD()
      readTask = nil
    end
  end, args)
  readTask = t
  t:start()
  showHUD(hudText)
end

local function startReading(text)
  local args = { "-s", tostring(speed), "-l", lang }
  if voice then
    table.insert(args, "--voice"); table.insert(args, voice)
  end
  table.insert(args, text)
  launch(args, text)
end

local function rereadEntry(e)
  launch({ "--reread", e.id, "-s", tostring(speed) }, e.text)
end

-- ======================= selection capture =================================

-- capture via simulated Cmd+C, restoring the clipboard afterwards
local function captureWithCmdC(callback)
  local prev = hs.pasteboard.getContents()
  local cc = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  hs.timer.doAfter(0.25, function()
    if hs.pasteboard.changeCount() == cc then
      hs.alert.show(T.no_selection, 1.2)
      return
    end
    local text = hs.pasteboard.getContents()
    hs.timer.doAfter(0.15, function()
      if prev then hs.pasteboard.setContents(prev) end
    end)
    if text and text ~= "" then callback(text) end
  end)
end

local function captureSelection(callback)
  -- iTerm blocks synthetic keystrokes (Secure Keyboard Entry) but copies the
  -- selection to the clipboard automatically: read it directly
  local app = hs.application.frontmostApplication()
  if app and app:bundleID() == "com.googlecode.iterm2" then
    local text = hs.pasteboard.getContents()
    if text and text ~= "" then
      callback(text)
    else
      hs.alert.show(T.no_selection, 1.2)
    end
    return
  end
  -- other apps: try Accessibility first (doesn't touch the clipboard)
  local ok, el = pcall(hs.uielement.focusedElement)
  if ok and el then
    local ok2, sel = pcall(function() return el:selectedText() end)
    if ok2 and sel and sel ~= "" then
      callback(sel)
      return
    end
  end
  captureWithCmdC(callback)
end

-- ======================= history search (⌥⌘H) ==============================

local chooser = hs.chooser.new(function(item)
  if item then rereadEntry(item.entry) end
end)
chooser:placeholderText(T.search_ph)

local function showChooser()
  local choices = {}
  for _, e in ipairs(history(300)) do
    table.insert(choices, {
      text = excerpt(e.text, 60),
      subText = shortDate(e.date) .. "  ·  " .. utf8.len(e.text) .. " " .. T.chars,
      entry = e,
    })
  end
  chooser:choices(choices)
  chooser:show()
end

-- =========================== menu bar ======================================

local bar = hs.menubar.new()
bar:setTitle("🔊")

local function buildMenu()
  local menu = {}
  local recent = history(10)
  if #recent == 0 then
    table.insert(menu, { title = T.no_readings, disabled = true })
  else
    for _, e in ipairs(recent) do
      table.insert(menu, {
        title = shortDate(e.date) .. "  ·  " .. excerpt(e.text, 40),
        fn = function() rereadEntry(e) end,
      })
    end
  end
  table.insert(menu, { title = "-" })
  table.insert(menu, { title = T.search .. "      ⌥⌘H", fn = showChooser })
  table.insert(menu, { title = T.stop .. "      ⌥⌘K", fn = stopReading })
  table.insert(menu, { title = "-" })
  local speedMenu = {}
  for _, v in ipairs({ 1.0, 1.25, 1.5, 1.75, 2.0, 2.5 }) do
    table.insert(speedMenu, {
      title = tostring(v) .. "×",
      checked = v == speed,
      fn = function() setSpeed(v) end,
    })
  end
  local voiceMenu = {}
  for _, opt in ipairs(VOICE_MENU) do
    table.insert(voiceMenu, {
      title = opt.label,
      checked = opt.voice == voice or (voice == nil and opt.lang == lang and opt == VOICE_MENU[1]),
      fn = function()
        lang, voice = opt.lang, opt.voice
        hs.settings.set("outloud.lang", lang)
        hs.settings.set("outloud.voice", voice)
      end,
    })
  end
  table.insert(menu, { title = T.speed, menu = speedMenu })
  table.insert(menu, { title = T.voice, menu = voiceMenu })
  return menu
end

bar:setMenu(buildMenu)

-- ============================ hotkeys ======================================

hs.hotkey.bind(HOTKEY_READ[1], HOTKEY_READ[2], function()
  captureSelection(startReading)
end)

hs.hotkey.bind(HOTKEY_STOP[1], HOTKEY_STOP[2], stopReading)

hs.hotkey.bind(HOTKEY_HISTORY[1], HOTKEY_HISTORY[2], showChooser)

-- console access: hs -c "outloud.read('hello')" / hs -c "outloud.stop()"
outloud = { read = startReading, stop = stopReading, history = history,
          menu = buildMenu, speed = setSpeed }

hs.alert.show(T.ready, 2)
