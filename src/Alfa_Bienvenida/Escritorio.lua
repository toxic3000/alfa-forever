-- Alfa - Bienvenida: el Escritorio de Alfa, Alfa en tu segundo monitor (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Con la ventana del juego estirada sobre dos monitores (o más), el mundo y
-- la interfaz del juego se quedan en el monitor principal y Alfa pone sus
-- paneles en vivo en el otro. Todo dentro del juego: nada de programas aparte.
--
-- Cómo (lo que el cliente deja hacer a un addon, ver referencia/):
--   * WorldFrame (el mundo 3D) no tiene padre; la cinemática lo achica con
--     ClearAllPoints/SetPoint (Blizzard_FrameXML/Shared/CinematicFrame.lua) y
--     lo devuelve con SetAllPoints(nil) al cerrarse: Alfa lo vuelve a poner.
--   * UIParent tampoco tiene padre: se ancla al rectángulo del monitor
--     principal y toda la interfaz del juego (barras, retrato, minimapa,
--     chat, misiones) lo sigue sola, sin mover marco por marco.
--   * Los dos solo se mueven fuera de combate (N.FueraDeCombate): en combate
--     los marcos protegidos anclados a UIParent lo protegen también.
--   * «Volver a una pantalla» devuelve las anclas exactas que tenían.
--   * La medida de la pantalla sale de un marco propio sin padre que la
--     llena siempre (AlfaEscritorioPantalla), en sus unidades; cada marco se
--     coloca en las suyas (su escala efectiva).
--   * Con el addon Offhand (que ya hace lo mismo con la interfaz), Alfa no
--     mueve nada: solo pone su escritorio en el otro monitor.
-- Probar es como cambiar la resolución: se aplica, y si no dices «Sí» en 15 s
-- vuelve sola a como estaba. Un /reload a media prueba no la deja puesta.
--
-- El escritorio (AlfaEscritorioMarco) es un marco de Alfa (va con «Esconder todo
-- Alfa» y con Alt+Z) en el rectángulo del otro monitor: arriba su barra (la
-- distribución, «Cambia sola», «Editar» y el menú) y abajo los paneles en una
-- rejilla de 24 x 16. Cada panel (EscritorioPaneles.lua) es un marco propio que
-- usa lo que ya hace cada módulo. El editor está en EscritorioEditor.lua, el
-- asistente en EscritorioAsistente.lua y la página en EscritorioPagina.lua.
--
--   /alfa pantallas [probar | volver | editar | <distribución>]
--   AlfaEscritorio.* (abajo): para el menú de Alfa, Lya y el banco.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local type, pairs, ipairs, tonumber, tostring, pcall, next = type, pairs, ipairs, tonumber, tostring, pcall, next
local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local format, tinsert, tremove = string.format, table.insert, table.remove

local Es = {}
M.Escritorio = Es
local ID = "pantallas"
Es.ID = ID
Es.COLUMNAS, Es.FILAS = 24, 16
Es.BARRA = 56
Es.GAP = 12 -- 1.4.0: más aire entre paneles (se ve el cielo de Alfa)
Es.CABECERA = 34
Es.PRUEBA_SEG = 15
-- 1.4.0: el tamaño de los paneles (pantallas.tamano): todo crece junto,
-- letras incluidas, para leerlo desde la silla.
Es.TAMANOS = {
	{ valor = "normal", texto = "Normal", escala = 1 },
	{ valor = "grande", texto = "Grande", escala = 1.15 },
	{ valor = "enorme", texto = "Muy grande", escala = 1.3 },
}

local function opt(k) return N.Get(ID, k) end
local function setOpt(k, v) N.Set(ID, k, v) end
local function datos() return N.Datos(ID) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
Es.EnCombate = enCombate

---------------------------------------------------------------------------
-- Proporciones y lados
---------------------------------------------------------------------------
Es.PROPORCIONES = {
	{ valor = "16:9", texto = "16:9", ancho = 16 / 9, ayuda = "El monitor de siempre: 1920 × 1080, 2560 × 1440 o 3840 × 2160." },
	{ valor = "21:9", texto = "21:9", ancho = 64 / 27, ayuda = "Un monitor ultra ancho: 2560 × 1080 o 3440 × 1440." },
	{ valor = "16:10", texto = "16:10", ancho = 1.6, ayuda = "1920 × 1200 o 2560 × 1600." },
	{ valor = "medida", texto = "A la medida", ayuda = "Tú eliges cuánto ocupa el juego con la barra." },
}
local porProporcion = {}
for _, p in ipairs(Es.PROPORCIONES) do porProporcion[p.valor] = p end
function Es.Proporcion(valor) return porProporcion[valor] end

Es.LADOS = {
	{ valor = "derecha", texto = "A la derecha", icono = "chevron-right" },
	{ valor = "izquierda", texto = "A la izquierda", icono = "chevron-left" },
	{ valor = "arriba", texto = "Arriba", icono = "chevron-up" },
	{ valor = "abajo", texto = "Abajo", icono = "chevron-down" },
}
local LADO_OK = { derecha = true, izquierda = true, arriba = true, abajo = true }

---------------------------------------------------------------------------
-- La pantalla entera: un marco sin padre que la llena
---------------------------------------------------------------------------
local ref
local function pantalla()
	if not ref then
		ref = CreateFrame("Frame", "AlfaEscritorioPantalla")
		if ref.SetParent then ref:SetParent(nil) end
		ref:SetAllPoints()
		ref:EnableMouse(false)
	end
	return ref
end
Es.Referencia = pantalla

local function escala(f)
	local ok, s = pcall(f.GetEffectiveScale, f)
	s = ok and tonumber(s) or 1
	return s > 0 and s or 1
end

-- Ancho y alto de la ventana del juego (en unidades del marco de referencia).
function Es.Pantalla()
	local r = pantalla()
	local w, h = K.num(r:GetWidth(), 0), K.num(r:GetHeight(), 0)
	if w <= 0 or h <= 0 then
		w = tonumber(GetScreenWidth and GetScreenWidth()) or 1920
		h = tonumber(GetScreenHeight and GetScreenHeight()) or 1080
	end
	return w, h
end

-- La proporción de la ventana (ancho / alto).
function Es.Ratio()
	local w, h = Es.Pantalla()
	return h > 0 and w / h or 16 / 9
end

-- Los píxeles de verdad de la ventana, o nil.
function Es.Fisica()
	if not GetPhysicalScreenSize then return nil end
	local ok, a, b = pcall(GetPhysicalScreenSize)
	a, b = ok and tonumber(a), ok and tonumber(b)
	if not (a and b and a > 0 and b > 0) then return nil end
	return floor(a + 0.5), floor(b + 0.5)
end

-- «32:9» para una proporción (la más parecida de las conocidas, o «3,56:1»).
local CONOCIDAS = { { 16 / 9, "16:9" }, { 64 / 27, "21:9" }, { 1.6, "16:10" }, { 32 / 9, "32:9" }, { 32 / 10, "32:10" },
	{ 48 / 9, "48:9" }, { 128 / 27, "42:9" }, { 4 / 3, "4:3" }, { 5 / 4, "5:4" }, { 16 / 18, "16:18" }, { 8 / 9, "8:9" } }
function Es.NombreRatio(r)
	r = r or Es.Ratio()
	for _, c in ipairs(CONOCIDAS) do
		if abs(c[1] - r) / c[1] < 0.03 then return c[2] end
	end
	return (format("%.2f:1", r):gsub("%.", N.espanol and "," or "."))
end

-- ¿La ventana se ve como de dos monitores? (mucho más ancha que un ultra
-- ancho, o más alta que ancha).
function Es.EsAncha(r)
	r = r or Es.Ratio()
	return r >= 2.6 or r <= 1.25
end

-- Lo que Alfa sugiere para tu ventana: { lado, proporcion, monitores, motivo }.
function Es.Sugerencia()
	local r = Es.Ratio()
	if r >= 2.6 then
		local mejor, err
		for _, p in ipairs(Es.PROPORCIONES) do
			if p.ancho then
				local n = r / p.ancho
				-- Lo que menos sobra, y a igual, menos monitores (21:9 x 2 antes que 16:10 x 3).
				local e = abs(n - floor(n + 0.5)) + (floor(n + 0.5) - 2) * 0.03
				if floor(n + 0.5) >= 2 and (not err or e < err) then mejor, err = p, e end
			end
		end
		mejor = mejor or porProporcion["16:9"]
		return { lado = "derecha", proporcion = mejor.valor, monitores = max(2, floor(r / mejor.ancho + 0.5)), motivo = "ancha" }
	elseif r <= 1.25 then
		local mejor, err
		for _, p in ipairs(Es.PROPORCIONES) do
			if p.ancho then
				local n = p.ancho / r
				local e = abs(n - floor(n + 0.5)) + (floor(n + 0.5) - 2) * 0.03
				if floor(n + 0.5) >= 2 and (not err or e < err) then mejor, err = p, e end
			end
		end
		mejor = mejor or porProporcion["16:9"]
		return { lado = "arriba", proporcion = mejor.valor, monitores = 2, motivo = "alta" }
	end
	return { lado = "derecha", proporcion = "medida", monitores = 1, motivo = "una" }
end

-- La geometría: o = { lado, proporcion, medida } (sin o, los ajustes).
-- -> { lado, parte, principal = { x, y, w, h }, escritorio = { x, y, w, h }, una }
-- (fracciones de la pantalla, desde arriba a la izquierda). una: la pantalla
-- no es más ancha que el monitor principal y se usa «A la medida».
function Es.Geometria(o)
	o = o or {}
	local lado = o.lado or opt("lado")
	if not LADO_OK[lado] then lado = "derecha" end
	local prop = o.proporcion or opt("proporcion") or "16:9"
	local medida = tonumber(o.medida or opt("medida")) or 70
	medida = max(40, min(90, medida))
	local r = o.ratio or Es.Ratio()
	local horizontal = lado == "derecha" or lado == "izquierda"
	local p = porProporcion[prop]
	local parte, una
	if p and p.ancho then parte = horizontal and p.ancho / r or r / p.ancho end
	if not parte or parte > 0.9 then
		if p and p.ancho then una = true end
		parte = medida / 100
	end
	parte = max(0.25, min(0.9, parte))
	local g = { lado = lado, parte = parte, una = una, proporcion = prop, medida = medida }
	if lado == "derecha" then
		g.principal, g.escritorio = { 0, 0, parte, 1 }, { parte, 0, 1 - parte, 1 }
	elseif lado == "izquierda" then
		g.principal, g.escritorio = { 1 - parte, 0, parte, 1 }, { 0, 0, 1 - parte, 1 }
	elseif lado == "abajo" then
		g.principal, g.escritorio = { 0, 0, 1, parte }, { 0, parte, 1, 1 - parte }
	else
		g.principal, g.escritorio = { 0, 1 - parte, 1, parte }, { 0, 0, 1, 1 - parte }
	end
	return g
end

---------------------------------------------------------------------------
-- Mover el mundo y la interfaz del juego (fuera de combate, reversible)
---------------------------------------------------------------------------
local orig     -- { mundo = anclas, interfaz = anclas } de antes de mover nada
local actual   -- la geometría puesta, o nil

local function anclas(f)
	local t = {}
	local n = f.GetNumPoints and f:GetNumPoints() or 0
	for i = 1, n do
		local p, rel, rp, x, y = f:GetPoint(i)
		if p then t[#t + 1] = { p, rel, rp, x, y } end
	end
	return t
end
Es.Anclas = anclas

local function devolver(f, t)
	f:ClearAllPoints()
	-- Sin anclas de antes, sin anclas (así estaba).
	if type(t) ~= "table" or #t == 0 then return end
	for _, q in ipairs(t) do f:SetPoint(q[1], q[2], q[3], q[4] or 0, q[5] or 0) end
end

-- Un marco sin padre (WorldFrame, UIParent) al rectángulo r de la pantalla.
local function colocar(f, r, rel)
	local W, H = Es.Pantalla()
	local k = escala(pantalla()) / escala(f)
	local x, y, w, h = r[1] * W * k, r[2] * H * k, r[3] * W * k, r[4] * H * k
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y)
	f:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x + w, -(y + h))
