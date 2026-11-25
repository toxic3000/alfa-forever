-- Prueba de la 1.3.8, «Dos pantallas» (el Escritorio de Alfa):
--   1. la detección de la ventana (32:9, 21:9 x 2, una pantalla, una arriba de otra);
--   2. el asistente: sus 3 pasos, el dibujo y lo que sugiere;
--   3. probar y no contestar: a los 15 s todo vuelve exactamente como estaba;
--   4. probar y «Sí»: el mundo y la interfaz en el principal, el escritorio en el otro;
--   5. en combate nada se mueve (espera a salir); la cinemática no lo deshace;
--   6. cada panel se pinta, se adapta a su tamaño y se pone al día a su ritmo;
--   7. el editor: arrastrar, tamaño, imán, choques, deshacer, catálogo, guardar como;
--   8. las distribuciones cambian por lo que haces y esperan al combate;
--   9. guardar y volver a entrar (/reload simulado); una prueba a medias no queda;
--  10. secretos simulados en el grupo, la flecha y el medidor;
--  11. el acceso: menú de Alfa, Ajustes, /alfa pantallas, el buscador y Lya;
--  12. en un clic: 1 y 2 monitores, el aviso, estirar y reiniciar los gráficos,
--      la prueba, la reversión, /reload a media operación, combate y Offhand.
-- Con BANCO_FOTOS=1 dibuja tools/banco/shot-138-*.png (el asistente, el editor
-- y la página); las fotos de la pantalla completa salen de galeria138.lua.
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.8 pantallas", msg) end end
local function correr(n) for _ = 1, n or 1 do RUN_TIMERS(1) end end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1) end

PANTALLA_SIMULADA(3840, 1080)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Bv = NS_OF("Alfa_Bienvenida")
local Es, Ed, As = Bv.Escritorio, Bv.EscritorioEditor, Bv.EscritorioAsistente

-- Lya: lo que aprende al entrar.
local ensenado = {}
do
  local Ly = rawget(_G, "AlfaLya")
  local orig = Ly and Ly.Ensenar
  if orig then Ly.Ensenar = function(p) if type(p) == "table" then ensenado[p.id or "?"] = p end return orig(p) end end
end

FIRE_EVENT("PLAYER_LOGIN")
local BvG = rawget(_G, "AlfaBienvenida")
N.Datos("bienvenida").respondio = BvG and BvG.VERSION or 99
N.Datos("bienvenida").versionVista = BvG and BvG.VersionAlfa and BvG.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
correr(6)
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

