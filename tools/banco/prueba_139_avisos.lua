-- Prueba de la 1.3.9, los avisos (área «avisos»):
--   101/106. El Lobo Malo caza bichos: un error de Lua de Alfa da un aviso
--      chico (una vez por error, nunca en combate, se apaga en el Centro); la
--      ventana sencilla del reporte (Error · Mejora · Comentario, «Ver lo que
--      se manda», «Enviar», «Enviar ya por el navegador», «Copiar»); el buzón
--      AlfaNucleoDB.buzon.pendientes (el contrato con el instalador) y el
--      enlace del formulario (acentos y saltos de línea codificados, ≤ 1800).
--   67. El Centro de avisos: cada tipo con su interruptor y «Probar».
--   68. Lo que se repite mucho se calla solo («Ya te lo dije 3 veces»).
--   69. Lya más tranquila con personajes nuevos en la primera hora.
--   41. Lya: «¿Qué hago ahora?».
--   66. Los números con su separador de miles (y el oro).
--   70. Los sonidos parejos (la firma de Combate ya no es el «aggro»).
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-139-*.png; BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.3.9 avisos", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end

local A = Alfa
local K = N.Kit
local M = NS_OF("Alfa_Bienvenida")
local Ly = NS_OF("Alfa_Lya")
if N.Entrando then N.Entrando = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local combate = false
InCombatLockdown = function() return combate end
local function cerrarAvisos()
  for _ = 1, 6 do
    local hubo = false
    for _, f in ipairs({ UIParent:GetChildren() }) do
      if rawget(f, "alfaVivo") and f.Cerrar then f:Cerrar() hubo = true end
    end
    if not hubo then break end
  end
end
local function avisoCon(titulo)
  local hallado
  local function buscar(f)
    for _, h in ipairs(rawget(f, "_children") or {}) do
      if rawget(h, "alfaVivo") and h.Titulo and tostring(h.Titulo:GetText() or ""):find(titulo, 1, true) then hallado = h end
      buscar(h)
    end
  end
  buscar(UIParent)
  return hallado
end
-- Un fondo nocturno para las capturas (nada de verde liso).
local function fondo(de, extra)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetPoint("TOPLEFT", de, "TOPLEFT", -16, 16)
  f:SetPoint("BOTTOMRIGHT", de, "BOTTOMRIGHT", 16, -16)
  local c = f:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(f)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.05, 1), CreateColor(0.09, 0.11, 0.15, 1))
  f:Show()
  return f
end

