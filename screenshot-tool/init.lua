-- screenshotfolder: screenshots to the clipboard, optionally also saved to a folder.
--   ⌃⇧S      full screenshot of the display under the mouse.
--   ⌃⇧D      snip: interactive area capture (Esc cancels).
--            Both always land on the clipboard; while saving is on, the PNG is also written to
--            the chosen folder.
--   ⌃⌥⇧S     toggle saving. Off -> on (asks for a folder if none is remembered); on -> off.
--   menu bar camera icon (or ⌃⌥⇧M, which opens the same menu at the mouse): status, take a
--            screenshot, hotkeys on/off, saving on/off, change or open the folder, restart.
--
-- State lives in hs.settings (screenshotfolder.active / .enabled / .folder), so it survives
-- reloads. If the folder disappears, the next capture falls back to clipboard only and saving
-- turns off.

local M = {}

local KEY_ACTIVE = "screenshotfolder.active" -- hotkeys on; nil counts as on
local KEY_ENABLED = "screenshotfolder.enabled" -- save-to-folder on
local KEY_FOLDER = "screenshotfolder.folder"
local FULL_MODS, FULL_KEY = { "ctrl", "shift" }, "s"
local SNIP_MODS, SNIP_KEY = { "ctrl", "shift" }, "d"
local TOGGLE_MODS, TOGGLE_KEY = { "ctrl", "alt", "shift" }, "s"
-- Opens the menu at the mouse: the menu bar icon can end up hidden behind the MacBook notch.
-- Stays bound while the capture hotkeys are off, so they can be turned back on.
local MENU_MODS, MENU_KEY = { "ctrl", "alt", "shift" }, "m"

local menu, menuHotkey
local hotkeys = {}
local tasks = {} -- running hs.task objects; unreferenced tasks can be garbage-collected mid-run
local pending = {} -- same for hs.timer.doAfter timers

local function log(...) print("[screenshotfolder]", ...) end

local function later(sec, fn)
  local t
  t = hs.timer.doAfter(sec, function() pending[t] = nil; fn() end)
  pending[t] = true
end

local function isDir(path)
  return path ~= nil and hs.fs.attributes(path, "mode") == "directory"
end

local function active() return hs.settings.get(KEY_ACTIVE) ~= false end
local function enabled() return hs.settings.get(KEY_ENABLED) == true end
local function folder() return hs.settings.get(KEY_FOLDER) end
local function folderName(path) return path and (path:match("([^/]+)/*$") or path) or "" end
local function shortPath(path) return (path:gsub("^" .. os.getenv("HOME"):gsub("%p", "%%%0"), "~")) end

---------------------------------------------------------------------------
-- menu bar

local function refreshMenu()
  if not menu then return end
  local on, dir = enabled(), folder()
  if not active() then
    menu:setTitle("📷⏸")
    menu:setTooltip("Screenshot hotkeys are off")
  elseif on then
    menu:setTitle("📸●")
    menu:setTooltip("Screenshots: clipboard + " .. dir)
  else
    menu:setTitle("📷")
    menu:setTooltip("Screenshots: clipboard only")
  end
end

local function setEnabled(on)
  hs.settings.set(KEY_ENABLED, on)
  refreshMenu()
  if on then
    hs.alert.show("📁 Saving to: " .. folderName(folder()))
  else
    hs.alert.show("📋 Clipboard only")
  end
end

function M.chooseFolder()
  local start = isDir(folder()) and folder() or (os.getenv("HOME") .. "/Desktop")
  hs.focus()
  local picked = hs.dialog.chooseFileOrFolder("Save screenshots to…", start, false, true, false)
  if not picked or not picked["1"] then return false end
  hs.settings.set(KEY_FOLDER, picked["1"])
  setEnabled(true)
  return true
end

function M.toggle()
  if enabled() then
    setEnabled(false)
  elseif isDir(folder()) then
    setEnabled(true)
  else
    M.chooseFolder()
  end
end

local function setActive(on)
  hs.settings.set(KEY_ACTIVE, on)
  for _, hk in ipairs(hotkeys) do
    if on then hk:enable() else hk:disable() end
  end
  refreshMenu()
  hs.alert.show(on and "📷 Screenshot hotkeys on" or "⏸ Screenshot hotkeys off")
end

function M.toggleActive() setActive(not active()) end