end
Es.Colocar = colocar

-- Otro addon ya acomoda la interfaz en el monitor principal (Offhand).
function Es.OtroLoHace()
	local cargado = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if type(cargado) ~= "function" then return false end
	for _, n in ipairs({ "Offhand", "OffhandUI", "Offhand_Companion" }) do
		local ok, si = pcall(cargado, n)
		if ok and si == true then return n end
	end
	return false
end

function Es.MueveMundo() return opt("moverMundo") ~= false and not Es.OtroLoHace() end
function Es.MueveInterfaz() return opt("moverInterfaz") ~= false and not Es.OtroLoHace() end

local alAplicar = {}
function Es.AlAplicar(fn) alAplicar[#alAplicar + 1] = fn end
local function avisarAplicado()
	for _, fn in ipairs(alAplicar) do K.Llamar(fn, actual) end
end

function Es.Aplicado() return actual end
function Es.Original() return orig end

-- Pone la geometría g (sin g, la de los ajustes). En combate espera.
function Es.Aplicar(g)
	g = g or Es.Geometria()
	if enCombate() then
		N.FueraDeCombate("pantallas.aplicar", function() Es.Aplicar(g) end)
		return false, "combate"
	end
	if not orig then
		orig = { mundo = anclas(WorldFrame), interfaz = anclas(UIParent), lleno = Es.FotoAntes() }
		-- 1.4.0: lo de antes, guardado hasta confirmar que volvió (EscritorioReparar.lua).
		if M.EscritorioReparar then M.EscritorioReparar.Guardar() end
	end
	if Es.CerrarVista then Es.CerrarVista() end
	if Es.MueveMundo() then colocar(WorldFrame, g.principal, nil) else devolver(WorldFrame, orig.mundo) end
	if Es.MueveInterfaz() then colocar(UIParent, g.principal, nil) else devolver(UIParent, orig.interfaz) end
	actual = g
	Es.MostrarEscritorio(true)
	avisarAplicado()
	return true
end

-- Todo como estaba: el mundo y la interfaz en toda la ventana, sin escritorio.
function Es.Volver()
	if enCombate() then
		N.FueraDeCombate("pantallas.aplicar", function() Es.Volver() end)
		return false, "combate"
	end
	if Es.CerrarVista then Es.CerrarVista() end
	if orig then
		devolver(WorldFrame, orig.mundo)
		devolver(UIParent, orig.interfaz)
	end
	local estaba = actual ~= nil
	local lleno = orig and orig.lleno
	orig, actual = nil, nil
	-- 1.4.0: el mapa de Alfa vuelve a su lugar antes de esconder el escritorio.
	if Es.SoltarMapa then pcall(Es.SoltarMapa) end
	Es.MostrarEscritorio(false)
	-- 1.4.0: volver siempre deja todo limpio: lo que llenaba la ventana antes
	-- de Dos pantallas la vuelve a llenar, con la misma escala.
	Es.Limpiar(lleno)
	avisarAplicado()
	if estaba then A.Fire("ALFA_ESCRITORIO", "volvio") end
	return true
end

-- ¿El marco llena la ventana? (en unidades de la pantalla)
local function llena(f)
	local W, H = Es.Pantalla()
	local k = escala(pantalla())
	local s = escala(f) / k
	local w, h = K.num(f:GetWidth(), 0) * s, K.num(f:GetHeight(), 0) * s
	local l, b = K.num(f:GetLeft(), 0) * s, K.num(f:GetBottom(), 0) * s
	return abs(w - W) <= 1 and abs(h - H) <= 1 and abs(l) <= 1 and abs(b) <= 1
end
Es.Llena = llena

-- Lo de antes de aplicar: qué llenaba la ventana y la escala de la interfaz.
function Es.FotoAntes()
	return { mundo = llena(WorldFrame), interfaz = llena(UIParent), escala = tonumber(UIParent:GetScale()) or 1 }
end

-- ¿Quedó como estaba? -> ok, lo que no (mundo | interfaz | escala)
function Es.Limpio(lleno)
	if type(lleno) ~= "table" then lleno = { mundo = true, interfaz = true } end
	if lleno.mundo and not llena(WorldFrame) then return false, "mundo" end
	if lleno.interfaz and not llena(UIParent) then return false, "interfaz" end
	if lleno.escala and abs((tonumber(UIParent:GetScale()) or 1) - lleno.escala) > 0.001 then return false, "escala" end
	return true
end

-- Sin Dos pantallas puesto y fuera de combate: arregla lo que no quedó como
-- estaba (nunca toca un mundo que ya venía achicado por otro addon).
function Es.Limpiar(lleno)
	if enCombate() or actual or type(lleno) ~= "table" or Es.OtroLoHace() then return false end
	local arreglado = false
	for _ = 1, 3 do
		local ok, que = Es.Limpio(lleno)
		if ok then break end
		arreglado = true
		if que == "mundo" then WorldFrame:ClearAllPoints() WorldFrame:SetAllPoints(nil)
		elseif que == "interfaz" then UIParent:ClearAllPoints() UIParent:SetAllPoints(nil)
		elseif que == "escala" then UIParent:SetScale(lleno.escala) end
	end
	return arreglado
end

-- Encender (guardado) y apagar el modo.
function Es.Encender()
	setOpt("activo", true)
	return Es.Aplicar()
end
function Es.Apagar(silencio)
	setOpt("activo", false)
	local ok = Es.Volver()
	-- 1.3.8: si Alfa estiró la ventana con un clic, la ventana vuelve a como estaba.
	local estiro = ok and Es.DesestirarAuto and Es.DesestirarAuto()
	-- 1.4.0: sin ventana que devolver, igual se revisa que la escala y todo
	-- quedaran como antes (y se olvida lo guardado).
	local Rp = M.EscritorioReparar
	if ok and not estiro and Rp and Rp.Antes() then
		datos().verificar = { foto = Rp.Antes(), intentos = 1 }
		Rp.Verificar()
	end
	if not silencio then N.Imprimir(L["Alfa volvió a una sola pantalla. Para usar el escritorio otra vez: /alfa pantallas."]) end
	return ok
end

-- La cinemática y el cambio de tamaño de la ventana devuelven el mundo a
-- toda la pantalla: se vuelve a poner (con la medida nueva).
local function reponer()
	if not actual then return end
	local cine = rawget(_G, "CinematicFrame")
	if type(cine) == "table" and cine.IsShown and cine:IsShown() then return end
	local g = Es.Geometria({ lado = actual.lado, proporcion = actual.proporcion, medida = actual.medida })
	Es.Aplicar(g)
end
Es.Reponer = reponer
local function reponerLuego() N.Una("pantallas.reponer", 0.2, reponer) end
A.RegisterEvent("DISPLAY_SIZE_CHANGED", reponerLuego)
A.RegisterEvent("UI_SCALE_CHANGED", reponerLuego)
A.RegisterEvent("CINEMATIC_STOP", reponerLuego)
local enganchado = false
local function engancharCine()
	if enganchado then return end
	local cine = rawget(_G, "CinematicFrame")
	if type(cine) == "table" and cine.HookScript then
		enganchado = true
		cine:HookScript("OnHide", reponerLuego)
	end
end

---------------------------------------------------------------------------
-- Probar antes de guardar (como al cambiar la resolución)
---------------------------------------------------------------------------
local prueba -- { o, antes, quedan }
local confirmar

local function armarConfirmar()
	local f = CreateFrame("Frame", "AlfaEscritorioConfirmar", K.Raiz())
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(50)
	f:SetSize(480, 184)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.ventana })
	f.Marca = K.Marca(f, K.CORTE.ventana, "acento", 44)
	f.Lobo = f:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(44, 44)
	f.Lobo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.l, -ESP.l)
	f.Lobo:SetTexture(K.Lobo("atento"))
	K.Pintar(f.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	-- 1.4.0: los segundos que quedan, en grande (antes solo una barrita).
	f.Cuenta = K.Texto(f, "portada", "acento")
	f.Cuenta:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.l, -ESP.l + 2)
	f.Cuenta:SetJustifyH("RIGHT")
	f.Titulo = K.Texto(f, "titulo", "texto")
	f.Titulo:SetPoint("TOPLEFT", f.Lobo, "TOPRIGHT", ESP.base, -2)
	f.Titulo:SetPoint("RIGHT", f, "RIGHT", -ESP.l - 48, 0)
	f.Titulo:SetJustifyH("LEFT")
	f.Texto = K.Texto(f, "texto", "textoSuave")
	f.Texto:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -ESP.s)
	f.Texto:SetJustifyH("LEFT")
	f.Barra = K.Progreso(f, { alto = 4, tono = "acento" })
	f.Barra:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ESP.l, ESP.l + K.ALTO.boton + ESP.base)
	f.Barra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -ESP.l, ESP.l + K.ALTO.boton + ESP.base)
	f.Si = K.Boton(f, L["Sí, guardar"], function() Es.Confirmar() end, { tipo = "primario", icono = "ic-exito" })
	f.Si:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -ESP.l, ESP.l)
	f.No = K.Boton(f, L["Volver como estaba"], function() Es.Rechazar() end, { tipo = "secundario" })
	f.No:SetPoint("RIGHT", f.Si, "LEFT", -ESP.s, 0)
	-- (1.3.8 revisión) Las teclas pasan siempre al juego (se arma fuera de
	-- combate); solo Esc se queda aquí y rechaza. En combate no toma el teclado.
	f:EnableKeyboard(true)
	if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
	f:SetScript("OnKeyDown", function(self, tecla)
		local esc = tecla == "ESCAPE"
		if enCombate() then return end
		if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not esc) end
		if esc then Es.Rechazar() end
	end)
	f:SetScript("OnHide", function(self)
		if self.SetPropagateKeyboardInput and not enCombate() then self:SetPropagateKeyboardInput(true) end
	end)
	f:Hide()
	return f
