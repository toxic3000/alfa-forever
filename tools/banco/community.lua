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
-- Two community packs and a route of Mis rutas.
for _, id in ipairs({ "packuno", "packdos" }) do
  local ok, err = A.RegisterPack({ addon = "Alfa_Test_" .. id, id = id, format = 9, title = "Paquete " .. id, author = "Autor", version = "1.0", license = "CC-BY-4.0" })
  print("pack", id, ok, err)
  for i = 1, 3 do
    local ok2, err2 = A.RegisterGuide({ id = id .. "/guia-" .. i, pack = id, title = "Guía " .. i .. " de " .. id, category = "Leveling", minLevel = 10 * i, maxLevel = 10 * i + 8,
      steps = { { title = "Paso", goals = { { t = "note", text = "Hola" } } } } })
    if not ok2 then print("  guide", ok2, err2) end
  end
end
local ok3, err3 = A.RegisterGuide({ id = "mis-rutas/ruta-1", pack = "mis-rutas", title = "Mi ruta de Durotar", category = "Mis rutas", steps = { { title = "Paso", goals = { { t = "note", text = "x" } } } } })
print("ruta", ok3, err3)
A.Fire("GUIDES_REGISTERED")
A.Fire("PACKS_CHANGED")
RUN_TIMERS(3)
step("show", function() UI.ShowPicker() end)
local win = P.frame
local pills = {}
for _, b in ipairs(win.pillButtons) do if b:IsShown() then pills[#pills + 1] = b.psKey .. "=" .. (b.Label:GetText() or "") end end
print("pills:", table.concat(pills, " | "))
step("community", function() for _, b in ipairs(win.pillButtons) do if b:IsShown() and b.psKey == "community" then b:Click() end end end)
print("menu shown:", A.Widgets.MenuShown())
local menu = _G.AlfaMenu
if menu then for _, r in ipairs(menu.rows) do if r:IsShown() then print("  menu:", r.Text:GetText()) end end end
step("pick pack", function() for _, r in ipairs(menu.rows) do if r:IsShown() then r:Click() break end end end)
print("category:", P.Category(), "guides:", P.shown and P.shown.guides)
SNAP("guias-comunidad", win)
step("mine", function() P.SetCategory("pack:mis-rutas") end)
print("mine guides:", P.shown and P.shown.guides)
SNAP("guias-mis-rutas-1", win)
-- Rutas' own entry point
step("rutas menu", function() P.SetCategory("All"); win:Hide(); local Pk = UI.Picker; if Pk.ShowSection then Pk.ShowSection(nil) end; Pk.SetCategory("pack:mis-rutas"); Pk.Select("mis-rutas/ruta-1"); UI.ShowPicker() end)
print("after rutas:", P.Category(), P.Selected(), P.detail and P.detail.id)
print("errors after community:", #ERRORS - before)
for i = before + 1, #ERRORS do print(ERRORS[i]) end
