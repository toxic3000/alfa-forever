-- Prueba de guardar, recargar y volver a leer los ajustes (1.1.9). tools/prueba.py
-- la corre dos veces con las mismas variables guardadas (BANCO_GUARDADAS):
--   fase 1: cambia ajustes del motor y de varios módulos, y corre una migración;
--   fase 2 (como después de un /reload): todo sigue igual y la migración no
--           vuelve a correr.
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
  N.Migracion(1, function(db)
    db.pruebaMigracion = (db.pruebaMigracion or 0) + 1
  end)
end

if FASE == "1" then
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
    if AlfaDB.pruebaMigracion ~= 1 or AlfaDB.alfaSchema ~= 1 then error("la migración no quedó anotada") end
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