end

local function pintarConfirmar()
	if not (prueba and confirmar) then return end
	K.Escribir(confirmar.Titulo, L["¿Se ve bien?"])
	local g = prueba.g
	local donde = (g and g.una) and L["El juego quedó a un lado y tu escritorio de Alfa al otro."]
		or L["El juego quedó en tu monitor principal y Alfa en el otro."]
	-- 1.3.8 (un clic): una línea más, por ejemplo cómo acomodar la ventana.
	if prueba.nota then donde = donde .. "\n" .. prueba.nota end
	K.Escribir(confirmar.Texto, donde .. "\n" .. N.Plural(prueba.quedan, L["Si no eliges nada, vuelvo a como estaba en %d segundo."],
		L["Si no eliges nada, vuelvo a como estaba en %d segundos."]))
	local tw = 480 - ESP.l * 2 - 44 - ESP.base
	local th = K.Parrafo(confirmar.Texto, tw)
	confirmar:SetHeight(math.max(184, ESP.l + 30 + ESP.s + th + ESP.base + 4 + ESP.base + K.ALTO.boton + ESP.l))
	confirmar.Barra:Set(prueba.quedan, Es.PRUEBA_SEG)
	K.Escribir(confirmar.Cuenta, tostring(prueba.quedan))
end

function Es.Probando() return prueba ~= nil end
function Es.Quedan() return prueba and prueba.quedan or nil end

-- o = { lado, proporcion, medida }: se pone ya y espera tu «Sí».
-- extra (1.3.8, un clic) = { nota, alConfirmar, alRechazar }
function Es.Probar(o, extra)
	if enCombate() then
		N.Imprimir(L["Las pantallas se acomodan fuera de combate."])
		return false
	end
	o = o or {}
	if prueba then Es.Rechazar(true) end
	local antes = { activo = opt("activo") == true, puesta = actual ~= nil,
		lado = opt("lado"), proporcion = opt("proporcion"), medida = opt("medida") }
	local g = Es.Geometria(o)
	-- (1.3.8 revisión) El cuadro y la cuenta van primero: si algo falla al
	-- aplicar, se vuelve a como estaba (nada queda movido sin cuenta).
	confirmar = confirmar or armarConfirmar()
	extra = type(extra) == "table" and extra or {}
	prueba = { o = o, antes = antes, quedan = Es.PRUEBA_SEG, g = g, nota = extra.nota,
		alConfirmar = extra.alConfirmar, alRechazar = extra.alRechazar }
	datos().probando = true
	pintarConfirmar()
	confirmar:EnableKeyboard(true)
	confirmar:Show()
	N.Cada("pantallas.cuenta", 1, function()
		if not prueba then N.Quitar("pantallas.cuenta") return end
		prueba.quedan = prueba.quedan - 1
		if prueba.quedan <= 0 then Es.Rechazar() return end
		pintarConfirmar()
	end)
	local ok, err = pcall(Es.Aplicar, g)
	if not ok then
		Es.Rechazar(true)
		if geterrorhandler then geterrorhandler()(err) end
		return false
	end
	return true
end

function Es.Confirmar()
	if not prueba then return false end
	local o, g, alConfirmar = prueba.o, prueba.g, prueba.alConfirmar
	prueba = nil
	N.Quitar("pantallas.cuenta")
	datos().probando = nil
	if confirmar then confirmar:Hide() end
	setOpt("lado", g.lado)
	setOpt("proporcion", o.proporcion or g.proporcion)
	if o.medida then setOpt("medida", o.medida) end
	setOpt("activo", true)
	datos().elegido = true
	if alConfirmar then K.Llamar(alConfirmar) end
	A.Fire("ALFA_ESCRITORIO", "guardado")
	N.Imprimir(L["¡Listo! Tu escritorio de Alfa queda así. Para volver a una pantalla: /alfa pantallas volver."])
	return true
end

-- Vuelve a lo de antes de probar (con todo como estaba guardado).
function Es.Rechazar(sinAviso)
	if not prueba then return false end
	local antes, alRechazar = prueba.antes, prueba.alRechazar
	prueba = nil
	N.Quitar("pantallas.cuenta")
	datos().probando = nil
	if confirmar then confirmar:Hide() end
	if antes.puesta then
		Es.Aplicar(Es.Geometria({ lado = antes.lado, proporcion = antes.proporcion, medida = antes.medida }))
	else
		Es.Volver()
	end
	if alRechazar then K.Llamar(alRechazar) end
	A.Fire("ALFA_ESCRITORIO", "rechazado")
	if not sinAviso then N.Imprimir(L["Volví a como estaba. Puedes probar otra vez cuando quieras."]) end
	return true
end

