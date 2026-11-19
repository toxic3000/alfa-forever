-- Barrido de letra y alineación (1.2.3). Recorre las mismas páginas y
-- pestañas que prueba_botones y, en cada vista, mide cada texto a la vista:
--   * su letra y tamaño: los de Alfa siguen la escala del Kit (K.TIPO); los
--     del motor, la suya. Se listan las combinaciones y dónde salen;
--   * si queda centrado en su botón, pestaña o píldora (más de 1.5 px de
--     diferencia entre el centro del texto y el del botón).
-- Lo de abajo es de prueba_botones (cómo abre y clica).
-- abre cada página de Alfa y clica cada botón a la vista, como un jugador.
-- Si un clic muestra botones nuevos (una pestaña, un menú, un diálogo), los
-- clica también, hasta dos niveles; cada uno se prueba desde la página
-- recién abierta, repitiendo los clics que llevan a él.
--   * Un error de Lua al clicar sale como "FALLA EN: <página> > <botón>".
--   * Un botón que no hace nada que se note (no muestra ni esconde nada, no
--     cambia un ajuste, no avisa, no escribe en el chat, no lanza un evento
--     de Alfa) sale en la lista "SIN EFECTO" para revisarlo a mano.
-- BANCO_PAGINAS="inicio,rutas" prueba solo esas (para depurar).
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 500)) end
  end
  return #ERRORS > antes
end
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
-- Lya se escondió al entrar (la bienvenida estaba pendiente): ya puede verse.
local Ly = NS_OF("Alfa_Lya")
if Ly and Ly.UI and Ly.UI.Aplicar then Ly.UI.Aplicar() end
local bv = _G.AlfaBienvenidaVentana
if bv and bv.Hide then bv:Hide() end

---------------------------------------------------------------------------
-- Lo que cuenta como "hizo algo"
---------------------------------------------------------------------------
local efecto = 0
local function marcar() efecto = efecto + 1 end
local function espiar(t, k)
  local f = t and rawget(t, k)
  if type(f) ~= "function" then return end
  t[k] = function(...) marcar() return f(...) end
end
espiar(A, "Fire")
espiar(A, "Set")
espiar(A, "RunCommand")
espiar(N, "Set")
espiar(N, "Abrir")
espiar(K, "Aviso")
espiar(K, "Dialogo")
espiar(K, "Menu")
local addMsg = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(...) marcar() return addMsg(...) end
-- Funciones del juego que un botón llama a propósito.
for _, nombre in ipairs({ "ReloadUI", "ToggleWorldMap", "ToggleCharacter", "ToggleSpellBook", "ToggleTalentFrame",
  "OpenAllBags", "CloseAllBags", "ToggleAllBags", "PlaySound", "PlaySoundFile", "AbandonQuest", "C_QuestLog",
  "OpenURL", "ChatFrame_OpenChat", "SetCVar" }) do
  local f = rawget(_G, nombre)
  if type(f) == "function" then _G[nombre] = function(...) marcar() return f(...) end end
end
local CFU = rawget(_G, "ChatFrameUtil")
if type(CFU) == "table" then espiar(CFU, "OpenChat") end
if type(rawget(_G, "C_CVar")) == "table" then espiar(C_CVar, "SetCVar") end
local QL = rawget(_G, "C_QuestLog")
if type(QL) == "table" then for _, k in ipairs({ "SetSelectedQuest", "AbandonQuest", "SetAbandonQuest", "AddQuestWatch", "RemoveQuestWatch" }) do espiar(QL, k) end end

-- Lo que se ve: cuántos marcos a la vista y cuáles (por su número en la lista).
local function firma()
  local n, suma = 0, 0
  for i, f in ipairs(ALL_FRAMES()) do
    if f._kind ~= "Texture" and f._kind ~= "FontString" and f:IsVisible() then n = n + 1 suma = (suma + i * 7919) % 1000003 end
  end
  return n .. ":" .. suma
