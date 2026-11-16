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
RUN_TIMERS(3)
local win = P.frame
SNAP("guias-inicio", win)
step("browse", function() P.SetView("browse") end)
-- select a leveling guide that fits
local pick
for _, g in ipairs(A.Guides.List()) do
  if not pick and (g.category == nil or g.category == "Leveling") and g.minLevel and g.minLevel <= 23 and (g.maxLevel or 0) >= 23 and g.faction == "Horde" then pick = g.id end
end
step("select", function() P.Select(pick) end)
SNAP("guias-todas", win)
step("scroll", function() P.scroll:SetVerticalScroll(420) end)
SNAP("guias-todas-abajo", win)
step("scroll0", function() P.scroll:SetVerticalScroll(0) end)
step("fits", function() P.SetFits(true) end)
SNAP("guias-para-tu-nivel", win)
step("grid", function() P.view.Tool.Place:Click() end)
SNAP("guias-zona", win, { _G.AlfaHubGrid })
step("grid close", function() UI.HubKit.HideGrid() end)
step("clear", function() P.ClearFilters() end)
step("type", function() P.view.Tool.Type:Click() end)
SNAP("guias-tipo", win, { _G.AlfaMenu })
step("menu close", function() A.Widgets.HideMenu() end)

step("mis rutas", function() P.SetCategory("pack:mis-rutas") end)
SNAP("guias-mis-rutas", win)
step("search lobo", function() P.SetCategory("All"); P.SetQuery("lobo") end)
SNAP("guias-busqueda", win)
step("search clear", function() P.SetQuery("") end)
step("lookup", function() UI.ShowLookup({ query = "lobo" }) end)
RUN_TIMERS(3)
local LK = UI.Lookup
local first = LK.results and nil
step("lookup pick", function()
  local sh = LK.shown
  -- the first item result, when there is one
  LK.Step(1); LK.Step(1)
end)
SNAP("buscador", win)
step("lookup item", function() LK.SetKind("item") end)
SNAP("buscador-objetos", win)

step("dungeons", function() A.Fire("SHOW_DUNGEON") end)
RUN_TIMERS(3)
SNAP("mazmorras", win)
step("dungeons all", function() UI.DungeonsSection.SetBand("all") end)
SNAP("mazmorras-todas", win)
local D = A.Dungeons
local key
for _, d in ipairs(D.List()) do if d.key == "the-deadmines" or d.key == "wailing-caverns" then key = key or d.key end end
for _, d in ipairs(D.List()) do key = key or d.key end
step("open", function() D.Open(key) end)
SNAP("mazmorra-misiones", win)
step("bosses", function() UI.DungeonsSection.SetTab("bosses") end)
SNAP("mazmorra-jefes", win)
step("map", function() UI.DungeonsSection.SetTab("map") end)
SNAP("mazmorra-entrada", win)
print("errors after shots:", #ERRORS - before)
for i = before + 1, #ERRORS do print(ERRORS[i]) end
