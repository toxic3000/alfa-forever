-- Log in, then walk through the hub's three windows.
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
print("load+login errors:", before)
for i = 1, before do print("  E", (tostring(ERRORS[i]):sub(1, 300))) end
if #ERRORS > 0 then print(ERRORS[#ERRORS]) end

step("show picker", function() UI.ShowPicker() end)
RUN_TIMERS(3)
local win = P.frame
if not win then for i = before + 1, #ERRORS do print(ERRORS[i]) end return end
print("hub shown:", win:IsShown(), "size", win:GetWidth(), win:GetHeight())
print("guides in list:", #(A.Guides.List()))
print("shown:", P.shown and P.shown.view, P.shown and P.shown.guides, P.shown and P.shown.cards, P.shown and P.shown.folders)
print("painted:", P.painted and P.painted.cards, P.painted and P.painted.folders, P.painted and P.painted.tabs)
print("detail:", P.detail and P.detail.id, P.detail and P.detail.label)

for _, v in ipairs({ "browse", "current", "recent", "home" }) do
  step("view " .. v, function() P.SetView(v) end)
  print("view", v, P.shown and P.shown.guides, P.shown and P.shown.folders, "painted", P.painted and P.painted.cards)
end
step("browse", function() P.SetView("browse") end)
-- scroll the list
step("scroll", function() P.scroll:SetVerticalScroll(600) end)
print("after scroll painted", P.painted and P.painted.cards)
-- select first visible guide
local first
for _, g in ipairs(A.Guides.List()) do first = first or g.id end
step("select", function() P.Select(first) end)
print("selected:", P.Selected(), P.detail and P.detail.label, P.detail and #P.detail.facts)
step("fav", function() P.ToggleFavorite(first) end)
step("fav pill", function() P.SetCategory("Favorites") end)
print("fav guides", P.shown and P.shown.guides)
step("fav off", function() P.ToggleFavorite(first) end)
step("all", function() P.SetCategory("All") end)
-- filters
step("fits", function() P.SetFits(true) end)
print("fits guides", P.shown and P.shown.guides)
step("band", function() P.SetLevelBand("20") end)
print("band 20 guides", P.shown and P.shown.guides)
step("clear", function() P.ClearFilters() end)
print("cleared guides", P.shown and P.shown.guides)
step("type", function() P.SetCategory("Professions") end)
print("professions", P.shown and P.shown.guides)
step("all2", function() P.SetCategory("All") end)
step("faction all", function() A.Set("ui.pickerFaction", "All") end)
print("all factions guides", P.shown and P.shown.guides)
step("faction auto", function() A.Set("ui.pickerFaction", "auto") end)
-- menus and grid
local tb = P.view.Tool
step("place grid", function() tb.Place:Click() end)
print("grid shown:", UI.HubKit.GridShown())
local grid = _G.AlfaHubGrid
if grid then
  local n = 0
  for _, b in ipairs(grid.items or {}) do if b:IsShown() then n = n + 1 end end
  print("grid items:", n)
  -- pick the second item (a race or zone)
  local pick
  for i, b in ipairs(grid.items or {}) do if b:IsShown() and i == 2 then pick = b end end
  if pick then step("grid pick", function() pick:Click() end) end
  print("place filter:", P.Filters().place, "guides", P.shown and P.shown.guides)
end
step("faction menu", function() tb.Faction:Click() end)
step("band menu", function() tb.Band:Click() end)
step("type menu", function() tb.Type:Click() end)
step("fits click", function() tb.Fits:Click() end)
step("clear click", function() if tb.Clear:IsShown() then tb.Clear:Click() end end)
-- search
step("search", function() P.SetQuery("dur") end)
print("search guides", P.shown and P.shown.guides, P.Query())
step("search clear", function() P.SetQuery("") end)
-- step keys
step("step", function() P.Step(1); P.Step(1); P.Step(-1) end)
-- Mis rutas category (pack may not exist)
step("mis rutas", function() P.SetCategory("pack:mis-rutas") end)
print("mis rutas category now:", P.Category())
-- new tab mode
step("newtab", function() UI.ShowPicker({ newTab = true }) end)
step("pills click", function()
  for _, b in ipairs(win.pillButtons) do if b:IsShown() then b:Click() end end
end)
print("after pills view", P.View(), P.Category())
step("sections", function()
  for _, b in ipairs(win.sectionButtons) do
    if b:IsShown() and b.psKey ~= "__alfa" then b:Click(); RUN_TIMERS(2) end
  end
end)
print("section now", P.Section())

-- Lookup
step("lookup", function() UI.ShowLookup({ query = "lobo" }) end)
RUN_TIMERS(3)
local LK = UI.Lookup
print("lookup shown:", LK.shown and LK.shown.query, LK.shown and LK.shown.rows, LK.shown and LK.shown.empty)
for _, k in ipairs({ "item", "mount", "npc", "all" }) do step("kind " .. k, function() LK.SetKind(k) end) end
step("lookup select guide", function() LK.Select("guide", first, { title = "x" }) end)
print("lookup detail:", LK.detail and LK.detail.title, LK.detail and LK.detail.primary)
step("lookup select item", function() LK.Select("item", 12345, { title = "Espada" }) end)
print("lookup detail item:", LK.detail and LK.detail.title, LK.detail and LK.detail.note)
step("lookup empty", function() UI.ShowLookup({ query = "" }) end)
step("lookup pills", function()
  for _, b in ipairs(win.pillButtons) do if b:IsShown() then b:Click() end end
end)
step("lookup rows in picker", function() P.ShowSection("Guides"); P.SetQuery("lobo") end)

-- Dungeons
step("dungeons", function() A.Fire("SHOW_DUNGEON") end)
RUN_TIMERS(3)
local DS = UI.DungeonsSection
local sh = DS.Shown()
print("dungeons:", P.Section(), sh.view, sh.empty, sh.cards)
step("dungeon pills", function()
  for _, b in ipairs(win.pillButtons) do if b:IsShown() then b:Click() end end
end)
local key
local D = A.Dungeons
local okD, loaded = pcall(function() return D.Load() end)
print("dungeons loaded:", okD, loaded)
if okD and loaded then
  for _, d in ipairs(D.List()) do key = key or d.key end
  print("first dungeon", key)
  step("open dungeon", function() D.Open(key) end)
  sh = DS.Shown()
  print("page:", sh.view, sh.page, sh.tab, sh.quests)
  for _, t in ipairs({ "bosses", "attune", "map", "quests" }) do
    step("tab " .. t, function() DS.SetTab(t) end)
    sh = DS.Shown()
    print("tab", t, sh.tab, sh.bosses, sh.map, sh.blocks)
  end
  step("page pills", function()
    for _, b in ipairs(win.pillButtons) do if b:IsShown() and b.psKey ~= "home" then b:Click() end end
  end)
  step("faction all", function() DS.SetFaction("All") end)
  step("home", function() DS.Home() end)
  step("search dungeon", function() P.SetQuery("a") end)
  step("enter", function() DS.Enter() end)
end
step("hide", function() win:Hide() end)
step("reopen", function() UI.ShowPicker() end)
step("theme change", function() A.Set("ui.scheme", "noche") ; A.Theme.Refresh() end)
print("total errors after drive:", #ERRORS - before)

-- Screenshots of the states worth looking at.
SNAPSHOTS = {}
function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end

for k in pairs(GLOBAL_READS) do print("GLOBAL", k) end