---------------------------------------------------------------------------
-- Los paneles (EscritorioPaneles.lua los registra)
---------------------------------------------------------------------------
Es.TIPOS, Es.ORDEN = {}, {}
-- def = { id, titulo, icono, texto, tam = { w, h } (celdas), min = { w, h },
--   ritmo (s) | nil, enCombate, crear(p, cuerpo), pintar(p, cuerpo, w, h, tam),
--   menu(p) -> opciones de K.Menu, alMenu(p, valor), abrir() (su página),
--   alMostrar(p), alOcultar(p) }
function Es.Registrar(def)
	if type(def) ~= "table" or type(def.id) ~= "string" then return false end
	if not Es.TIPOS[def.id] then Es.ORDEN[#Es.ORDEN + 1] = def.id end
	Es.TIPOS[def.id] = def
	return true
end

---------------------------------------------------------------------------
-- Las distribuciones: dónde va cada panel (celdas de la rejilla 24 x 16)
---------------------------------------------------------------------------
local function P(id, x, y, w, h) return { id = id, x = x, y = y, w = w, h = h } end
-- 1.4.0 (tablero): arriba lo principal en grande (la guía y la flecha, el
-- medidor, la pesca), abajo lo secundario; menos paneles y más grandes, y la
-- hora va en la barra (el panel «Reloj y sesión» sigue en el catálogo).
Es.DISTRIBUCIONES = {
	{ id = "aventura", nombre = "Aventura", icono = "ic-aventura", texto = "Tu guía, la flecha grande, el mapa y Lya.",
		paneles = { P("rastreador", 0, 0, 10, 9), P("flecha", 10, 0, 6, 9), P("mapa", 16, 0, 8, 9),
			P("lya", 0, 9, 8, 7), P("hoy", 8, 9, 8, 7), P("avisos", 16, 9, 8, 7) } },
	{ id = "mazmorra", nombre = "Mazmorra", icono = "ic-mazmorra", texto = "El medidor, tu grupo, la pelea y los avisos.",
		-- 1.3.9: dentro de una mazmorra, su plano (mapaMazmorra) en vez del mapa del mundo.
		paneles = { P("medidor", 0, 0, 10, 9), P("grupo", 10, 0, 7, 9), P("avisos", 17, 0, 7, 9),
			P("pelea", 0, 9, 10, 7), P("mapaMazmorra", 10, 9, 7, 7), P("lya", 17, 9, 7, 7) } },
	{ id = "pesca", nombre = "Pesca", icono = "ic-pesca", texto = "Tu pesca, tus bolsas, tu oro y Lya.",
		paneles = { P("pesca", 0, 0, 12, 9), P("mapa", 12, 0, 12, 9),
			P("bolsas", 0, 9, 8, 7), P("oro", 8, 9, 8, 7), P("lya", 16, 9, 8, 7) } },
	{ id = "comercio", nombre = "Comercio", icono = "ic-comercio", texto = "Tus bolsas, tu oro y tus planes.",
		paneles = { P("bolsas", 0, 0, 12, 9), P("oro", 12, 0, 6, 9), P("planes", 18, 0, 6, 9),
			P("hoy", 0, 9, 12, 7), P("avisos", 12, 9, 6, 7), P("lya", 18, 9, 6, 7) } },
	-- 1.3.9: para un monitor de lado (vertical) y uno ultraancho. La vertical
	-- trae su propio acomodo para la forma angosta (no el de dos columnas).
	{ id = "vertical", nombre = "Monitor vertical", icono = "ic-ventana", texto = "Todo de arriba abajo: tu guía, la flecha, el mapa y tus misiones.",
		paneles = { P("rastreador", 0, 0, 8, 10), P("flecha", 0, 10, 8, 6), P("mapa", 8, 0, 10, 10), P("misiones", 18, 0, 6, 10),
			P("hoy", 8, 10, 8, 6), P("lya", 16, 10, 8, 6) },
		angosta = { P("rastreador", 0, 0, 24, 3), P("flecha", 0, 3, 12, 2), P("hoy", 12, 3, 12, 2), P("mapa", 0, 5, 24, 5),
			P("misiones", 0, 10, 12, 3), P("cerrar", 12, 10, 12, 3), P("lya", 0, 13, 12, 3), P("avisos", 12, 13, 12, 3) } },
	{ id = "ultraancho", nombre = "Ultraancho", icono = "ic-ventana", texto = "Seis columnas: tu guía, el mapa grande, tus misiones, la manada y Lya.",
		paneles = { P("rastreador", 0, 0, 5, 10), P("flecha", 0, 10, 5, 6), P("mapa", 5, 0, 9, 16), P("misiones", 14, 0, 5, 8),
			P("cerrar", 14, 8, 5, 4), P("planes", 14, 12, 5, 4), P("hoy", 19, 0, 5, 6), P("manada", 19, 6, 5, 5), P("lya", 19, 11, 5, 5) } },
}
local porDistribucion = {}
for _, d in ipairs(Es.DISTRIBUCIONES) do porDistribucion[d.id] = d end

local function copiar(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = copiar(v) end
	return o
end
Es.Copiar = copiar

local function propias()
	local d = datos()
	if type(d.propias) ~= "table" then d.propias = {} end
	return d.propias
end
local function cambios()
	local d = datos()
	if type(d.dist) ~= "table" then d.dist = {} end
	return d.dist
end

-- Una celda válida (dentro de la rejilla y de al menos 2 x 2).
local function sano(p)
	if type(p) ~= "table" or type(p.id) ~= "string" or not Es.TIPOS[p.id] then return nil end
	local w = max(2, min(Es.COLUMNAS, floor(tonumber(p.w) or 6)))
	local h = max(2, min(Es.FILAS, floor(tonumber(p.h) or 6)))
	local x = max(0, min(Es.COLUMNAS - w, floor(tonumber(p.x) or 0)))
	local y = max(0, min(Es.FILAS - h, floor(tonumber(p.y) or 0)))
	return { id = p.id, x = x, y = y, w = w, h = h }
end
Es.Sano = sano

-- Todas: las de Alfa y las tuyas -> { { id, nombre, icono, propia } }
function Es.Distribuciones()
	local out = {}
	for _, d in ipairs(Es.DISTRIBUCIONES) do out[#out + 1] = { id = d.id, nombre = L[d.nombre], icono = d.icono, texto = L[d.texto] } end
	for _, d in ipairs(propias()) do
		if type(d) == "table" and type(d.id) == "string" then
			out[#out + 1] = { id = d.id, nombre = type(d.nombre) == "string" and d.nombre or L["Mi escritorio"], icono = "ic-lobo", propia = true }
		end
	end
	return out
end

local function propiaDe(id)
	for i, d in ipairs(propias()) do if type(d) == "table" and d.id == id then return d, i end end
	return nil
end
function Es.Existe(id) return porDistribucion[id] ~= nil or propiaDe(id) ~= nil end
function Es.NombreDe(id)
	local d = porDistribucion[id]
	if d then return L[d.nombre] end
	local p = propiaDe(id)
	return p and (type(p.nombre) == "string" and p.nombre or L["Mi escritorio"]) or nil
end

-- Los paneles de una distribución (una copia): los que cambiaste tú, o los de fábrica.
-- La forma del escritorio: "ancha" (un monitor de lado) o "angosta" (una
-- franja alta, como el escritorio a un lado de una sola pantalla). Cada forma
-- guarda sus propios lugares; la angosta de fábrica sale de la ancha en dos columnas.
local desk
function Es.Forma()
	if not desk then return "ancha" end
	local w, h = K.num(desk:GetWidth(), 0), K.num(desk:GetHeight(), 0)
	return (w > 0 and h > 0 and w / h < 1.15) and "angosta" or "ancha"
end
local function clave(id) return Es.Forma() == "angosta" and (id .. ":angosta") or id end
local function campo() return Es.Forma() == "angosta" and "angosta" or "paneles" end

local function enColumnas(lista)
	local orden = copiar(lista)
	table.sort(orden, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
	local out, alto = {}, { 0, 0 }
	local mitad = floor(Es.COLUMNAS / 2)
	for _, x in ipairs(orden) do
		local h = max(3, min(8, floor((tonumber(x.h) or 6) * 0.6 + 0.5)))
		local col = alto[1] <= alto[2] and 1 or 2
		if alto[col] + h > Es.FILAS then col = col == 1 and 2 or 1 end
		if alto[col] + h <= Es.FILAS then
			out[#out + 1] = { id = x.id, x = (col - 1) * mitad, y = alto[col], w = mitad, h = h }
			alto[col] = alto[col] + h
		end
	end
	-- 1.4.0: el último de cada columna llega hasta abajo (sin hueco vacío).
	for col = 1, 2 do
		local ultimo
		for _, x in ipairs(out) do if x.x == (col - 1) * mitad and (not ultimo or x.y > ultimo.y) then ultimo = x end end
		if ultimo then ultimo.h = Es.FILAS - ultimo.y end
	end
	return out
end
Es.EnColumnas = enColumnas

-- Los paneles de una distribución (una copia): los que cambiaste tú, o los de fábrica.
function Es.PanelesDe(id)
	local lista
	local angosta = Es.Forma() == "angosta"
	local p = propiaDe(id)
	if p then
		lista = p[campo()]
		if type(lista) ~= "table" and angosta and type(p.paneles) == "table" then lista = enColumnas(p.paneles) end
	elseif type(cambios()[clave(id)]) == "table" then lista = cambios()[clave(id)]
	elseif porDistribucion[id] then
		lista = porDistribucion[id].paneles
		if angosta then lista = porDistribucion[id].angosta or enColumnas(lista) end
	end
	local out, vistos = {}, {}
	for _, x in ipairs(type(lista) == "table" and lista or {}) do
		local s = sano(x)
		if s and not vistos[s.id] then vistos[s.id] = true out[#out + 1] = s end
	end
	return out
end

function Es.Cambiada(id) return type(cambios()[clave(id)]) == "table" end

local distActual  -- id de la que se ve
local ultimoCtx   -- el contexto de la última revisión (cambia solo cuando cambia lo que haces)
local paneles = {} -- los de la distribución de ahora: { { id, x, y, w, h } }

function Es.Actual() return distActual end
function Es.Paneles() return paneles end

-- Guarda los paneles de ahora en la distribución de ahora.
function Es.Guardar()
	if not distActual then return end
	local lista = copiar(paneles)
	local p = propiaDe(distActual)
	if p then p[campo()] = lista else cambios()[clave(distActual)] = lista end
end

-- La de Alfa como venía (las tuyas no tienen «de fábrica»: quedan igual).
function Es.Restablecer()
	if not distActual then return false end
	if porDistribucion[distActual] then
		cambios()[clave(distActual)] = nil
		paneles = Es.PanelesDe(distActual)
		Es.Acomodar()
		return true
	end
	return false
end

-- «Guardar como…»: una distribución tuya con los paneles de ahora -> id
function Es.GuardarComo(nombre)
	nombre = type(nombre) == "string" and nombre:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if nombre == "" then nombre = format(L["Mi escritorio %d"], #propias() + 1) end
	local d = datos()
	d.siguiente = (tonumber(d.siguiente) or 0) + 1
	local id = "propia" .. d.siguiente
	tinsert(propias(), { id = id, nombre = nombre, [campo()] = copiar(paneles) })
	Es.Usar(id, "jugador")
	return id
end

function Es.Borrar(id)
	local p, i = propiaDe(id)
	if not p then return false end
	tremove(propias(), i)
	local r = datos().reglas
	if type(r) == "table" then for k, v in pairs(r) do if v == id then r[k] = nil end end end
	if distActual == id then Es.Usar("aventura", "jugador") end
	return true
end

---------------------------------------------------------------------------
-- El escritorio: su marco, su barra y la rejilla de paneles
---------------------------------------------------------------------------
local marcos = {} -- id -> marco del panel
Es.Marcos = marcos

local function tamDe(w, h)
	if w < 300 or h < 170 then return "compacto" end
	if w >= 520 and h >= 300 then return "grande" end
	return "medio"
end
Es.TamDe = tamDe

local function pintarPanel(p, forzar)
	local def = p.def
	if not (p:IsVisible() and def.pintar) then return end
	if enCombate() and not def.enCombate and not forzar then return end
	local c = p.Cuerpo
	local w, h = K.num(c:GetWidth(), 0), K.num(c:GetHeight(), 0)
	if w <= 0 or h <= 0 then return end
	p.tam = tamDe(K.num(p:GetWidth(), 0), K.num(p:GetHeight(), 0))
	local ok, err = pcall(def.pintar, p, c, w, h, p.tam)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end
Es.PintarPanel = pintarPanel

local function menuPanel(p)
	local def = p.def
	local ops = {}
	if def.menu then
		local ok, l = pcall(def.menu, p)
		if ok and type(l) == "table" then for _, o in ipairs(l) do ops[#ops + 1] = o end end
	end
	if def.abrir then
		if #ops > 0 then ops[#ops + 1] = { separador = true } end
		ops[#ops + 1] = { valor = "_abrir", texto = L["Abrir en Alfa"], icono = "ic-ventana" }
	end
	if #ops > 0 then ops[#ops + 1] = { separador = true } end
	ops[#ops + 1] = { valor = "_quitar", texto = L["Quitar del escritorio"], icono = "ic-cerrar" }
	K.Menu(p.Cab.Menu, ops, nil, function(v)
		if v == "_abrir" then K.Llamar(def.abrir, p)
		elseif v == "_quitar" then Es.QuitarPanel(def.id)
		elseif def.alMenu then K.Llamar(def.alMenu, p, v) end
	end, 220)
end

local function crearPanel(def)
	local p = CreateFrame("Frame", nil, desk.Area)
	p.def = def
	p:SetFrameLevel(desk.Area:GetFrameLevel() + 2)
	-- 1.4.0: lo principal (la guía, la flecha, el medidor, la pesca) resalta:
	-- su fondo un poco más claro, un brillo del acento arriba y el título más
	-- grande; lo demás, más quieto.
	local prota = def.protagonista == true
	p.protagonista = prota
	p.caja = K.Caja(p, { fondo = prota and "elevado" or "panel", borde = prota and "lineaFuerte" or "linea", corte = K.CORTE.panel })
	p.Marca = K.Marca(p, K.CORTE.panel, "acento", prota and 64 or nil)
	if prota then
		p.Brillo = p:CreateTexture(nil, "BACKGROUND", nil, 2)
		p.Brillo:SetTexture(K.Ruta("white"))
		p.Brillo:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
		p.Brillo:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -1)
		p.Brillo:SetHeight(90)
		K.Pintar(p.Brillo, function(t)
			local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
			if t.SetGradient and CreateColor then t:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.08))
			else t:SetVertexColor(r, g, b, 0.05) end
		end)
	end
	local c = CreateFrame("Frame", nil, p)
	p.Cab = c
	c:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	c:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
	c:SetHeight(prota and Es.CABECERA + 6 or Es.CABECERA)
	c.Icono = K.Icono(c, def.icono or "ic-lobo", prota and 18 or 14, prota and "acento" or "textoSuave")
	c.Icono:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	c.Cerrar = K.BotonIcono(c, "ic-cerrar", function() Es.QuitarPanel(def.id) end, { tam = 24, icono = 10, ayuda = L["Quitar del escritorio"] })
	c.Cerrar:SetPoint("RIGHT", c, "RIGHT", -ESP.s, 0)
	c.Menu = K.BotonIcono(c, "menu", function() menuPanel(p) end, { tam = 24, icono = 14, ayuda = L["Más"] })
	c.Menu:SetPoint("RIGHT", c.Cerrar, "LEFT", -2, 0)
	-- 1.4.0: «…» y «×» solo con el ratón encima (Es.RevisarRaton): menos ruido.
	-- Revisión: escondidos no toman el ratón (nada invisible atrapa un clic).
	Es.BotonesCabecera(c, false)
	c.Titulo = K.Texto(c, prota and "subtitulo" or "encabezado", prota and "texto" or "textoSuave")
	c.Titulo:SetPoint("LEFT", c.Icono, "RIGHT", ESP.s, 0)
	c.Titulo:SetPoint("RIGHT", c.Menu, "LEFT", -ESP.s, 0)
	c.Titulo:SetJustifyH("LEFT")
	c.Titulo:SetWordWrap(false)
	K.Escribir(c.Titulo, L[def.titulo])
	c.Linea = K.Linea(c, "linea")
	c.Linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 1, 0)
	c.Linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 0)
	local cuerpo = CreateFrame("Frame", nil, p)
	p.Cuerpo = cuerpo
	cuerpo:SetPoint("TOPLEFT", c, "BOTTOMLEFT", ESP.m, -ESP.s)
	cuerpo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -ESP.m, ESP.m)
	if def.crear then
		local ok, err = pcall(def.crear, p, cuerpo)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
	p:SetScript("OnShow", function(self)
		if def.alMostrar then K.Llamar(def.alMostrar, self) end
		pintarPanel(self, true)
	end)
	p:SetScript("OnHide", function(self) if def.alOcultar then K.Llamar(def.alOcultar, self) end end)
	return p
end

-- Coloca cada panel de la distribución en su celda; esconde los demás.
function Es.Acomodar()
	if not desk then return end
	local area = desk.Area
	local AW, AH = K.num(area:GetWidth(), 0), K.num(area:GetHeight(), 0)
	if AW <= 0 or AH <= 0 then return end
	local cw, ch = AW / Es.COLUMNAS, AH / Es.FILAS
	local g = Es.GAP
	local usados = {}
	for _, x in ipairs(paneles) do
		local def = Es.TIPOS[x.id]
		if def then
			local p = marcos[x.id] or crearPanel(def)
			marcos[x.id] = p
			usados[x.id] = true
			p:ClearAllPoints()
			p:SetPoint("TOPLEFT", area, "TOPLEFT", x.x * cw + g / 2, -(x.y * ch + g / 2))
			local w, h = max(40, x.w * cw - g), max(40, x.h * ch - g)
			p:SetSize(w, h)
			p.celda = x
			p:Show()
			-- Recién hecho o de otro tamaño: se pinta otra vez (y se adapta).
			local medida = floor(w) * 10000 + floor(h)
			if p.medida ~= medida then
				p.medida = medida
				pintarPanel(p, true)
			end
		end
	end
	for id, p in pairs(marcos) do if not usados[id] then p:Hide() end end
	if M.EscritorioEditor then K.Llamar(M.EscritorioEditor.Repintar) end
	Es.PintarBarra()
end

-- Celdas -> píxeles del área (para el editor).
function Es.Celda()
	if not desk then return 0, 0 end
	local area = desk.Area
	return K.num(area:GetWidth(), 0) / Es.COLUMNAS, K.num(area:GetHeight(), 0) / Es.FILAS
end

-- Usa la distribución id (motivo: "jugador" | "auto" | "entrar"). En combate
-- espera a salir (nada se acomoda en plena pelea).
function Es.Usar(id, motivo)
	if not Es.Existe(id) then return false end
	if enCombate() and desk and desk:IsShown() then
		N.FueraDeCombate("pantallas.distribucion", function() Es.Usar(id, motivo) end)
		return false, "combate"
	end
	if M.EscritorioEditor and M.EscritorioEditor.Activo() and distActual ~= id then K.Llamar(M.EscritorioEditor.Cerrar) end
	distActual = id
	paneles = Es.PanelesDe(id)
	setOpt("distribucion", id)
	-- Lo que eliges tú se queda hasta que cambia lo que haces.
	if motivo == "jugador" then Es.manual = id ultimoCtx = Es.Contexto() end
	Es.Acomodar()
	A.Fire("ALFA_ESCRITORIO", "distribucion", id, motivo)
	return true
end

function Es.TienePanel(id)
	for _, x in ipairs(paneles) do if x.id == id then return true end end
	return false
end

-- Un lugar libre para un panel de w x h celdas (o nil).
local function libre(w, h, sin)
	local ocupado = {}
	for _, x in ipairs(paneles) do
		if x.id ~= sin then
			for i = x.x, x.x + x.w - 1 do for j = x.y, x.y + x.h - 1 do ocupado[j * 100 + i] = true end end
		end
	end
	for y = 0, Es.FILAS - h do
		for x = 0, Es.COLUMNAS - w do
			local cabe = true
			for i = x, x + w - 1 do
				for j = y, y + h - 1 do if ocupado[j * 100 + i] then cabe = false break end end
				if not cabe then break end
			end
			if cabe then return x, y end
		end
	end
	return nil
end
Es.Libre = libre

function Es.AgregarPanel(id)
	local def = Es.TIPOS[id]
	if not def or Es.TienePanel(id) then return false end
	local w, h = (def.tam and def.tam[1]) or 6, (def.tam and def.tam[2]) or 6
	local x, y = libre(w, h)
	if not x then
		-- Sin lugar: más chico, y si tampoco, arriba a la izquierda (encima).
		w, h = max(4, floor(w * 0.7)), max(3, floor(h * 0.7))
		x, y = libre(w, h)
		if not x then x, y = 0, 0 end
	end
	paneles[#paneles + 1] = { id = id, x = x, y = y, w = w, h = h }
	Es.Guardar()
	Es.Acomodar()
	return true
end

function Es.QuitarPanel(id)
	for i, x in ipairs(paneles) do
		if x.id == id then
			if M.EscritorioEditor then K.Llamar(M.EscritorioEditor.AntesDeCambiar) end
			tremove(paneles, i)
			Es.Guardar()
			Es.Acomodar()
			return true
		end
	end
	return false
end

-- Reemplaza todos los paneles (el editor: deshacer).
function Es.PonerPaneles(lista)
	local out = {}
	for _, x in ipairs(type(lista) == "table" and lista or {}) do
		local s = sano(x)
		if s then out[#out + 1] = s end
	end
	paneles = out
	Es.Guardar()
	Es.Acomodar()
end

-- La barra de arriba: el selector de distribuciones, «Cambia sola», «Editar» y el menú.
function Es.PintarBarra()
	local b = desk and desk.Barra
	if not b then return end
	local ops = {}
	for _, d in ipairs(Es.Distribuciones()) do ops[#ops + 1] = { valor = d.id, texto = d.nombre, icono = d.icono } end
	b.Lista:SetOpciones(ops)
	b.Lista:SetValor(distActual)
	local auto = opt("auto") ~= false
	b.Auto:SetValor(auto)
	local nombre = Es.NombreDe(distActual) or ""
	local sub
	if auto then sub = format(L["%s · cambia sola"], nombre) else sub = nombre end
	K.Escribir(b.Sub, sub)
	local W = K.num(b:GetWidth(), 0)
	-- Una barra angosta (el escritorio a un lado): primero se va el nombre,
	-- luego «Una pantalla» (sigue en el menú «…»), luego la hora y «Cambia sola».
	local x = ESP.base + 30 + ESP.m + max(K.AnchoTexto(b.Titulo), K.AnchoTexto(b.Sub)) + ESP.xl
	local conUna = true
	local function derechaDe() return K.num(b.Menu:GetWidth(), 32) + (conUna and K.num(b.Una:GetWidth(), 100) + ESP.s or 0) + K.num(b.Editar:GetWidth(), 90) + ESP.s + ESP.m end
	local nombre = x + 200 + derechaDe() + ESP.m <= W
	if not nombre then
		x = ESP.base + 30 + ESP.m
		if x + 200 + derechaDe() + ESP.m > W then conUna = false end
	end
	b.Titulo:SetShown(nombre)
	b.Sub:SetShown(nombre)
	b.Una:SetShown(conUna)
	b.Editar:ClearAllPoints()
	b.Editar:SetPoint("RIGHT", conUna and b.Una or b.Menu, "LEFT", -ESP.s, 0)
	b.Lista:ClearAllPoints()
	b.Lista:SetPoint("LEFT", b, "LEFT", x, 0)
	local derecha = derechaDe()
	local auto0 = K.num(b.Auto:GetWidth(), 40) + K.AnchoTexto(b.AutoTexto) + ESP.l + ESP.s
	local libre = W - x - 200 - derecha
	b.Auto:SetShown(libre >= auto0)
	b.AutoTexto:SetShown(libre >= auto0)
	if libre >= auto0 then libre = libre - auto0 end
	Es.PintarHora()
	local hw = max(K.AnchoTexto(b.Hora), K.AnchoTexto(b.Sesion)) + ESP.xl * 2
	-- La hora va al centro si cabe sin encimarse; si no, se esconde.
	local centro = W / 2
	local cabe = centro - hw / 2 >= x + 200 + ESP.l and centro + hw / 2 <= W - derecha - (b.Auto:IsShown() and auto0 or 0)
	b.Hora:SetShown(cabe)
	b.Sesion:SetShown(cabe)
end

-- La hora (la de tu reloj, como el panel «Reloj y sesión») y tu sesión.
function Es.PintarHora()
	local b = desk and desk.Barra
	if not (b and b.Hora) then return end
	local t = date and date("%H:%M") or ""
	K.Escribir(b.Hora, t)
	local I = rawget(_G, "AlfaInicio")
	local s
	if type(I) == "table" and type(I.Sesion) == "function" then
		local ok, x = pcall(I.Sesion)
		local dur = ok and type(x) == "table" and tonumber(x.dur) or nil
		if dur and dur > 0 then s = format(L["Esta sesión: %s"], N.Duracion(dur, true)) end
	end
	K.Escribir(b.Sesion, s or "")
end

local function menuEscritorio(dueno)
	local ops = {
		{ valor = "editar", texto = L["Editar escritorio"], icono = "ic-ajustes" },
		{ valor = "agregar", texto = L["Agregar un panel"], icono = "ic-mas" },
		{ separador = true },
		{ valor = "asistente", texto = L["Ajustar a mano"], icono = "ic-ventana" },
		{ valor = "ajustes", texto = L["Ajustes de Dos pantallas"], icono = "ic-ajustes" },
		{ separador = true },
		{ valor = "volver", texto = L["Volver a una pantalla"], icono = "ic-cerrar" },
	}
	K.Menu(dueno, ops, nil, function(v)
		local Ed = M.EscritorioEditor
		if v == "editar" and Ed then Ed.Abrir()
		elseif v == "agregar" and Ed then Ed.Abrir(true)
		elseif v == "asistente" then Es.AbrirAsistente(true)
		elseif v == "ajustes" then N.Abrir(ID)
		elseif v == "volver" then Es.Apagar() end
	end, 240)
end
Es.MenuEscritorio = menuEscritorio

local function crearEscritorio()
	desk = CreateFrame("Frame", "AlfaEscritorioMarco", K.Raiz())
	desk:SetFrameStrata("BACKGROUND")
	desk:SetFrameLevel(1)
	desk:EnableMouse(true)
	desk:SetClipsChildren(true)
	-- 1.4.0: el fondo es una noche de Alfa (EscritorioFondo.lua): cielo
	-- azul de noche, estrellas, la luna con su halo, colinas y el lobo.
	desk.Cielo = CreateFrame("Frame", nil, desk)
	desk.Cielo:SetAllPoints(desk)
	desk.Cielo:SetFrameLevel(desk:GetFrameLevel())
	if Es.ArmarCielo then Es.ArmarCielo(desk.Cielo) end
	K.Pintar(desk, function(x)
		x.Cielo:SetAlpha(opt("fondo") == false and 0 or 1)
		if Es.PintarCielo then Es.PintarCielo(x.Cielo) end
	end)
	-- La barra de arriba.
	local b = CreateFrame("Frame", nil, desk)
	desk.Barra = b
	b:SetPoint("TOPLEFT", desk, "TOPLEFT", 0, 0)
	b:SetPoint("TOPRIGHT", desk, "TOPRIGHT", 0, 0)
	b:SetHeight(Es.BARRA)
	b.Fondo = K.Plano(b, "hundido", "BACKGROUND", 0)
	b.Fondo:SetAllPoints(b)
	b.Fondo:SetAlpha(0.82) -- 1.4.0: se asoma la noche de atrás
	b.Linea = K.Linea(b, "linea")
	b.Linea:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.Linea:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.Lobo = b:CreateTexture(nil, "ARTWORK")
	b.Lobo:SetSize(30, 30)
	b.Lobo:SetPoint("LEFT", b, "LEFT", ESP.base, 0)
	b.Lobo:SetTexture(K.Lobo("normal"))
	K.Pintar(b.Lobo, function(t) t:SetVertexColor(K.Color(K.Clasico() and "oro" or "acento")) end)
	b.Titulo = K.Texto(b, "subtitulo", "texto")
	b.Titulo:SetPoint("TOPLEFT", b.Lobo, "TOPRIGHT", ESP.m, 0)
	K.Escribir(b.Titulo, L["Escritorio de Alfa"])
	b.Sub = K.Texto(b, "pequeno", "textoTenue")
	b.Sub:SetPoint("TOPLEFT", b.Titulo, "BOTTOMLEFT", 0, -2)
	b.Sub:SetWordWrap(false)
	-- 1.4.0: un solo desplegable con el escritorio de ahora (antes, una fila
	-- de pastillas que llenaba la barra).
	b.Lista = K.Desplegable(b, { ancho = 200, alCambiar = function(v) Es.Usar(v, "jugador") end })
	b.Lista:SetPoint("LEFT", b.Titulo, "RIGHT", ESP.xl, -8)
	-- 1.4.0: la hora y tu sesión, en la barra (antes era un panel aparte).
	b.Hora = K.Texto(b, "titulo", "texto")
	b.Hora:SetPoint("CENTER", b, "CENTER", 0, 6)
	b.Hora:SetWordWrap(false)
	b.Sesion = K.Texto(b, "pequeno", "textoTenue")
	b.Sesion:SetPoint("TOP", b.Hora, "BOTTOM", 0, -1)
	b.Sesion:SetWordWrap(false)
	b.Menu = K.BotonIcono(b, "menu", function(self) menuEscritorio(self) end, { tam = 32, icono = 16, ayuda = L["Más"] })
	b.Menu:SetPoint("RIGHT", b, "RIGHT", -ESP.m, 0)
	-- 1.4.0: volver a una pantalla a la vista, con un clic.
	b.Una = K.Boton(b, L["Una pantalla"], function() Es.Apagar() end,
		{ tipo = "secundario", icono = "ic-cerrar", ayuda = L["El juego y su interfaz vuelven a toda la ventana, como siempre."] })
	b.Una:SetPoint("RIGHT", b.Menu, "LEFT", -ESP.s, 0)
	b.Editar = K.Boton(b, L["Editar"], function() if M.EscritorioEditor then M.EscritorioEditor.Alternar() end end,
		{ tipo = "secundario", icono = "ic-ajustes", ayuda = L["Mueve los paneles, cámbiales el tamaño y agrega otros."] })
	b.Editar:SetPoint("RIGHT", b.Una, "LEFT", -ESP.s, 0)
	-- «Cambia sola»: un interruptor con su nombre.
	b.AutoTexto = K.Texto(b, "etiqueta", "textoSuave")
	K.Escribir(b.AutoTexto, L["Cambia sola"])
	b.Auto = K.Interruptor(b, { clave = ID .. ".auto", alCambiar = function(on)
		Es.PintarBarra()
		if on then Es.RevisarContexto(true) end
	end, ayuda = L["En una mazmorra, pescando o en la subasta, el escritorio cambia a lo que te sirve ahí."] })
	b.Auto:SetPoint("RIGHT", b.Editar, "LEFT", -ESP.l, 0)
	b.AutoTexto:SetPoint("RIGHT", b.Auto, "LEFT", -ESP.s, 0)
	-- El área de los paneles.
	local area = CreateFrame("Frame", nil, desk)
	desk.Area = area
	area:SetPoint("TOPLEFT", b, "BOTTOMLEFT", ESP.s, -ESP.s)
	area:SetPoint("BOTTOMRIGHT", desk, "BOTTOMRIGHT", -ESP.s, ESP.s)
	area:SetFrameLevel(desk:GetFrameLevel() + 2)
	area:SetScale(Es.Escala())
	-- 1.4.0: «…» y «×» de cada panel se ven solo con el ratón encima (o al
	-- editar); se revisa cada 0,15 s y solo con el escritorio a la vista.
	local espera = 0
	desk:SetScript("OnUpdate", function(_, dt)
		espera = espera + (dt or 0)
		if espera < 0.15 then return end
		espera = 0
		Es.RevisarRaton()
	end)
	desk:SetScript("OnSizeChanged", function() Es.Acomodar() end)
	desk:SetScript("OnShow", function()
		N.Cada("pantallas.paneles", 1, Es.Latido)
		Es.Acomodar()
	end)
	desk:SetScript("OnHide", function()
		N.Quitar("pantallas.paneles")
		if M.EscritorioEditor then K.Llamar(M.EscritorioEditor.Cerrar) end
	end)
	desk:Hide()
end

function Es.Marco() return desk end
function Es.Visible() return desk ~= nil and desk:IsVisible() end

-- 1.4.0: la escala de los paneles (pantallas.tamano). En una franja angosta
-- (el escritorio a un lado de una sola pantalla) no crece: no cabría.
function Es.Escala()
	local v = opt("tamano")
	local e = 1
	for _, t in ipairs(Es.TAMANOS) do if t.valor == v then e = t.escala end end
	if desk then
		local w, h = K.num(desk:GetWidth(), 0), K.num(desk:GetHeight(), 0)
		if w > 0 and h > 0 and w / h < 1.15 then e = 1 end
	end
	return e
end
function Es.PonerEscala()
	if not (desk and desk.Area) then return end
	local e = Es.Escala()
	if abs((tonumber(desk.Area:GetScale()) or 1) - e) > 0.001 then
		desk.Area:SetScale(e)
		for _, p in pairs(marcos) do p.medida = nil end
		Es.Acomodar()
	end
end

-- «…» y «×» de una cabecera: a la vista y con ratón, o invisibles y sin ratón.
function Es.BotonesCabecera(c, ver)
	local a = ver and 1 or 0
	for _, b in ipairs({ c.Menu, c.Cerrar }) do
		b:SetAlpha(a)
		if b.EnableMouse then b:EnableMouse(ver and true or false) end
	end
end

-- «…» y «×» de cada panel: solo con el ratón encima, al editar o con su menú abierto.
function Es.RevisarRaton()
	if not (desk and desk:IsVisible()) then return end
	local editando = M.EscritorioEditor and M.EscritorioEditor.Activo()
	for _, p in pairs(marcos) do
		if p:IsShown() and p.Cab then
			local ver = editando or (p.IsMouseOver and p:IsMouseOver()) or false
			local a = ver and 1 or 0
			if p.Cab.Menu:GetAlpha() ~= a then Es.BotonesCabecera(p.Cab, ver) end
		end
	end
end

---------------------------------------------------------------------------
-- 1.4.0: la vista previa (el escritorio de verdad, sin mover nada)
---------------------------------------------------------------------------
-- Con la ventana ya estirada, Alfa pone su escritorio donde va a quedar y
-- tapa el lado del juego con un velo que dice «aquí sigue tu juego». El mundo
-- y la interfaz no se mueven: es solo para ver. Se cierra sola a los 30 s,
-- con Esc o al entrar en combate; «Probar» sigue con la prueba de 15 s.
local vista, velo
function Es.EnVista() return vista ~= nil end

local function armarVelo()
	local f = CreateFrame("Frame", "AlfaEscritorioVista", K.Raiz())
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(30)
	f:EnableMouse(true)
	f.Fondo = f:CreateTexture(nil, "BACKGROUND")
	f.Fondo:SetAllPoints(f)
	f.Fondo:SetColorTexture(0.02, 0.03, 0.05, 0.72)
	f.Borde = K.Plano(f, "acento", "BORDER")
	f.Tarjeta = CreateFrame("Frame", nil, f)
	f.Tarjeta:SetSize(480, 200)
	f.Tarjeta:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Tarjeta.caja = K.Caja(f.Tarjeta, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.ventana })
	f.Tarjeta.Marca = K.Marca(f.Tarjeta, K.CORTE.ventana, "acento", 44)
	local t = f.Tarjeta
	t.Lobo = t:CreateTexture(nil, "ARTWORK")
	t.Lobo:SetSize(48, 48)
	t.Lobo:SetPoint("TOPLEFT", t, "TOPLEFT", ESP.l, -ESP.l)
	t.Lobo:SetTexture(K.Lobo("atento"))
	K.Pintar(t.Lobo, function(x) x:SetVertexColor(K.Color("acento")) end)
	t.Titulo = K.Texto(t, "titulo", "texto")
	t.Titulo:SetPoint("TOPLEFT", t.Lobo, "TOPRIGHT", ESP.base, -2)
	t.Titulo:SetJustifyH("LEFT")
	t.Texto = K.Texto(t, "texto", "textoSuave")
	t.Texto:SetJustifyH("LEFT")
	t.Probar = K.Boton(t, L["Probar 15 segundos"], function() Es.ProbarVista() end, { tipo = "primario", icono = "ic-ventana" })
	t.Cerrar = K.Boton(t, L["Cerrar la vista previa"], function() Es.CerrarVista() end, { tipo = "secundario" })
	f:EnableKeyboard(true)
	if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
	f:SetScript("OnKeyDown", function(self, tecla)
		if enCombate() then return end
		local esc = tecla == "ESCAPE"
		if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not esc) end
		if esc then Es.CerrarVista() end
	end)
	f:Hide()
	return f
end

local function pintarVelo()
	if not (vista and velo) then return end
	colocar(velo, vista.principal, pantalla())
	local t = velo.Tarjeta
	-- La raya del acento en la orilla con el escritorio.
	velo.Borde:ClearAllPoints()
	local l = vista.lado
	if l == "derecha" then velo.Borde:SetPoint("TOPRIGHT", velo, "TOPRIGHT") velo.Borde:SetPoint("BOTTOMRIGHT", velo, "BOTTOMRIGHT") velo.Borde:SetWidth(3)
	elseif l == "izquierda" then velo.Borde:SetPoint("TOPLEFT", velo, "TOPLEFT") velo.Borde:SetPoint("BOTTOMLEFT", velo, "BOTTOMLEFT") velo.Borde:SetWidth(3)
	elseif l == "abajo" then velo.Borde:SetPoint("BOTTOMLEFT", velo, "BOTTOMLEFT") velo.Borde:SetPoint("BOTTOMRIGHT", velo, "BOTTOMRIGHT") velo.Borde:SetHeight(3)
	else velo.Borde:SetPoint("TOPLEFT", velo, "TOPLEFT") velo.Borde:SetPoint("TOPRIGHT", velo, "TOPRIGHT") velo.Borde:SetHeight(3) end
	K.Escribir(t.Titulo, L["Así queda tu escritorio"])
	local W = 480
	local x = ESP.l + 48 + ESP.base
	local tw = W - x - ESP.l
	t.Titulo:SetWidth(tw)
	local th = K.Parrafo(t.Titulo, tw, 2)
	local quedan = vista.quedan or 30
	K.Escribir(t.Texto, (vista.una and L["Aquí sigue tu juego, y tus paneles al lado. Todavía no se movió nada: es solo para que lo veas."]
		or L["Aquí sigue tu juego, en tu monitor principal, y tus paneles en el otro. Todavía no se movió nada: es solo para que lo veas."])
		.. "\n" .. N.Plural(quedan, L["La vista previa se cierra sola en %d segundo."], L["La vista previa se cierra sola en %d segundos."]))
	t.Texto:ClearAllPoints()
	t.Texto:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(ESP.l + th + ESP.s))
	local tx = K.Parrafo(t.Texto, tw, 5)
	local y = ESP.l + th + ESP.s + tx + ESP.base
	t.Probar:ClearAllPoints()
	t.Probar:SetPoint("TOPLEFT", t, "TOPLEFT", x, -y)
	t.Cerrar:ClearAllPoints()
	t.Cerrar:SetPoint("LEFT", t.Probar, "RIGHT", ESP.s, 0)
	t:SetSize(W, y + K.ALTO.boton + ESP.l)
	-- Que la tarjeta quepa en el lado del juego.
	local vw = K.num(velo:GetWidth(), W)
	if vw > 0 and vw < W + 20 then t:SetScale(max(0.6, (vw - 20) / W)) else t:SetScale(1) end
end

-- o = { lado, proporcion, medida }; alCerrar(probo) cuando se cierra.
function Es.VistaPrevia(o, alCerrar)
	if enCombate() then
		N.Imprimir(L["Las pantallas se acomodan fuera de combate."])
		return false
	end
	if actual or prueba then return false end
	if vista then Es.CerrarVista(true) end
	o = type(o) == "table" and o or {}
	vista = Es.Geometria(o)
	vista.o, vista.alCerrar, vista.quedan = o, alCerrar, 30
	velo = velo or armarVelo()
	Es.MostrarEscritorio(true)
	-- Mientras se ve, el escritorio va encima de la interfaz del juego (que
	-- sigue en toda la ventana): así se ve como va a quedar.
	if desk then desk:SetFrameStrata("DIALOG") desk:SetFrameLevel(2) end
	pintarVelo()
	velo:Show()
	N.Cada("pantallas.vista", 1, function()
		if not vista then N.Quitar("pantallas.vista") return end
		vista.quedan = vista.quedan - 1
		if vista.quedan <= 0 then Es.CerrarVista() return end
		pintarVelo()
	end)
	A.Fire("ALFA_ESCRITORIO", "vista")
	return true
end

function Es.CerrarVista(probo)
	if not vista then return false end
	local alCerrar = vista.alCerrar
	vista = nil
	N.Quitar("pantallas.vista")
	if velo then velo:Hide() end
	if desk then desk:SetFrameStrata("BACKGROUND") desk:SetFrameLevel(1) end
	if not actual then Es.MostrarEscritorio(false) end
	if alCerrar then K.Llamar(alCerrar, probo == true) end
	return true
end

-- «Probar 15 segundos» desde la vista previa: la prueba de siempre.
function Es.ProbarVista()
	if not vista then return false end
	local o = vista.o
	Es.CerrarVista(true)
	return Es.Probar(o)
end

function Es.MostrarEscritorio(on)
	if not on then
		if desk then desk:Hide() end
		return
	end
	if not desk then crearEscritorio() end
	local g = actual or vista
	if not g then return end
	colocar(desk, g.escritorio, pantalla())
	Es.PonerEscala()
	if not distActual then
		local d = opt("distribucion")
		distActual = Es.Existe(d) and d or "aventura"
		paneles = Es.PanelesDe(distActual)
	elseif Es.formaVista ~= Es.Forma() then
		-- De ancha a angosta (o al revés): cada forma con sus lugares.
		paneles = Es.PanelesDe(distActual)
	end
	Es.formaVista = Es.Forma()
	desk:Show()
	Es.Acomodar()
end

-- Cada segundo, con el escritorio a la vista: cada panel a su ritmo; en
-- combate solo los que lo piden (el medidor) y nada pesado.
local cuenta = 0
function Es.Latido()
	if not (desk and desk:IsVisible()) then return end
	cuenta = cuenta + 1
	local pelea = enCombate()
	for _, x in ipairs(paneles) do
		local p = marcos[x.id]
		local def = p and p.def
		local ritmo = def and tonumber(def.ritmo)
		if ritmo and p:IsVisible() and (not pelea or def.enCombate) and cuenta % max(1, floor(ritmo)) == 0 then
			pintarPanel(p)
		end
	end
	if cuenta % 2 == 0 and not pelea then Es.RevisarContexto() end
	if cuenta % 10 == 0 then Es.PintarHora() end
end

---------------------------------------------------------------------------
-- Cambiar sola por lo que haces
---------------------------------------------------------------------------
Es.CONTEXTOS = {
	{ id = "instancia", texto = "En una mazmorra o banda", icono = "ic-mazmorra" },
	{ id = "pesca", texto = "Pescando", icono = "ic-pesca" },
	{ id = "comercio", texto = "En la subasta, el buzón o el banco", icono = "ic-comercio" },
	{ id = "grupo", texto = "En grupo", icono = "ic-manada" },
	{ id = "nada", texto = "Lo demás", icono = "ic-aventura" },
}
Es.REGLAS = { instancia = "mazmorra", pesca = "pesca", comercio = "comercio", grupo = "aventura", nada = "aventura" }

function Es.Regla(ctx)
	local r = datos().reglas
	local v = type(r) == "table" and r[ctx] or nil
	if v and Es.Existe(v) then return v end
	return Es.REGLAS[ctx]
end
function Es.PonerRegla(ctx, id)
	local d = datos()
	if type(d.reglas) ~= "table" then d.reglas = {} end
	d.reglas[ctx] = (id ~= Es.REGLAS[ctx]) and id or nil
	ultimoCtx = nil
	Es.RevisarContexto(true)
end

local abiertos = {} -- la subasta, el buzón o el banco a la vista
function Es.Contexto()
	local dentro, tipo = false, nil
	if IsInInstance then dentro, tipo = IsInInstance() end
	if N.Secreto and (N.Secreto(dentro) or N.Secreto(tipo)) then dentro, tipo = false, nil end
	if dentro == true and (tipo == "party" or tipo == "raid" or tipo == "scenario") then return "instancia" end
	local Pe = rawget(_G, "AlfaPesca")
	if type(Pe) == "table" and type(Pe.Activo) == "function" then
		local ok, si = pcall(Pe.Activo)
		if ok and si == true then return "pesca" end
	end
	if next(abiertos) then return "comercio" end
	if IsInGroup and IsInGroup() == true then return "grupo" end
	return "nada"
end

function Es.RevisarContexto(forzar)
	if not actual or opt("auto") == false then return end
	local c = Es.Contexto()
	if c == ultimoCtx and not forzar then return end
	ultimoCtx = c
	local d = Es.Regla(c)
	if d and d ~= distActual then Es.Usar(d, "auto") end
end
local function revisarLuego() N.Una("pantallas.contexto", 0.3, function() Es.RevisarContexto() end) end
for ev, que in pairs({ AUCTION_HOUSE_SHOW = "subasta", MAIL_SHOW = "buzon", BANKFRAME_OPENED = "banco" }) do
	A.RegisterEvent(ev, function() abiertos[que] = true revisarLuego() end)
end
for ev, que in pairs({ AUCTION_HOUSE_CLOSED = "subasta", MAIL_CLOSED = "buzon", BANKFRAME_CLOSED = "banco" }) do
	A.RegisterEvent(ev, function() abiertos[que] = nil revisarLuego() end)
end
for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }) do A.RegisterEvent(ev, revisarLuego) end
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	wipe(abiertos)
	revisarLuego()
end)
-- Una pelea termina el editor (en combate no se acomoda nada).
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if M.EscritorioEditor and M.EscritorioEditor.Activo() then K.Llamar(M.EscritorioEditor.Cerrar) end
	-- 1.4.0: la vista previa se cierra al empezar una pelea (nada que tape el juego).
	if vista then Es.CerrarVista() end
	-- (1.3.8 revisión) «¿Se ve bien?» no toma el teclado en combate (antes del bloqueo).
	if confirmar then confirmar:EnableKeyboard(false) end
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if confirmar and prueba then confirmar:EnableKeyboard(true) end
end)

---------------------------------------------------------------------------
-- Al entrar: lo guardado vuelve; una prueba a medias no
---------------------------------------------------------------------------
function Es.AlEntrar()
	engancharCine()
	local d = datos()
	-- 1.3.8: un clic a medias (la ventana estirada sin decir «Sí»): todo como estaba.
	if Es.AlEntrarAuto and Es.AlEntrarAuto() then d.probando = nil return end
	if d.probando then
		d.probando = nil
		N.Imprimir(L["La prueba de las dos pantallas no se terminó: Alfa quedó en una sola pantalla."])
		return
	end
	if opt("activo") == true then
		N.FueraDeCombate("pantallas.aplicar", function() Es.Aplicar() end)
	elseif Es.OfrecerAuto and Es.OfrecerAuto() then
		-- (EscritorioAuto.lua: hay otro monitor y el juego ocupa uno)
	elseif opt("ofrecer") ~= false and not d.ofrecido and Es.EsAncha() then
		local libre = N.AlLibre or function(_, f) f() end
		libre("pantallas.ofrecer", function()
			d.ofrecido = true
			K.Aviso({ id = "pantallas.ofrecer", icono = "ic-ventana", lobo = "atento", prioridad = 3,
				titulo = L["¿Juegas con dos monitores?"],
				texto = L["Tu ventana es muy ancha: puedo dejar el juego en tu monitor principal y poner a Alfa en el otro."],
				acciones = { { texto = L["Ver cómo"], fn = function() Es.AbrirAsistente(true) end },
					{ texto = L["Ahora no"], fn = function() end } } })
		end, 3)
	end
end
A.OnLogin(function() Es.AlEntrar() end)

function Es.AbrirAsistente()
	if M.EscritorioAsistente then return M.EscritorioAsistente.Abrir() end
	N.Abrir(ID)
end

---------------------------------------------------------------------------
-- /alfa pantallas
---------------------------------------------------------------------------
local function comando(resto)
	resto = type(resto) == "string" and resto:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
	if resto == "volver" or resto == "una" or resto == "apagar" then return Es.Apagar() end
	-- 1.4.0: «Reparar mi pantalla» (con confirmación).
	if resto == "reparar" or resto == "arreglar" then return M.EscritorioReparar and M.EscritorioReparar.Preguntar() end
	if resto == "probar" then return Es.Probar({ lado = opt("lado"), proporcion = opt("proporcion"), medida = opt("medida") }) end
	if resto == "editar" then
		if not actual then N.Imprimir(L["Primero acomoda tus pantallas: /alfa pantallas."]) return end
		return M.EscritorioEditor and M.EscritorioEditor.Abrir()
	end
	if resto == "ajustes" then return N.Abrir(ID) end
	if resto ~= "" then
		for _, d in ipairs(Es.Distribuciones()) do
			if d.id == resto or (d.nombre or ""):lower() == resto then
				if actual then Es.Usar(d.id, "jugador") end
				return
			end
		end
	end
	Es.AbrirAsistente()
end
A.RegisterCommand("pantallas", comando, L["Alfa en tu segundo monitor (también: probar, volver, editar, reparar)"])
A.RegisterCommand("escritorio", comando, L["Alfa en tu segundo monitor (también: probar, volver, editar, reparar)"], true)

---------------------------------------------------------------------------
-- AlfaEscritorio: para el menú de Alfa, Lya, otros módulos y el banco
---------------------------------------------------------------------------
AlfaEscritorio = type(rawget(_G, "AlfaEscritorio")) == "table" and rawget(_G, "AlfaEscritorio") or {}
local API = AlfaEscritorio
API.Abrir = function() return Es.AbrirAsistente() end
API.Activo = function() return actual ~= nil end
API.Probar = function(o) return Es.Probar(o) end
API.Volver = function() return Es.Apagar() end
API.Editar = function() return M.EscritorioEditor and M.EscritorioEditor.Abrir() end
API.Usar = function(id) return Es.Usar(id, "jugador") end
API.Distribucion = function() return distActual end
API.EsAncha = function() return Es.EsAncha() end
-- 1.3.9: otros módulos registran su panel (La Jauría: el marcador por bando).
API.RegistrarPanel = function(def) return Es.Registrar(def) end
