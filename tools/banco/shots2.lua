SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(name, fn, ...)
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("step " .. name, e) end
end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
local A = Alfa
local UI = A.UI
local P = UI.Picker
local before = #ERRORS
step("show", function() UI.ShowPicker() end)
local win = P.frame
for _, key in ipairs({ "Rares", "Characters", "Talents", "Import" }) do
  step("section " .. key, function() P.ShowSection(key) end)
  RUN_TIMERS(2)
  SNAP("seccion-" .. key, win)
end
step("newtab", function() P.ShowSection("Guides"); UI.ShowPicker({ newTab = true }); P.SetView("browse") end)
local sel
for _, g in ipairs(A.Guides.List()) do if g.category == "Professions" then sel = sel or g.id end end
step("sel", function() P.Select(sel) end)
SNAP("guias-pestana-nueva", win)
print("errors after shots2:", #ERRORS - before)
for i = before + 1, #ERRORS do print(ERRORS[i]) end