local function menuItems()
  local on, dir = enabled(), folder()
  local status
  if not active() then
    status = "Status: hotkeys off"
  elseif on then
    status = "Status: on — clipboard + folder"
  else
    status = "Status: on — clipboard only"
  end

  -- Captures from the menu wait for it to close, or the menu ends up in the screenshot.
  local items = {
    { title = "Screenshot Tool", disabled = true },
    { title = status, disabled = true },
    { title = "-" },
    { title = "Full screenshot\t⌃⇧S", fn = function() later(0.3, function() M.capture("full") end) end },
    { title = "Snip area\t⌃⇧D", fn = function() later(0.3, function() M.capture("snip") end) end },
    { title = "-" },
    { title = "Hotkeys on", checked = active(), fn = M.toggleActive },
    { title = "Save to folder\t⌃⌥⇧S", checked = on, fn = M.toggle },
    { title = "Folder: " .. (dir and shortPath(dir) or "none chosen"), disabled = true },
    { title = dir and "Change folder…" or "Choose folder…", fn = M.chooseFolder },
  }
  if isDir(dir) then
    table.insert(items, { title = "Open folder in Finder", fn = function() hs.execute(string.format("open %q", dir)) end })
  end
  table.insert(items, { title = "-" })
  table.insert(items, { title = "Restart Screenshot Tool", fn = M.restart })
  table.insert(items, { title = "This menu anywhere: ⌃⌥⇧M", disabled = true })
  return items
end

---------------------------------------------------------------------------
-- capture

local function run(args, onExit)
  local t
  t = hs.task.new("/usr/sbin/screencapture", function(code, _, err)
    tasks[t] = nil
    if code ~= 0 and not hs.screenRecordingState() then
      hs.alert.show("⚠️ Screenshot failed: give Hammerspoon Screen Recording permission")
      log("screencapture failed:", code, err)
    end
    if onExit then onExit(code) end
  end, args)
  tasks[t] = true
  t:start()
  return t
end

-- screencapture -D index of the display under the mouse. Assumes hs.screen.allScreens() and
-- screencapture both list the main display first.
local function mouseDisplay()
  local current = hs.mouse.getCurrentScreen()
  for i, s in ipairs(hs.screen.allScreens()) do
    if current and s:id() == current:id() then return i end
  end
  return 1
end

-- kind: "full" (display under the mouse, default) or "snip" (area picker).
function M.capture(kind)
  local args
  if kind == "snip" then
    args = { "-i" }
  else
    args = { "-x", "-D", tostring(mouseDisplay()) }
  end
  -- Feedback for a silent full capture, shown only once the image is taken so it never ends up in it.
  local function done(code)
    if kind ~= "snip" and code == 0 then hs.alert.show("📸", { textSize = 64 }, 1) end
  end

  if enabled() and not isDir(folder()) then
    hs.alert.show("⚠️ Screenshot folder missing — clipboard only")
    log("folder missing:", tostring(folder()))
    hs.settings.set(KEY_ENABLED, false)
    refreshMenu()
  end

  if not enabled() then
    table.insert(args, "-c")
    return run(args, done)
  end

  local path = string.format("%s/Screenshot %s.png", folder(), os.date("%Y-%m-%d %H.%M.%S"))
  table.insert(args, path)
  return run(args, function(code)
    -- Esc during the area picker writes no file; leave the clipboard alone in that case.
    if hs.fs.attributes(path) == nil then return end
    local img = hs.image.imageFromPath(path)
    if img then hs.pasteboard.writeObjects(img) end
    done(code)
  end)
end

function M.status()
  return { active = active(), enabled = enabled(), folder = folder(), hotkeys = #hotkeys }
end

function M.showMenu()
  if menu then menu:popupMenu(hs.mouse.absolutePosition()) end
end

function M.stop()
  for _, hk in ipairs(hotkeys) do hk:delete() end
  hotkeys = {}
  if menuHotkey then menuHotkey:delete(); menuHotkey = nil end
  if menu then menu:delete(); menu = nil end
end

function M.start()
  M.stop()
  menu = hs.menubar.new()
  menu:setMenu(menuItems)
  hotkeys = {
    hs.hotkey.new(FULL_MODS, FULL_KEY, function() M.capture("full") end),
    hs.hotkey.new(SNIP_MODS, SNIP_KEY, function() M.capture("snip") end),
    hs.hotkey.new(TOGGLE_MODS, TOGGLE_KEY, M.toggle),
  }
  if active() then
    for _, hk in ipairs(hotkeys) do hk:enable() end
  end
  menuHotkey = hs.hotkey.bind(MENU_MODS, MENU_KEY, M.showMenu)
  refreshMenu()
  log("started", hs.inspect(M.status()))
end

function M.restart()
  M.start()
  hs.alert.show("🔄 Screenshot tool restarted")
end

return M