---------------------------------------------------------------------------
-- 101. El buzón: el contrato con el instalador
---------------------------------------------------------------------------
step("El buzón guarda cada reporte con sus campos exactos", function()
  local Bz = M.Buzon
  check(Bz and Bz.Guardar and Bz.Pendientes and Bz.Limpiar, "falta el buzón")
  if not Bz then return end
  AlfaNucleoDB.buzon = nil
  local e = Bz.Guardar(("x"):rep(3000), "mejora", "lo que escribí", "datos")
  local l = AlfaNucleoDB.buzon and AlfaNucleoDB.buzon.pendientes
  check(type(l) == "table" and l[1] == e, "no quedó en AlfaNucleoDB.buzon.pendientes")
  check(e.enviado == false, "enviado no es el booleano false: " .. tostring(e.enviado))
  check(type(e.texto) == "string" and #e.texto <= 1950, "texto no es un texto de 1950 como mucho")
  check(type(e.id) == "string" and e.id ~= "", "falta el id")
  check(type(e.fecha) == "string" and e.fecha:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$"), "la fecha no es AAAA-MM-DD HH:MM: " .. tostring(e.fecha))
  check(type(e.version) == "string" and e.version ~= "", "falta la versión")
  check(e.tipo == "mejora", "el tipo no se guardó")
  check(e.escrito == "lo que escribí" and e.tecnico == "datos", "faltan escrito y tecnico")
  -- El mismo texto sin mandar no se guarda dos veces.
  local e2, ya = Bz.Guardar(e.texto, "mejora")
  check(ya and e2 == e and #l == 1, "el mismo reporte se guardó dos veces")
  -- Tope de 20: se va el más viejo.
  for i = 1, 25 do Bz.Guardar("reporte " .. i, "error") end
  check(#l == 20, "el buzón pasó de 20: " .. #l)
  check(l[#l].texto == "reporte 25" and l[1].texto == "reporte 6", "no se fue el más viejo")
  check(Bz.Pendientes() == 20, "no cuenta 20 pendientes")
  -- El instalador marca dos como enviados: ya no cuentan, y al entrar se quitan.
  l[1].enviado, l[2].enviado = true, true
  check(Bz.Pendientes() == 18, "los enviados siguen como pendientes")
  Bz.Limpiar()
  check(#l == 18, "al entrar no se quitaron los enviados")
  check(AlfaReporte.Pendientes() == 18, "AlfaReporte.Pendientes no lo sabe")
  -- Ningún dato personal.
  for _, x in ipairs(l) do
    check(not tostring(x.texto):find(tostring(UnitName and UnitName("player") or "\1"), 1, true), "un reporte lleva tu nombre")
  end
  AlfaNucleoDB.buzon = nil
end)

---------------------------------------------------------------------------
-- 101. El enlace del formulario
---------------------------------------------------------------------------
step("El enlace del formulario se arma bien (acentos, saltos, tope)", function()
  check(type(M.EnlaceFormulario) == "function", "falta M.EnlaceFormulario")
  if not M.EnlaceFormulario then return end
  local url = M.EnlaceFormulario("error", "Abrí el mapa\ny salió", "Alfa 1.3.9 · cliente", "1.3.9", "K7QM2F")
  check(url:find("^https://docs%.google%.com/forms/d/e/1FAIpQLSfCKW97uxmZL5ZGl5Ym4hLjUMTWt6O0N7TJgw6buSDMoRIXUA/viewform%?usp=pp_url"), "no empieza con el formulario")
  check(url:find("&entry.832145550=Error&", 1, true), "el tipo no es «Error»: " .. url)
  -- 1.4.0 (71): un solo texto: «Código: X», lo escrito y, tras «— Datos de Alfa —», lo técnico.
  check(url:find("&entry.1889667288=C%C3%B3digo%3A%20K7QM2F%0A%0AAbr%C3%AD%20el%20mapa%0Ay%20sali%C3%B3%0A%0A%E2%80%94%20Datos%20de%20Alfa%20%E2%80%94%0AAlfa%201.3.9%20%C2%B7%20cliente&", 1, true), "el texto del formulario no lleva código, lo escrito y los datos: " .. url)
  check(not url:find("entry.917548369", 1, true), "sigue mandando el campo borrado de datos técnicos")
  check(url:find("&entry.1259972415=1.3.9", 1, true), "falta la versión")
  check(not url:find(" ", 1, true) and not url:find("\n", 1, true), "quedaron espacios o saltos sin codificar")
  check(M.EnlaceFormulario("mejora", "", "", "1"):find("entry.832145550=Mejora&", 1, true), "el tipo de mejora no es «Mejora»")
  check(M.EnlaceFormulario("comentario", "", "", "1"):find("entry.832145550=Comentario&", 1, true), "el tipo de comentario no es «Comentario»")
  -- Largo: lo técnico se recorta y nunca pasa de 1800; ruso largo, igual.
  local largo = M.EnlaceFormulario("error", ("Ошибка "):rep(200), ("línea técnica\n"):rep(300), "1.3.9")
  check(#largo <= 1800, "el enlace pasó de 1800: " .. #largo)
  check(largo:find("Ошибка", 1, true) == nil and largo:find("%D0%9E", 1, true), "lo escrito largo no quedó en el enlace")
  -- El formulario de capturas, aparte, con el código.
  check(M.EnlaceCapturas and M.EnlaceCapturas("K7QM2F") == "https://docs.google.com/forms/d/e/1FAIpQLSd8g5jhxh6AM5p9oAKSqz4LocnRLNhtIxpeYqP3Rx2o8KFV4Q/viewform?usp=pp_url&entry.1102491070=K7QM2F", "el enlace de capturas no es el del formulario con el código")
  check(M.NuevoCodigo and #M.NuevoCodigo() == 6 and not M.NuevoCodigo():find("[IL01O]"), "el código no es corto y claro")
  check(largo:find("entry.1259972415=1.3.9", 1, true), "al recortar se perdió la versión")
  check(not largo:find("%%[0-9A-F]?$") and not largo:find("%%[CD][0-9A-F]%%?$"), "se cortó a media letra")
  -- Lo que se arma de la ventana: los datos técnicos sin nombre ni reino.
  local texto, escrito, tecnico = M.ComponerPartes()
  check(type(texto) == "string" and type(escrito) == "string" and type(tecnico) == "string", "ComponerPartes no da las tres partes")
end)

---------------------------------------------------------------------------
-- 101/106. La ventana sencilla
---------------------------------------------------------------------------
step("La ventana: escribir, Enviar, Enviar ya por el navegador y Copiar", function()
  AlfaNucleoDB.buzon = nil
  N.BorrarErrores()
  N.AnotarError("Interface/AddOns/Alfa_Bolsas/Bolsas.lua:12: attempt to index a nil value",
    "[string \"@Interface/AddOns/Alfa_Bolsas/Bolsas.lua\"]:12: in function `Abrir'\n[string \"@Interface/AddOns/Alfa_Bolsas/Ventana.lua\"]:40: in function <x>\n[C]: ?")
  AlfaReporte.Abrir("error")
  local v, ui = M.ReporteUI()
  -- El reporte se ve de Alfa Forever: renglones con su etiqueta, sin Markdown.
  do
    ui.texto = "Abrí las bolsas"
    local texto, escrito, tecnico = M.ComponerPartes()
    local lobo = M.LOBO_EMOJI
    check(texto:find(lobo .. " Reporte de Alfa Forever · Error\n", 1, true) == 1,"el título no es «🐺 Reporte de Alfa Forever · Error»: " .. texto:sub(1, 60))
    check(escrito == "Abrí las bolsas", "escrito no es tal cual lo que se escribió")
    check(tecnico:find("^" .. lobo .. " Alfa Forever "), "lo técnico no empieza con «🐺 Alfa Forever»")
    check(tecnico:find("\nPersonaje: [^\n]* nivel %d+"), "falta «Personaje: <clase> nivel N»")
    check(tecnico:find("\nLugar: ", 1, true), "falta «Lugar:»")
    check(tecnico:find("\nMódulo: Alfa_Bolsas", 1, true), "falta «Módulo: Alfa_Bolsas»")
    check(tecnico:find("\nError: [", 1, true) and tecnico:find("Bolsas.lua:12", 1, true), "falta «Error:» con el error")
    check(tecnico:find("\n  Alfa_Bolsas/Ventana.lua:40", 1, true), "falta la traza corta del error")
    check(tecnico:find("\nAcciones bloqueadas: ", 1, true), "falta «Acciones bloqueadas:»")
    check(tecnico:find("Otros addons", 1, true), "falta «Otros addons»")
    check(not texto:find("```", 1, true) and not texto:find("**", 1, true), "el reporte trae Markdown")
    check(#texto <= 1950 and #tecnico <= 1950, "el reporte pasó de 1950")
    local nombre = UnitName and UnitName("player")
    if type(nombre) == "string" and nombre ~= "" then check(not texto:find(nombre, 1, true), "el reporte lleva tu nombre") end
    ui.texto = ""
  end
  check(v and v:IsShown(), "/alfa reportar no abrió la ventana")
  if not (v and ui) then return end
  check(ui.pregunta.Texto:GetText() == "¿Qué hacías cuando pasó? (opcional)", "la pregunta del error no es la sencilla")
  check(ui.captura:IsShown() and tostring(ui.captura.Texto:GetText()):find("Screenshots", 1, true), "no recuerda la captura (106)")
  check(not ui.reporte:IsShown(), "lo técnico no viene plegado")
  check(ui.enviar and ui.enviar:IsShown() and ui.navegador and ui.navegador:IsShown(), "faltan «Enviar» o «Enviar ya por el navegador»")
  SNAP("reporte", fondo(v), { v })
  -- 1.4.0 (71): lo técnico ya no se enseña, pero se sigue armando y mandando.
  check(ui.plegar == nil, "sigue el botón «Ver lo que se manda»")
  check(ui.capturasForm and ui.capturasForm:IsShown() and tostring(ui.capturasForm.Texto:GetText()):find("capturas", 1, true), "no dice que las capturas se suben en el formulario (71)")
  local r = ui.reporte.Cuadro.texto or ""
  check(r:find("Bolsas.lua:12", 1, true), "lo que se manda no lleva el error atrapado")
  -- Escribir y Enviar.
  ui.texto = "Abrí las bolsas en el banco"
  ui.entrada:Set(ui.texto)
  ui.enviar:Click()
  local l = AlfaNucleoDB.buzon and AlfaNucleoDB.buzon.pendientes or {}
  check(#l == 1 and l[1].tipo == "error" and l[1].enviado == false, "«Enviar» no lo guardó en el buzón")
  check(l[1] and l[1].escrito == "Abrí las bolsas en el banco", "no guardó lo escrito aparte")
  check(l[1] and tostring(l[1].tecnico):find("Bolsas.lua:12", 1, true), "no guardó lo técnico aparte")
  check(ui.gracias:IsShown() and tostring(ui.gracias.Texto:GetText()):find("instalador", 1, true), "no dio las gracias ni dijo lo del instalador")
  check(not tostring(ui.gracias.Texto:GetText()):find("pégalo", 1, true), "las gracias siguen mandando a pegar en Discord")
  check(ui.pendientes:IsShown(), "no dice cuántos esperan al instalador")
  SNAP("reporte-enviado", fondo(v), { v })
  -- Otra vez: ya estaba.
  ui.enviar:Click()
  check(#l == 1, "«Enviar» dos veces guardó dos")
  -- Por el navegador.
  local url = M.EnlaceReporte()
  check(ui.enlace:IsShown() and ui.navegadorNota:IsShown(), "no salió el enlace para copiar")
  check(url:find("Abr%C3%AD%20las%20bolsas", 1, true), "el enlace no lleva lo escrito")
  local cod = M.CodigoReporte()
  check(url:find("C%C3%B3digo%3A%20" .. cod, 1, true), "el enlace no empieza con el código del reporte")
  check(l[1] and l[1].id == cod, "el id del buzón no es el código que ve el jugador")
  check(ui.codigoTexto:IsShown() and ui.codigoTexto.Texto:GetText() == "Código: " .. cod, "no enseña «Código: X»")
  check(tostring(l[1] and l[1].texto):find("Código: " .. cod, 1, true), "el texto guardado no lleva el código")
  -- Subir capturas: el enlace aparte, con el código, para copiar.
  check(not ui.capturasEnlace:IsShown(), "el enlace de capturas sale antes de pedirlo")
  ui.subirCapturas.Hijo:Click()
  check(ui.capturasEnlace:IsShown() and ui.capturasNota:IsShown(), "«Subir capturas» no enseñó el enlace")
  check(tostring(ui.capturasEnlace.Cuadro.texto):find("entry.1102491070=" .. cod, 1, true), "el enlace de capturas no lleva el código")
  check(tostring(ui.capturasNota.Texto:GetText()):find("hasta 5 capturas", 1, true), "falta la línea de cómo subirlas")
  check(#url <= 1800, "el enlace de la ventana pasó de 1800")
  SNAP("reporte-navegador", fondo(v), { v })
  -- Copiar (extra): el reporte y el Discord.
  ui.copiar:Click()
  check(ui.reporte:IsShown() and ui.donde:IsShown(), "«Copiar» no enseñó el reporte y dónde pegarlo")
  check(tostring(ui.donde.Texto:GetText()):find("#buzon-alfa", 1, true), "el canal no es #buzon-alfa")
  -- Mejora sin texto: no se envía.
  ui.texto = ""
  ui.entrada:Set("")
  M.AbrirReporte("mejora")
  check(M.EnviarReporte() == nil and ui.estado:IsShown(), "una mejora vacía se envió")
  v:Cerrar()
  AlfaNucleoDB.buzon = nil
  N.BorrarErrores()
end)

---------------------------------------------------------------------------
-- 101. El aviso del bicho
---------------------------------------------------------------------------
step("Un error nuevo de Alfa da un aviso chico, una vez y nunca en combate", function()
  BANCO_BICHO = true
  M.OlvidarBichos()
  cerrarAvisos()
  N.BorrarErrores()
  NOW = NOW + 60
  combate = true
  N.AnotarError("Interface/AddOns/Alfa_Mundo/Mapa.lua:77: bicho uno", nil)
  RUN_TIMERS(3)
  check(avisoCon("Alfa encontró un error") == nil, "el aviso del bicho salió en combate")
  combate = false
  -- (sin RUN_TIMERS: correría también el reloj que lo cierra)
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  local a = avisoCon("Alfa encontró un error")
  check(a ~= nil, "al salir de combate no salió el aviso del bicho")
  if a then
    check(a.Icono:GetTexture() == M.LOBO_MALO, "el aviso no lleva al Lobo Malo")
    check(a.Boton and a.Boton:IsShown(), "el aviso no trae «Reportar»")
    SNAP("bicho", fondo(a), { a })
    a.Boton:Click()
    local v = M.ReporteUI()
    check(v and v:IsShown(), "«Reportar» no abrió la ventana")
    if v then v:Cerrar() end
  end
  cerrarAvisos()
  -- El mismo error otra vez, o uno ajeno: nada.
  local kav, n0 = K.Aviso, 0
  K.Aviso = function(o) if o and o.titulo == "Alfa encontró un error" then n0 = n0 + 1 end return kav(o) end
  NOW = NOW + 60
  N.AnotarError("Interface/AddOns/Alfa_Mundo/Mapa.lua:77: bicho uno", nil)
  RUN_TIMERS(3)
  check(n0 == 0, "el mismo error avisó dos veces")
  N.AnotarError("Interface/AddOns/OtroAddon/x.lua:1: ajeno", nil)
  RUN_TIMERS(3)
  check(n0 == 0, "un error ajeno dio aviso")
  K.Aviso = kav
  -- Apagado en el Centro de avisos.
  A.Set("nucleo.avisos.errores", false)
  check(M.NuevoBicho({ msg = "otro" }) == false, "con el Centro apagado igual avisa")
  A.Set("nucleo.avisos.errores", nil)
  -- Tres por sesión como mucho.
  M.OlvidarBichos()
  local n = 0
  for i = 1, 5 do if M.NuevoBicho({ msg = "bicho " .. i }) then n = n + 1 end end
  check(n == 3, "avisó de más de 3 bichos en la sesión: " .. n)
  RUN_TIMERS(3)
  cerrarAvisos()
  BANCO_BICHO = nil
  N.BorrarErrores()
end)

---------------------------------------------------------------------------
-- 67. El Centro de avisos
---------------------------------------------------------------------------
step("Centro de avisos: un tipo apagado no sale; «Probar» sí", function()
  cerrarAvisos()
  NOW = NOW + 60
  check(A.Get("nucleo.avisos.bolsas") == true, "de fábrica los avisos de Bolsas no están prendidos")
  A.Set("nucleo.avisos.bolsas", false)
  local r = K.Aviso({ titulo = "Prueba del centro apagado", firma = "bolsas", lya = false })
  check(r == false, "un aviso de un tipo apagado salió")
  r = K.Aviso({ titulo = "Prueba del centro urgente", firma = "bolsas", lya = false, prioridad = 1 })
  check(type(r) == "table", "lo urgente de un tipo apagado no salió")
  if type(r) == "table" then r:Cerrar() end
  local p = N.ProbarAviso("bolsas")
  check(type(p) == "table" and tostring(p.Texto:GetText()):find("apagado", 1, true), "«Probar» no salió o no dice que está apagado")
  if type(p) == "table" then p:Cerrar() end
  A.Set("nucleo.avisos.bolsas", nil)
  check(A.Get("nucleo.avisos.bolsas") == true, "no volvió a prenderse")
  -- Todos los tipos, con su nombre y en orden; errores incluido.
  local tipos = N.TiposDeAviso()
  local hay = {}
  for _, c in ipairs(tipos) do hay[c] = true end
  check(hay.errores and hay.ruta and hay.lya and #tipos >= 17, "faltan tipos en el Centro")
  -- El grupo de ajustes se arma y sus filas leen su ajuste.
  local caja = CreateFrame("Frame", nil, UIParent)
  caja:SetSize(620, 900)
  caja:SetPoint("CENTER")
  local g = N.GrupoCentroAvisos(caja)
  check(g ~= nil, "no se armó el grupo del Centro")
  if g then
    g:SetPoint("TOPLEFT", caja, "TOPLEFT", 0, 0)
    local h = g:Acomodar(620)
    g:Refrescar()
    check(h > 200, "el Centro salió muy chico")
    SNAP("centro", fondo(g), { g })
  end
  caja:Hide()
end)

---------------------------------------------------------------------------
-- 68. Lo que se repite se calla
---------------------------------------------------------------------------
step("Un aviso que se repite mucho se calla solo y se reactiva", function()
  cerrarAvisos()
  N.ReactivarTodos()
  local salieron, ultima = 0, nil
  for i = 1, 5 do
    NOW = NOW + 120
    if N.OlvidarSucesos then N.OlvidarSucesos() end
    local a = K.Aviso({ titulo = "Repetido de prueba", texto = "Vez " .. i, lya = false, firma = "hoy" })
    if type(a) == "table" then
      salieron = salieron + 1
      if tostring(a.Texto:GetText()):find("Ya te lo dije", 1, true) then ultima = a end
      if i == 4 then
        SNAP("callado", fondo(a), { a })
      end
      a:Cerrar()
    end
  end
  check(salieron == 4, "salieron " .. salieron .. " (deben ser 3 y la del «Ya te lo dije»)")
  check(ultima ~= nil, "la cuarta no dijo «Ya te lo dije»")
  check(N.Callados() == 1, "no cuenta el callado")
  if ultima and ultima.Boton2 then
    check(ultima.Boton:IsShown() or ultima.Boton2:IsShown(), "la cuarta no trae «Seguir avisando»")
  end
  N.ReactivarTodos()
  NOW = NOW + 120
  if N.OlvidarSucesos then N.OlvidarSucesos() end
  local a = K.Aviso({ titulo = "Repetido de prueba", texto = "Otra vez", lya = false, firma = "hoy" })
  check(type(a) == "table", "«Reactivar todos» no lo volvió a prender")
  if type(a) == "table" then a:Cerrar() end
  -- Apagado el ajuste, nunca se calla; lo urgente tampoco.
  A.Set("nucleo.callarRepetidos", false)
  for _ = 1, 6 do check(N.Repeticion({ titulo = "Siempre" }) == "sale", "con el ajuste apagado se calló") end
  A.Set("nucleo.callarRepetidos", nil)
  N.ReactivarTodos()
end)

---------------------------------------------------------------------------
-- 69. Lya más tranquila con personajes nuevos
---------------------------------------------------------------------------
step("Lya habla menos la primera hora con un personaje nuevo", function()
  local Ce = Ly and Ly.Cerebro
  check(Ce and Ce.Novato and Ce.Intervalo, "falta Ce.Novato / Ce.Intervalo")
  if not (Ce and Ce.Novato) then return end
  local ul = UnitLevel
  UnitLevel = function() return 20 end
  Ce.EmpezoSesion(NOW)
  local normal = Ce.Intervalo()
  check(not Ce.Novato(), "un personaje de nivel 20 cuenta como nuevo")
  UnitLevel = function() return 5 end
  check(Ce.Novato(), "un personaje de nivel 5 en su primera hora no cuenta como nuevo")
  check(Ce.Intervalo() == normal * 3, "con un personaje nuevo no espera el triple")
  Ce.EmpezoSesion(NOW - 3700)
  check(not Ce.Novato(), "pasada la hora sigue tranquila")
  Ce.EmpezoSesion(NOW)
  A.Set("lya.calmaNuevos", false)
  check(not Ce.Novato(), "con el ajuste apagado sigue tranquila")
  A.Set("lya.calmaNuevos", nil)
  UnitLevel = ul
  Ce.EmpezoSesion(NOW - 99999)
end)

---------------------------------------------------------------------------
-- 41. «¿Qué hago ahora?»
---------------------------------------------------------------------------
step("Lya: «¿Qué hago ahora?» da tu siguiente mejor acción con su botón", function()
  local Ce = Ly and Ly.Cerebro
  check(Ce and Ce.SiguienteAccion and Ce.QueHagoAhora, "falta «¿Qué hago ahora?»")
  if not (Ce and Ce.SiguienteAccion) then return end
  local dur = GetInventoryItemDurability
  GetInventoryItemDurability = function(slot) if slot == 5 then return 10, 100 end return 90, 100 end
  local s = Ce.SiguienteAccion()
  check(s.clave == "reparar" and s.acciones and s.acciones[1], "con el equipo roto no manda a reparar: " .. tostring(s.clave))
  check(s.texto:find("10 %", 1, true), "no dice el %: " .. s.texto)
  GetInventoryItemDurability = function() return 90, 100 end
  s = Ce.SiguienteAccion()
  check(s.clave ~= "reparar", "con el equipo bien sigue mandando a reparar")
  check(type(s.texto) == "string" and s.texto ~= "" and s.acciones and s.acciones[1], "sin pendientes no dice qué hacer con un botón")
  GetInventoryItemDurability = dur
  -- El menú de Lya lo trae arriba y sigue en 10 filas.
  local f = rawget(_G, "AlfaLyaLoba")
  if f then
    local menu, opciones = K.Menu, nil
    K.Menu = function(_, o) opciones = o end
    FIRE(f, "OnClick", "RightButton")
    K.Menu = menu
    check(opciones and opciones[1] and opciones[1].valor == "ahora", "«¿Qué hago ahora?» no va primero en el menú de Lya")
    check(opciones and #opciones <= 10, "el menú de Lya pasó de 10 filas")
  end
  -- Lo dice en su globo.
  local decir = Ce.Decir
  local dicho
  Ce.Decir = function(c) dicho = c return true end
  Ce.QueHagoAhora()
  Ce.Decir = decir
  check(dicho and dicho.pedido and dicho.acciones, "Lya no lo dijo con su botón")
end)

---------------------------------------------------------------------------
-- 66 y 70. Números y sonidos
---------------------------------------------------------------------------
step("Los números con su separador de miles y el oro igual", function()
  check(N.Numero and N.Numero(1234567) == "1,234,567", "en español no sale 1,234,567: " .. tostring(N.Numero and N.Numero(1234567)))
  check(N.Numero(999) == "999" and N.Numero(-12345) == "-12,345" and N.Numero(0) == "0", "N.Numero falla con 999, -12345 o 0")
  local loc = N.locale
  N.locale = "deDE"
  check(N.Numero(1234567) == "1.234.567", "en alemán no sale 1.234.567: " .. N.Numero(1234567))
  N.locale = "frFR"
  check(N.Numero(12345) == "12\194\160" .. "345", "en francés no sale 12 345 con espacio fijo")
  N.locale = loc
  check(N.DineroTexto(123456789):find("12,345", 1, true), "el oro no lleva separador: " .. N.DineroTexto(123456789))
end)

step("Los sonidos de Alfa, parejos", function()
  local f = K.FIRMAS.combate
  check(f and f.sonido ~= "IG_CREATURE_AGGRO_SELECT", "la firma de Combate sigue siendo el «aggro» del juego")
  for c, x in pairs(K.FIRMAS) do
    check(type(x.sonido) == "string" and type(x.id) == "number", "la firma " .. c .. " no tiene su sonido con respaldo")
  end
end)

print(("1.3.9 avisos: %d pasos"):format(pasos))