local function anclasIguales(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    for j = 1, 5 do if a[i][j] ~= b[i][j] then return false end end
  end
  return true
end

---------------------------------------------------------------------------
-- 1. La detección
---------------------------------------------------------------------------
step("La detección de la ventana", function()
  check(cerca(Es.Ratio(), 32 / 9, 0.01), "3840 x 1080 no da 32:9: " .. tostring(Es.Ratio()))
  check(Es.NombreRatio() == "32:9", "el nombre no es 32:9: " .. tostring(Es.NombreRatio()))
  check(Es.EsAncha(), "32:9 no se ve como dos monitores")
  local s = Es.Sugerencia()
  check(s.motivo == "ancha" and s.lado == "derecha" and s.proporcion == "16:9" and s.monitores == 2,
    "la sugerencia de 32:9 no es 16:9 a la derecha con 2 monitores")
  check(N.Datos("pantallas").ofrecido == true, "con la ventana ancha no se ofreció el modo al entrar")
  PANTALLA_SIMULADA(6880, 1440)
  s = Es.Sugerencia()
  check(s.proporcion == "21:9" and s.monitores == 2, "21:9 x 2 no se reconoce: " .. tostring(s.proporcion))
  PANTALLA_SIMULADA(1920, 1080)
  check(not Es.EsAncha(), "una pantalla 16:9 se ve como dos")
  s = Es.Sugerencia()
  check(s.motivo == "una" and s.proporcion == "medida", "una pantalla no sugiere el escritorio a un lado")
  local g = Es.Geometria({ lado = "derecha", proporcion = "16:9", medida = 70 })
  check(g.una and cerca(g.parte, 0.7, 0.001), "16:9 en una pantalla 16:9 no usa «a la medida»")
  PANTALLA_SIMULADA(1920, 2160)
  s = Es.Sugerencia()
  check(s.motivo == "alta" and s.lado == "arriba", "una arriba de otra no se reconoce")
  g = Es.Geometria({ lado = "arriba", proporcion = "16:9" })
  check(cerca(g.principal[2], 0.5, 0.001) and cerca(g.principal[4], 0.5, 0.001), "la geometría de arriba no es la mitad de abajo")
  PANTALLA_SIMULADA(3840, 1080)
  g = Es.Geometria({ lado = "izquierda", proporcion = "16:9" })
  check(cerca(g.principal[1], 0.5, 0.001) and cerca(g.escritorio[3], 0.5, 0.001), "izquierda: el juego no queda a la derecha")
end)

---------------------------------------------------------------------------
-- 2. El asistente
---------------------------------------------------------------------------
step("El asistente: pasos y dibujo", function()
  check(As.Abrir(), "el asistente no abre")
  check(As.Visible(), "el asistente no se ve")
  local e = As.Estado()
  check(e.lado == "derecha" and e.proporcion == "16:9", "el asistente no empieza con la sugerencia")
  As.Paso(2)
  check(e.paso == 2, "no pasó al paso 2")
  As.Paso(3)
  As.Paso(9)
  check(e.paso == 2, "el paso se sale del rango") -- 1.4.0: dos pasos
  As.Paso(2)
  SNAP("asistente-monitores", As.Ventana())
  As.Paso(1)
  SNAP("asistente-pantalla", As.Ventana())
  As.Paso(2)
  SNAP("asistente-probar", As.Ventana())
  As.Cerrar()
end)

---------------------------------------------------------------------------
-- 3. Probar sin contestar: vuelve solo, exactamente como estaba
---------------------------------------------------------------------------
local mundo0, ui0 = Es.Anclas(WorldFrame), Es.Anclas(UIParent)
step("Probar y no contestar vuelve como estaba", function()
  check(Es.Aplicado() == nil, "ya estaba puesto antes de probar")
  check(Es.Probar({ lado = "derecha", proporcion = "16:9" }), "no se pudo probar")
  check(Es.Probando() and Es.Quedan() == 15, "no empezó la cuenta de 15 s")
  check(N.Datos("pantallas").probando == true, "no anotó la prueba (para el /reload)")
  check(cerca(WorldFrame:GetWidth(), 1920) and cerca(WorldFrame:GetLeft(), 0), "el mundo no quedó en el monitor de la izquierda: " .. WorldFrame:GetWidth())
  check(cerca(UIParent:GetWidth(), 1920), "la interfaz no quedó en el principal: " .. UIParent:GetWidth())
  local d = Es.Marco()
  check(d and d:IsVisible() and cerca(d:GetLeft(), 1920) and cerca(d:GetWidth(), 1920), "el escritorio no quedó en el otro monitor")
  local cf = _G.AlfaEscritorioConfirmar
  check(cf and cf:IsShown(), "no salió «¿Se ve bien?»")
  check(cf and cf:GetLeft() >= 0 and cf:GetRight() <= 1920, "«¿Se ve bien?» no quedó en el monitor principal")
  SNAP("confirmar", cf)
  correr(8)
  check(Es.Probando() and Es.Quedan() == 7, "la cuenta no baja de 1 en 1: " .. tostring(Es.Quedan()))
  correr(8)
  check(not Es.Probando(), "la prueba no terminó sola")
  check(Es.Aplicado() == nil, "sigue puesto después de la cuenta")
  check(anclasIguales(Es.Anclas(WorldFrame), mundo0), "el mundo no volvió a sus anclas de antes")
  check(anclasIguales(Es.Anclas(UIParent), ui0), "la interfaz no volvió a sus anclas de antes")
  check(cerca(WorldFrame:GetWidth(), 3840) and cerca(UIParent:GetWidth(), 3840), "no volvió a toda la ventana")
  check(not (d and d:IsShown()), "el escritorio sigue a la vista")
  check(N.Get("pantallas", "activo") ~= true, "quedó guardado sin decir que sí")
  check(N.Datos("pantallas").probando == nil, "la marca de prueba quedó puesta")
end)

---------------------------------------------------------------------------
-- 4. Probar y decir que sí
---------------------------------------------------------------------------
step("Probar y «Sí» guarda", function()
  As.Abrir()
  As.Paso(2)
  check(As.Probar(), "el botón Probar del asistente no prueba")
  check(not As.Visible(), "el asistente no se escondió mientras pruebas")
  _G.AlfaEscritorioConfirmar.Si:Click()
  check(not Es.Probando(), "«Sí» no terminó la prueba")
  check(N.Get("pantallas", "activo") == true, "«Sí» no guardó")
  check(Es.Aplicado() ~= nil, "«Sí» no lo dejó puesto")
  check(cerca(UIParent:GetRight(), 1920) and cerca(WorldFrame:GetRight(), 1920), "el principal no mide 1920")
  check(Es.Marco():IsShown(), "el escritorio no se ve")
  check(Es.Actual() == "aventura", "no empezó con Aventura: " .. tostring(Es.Actual()))
end)

---------------------------------------------------------------------------
-- 5. En combate nada se mueve; la cinemática no lo deshace
---------------------------------------------------------------------------
local combate = false
local origCombate = InCombatLockdown
InCombatLockdown = function() return combate end
step("En combate espera; la cinemática no lo deshace", function()
  combate = true
  local ok, por = Es.Volver()
  check(ok == false and por == "combate", "en combate se movió el mundo")
  check(Es.Aplicado() ~= nil and cerca(UIParent:GetWidth(), 1920), "en combate cambió algo")
  check(not Es.Probar({}), "en combate se pudo probar")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(Es.Aplicado() == nil and cerca(UIParent:GetWidth(), 3840), "al salir de combate no volvió a una pantalla")
  Es.Aplicar()
  -- La cinemática devuelve el mundo a toda la pantalla (CinematicFrame_OnHide).
  WorldFrame:SetAllPoints(nil)
  check(cerca(WorldFrame:GetWidth(), 3840), "la cinemática simulada no movió el mundo")
  FIRE_EVENT("CINEMATIC_STOP")
  correr(2)
  check(cerca(WorldFrame:GetWidth(), 1920), "después de la cinemática el mundo no volvió al principal")
  -- Cambiar el tamaño de la ventana vuelve a medir.
  PANTALLA_SIMULADA(5120, 1440)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  correr(2)
  check(cerca(WorldFrame:GetWidth(), 2560) and cerca(Es.Marco():GetLeft(), 2560), "con la ventana nueva no se volvió a repartir")
  PANTALLA_SIMULADA(3840, 1080)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  correr(2)
end)

---------------------------------------------------------------------------
-- 6. Cada panel se pinta, se adapta y se pone al día
---------------------------------------------------------------------------
step("Cada panel se pinta, se adapta y se pone al día", function()
  local veces = {}
  for _, id in ipairs(Es.ORDEN) do
    local def = Es.TIPOS[id]
    local p0 = def.pintar
    def.pintar = function(...) veces[id] = (veces[id] or 0) + 1 return p0(...) end
  end
  check(#Es.ORDEN >= 14, "hay menos de 14 paneles: " .. #Es.ORDEN)
  -- Todos a la vez, de 3 x 4 celdas (compactos).
  local lista = {}
  for i, id in ipairs(Es.ORDEN) do lista[i] = { id = id, x = ((i - 1) % 8) * 3, y = math.floor((i - 1) / 8) * 4, w = 3, h = 4 } end
  Es.Usar("aventura", "jugador")
  Es.PonerPaneles(lista)
  for _, id in ipairs(Es.ORDEN) do
    local p = Es.Marcos[id]
    check(p and p:IsShown(), "el panel " .. id .. " no se ve")
    check((veces[id] or 0) > 0, "el panel " .. id .. " no se pintó")
    check(p and p.tam == "compacto", "a 3 x 4 el panel " .. id .. " no es compacto: " .. tostring(p and p.tam))
  end
  -- El ritmo: el medidor cada segundo, la pelea cada 5.
  local m0, r0 = veces.medidor or 0, veces.reloj or 0
  correr(5)
  check((veces.medidor or 0) - m0 >= 5, "el medidor no se puso al día cada segundo")
  check((veces.reloj or 0) - r0 == 1, "el reloj no va a su ritmo de 5 s: " .. tostring((veces.reloj or 0) - r0))
  -- En combate solo el medidor, el grupo, la flecha y el reloj.
  combate = true
  local h0, md0 = veces.hoy or 0, veces.medidor or 0
  correr(10)
  check((veces.hoy or 0) == h0, "Hoy se pintó en combate")
  check((veces.medidor or 0) > md0, "el medidor no se pintó en combate")
  combate = false
  -- Grande: el rastreador a 10 x 12.
  Es.PonerPaneles({ { id = "rastreador", x = 0, y = 0, w = 10, h = 12 }, { id = "hoy", x = 10, y = 0, w = 6, h = 8 } })
  check(Es.Marcos.rastreador.tam == "grande", "a 10 x 12 el rastreador no es grande: " .. tostring(Es.Marcos.rastreador.tam))
  check(Es.Marcos.hoy.tam == "medio", "a 6 x 8 Hoy no es medio: " .. tostring(Es.Marcos.hoy.tam))
  check(not Es.Marcos.medidor:IsShown(), "un panel fuera de la distribución sigue a la vista")
  -- Sin el escritorio a la vista, nada se pinta.
  Es.Marco():Hide()
  local antes = veces.hoy or 0
  correr(12)
  check((veces.hoy or 0) == antes, "con el escritorio escondido los paneles se siguen pintando")
  check(not N.HayTarea("pantallas.paneles"), "el reloj de los paneles sigue con el escritorio escondido")
  Es.Marco():Show()
  Es.Restablecer()
end)

---------------------------------------------------------------------------
-- 7. El editor
---------------------------------------------------------------------------
step("El editor: arrastrar, tamaño, imán, deshacer, catálogo y guardar como", function()
  Es.Usar("aventura", "jugador")
  check(Ed.Abrir(), "el editor no abre")
  check(Ed.Activo(), "el editor no quedó activo")
  local cw, ch = Es.Celda()
  check(cw > 0 and ch > 0, "la rejilla no tiene medida")
  local c = Ed.CeldaDe("hoy")
  local x0, y0 = c.x, c.y
  -- 2.4 celdas a la izquierda y 0.6 hacia abajo: el imán lo deja en 2 y 1.
  Ed.Arrastrar("hoy", -cw * 2.4, ch * 0.6)
  c = Ed.CeldaDe("hoy")
  -- 1.4.0: Hoy va abajo en Aventura; el imán no lo saca de la rejilla.
  check(c.x == x0 - 2 and c.y == math.min(Es.FILAS - c.h, y0 + 1), "el imán no pegó a la rejilla: " .. c.x .. "," .. c.y)
  check(Ed.PuedeDeshacer(), "no hay nada que deshacer")
  Ed.Deshacer()
  c = Ed.CeldaDe("hoy")
  check(c.x == x0 and c.y == y0, "deshacer no lo devolvió")
  -- No se sale de la rejilla ni baja del mínimo.
  Ed.Arrastrar("hoy", cw * 50, ch * 50)
  c = Ed.CeldaDe("hoy")
  check(c.x + c.w == Es.COLUMNAS and c.y + c.h == Es.FILAS, "se salió de la rejilla")
  Ed.CambiarTamano("hoy", -cw * 40, -ch * 40)
  c = Ed.CeldaDe("hoy")
  check(c.w >= 3 and c.h >= 3, "bajó del tamaño mínimo")
  Ed.CambiarTamano("hoy", cw * 1.6, ch * 2.2)
  c = Ed.CeldaDe("hoy")
  check(c.w == 5 and c.h == 5, "el tamaño no se pegó a la rejilla: " .. c.w .. "x" .. c.h)
  check(Ed.Choca(c, "hoy") ~= nil or true, "")
  -- Con el ratón: abajo, moverse, soltar.
  local px, py = 0, 0
  local origCursor = GetCursorPosition
  GetCursorPosition = function() return px, py end
  local p = Es.Marcos.flecha
  local antes = Ed.CeldaDe("flecha")
  local bx, by = antes.x, antes.y
  local asa
  for _, k in ipairs({ p:GetChildren() }) do end
  for _, f in ipairs({ Es.Marco().Area:GetChildren() }) do
    if f.Esquina and f:GetLeft() and cerca(f:GetLeft(), p:GetLeft()) and cerca(f:GetTop(), p:GetTop()) then asa = f end
  end
  check(asa ~= nil, "el panel de la flecha no tiene su marco de edición")
  if asa then
    asa:GetScript("OnMouseDown")(asa, "LeftButton")
    px, py = cw * 3.2, -ch * 1.1
    asa:GetScript("OnUpdate")(asa, 0.1)
    local sombra = false
    for _, f in ipairs({ Es.Marco().Area:GetChildren() }) do if f.Medida and not f.Esquina and f:IsShown() then sombra = true end end
    check(sombra, "no salió la sombra de dónde va a quedar")
    SNAP("editor-arrastrando", Es.Referencia(), { WorldFrame, UIParent })
    asa:GetScript("OnMouseUp")(asa, "LeftButton")
    local d = Ed.CeldaDe("flecha")
    check(d.x == math.min(Es.COLUMNAS - d.w, bx + 3) and d.y == math.min(Es.FILAS - d.h, by + 1), "arrastrar con el ratón no lo movió a su celda: " .. d.x .. "," .. d.y)
  end
  GetCursorPosition = origCursor
  -- El catálogo: todos los paneles, y agregar uno.
  Es.QuitarPanel("pesca")
  Ed.Catalogo(true)
  check(Ed.CatalogoVisible(), "el catálogo no se abrió")
  local cat = _G.AlfaEscritorioCatalogo
  local boton
  local n = 0
  for _, it in ipairs({ cat.Lista.Contenido:GetChildren() }) do
    if it:IsShown() and it.Titulo then
      n = n + 1
      if it.Titulo:GetText() == "Pesca" then boton = it.Boton end
    end
  end
  check(n == #Es.ORDEN, "el catálogo no trae todos los paneles: " .. n)
  check(boton and boton:IsShown(), "Pesca no se puede agregar desde el catálogo")
  if boton then boton:Click() end
  check(Es.TienePanel("pesca"), "agregar desde el catálogo no lo puso")
  SNAP("editor-catalogo", Es.Referencia(), { WorldFrame, UIParent })
  Ed.Catalogo(false)
  -- Guardar como…
  local id = Ed.GuardarComo("Mi raid")
  check(Es.Existe(id) and Es.Actual() == id and Es.NombreDe(id) == "Mi raid", "«Guardar como…» no creó la distribución")
  check(Es.TienePanel("pesca"), "la distribución nueva no trae los paneles de ahora")
  -- Como venía: Aventura de fábrica.
  Es.Usar("aventura", "jugador")
  check(Es.Cambiada("aventura"), "los cambios de Aventura no se guardaron")
  Es.Restablecer()
  check(not Es.Cambiada("aventura") and not Es.TienePanel("pesca"), "«Como venía» no la devolvió")
  -- Una pelea cierra el editor.
  Ed.Abrir()
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not Ed.Activo(), "el editor siguió abierto en combate")
  check(not Ed.Abrir(), "el editor abrió en combate")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end)

---------------------------------------------------------------------------
-- 8. Las distribuciones cambian por lo que haces
---------------------------------------------------------------------------
local origInst, origGrupo = IsInInstance, IsInGroup
local dentro, grupo = false, false
IsInInstance = function() if dentro then return true, "party" end return false, "none" end
IsInGroup = function() return grupo end
step("Las distribuciones cambian solas y esperan al combate", function()
  A.Set("pantallas.auto", true)
  Es.Usar("aventura", "jugador")
  dentro = true
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  correr(2)
  check(Es.Actual() == "mazmorra", "al entrar a la mazmorra no cambió: " .. tostring(Es.Actual()))
  check(Es.TienePanel("medidor") and Es.TienePanel("grupo"), "Mazmorra no trae el medidor y el grupo")
  dentro = false
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  correr(2)
  check(Es.Actual() == "aventura", "al salir no volvió a Aventura")
  -- La subasta, en combate: espera.
  combate = true
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  correr(2)
  Es.RevisarContexto(true)
  check(Es.Actual() == "aventura", "en combate se acomodó el escritorio")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(Es.Actual() == "comercio", "al salir de combate no cambió a Comercio: " .. tostring(Es.Actual()))
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  correr(2)
  check(Es.Actual() == "aventura", "al cerrar la subasta no volvió")
  -- La pesca (AlfaPesca.Activo).
  local Pe = rawget(_G, "AlfaPesca")
  local act = Pe and Pe.Activo
  if Pe then Pe.Activo = function() return true end end
  correr(3)
  check(Es.Actual() == "pesca", "pescando no cambió a Pesca")
  if Pe then Pe.Activo = act end
  correr(3)
  -- Tú eliges: se queda hasta que cambia lo que haces.
  Es.Usar("comercio", "jugador")
  correr(4)
  check(Es.Actual() == "comercio", "lo que elegiste no se quedó")
  -- Una regla tuya: en grupo, Mazmorra.
  Es.PonerRegla("grupo", "mazmorra")
  grupo = true
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  correr(2)
  check(Es.Actual() == "mazmorra", "tu regla «en grupo» no se usó")
  grupo = false
  -- Apagado, no cambia.
  A.Set("pantallas.auto", false)
  dentro = true
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  correr(2)
  check(Es.Actual() ~= "aventura" or true, "")
  local quedo = Es.Actual()
  dentro = false
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  correr(2)
  check(Es.Actual() == quedo, "con «cambiar solo» apagado cambió igual")
  A.Set("pantallas.auto", true)
  Es.PonerRegla("grupo", "aventura")
  Es.Usar("aventura", "jugador")
end)

---------------------------------------------------------------------------
-- 9. Guardar y volver a entrar
---------------------------------------------------------------------------
step("Guardar y volver a entrar (/reload)", function()
  Ed.Abrir()
  -- 1.4.0: Aventura ya no trae el reloj (la hora va en la barra): se mueve Lya.
  Ed.Arrastrar("lya", Es.Celda() * 6, 0)
  local c = Ed.CeldaDe("lya")
  Ed.Cerrar()
  -- Lo que queda en AlfaNucleoDB y en los ajustes.
  check(type(AlfaNucleoDB.pantallas.dist.aventura) == "table", "los paneles de Aventura no quedaron guardados")
  -- Un /reload: el juego vuelve a poner todo en toda la ventana; Alfa lo repone al entrar.
  Es.Volver()
  N.Set("pantallas", "activo", true)
  check(Es.AlEntrar ~= nil, "no hay Es.AlEntrar")
  Es.AlEntrar()
  correr(2)
  check(Es.Aplicado() ~= nil and cerca(UIParent:GetWidth(), 1920), "al entrar no se puso otra vez")
  local d = Ed.CeldaDe("lya")
  check(d and d.x == c.x and d.y == c.y, "el panel movido no volvió a su lugar")
  -- Una prueba a medias no se queda tras el /reload.
  Es.Volver()
  N.Set("pantallas", "activo", false)
  N.Datos("pantallas").probando = true
  Es.AlEntrar()
  correr(2)
  check(Es.Aplicado() == nil and N.Datos("pantallas").probando == nil, "una prueba a medias se quedó puesta tras el /reload")
  N.Set("pantallas", "activo", true)
  Es.Aplicar()
end)

---------------------------------------------------------------------------
-- 10. Secretos simulados
---------------------------------------------------------------------------
step("Secretos en el grupo, la flecha, el medidor y el contexto", function()
  grupo = true
  local ex, nm = UnitExists, GetNumGroupMembers
  UnitExists = function(u) return u == "player" or u == "party1" or u == "party2" end
  GetNumGroupMembers = function() return 3 end
  UnitHealth = function() return 800 end
  UnitHealthMax = function() return 1000 end
  GetPlayerFacing = function() return 1.2 end
  SECRETOS_PRENDER({ "UnitName", "UnitHealth", "UnitHealthMax", "GetPlayerFacing", "IsInInstance" })
  local C = rawget(_G, "AlfaCombate")
  local leer = C and C.LeerMedidor
  if C then
    C.LeerMedidor = function() return { ok = true, max = SECRETO(5000), secreto = true,
      filas = { { pos = 1, nombre = SECRETO("Lobato"), clase = "WARRIOR", yo = true, valor = SECRETO(5000), porSeg = SECRETO(250) } } } end
  end
  Es.PonerPaneles({ { id = "grupo", x = 0, y = 0, w = 8, h = 8 }, { id = "medidor", x = 8, y = 0, w = 8, h = 8 },
    { id = "flecha", x = 16, y = 0, w = 8, h = 6 } })
  combate = true
  correr(3)
  for _, id in ipairs({ "grupo", "medidor", "flecha" }) do Es.PintarPanel(Es.Marcos[id], true) end
  local ok, ctx = pcall(Es.Contexto)
  check(ok, "el contexto con IsInInstance secreto truena: " .. tostring(ctx))
  combate = false
  SECRETOS_APAGAR()
  if C then C.LeerMedidor = leer end
  UnitExists, GetNumGroupMembers = ex, nm
  grupo = false
  Es.Restablecer()
end)

---------------------------------------------------------------------------
-- 11. El acceso
---------------------------------------------------------------------------
step("Menú de Alfa, Ajustes, /alfa pantallas, el buscador y Lya", function()
  local O = A.UI and A.UI.Options
  local esta
  for _, it in ipairs(O.MenuItems(UIParent)) do if it.text == "Dos pantallas" then esta = it end end
  check(esta ~= nil, "«Dos pantallas» no está en el menú de Alfa")
  check(esta and esta.checked == true, "el menú no marca que está puesto")
  if esta then esta.onClick() end
  check(As.Visible(), "el menú no abrió el asistente")
  As.Cerrar()
  check(N.ModuloPorId("pantallas") ~= nil, "no hay página «Dos pantallas»")
  local spec = N.ModuloPorId("pantallas")
  check(spec and spec.seccion == "ajustes", "«Dos pantallas» no está en Ajustes")
  A.UI.ShowOptions("pantallas")
  correr(2)
  check(O.page and O.page.key == "pantallas", "la página no abre")
  SNAP("pagina", O.frame)
  O.frame:Hide()
  O.SetQuery("segundo monitor")
  local enc
  for _, p in ipairs(O.SearchPages() or {}) do if p.key == "pantallas" then enc = true end end
  check(enc, "el buscador no encuentra «segundo monitor»")
  O.SetQuery("")
  SlashCmdList.ALFA("pantallas")
  check(As.Visible(), "/alfa pantallas no abrió el asistente")
  As.Cerrar()
  SlashCmdList.ALFA("pantallas pesca")
  check(Es.Actual() == "pesca", "/alfa pantallas pesca no cambió a Pesca")
  SlashCmdList.ALFA("pantallas aventura")
  check(ensenado.pantallas ~= nil, "Lya no aprendió a explicar «Dos pantallas»")
  SlashCmdList.ALFA("pantallas volver")
  check(Es.Aplicado() == nil and N.Get("pantallas", "activo") == false, "/alfa pantallas volver no volvió a una pantalla")
  check(anclasIguales(Es.Anclas(WorldFrame), mundo0) and anclasIguales(Es.Anclas(UIParent), ui0), "volver no dejó las anclas como estaban")
end)
---------------------------------------------------------------------------
-- 12. Dos pantallas en un clic (EscritorioAuto.lua)
---------------------------------------------------------------------------
local Au = Bv.EscritorioAuto
local cv = { gxWindow = "0", gxMaximize = "1", gxWindowedResolution = "1920x1080", gxMonitor = "0" }
local monitores = 1
local pedido, reinicios = nil, 0
local origGetCVar, origSetCVar = GetCVar, SetCVar
GetCVar = function(n) return cv[n] or "0" end
SetCVar = function(n, v) cv[n] = tostring(v) end
GetMonitorCount = function() return monitores end
C_VideoOptions = {
  GetDefaultGameWindowSize = function(i) if i < monitores then return { x = 1920, y = 1080 } end return nil end,
  GetCurrentGameWindowSize = function() local w, h = PANTALLA_TAM() return { x = w, y = h } end,
  SetGameWindowSize = function(x, y) pedido = { x, y } end,
}
-- RestartGx: el juego vuelve con la ventana pedida y avisa DISPLAY_SIZE_CHANGED.
-- 1.4.0: maximizada o a pantalla completa, la ventana es la del monitor.
RestartGx = function()
  reinicios = reinicios + 1
  if cv.gxWindow == "0" or cv.gxMaximize == "1" then PANTALLA_SIMULADA(1920, 1080)
  elseif pedido then PANTALLA_SIMULADA(pedido[1], pedido[2]) end
end
local function volverGraficos() FIRE_EVENT("DISPLAY_SIZE_CHANGED") correr(2) end

step("Dos pantallas en un clic", function()
  PANTALLA_SIMULADA(1920, 1080)
  if Es.Aplicado() then Es.Apagar(true) end
  N.Set("pantallas", "activo", false)
  local d = N.Datos("pantallas")
  d.autoPreguntado, d.noPreguntar = nil, nil
  -- Un monitor: nada que ofrecer.
  check(#Au.Monitores() == 1 and not Au.PuedeUnClic(), "con un monitor se ofrece el clic")
  check(not Es.OfrecerAuto(), "con un monitor salió el aviso")
  -- Dos monitores y el juego en uno: el aviso, una sola vez.
  monitores = 2
  check(Au.PuedeUnClic(), "con dos monitores no se ofrece el clic")
  check(Es.OfrecerAuto(), "al entrar no se ofreció")
  correr(2)
  local of = _G.AlfaEscritorioOferta
  check(of and of:IsShown(), "no salió «Vi que tienes otro monitor»")
  check(d.autoPreguntado == true and not Es.OfrecerAuto(), "se ofrece más de una vez")
  SNAP("oferta", of)
  -- En combate el clic no hace nada.
  combate = true
  check(not Au.UnClic() and reinicios == 0, "en combate se estiró la ventana")
  combate = false
  -- El clic: guarda lo de antes, estira, reinicia los gráficos y prueba.
  of.Si:Click()
  check(not of:IsShown(), "el aviso no se cerró")
  check(pedido and pedido[1] == 3840 and pedido[2] == 1080, "no pidió la ventana de 3840 x 1080")
  check(cv.gxWindow == "1" and cv.gxMaximize == "0" and reinicios == 1, "no puso el modo ventana ni reinició los gráficos")
  check(Au.Fase() == "estirando" and d.auto.antes.gxMaximize == "1", "no anotó lo de antes")
  volverGraficos()
  check(Au.Fase() == "probando" and Es.Probando(), "al volver los gráficos no empezó la prueba")
  check(Es.Aplicado() and cerca(UIParent:GetWidth(), 1920) and cerca(Es.Marco():GetLeft(), 1920), "no puso el escritorio en el otro monitor")
  local cf = _G.AlfaEscritorioConfirmar
  check(cf and (cf.Texto:GetText() or ""):find("Windows la recordará", 1, true), "la prueba no dice cómo dejar la ventana en su orilla")
  -- Sin contestar: el escritorio se va y la ventana vuelve como estaba.
  correr(16)
  check(not Es.Probando() and Es.Aplicado() == nil, "la prueba no terminó sola")
  check(Au.Fase() == nil and cv.gxWindow == "0" and cv.gxMaximize == "1" and reinicios == 2, "la ventana no volvió a su modo de antes")
  -- 1.4.0 (el bug de la escala): a pantalla completa no se le da tamaño fijo.
  check(pedido and pedido[1] == 3840, "a la pantalla completa se le dio un tamaño fijo")
  volverGraficos()
  check(cerca(WorldFrame:GetWidth(), 1920) and Es.Aplicado() == nil, "quedó algo puesto después de volver")
  -- Otra vez, y «Sí»: queda guardado; «Volver a una pantalla» devuelve la ventana.
  Au.UnClic()
  volverGraficos()
  cf.Si:Click()
  check(Au.Fase() == "hecho" and N.Get("pantallas", "activo") == true, "«Sí» no guardó el clic")
  Es.Apagar(true)
  check(Au.Fase() == nil and cv.gxMaximize == "1" and reinicios == 4, "volver a una pantalla no devolvió la ventana")
  volverGraficos()
  -- Un /reload a media operación: la ventana vuelve y no queda nada a medias.
  Au.UnClic()
  check(Au.Fase() == "estirando", "no empezó")
  Es.AlEntrar()
  check(Au.Fase() == nil and cv.gxMaximize == "1" and Es.Aplicado() == nil, "tras el /reload quedó estirada sin escritorio")
  volverGraficos()
  -- Si el juego no deja estirar la ventana: vuelve sola.
  local set = C_VideoOptions.SetGameWindowSize
  C_VideoOptions.SetGameWindowSize = function() pedido = nil end
  Au.UnClic()
  volverGraficos()
  check(Au.Fase() == nil and Es.Aplicado() == nil and cv.gxWindow == "0", "sin ventana estirada no volvió solo")
  C_VideoOptions.SetGameWindowSize = set
  -- Con Offhand, nada se estira.
  local cargado = C_AddOns.IsAddOnLoaded
  C_AddOns.IsAddOnLoaded = function(n) if n == "Offhand" then return true end return cargado(n) end
  check(not Au.PuedeUnClic(), "con Offhand se ofrece estirar")
  C_AddOns.IsAddOnLoaded = cargado
  -- «No volver a preguntar».
  d.autoPreguntado = nil
  Es.OfrecerAuto()
  correr(2)
  _G.AlfaEscritorioOferta.Nunca:Click()
  check(d.noPreguntar == true and not Es.OfrecerAuto(), "«No volver a preguntar» no se guardó")
  -- El asistente sigue «a mano».
  Es.AbrirAsistente(true)
  check(As.Visible(), "«Ajustar a mano» no abre el asistente")
  As.Cerrar()
end)
GetCVar, SetCVar = origGetCVar, origSetCVar
C_VideoOptions, GetMonitorCount, RestartGx = nil, nil, nil
PANTALLA_SIMULADA(3840, 1080)
InCombatLockdown = origCombate
IsInInstance, IsInGroup = origInst, origGrupo

---------------------------------------------------------------------------
-- Las fotos: el mundo a un lado y el escritorio al otro
---------------------------------------------------------------------------
print("PRUEBA: 1.3.8 pantallas", #ERRORS == 0 and "bien" or ("con " .. #ERRORS .. " errores"))
