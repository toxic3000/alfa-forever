-- Prueba de guardar, recargar y volver a leer los ajustes (1.1.9, 1.2.0).
-- tools/prueba.py la corre tres veces con las mismas variables guardadas
-- (BANCO_GUARDADAS):
--   fase 0: deja una cuenta como la de alguien que venía de la 1.1.9 (sin
--           migraciones hechas, con "Ocultar los grifos" encendido);
--   fase 1: la mudanza de la 1.2.0 conserva lo suyo; cambia ajustes del
--           motor y de varios módulos, y corre una migración de prueba;
--   fase 2 (como después de un /reload): todo sigue igual y nada se muda dos veces.
-- Es la base para la 1.2.0, que muda ajustes de lugar sin que nadie pierda
-- su configuración.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local FASE = os and os.getenv and os.getenv("BANCO_FASE") or "1"
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A, N = Alfa, AlfaNucleo
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end

-- Valores que no son los de fábrica, de varias partes de Alfa.
local CAMBIOS = {
  { "maps.taxiPins", false },
  { "ui.textSize", 1.2 },
  { "recoleccion.minimapa", false },
  { "recoleccion.tamanoMapa", 1.4 },
  { "pesca.sonido", false },
  { "bolsas.agrupar", false },
  { "mundo.estiloMapa", "clasico" },
  { "inicio.verDiario", false },
}

local function migracionPrueba()
  N.Migracion(900, function(db)
    db.pruebaMigracion = (db.pruebaMigracion or 0) + 1
  end)
end

local ANTES = { "minimapa", "colores", "cuadro", "probador", "silenciarErrores", "barras" }

if FASE == "0" then
  step("fase 0: una instalación nueva recibe lo nuevo de fábrica", function()
    for _, k in ipairs(ANTES) do
      if A.Get("comodidades." .. k) ~= true then error("en una instalación nueva " .. k .. " no viene encendido") end
    end
  end)
  step("fase 0: una cuenta que venía de la 1.1.9", function()
    if type(AlfaDB) ~= "table" then error("no hay AlfaDB") end
    AlfaDB.alfaSchema = nil
    AlfaDB.settings.comodidades = { grifos = true, colores = true }
  end)
  print("FASE 0 lista: cuenta de antes")