end
-- Y cómo se ven los textos y los colores (un interruptor que se pinta distinto).
local function firmaTextos(raiz)
  local t = {}
  local function ver(f, d)
    if d > 60 or not f:IsShown() then return end
    if f._kind == "FontString" and type(f._text) == "string" then t[#t + 1] = f._text end
    if f._kind == "Texture" then t[#t + 1] = tostring(f._tex) .. (f._vc and table.concat(f._vc, ",") or "") end
    for _, h in ipairs(rawget(f, "_children") or {}) do ver(h, d + 1) end
  end
  if raiz then ver(raiz, 0) end
  return table.concat(t, "|")
end

---------------------------------------------------------------------------
-- Los botones
---------------------------------------------------------------------------
local function tieneClic(f)
  -- Una tarjeta del Kit sin acción no se ilumina ni parece botón: no cuenta.
  local d = rawget(f, "alfaDatos")
  if type(d) == "table" and rawget(f, "Baldosa") and not d.alClic then return false end
  -- Un campo de texto (elige lo escrito al clicar) y la barra para desplazar
  -- no son botones.
  if f._kind == "EditBox" or rawget(f, "psThumb") then return false end
  local s = rawget(f, "_scripts")
  local h = rawget(f, "_hooks")
  return (s and (s.OnClick or s.OnMouseUp)) or (h and (h.OnClick or h.OnMouseUp))
end

local function etiqueta(b)
  local textos = {}
  local function ver(f, d)
    if d > 4 or #textos >= 2 then return end
    if f._kind == "FontString" and type(f._text) == "string" and f._text ~= "" and f:IsShown() then
      textos[#textos + 1] = (f._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " ")):sub(1, 40)
    end
    for _, h in ipairs(rawget(f, "_children") or {}) do ver(h, d + 1) end
  end
  ver(b, 0)
  local t = table.concat(textos, " / ")
  if t == "" then t = b.alfaIcono or b._name or b.alfaClave or "(sin texto)" end
  return tostring(t)
end

-- Los botones a la vista dentro de `raiz`, en orden; de una lista larga
-- (filas iguales) solo los primeros TOPE_HERMANOS.
local TOPE_HERMANOS = 4
local function clicables(raiz, out)
  out = out or {}
  local function ver(f, d)
    if d > 30 or not f:IsShown() then return end
    local hijos = rawget(f, "_children") or {}
    local n = 0
    for _, h in ipairs(hijos) do
      if h._kind ~= "Texture" and h._kind ~= "FontString" and h:IsShown() then
        if tieneClic(h) and h:IsVisible() and h:IsEnabled() ~= false and (h._mouse ~= false or h._kind == "Button") then
          n = n + 1
          if n <= TOPE_HERMANOS or not h.alfaFila then out[#out + 1] = h end
        end
        ver(h, d + 1)
      end
    end
  end
  if raiz then ver(raiz, 0) end
  return out
end

-- Las tareas de Alfa (armar una ruta, revisar misiones) corren en el
-- OnUpdate de su marco (Alfa_Rutas/Tareas.lua): se dejan terminar.
local Ru = NS_OF("Alfa_Rutas")
local marcoTareas
local function correrTareas()
  if not (Ru and Ru.Tareas and Ru.Tareas.Alguna) then return end
  for _ = 1, 3000 do
    if not Ru.Tareas.Alguna() then break end
    if not marcoTareas then
      for _, f in ipairs(ALL_FRAMES()) do
        local fn = rawget(f, "_scripts") and f._scripts.OnUpdate
        if fn and (debug.getinfo(fn, "S").source or ""):find("Tareas.lua", 1, true) then marcoTareas = f break end
      end
    end
    if not marcoTareas then break end
    FIRE(marcoTareas, "OnUpdate", 0.016)
  end
  T(2)
end

local function clicar(b)
  local s = rawget(b, "_scripts") or {}
  if s.OnClick or (rawget(b, "_hooks") and b._hooks.OnClick) then
    FIRE(b, "PreClick", "LeftButton")
    FIRE(b, "OnClick", "LeftButton", false)
    FIRE(b, "PostClick", "LeftButton")
  else
    FIRE(b, "OnMouseDown", "LeftButton")
    FIRE(b, "OnMouseUp", "LeftButton")
  end
end

---------------------------------------------------------------------------
-- Volver al punto de partida: todo cerrado y la página abierta
---------------------------------------------------------------------------
-- Lo de Alfa cuelga de su raíz (AlfaUIParent); el rastreador, la flecha y el
-- botón del minimapa se quedan (no son ventanas que abre un clic).
local RAIZ = rawget(_G, "AlfaUIParent") or UIParent
local function fija(f)
  local nombre = rawget(f, "_name")
  return type(nombre) == "string" and (nombre == "AlfaRastreador" or nombre == "AlfaNavArrow" or nombre == "AlfaLyaLoba"
    or nombre:find("Minimapa") or nombre:find("^AlfaCombate"))
end
local function cerrarTodo()
  if K.CerrarDialogo then pcall(K.CerrarDialogo) end
  for _, f in ipairs(rawget(RAIZ, "_children") or {}) do
    if f._kind ~= "Texture" and f._kind ~= "FontString" and f:IsShown() and not fija(f) then pcall(f.Hide, f) end
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o then o:Hide() end
  T(1)
end

local function abrirPagina(id)
  cerrarTodo()
  A.Fire("SHOW_OPTIONS", id)
  T(1)
  correrTareas()
  return A.UI and A.UI.Options and A.UI.Options.frame
end

-- Donde se buscan botones: la ventana de Alfa y lo que esté encima
-- (diálogos, menús, ventanas que abrió el clic), todo en la raíz de Alfa.
local function raices()
  local out = {}
  for _, f in ipairs(rawget(RAIZ, "_children") or {}) do
    if f._kind ~= "Texture" and f._kind ~= "FontString" and f:IsVisible() and not fija(f) then out[#out + 1] = f end
  end
  return out
end
local function firmaTodo()
  local t = {}
  for _, r in ipairs(raices()) do t[#t + 1] = firmaTextos(r) end
  return table.concat(t, "#")
end
local function todosLosBotones()
  local out = {}
  for _, r in ipairs(raices()) do clicables(r, out) end
  return out
end

---------------------------------------------------------------------------
-- La recorrida
---------------------------------------------------------------------------
local PAGINAS = { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
  "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "questing" }
local solo = rawget(_G, "BANCO_PAGINAS") or (os and os.getenv and os.getenv("BANCO_PAGINAS"))
if type(solo) == "string" and solo ~= "" then
  PAGINAS = {}
  for p in solo:gmatch("[^,]+") do PAGINAS[#PAGINAS + 1] = p end
end
local NIVELES = 2
local TOPE_POR_PAGINA = 160


---------------------------------------------------------------------------
-- La medida
---------------------------------------------------------------------------
local letras = {}      -- "cara|tam" -> { n, ejemplos = {}, donde = {} }
local descentrados = {} -- clave -> texto
local vistos = setmetatable({}, { __mode = "k" })
local function cara(ruta)
  ruta = tostring(ruta or "?")
  return (ruta:gsub("^.*[/\]", ""))
end
local function medir(donde)
  for _, r in ipairs(raices()) do
    local function ver(f, d)
      if d > 60 or not f:IsShown() then return end
      if f._kind == "FontString" then
        local t = f._text
        if type(t) == "string" and t ~= "" and f:IsVisible() and not vistos[f] then
          vistos[f] = true
          local ruta, tam = f:GetFont()
          local k = cara(ruta) .. "|" .. tostring(tam) .. "|" .. (f.alfaRol and ("kit:" .. f.alfaRol) or "otro")
          local e = letras[k] or { n = 0, ejemplos = {}, donde = {} }
          letras[k] = e
          e.n = e.n + 1
          if #e.ejemplos < 3 then e.ejemplos[#e.ejemplos + 1] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " ")):sub(1, 30) end
          if not e.donde[donde] then e.donde[donde] = true end
          -- ¿centrado en su botón? Se mide el bloque de todos sus textos
          -- (una fila de lista lleva título y detalle uno sobre otro).
          local p = f._parent
          if p and p._kind == "Button" and tieneClic(p) and not vistos[p] then
            vistos[p] = true
            local _, py, _, ph = p:GetRect()
            local abajo, arriba
            for _, h in ipairs(rawget(p, "_children") or {}) do
              if h._kind == "FontString" and h:IsVisible() and type(h._text) == "string" and h._text ~= "" then
                local _, hy, _, hh = h:GetRect()
                if hy and hh and hh > 0 then
                  abajo = math.min(abajo or hy, hy)
                  arriba = math.max(arriba or (hy + hh), hy + hh)
                end
              end
            end
            if ph and ph > 0 and ph <= 44 and abajo then
              local dif = (abajo + arriba) / 2 - (py + ph / 2)
              if math.abs(dif) > 1.5 then
                local clave = donde .. " > " .. t:sub(1, 30)
                descentrados[clave] = string.format("%.1f px %s (botón %d de alto, texto %d)", math.abs(dif), dif > 0 and "arriba" or "abajo", ph, arriba - abajo)
              end
            end
          end
        end
      end
      for _, h in ipairs(rawget(f, "_children") or {}) do ver(h, d + 1) end
    end
    ver(r, 0)
  end
end

local yaVisto = {}
for _, id in ipairs(PAGINAS) do
  local cola = {}
  abrirPagina(id)
  medir(id)
  for _, b in ipairs(todosLosBotones()) do
    if not yaVisto[b] then yaVisto[b] = true cola[#cola + 1] = { b = b, nombre = etiqueta(b) } end
  end
  for _, x in ipairs(cola) do
    abrirPagina(id)
    if x.b:IsVisible() and x.b:IsEnabled() ~= false then
      pcall(clicar, x.b) T(2) correrTareas()
      medir(id .. " > " .. x.nombre)
    end
  end
end
cerrarTodo()

local claves = {}
for k in pairs(letras) do claves[#claves + 1] = k end
table.sort(claves, function(a, b) return letras[a].n > letras[b].n end)
print("LETRAS (cara|tamaño|origen: cuántos textos, ejemplos, dónde):")
for _, k in ipairs(claves) do
  local e = letras[k]
  local d = {}
  for w in pairs(e.donde) do d[#d + 1] = w end
  table.sort(d)
  print(string.format("  %-40s %4d  [%s]  en: %s", k, e.n, table.concat(e.ejemplos, " / "), table.concat(d, " ; ", 1, math.min(#d, 4)) .. (#d > 4 and (" y " .. (#d - 4) .. " más") or "")))
end
local dk = {}
for k in pairs(descentrados) do dk[#dk + 1] = k end
table.sort(dk)
print(string.format("DESCENTRADOS (%d):", #dk))
for _, k in ipairs(dk) do print("  - " .. k .. ": " .. descentrados[k]) end
-- Lo que hace fallar la prueba: un tamaño fuera de la escala de Alfa (la del
-- Kit, K.TIPO, que el motor también sigue), una letra que no es la de Alfa
-- (salvo la muestra «Alfa» del estilo Clásico WoW, a propósito con la del
-- juego) o un texto descentrado en su botón.
local ESCALA = {}
for _, spec in pairs(N.Kit.TIPO) do ESCALA[spec[2]] = true end
for _, k in ipairs(claves) do
  local cara, tam = k:match("^(.-)|([%d%.]+)|")
  local e = letras[k]
  if not ESCALA[tonumber(tam)] then NOTE("letras", "tamaño fuera de la escala: " .. k .. " [" .. table.concat(e.ejemplos, " / ") .. "]") end
  local deAlfa = cara:find("Inter%-") or cara:find("FiraSans%-") or cara:find("OpenSans%-")
  local muestra = #e.ejemplos == 1 and e.ejemplos[1] == "Alfa"
  if not deAlfa and not muestra then NOTE("letras", "letra que no es la de Alfa: " .. k .. " [" .. table.concat(e.ejemplos, " / ") .. "]") end
end
for _, k in ipairs(dk) do NOTE("letras", "descentrado: " .. k .. ": " .. descentrados[k]) end
if #ERRORS > 0 then print("FALLA EN: letras") for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 300)) end end
print(string.format("PRUEBA: letras, %d combinaciones, %d descentrados, errores: %d", #claves, #dk, #ERRORS))