elseif FASE == "1" then
  step("fase 1: la mudanza de la 1.2.0 conserva lo de antes", function()
    local s = AlfaDB.settings.comodidades or {}
    if (tonumber(AlfaDB.alfaSchema) or 0) < 1 then error("la mudanza de la 1.2.0 no corrió al entrar") end
    if s.grifos ~= nil then error("quedó el ajuste viejo de los grifos") end
    if s.barrasGrifos ~= "ocultar" then error("los grifos ocultos no pasaron a barrasGrifos: " .. tostring(s.barrasGrifos)) end
    if s.colores ~= true then error("se perdió un ajuste que el jugador había encendido (colores)") end
    for _, k in ipairs(ANTES) do
      if k ~= "colores" and A.Get("comodidades." .. k) ~= false then
        error("a quien ya tenía Alfa se le encendió " .. k .. " sin pedirlo")
      end
    end
  end)
  step("fase 1: cambiar ajustes", function()
    if type(AlfaDB) ~= "table" then error("no hay AlfaDB") end
    for _, c in ipairs(CAMBIOS) do
      A.Set(c[1], c[2])
      if A.Get(c[1]) ~= c[2] then error(c[1] .. " no quedó puesto") end
    end
  end)
  step("fase 1: una migración corre una vez", function()
    if not (N.Migracion and N.CorrerMigraciones) then error("faltan N.Migracion / N.CorrerMigraciones") end
    migracionPrueba()
    local n = N.CorrerMigraciones()
    if n ~= 1 then error("corrieron " .. tostring(n) .. " migraciones, se esperaba 1") end
    if N.CorrerMigraciones() ~= 0 then error("la migración volvió a correr en la misma sesión") end
    if AlfaDB.pruebaMigracion ~= 1 or AlfaDB.alfaSchema ~= 900 then error("la migración no quedó anotada") end
  end)
  step("fase 1: Ajustes en orden (1.2.0)", function()
    local O = A.UI and A.UI.Options
    if not (O and O.Estructura and O.PaginasDeAjustes) then error("faltan O.Estructura / O.PaginasDeAjustes") end
    -- Calidad de vida ya no es una página aparte: sus enlaces llevan a Comodidades.
    for _, k in ipairs(O.PaginasDeAjustes()) do
      if k == "qualityoflife" then error("Calidad de vida sigue como página aparte en Ajustes") end
    end
    local co = O.Estructura("comodidades")
    if not (co and co.custom) then error("Comodidades no es su página propia") end
    if co.tabs[1].name ~= "" then error("la primera pestaña de Comodidades no es la suya") end
    if #co.tabs < 4 then error("Comodidades no trae las pestañas de Calidad de vida (" .. #co.tabs .. ")") end
    local alias = O.Estructura("qualityoflife")
    if not (alias and alias.key == "comodidades") then error("el enlace a Calidad de vida no lleva a Comodidades") end
    local todas = {}
    for _, t in ipairs(co.tabs) do for k in pairs(t.keys) do todas[k] = true end end
    for _, k in ipairs({ "qol.sellJunk", "qol.autoRepair", "qol.acceptSummon", "qol.flightAutoOpen" }) do
      if not todas[k] then error("falta " .. k .. " en Comodidades") end
    end
    -- Las misiones, en Misiones: las de la guía, las de Alfa y la de tu ruta.
    local mi = O.Estructura("questing")
    local enMisiones = {}
    for _, t in ipairs(mi.tabs) do for k in pairs(t.keys) do enMisiones[k] = true end end
    for _, k in ipairs({ "behavior.autoAccept", "behavior.autoTurnin", "behavior.closeSkipped", "behavior.skipGrey",
        "comodidades.misiones", "comodidades.misionesDiarias", "ruta.soloRuta" }) do
      if not enMisiones[k] then error("falta " .. k .. " en Misiones") end
    end
    for _, t in ipairs(O.Estructura("guide").tabs) do
      if t.keys["behavior.closeSkipped"] then error("la automatización de misiones sigue en Guía") end
    end
    for k in pairs(co.tabs[1].keys) do
      if k:find("^comodidades%.misiones") then error("las misiones siguen en la pestaña de Comodidades: " .. k) end
    end
  end)
  step("fase 1: el buscador encuentra los ajustes de cada página", function()
    local O = A.UI and A.UI.Options
    if not (O and O.Search) then error("no hay O.Search") end
    for _, id in ipairs({ "pesca", "comercio", "rutas", "bolsas", "combate", "curacion", "lya", "bienvenida" }) do
      local spec = N.ModuloPorId(id)
      if spec then
        local lista = spec.controles
        if type(lista) ~= "table" or #lista == 0 then error(id .. ": la página no da sus ajustes al buscador") end
        local c
        for _, x in ipairs(lista) do if type(x.label) == "string" and x.key then c = x break end end
        if not c then error(id .. ": ningún ajuste con nombre y clave") end
        local grupos, n = O.Search(c.label)
        local visto = false
        for _, g in ipairs(grupos) do
          for _, y in ipairs(g.controls) do if y.key == c.key then visto = true end end
        end
        if not (n > 0 and visto) then error(string.format("%s: buscar «%s» no encuentra %s", id, c.label, c.key)) end
      end
    end
  end)
  print("FASE 1 lista: ajustes guardados")
else
  step("fase 2: la mudanza no se repite", function()
    if A.Get("comodidades.barras") ~= false then error("las barras se encendieron tras recargar") end
  end)
  step("fase 2: los ajustes siguen tras recargar", function()
    if type(AlfaDB) ~= "table" or type(AlfaDB.settings) ~= "table" then error("AlfaDB no se cargó de lo guardado") end
    for _, c in ipairs(CAMBIOS) do
      local v = A.Get(c[1])
      if v ~= c[2] then error(string.format("%s volvió como %s (se guardó %s)", c[1], tostring(v), tostring(c[2]))) end
    end
  end)
  step("fase 2: la migración no vuelve a correr", function()
    migracionPrueba()
    local n = N.CorrerMigraciones()
    if n ~= 0 then error("la migración corrió otra vez tras recargar (" .. tostring(n) .. ")") end
    if AlfaDB.pruebaMigracion ~= 1 then error("pruebaMigracion = " .. tostring(AlfaDB.pruebaMigracion)) end
  end)
  step("fase 2: solo se guarda lo que no es de fábrica", function()
    A.Set("maps.taxiPins", A.GetDefault("maps.taxiPins"))
    local s = AlfaDB.settings.maps
    if type(s) == "table" and s.taxiPins ~= nil then error("un ajuste puesto a su valor de fábrica siguió guardado") end
  end)
end

print("PRUEBA: ajustes fase " .. FASE .. ", " .. pasos .. " pasos, " .. #ERRORS .. " errores")
