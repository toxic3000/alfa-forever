-- Alfa - Bienvenida: Dos pantallas en un clic (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Si tienes otro monitor y el juego ocupa solo uno, Alfa lo ofrece una vez:
-- «Vi que tienes otro monitor. ¿Pongo Alfa ahí?». Con «Sí, en un clic» (el
-- clic del jugador, fuera de combate):
--   1. guarda el modo y el tamaño de la ventana de antes (CVars gxWindow,
--      gxMaximize, gxWindowedResolution y C_VideoOptions.GetCurrentGameWindowSize);
--   2. pone el juego en ventana del ancho de los dos monitores
--      (C_VideoOptions.SetGameWindowSize) y reinicia los gráficos (RestartGx);
--   3. al volver los gráficos (DISPLAY_SIZE_CHANGED / GX_RESTARTED) pone el
--      escritorio y arranca la prueba «¿Se ve bien?» de 15 s (Es.Probar);
--   4. si no contestas o dices que no, el escritorio se va y la ventana vuelve
--      a su modo y tamaño de antes (otro RestartGx).
-- Lo que va a medias se anota en AlfaNucleoDB.pantallas.auto: un /reload a
-- media operación devuelve la ventana (nunca queda estirada sin escritorio).
-- «Volver a una pantalla» también la devuelve. La posición de la ventana no se
-- puede mover desde un addon: la prueba dice cómo dejarla en su orilla.
-- Con Offhand cargado no se estira nada (él lo hace); para tres monitores o uno
-- arriba de otro está «Ajustar a mano» (el asistente).
--   M.EscritorioAuto.Monitores() / PuedeUnClic() / UnClic() / Revertir() / Fase()

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio

local type, ipairs, tonumber, tostring, pcall = type, ipairs, tonumber, tostring, pcall
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local Au = {}
M.EscritorioAuto = Au

local function opt(k) return N.Get(Es.ID, k) end
local function datos() return N.Datos(Es.ID) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function video() local v = rawget(_G, "C_VideoOptions") return type(v) == "table" and v or nil end
local function leer(v) if N.Secreto and N.Secreto(v) then return nil end return v end

-- Un tamaño del juego (Vector2D o { x, y }) -> ancho, alto | nil
local function medida(v)
	v = leer(v)
	if type(v) ~= "table" then return nil end
	local x, y = leer(v.x), leer(v.y)
	if (x == nil or y == nil) and type(v.GetXY) == "function" then
		local ok, a, b = pcall(v.GetXY, v)
		if ok then x, y = leer(a), leer(b) end
	end
	x, y = tonumber(x), tonumber(y)
	if x and y and x > 0 and y > 0 then return floor(x + 0.5), floor(y + 0.5) end
	return nil
end

local function cvar(n)
	if type(GetCVar) ~= "function" then return nil end
	local ok, v = pcall(GetCVar, n)
	v = ok and leer(v) or nil
	return type(v) == "string" and v or nil
end
local function ponerCVar(n, v)
	if v == nil or type(SetCVar) ~= "function" then return end
	pcall(SetCVar, n, v)
end

-- Los monitores: { { indice, w, h }, ... } (índices desde 0, como gxMonitor).
function Au.Monitores()
	local V = video()
	if not (V and type(V.GetDefaultGameWindowSize) == "function") then return {} end
	local cuenta = rawget(_G, "GetMonitorCount")
	local n
	if type(cuenta) == "function" then
		local ok, c = pcall(cuenta)
		n = ok and tonumber(leer(c)) or nil
	end
	local out = {}
	for i = 0, (n and n - 1 or 5) do
		local ok, s = pcall(V.GetDefaultGameWindowSize, i)
		local w, h = medida(ok and s or nil)
		if not w then
			if not n then break end
		else
			out[#out + 1] = { indice = i, w = w, h = h }
		end
	end
	return out
end

-- El tamaño de la ventana de ahora (píxeles), o nil.
function Au.Ventana()
	local V = video()
	if not (V and type(V.GetCurrentGameWindowSize) == "function") then return nil end
	local ok, s = pcall(V.GetCurrentGameWindowSize)
	return medida(ok and s or nil)
end

function Au.Fase() local a = datos().auto return type(a) == "table" and a.fase or nil end

-- ¿Se puede hacer todo con un clic? -> ok, el plan { principal, otro, W, H, parte }
function Au.Plan()
	local V = video()
	if not (V and type(V.SetGameWindowSize) == "function" and type(rawget(_G, "RestartGx")) == "function") then return nil end
	if Es.OtroLoHace() then return nil end
	local mons = Au.Monitores()
	if #mons < 2 then return nil end
	local actual = tonumber(cvar("gxMonitor")) or 0
	local principal, otro
	for _, m in ipairs(mons) do if m.indice == actual then principal = m end end
	principal = principal or mons[1]
	for _, m in ipairs(mons) do if m ~= principal and not otro then otro = m end end
	if not otro then return nil end
	local W, H = principal.w + otro.w, min(principal.h, otro.h)
	return { principal = principal, otro = otro, W = W, H = H, parte = principal.w / W * 100 }
end

function Au.PuedeUnClic()
	if Es.Aplicado() or Au.Fase() then return false end
	if Es.EsAncha() then return false end -- la ventana ya es de dos (Ajustar a mano o Offhand)
	return Au.Plan() ~= nil
end

---------------------------------------------------------------------------
-- Estirar y devolver
---------------------------------------------------------------------------
local function reiniciar()
	local r = rawget(_G, "RestartGx")
	if type(r) == "function" then pcall(r) end
end

-- La ventana a como estaba antes del clic (y se olvida lo anotado).
function Au.Revertir(porque)
	local a = datos().auto
	if type(a) ~= "table" then return false end
	if enCombate() then
		N.FueraDeCombate("pantallas.auto", function() Au.Revertir(porque) end)
		return false
	end
	datos().auto = nil
	N.Quitar("pantallas.auto.espera")
	local antes = type(a.antes) == "table" and a.antes or {}
	ponerCVar("gxWindow", antes.gxWindow)
	ponerCVar("gxMaximize", antes.gxMaximize)
	ponerCVar("gxWindowedResolution", antes.gxWindowedResolution)
	local V = video()
	if V and type(V.SetGameWindowSize) == "function" and tonumber(antes.w) and tonumber(antes.h) then
		pcall(V.SetGameWindowSize, antes.w, antes.h)
	end
	reiniciar()
	if porque then N.Imprimir(porque) end
	return true
end
Es.DesestirarAuto = function()
	if Au.Fase() == "hecho" then return Au.Revertir() end
	return false
end

local nota -- la línea de la prueba
local function alVolverGraficos()
	local a = datos().auto
	if type(a) ~= "table" or a.fase ~= "estirando" then return end
	if enCombate() then
		N.FueraDeCombate("pantallas.auto", alVolverGraficos)
		return
	end
	N.Quitar("pantallas.auto.espera")
	-- El juego no dejó estirar la ventana: todo como estaba.
	if not Es.EsAncha() then
		Au.Revertir(L["Tu juego no dejó estirar la ventana: quedó como estaba. Puedes ajustarlo a mano en Ajustes > Dos pantallas."])
		return
	end
	a.fase = "probando"
	local ok = Es.Probar({ lado = "derecha", proporcion = "medida", medida = tonumber(a.parte) or 50 }, {
		nota = L["Si la ventana no empieza en la orilla izquierda de tu monitor principal, arrástrala ahí una vez; Windows la recordará."],
		alConfirmar = function()
			local x = datos().auto
			if type(x) == "table" then x.fase = "hecho" end
		end,
		alRechazar = function() Au.Revertir() end,
	})
	if not ok then Au.Revertir() end
end
Au.AlVolverGraficos = alVolverGraficos

local function despuesDeGraficos()
	if Au.Fase() == "estirando" then N.Una("pantallas.auto.listo", 0.5, alVolverGraficos) end
end
A.RegisterEvent("DISPLAY_SIZE_CHANGED", despuesDeGraficos)
A.RegisterEvent("GX_RESTARTED", despuesDeGraficos)

-- «Sí, en un clic»: el clic del jugador, fuera de combate.
function Au.UnClic()
	if enCombate() then
		N.Imprimir(L["Las pantallas se acomodan fuera de combate."])
		return false
	end
	local plan = Au.Plan()
	if not plan or Au.Fase() or Es.Aplicado() then return false end
	local V = video()
	local w, h = Au.Ventana()
	datos().auto = {
		fase = "estirando", parte = plan.parte, W = plan.W, H = plan.H,
		antes = { gxWindow = cvar("gxWindow"), gxMaximize = cvar("gxMaximize"),
			gxWindowedResolution = cvar("gxWindowedResolution"), w = w, h = h },
	}
	ponerCVar("gxWindow", "1")
	ponerCVar("gxMaximize", "0")
	local ok = pcall(V.SetGameWindowSize, plan.W, plan.H)
	if not ok then
		Au.Revertir(L["Tu juego no dejó estirar la ventana: quedó como estaba. Puedes ajustarlo a mano en Ajustes > Dos pantallas."])
		return false
	end
	reiniciar()
	-- Si los gráficos no avisan, se revisa solo a los 12 s.
	N.Una("pantallas.auto.espera", 12, function()
		if Au.Fase() == "estirando" then alVolverGraficos() end
	end)
	return true
end

-- Un /reload (o salir) a media operación: la ventana vuelve a como estaba.
Es.AlEntrarAuto = function()
	local f = Au.Fase()
	if f == "estirando" or f == "probando" then
		Au.Revertir(L["La prueba de las dos pantallas no se terminó: devolví la ventana a como estaba."])
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- El aviso de una sola vez
---------------------------------------------------------------------------
local oferta

local function armarOferta()
	local f = CreateFrame("Frame", "AlfaEscritorioOferta", K.Raiz())
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(40)
	f:SetWidth(470)
	f:SetPoint("TOP", UIParent, "TOP", 0, -120)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.ventana })
	f.Marca = K.Marca(f, K.CORTE.ventana, "acento", 44)
	f.Lobo = f:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(44, 44)
	f.Lobo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.l, -ESP.l)
	f.Lobo:SetTexture(K.Lobo("atento"))
	K.Pintar(f.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	f.Titulo = K.Texto(f, "subtitulo", "texto")
	f.Titulo:SetPoint("TOPLEFT", f.Lobo, "TOPRIGHT", ESP.base, -2)
	f.Titulo:SetJustifyH("LEFT")
	f.Texto = K.Texto(f, "nota", "textoSuave")
	f.Texto:SetJustifyH("LEFT")
	f.Si = K.Boton(f, L["Sí, en un clic"], function() f:Hide() Au.UnClic() end, { tipo = "primario", icono = "ic-ventana" })
	f.Ahora = K.Boton(f, L["Ahora no"], function() f:Hide() end, { tipo = "secundario" })
	f.Nunca = K.Boton(f, L["No volver a preguntar"], function()
		datos().noPreguntar = true
		f:Hide()
	end, { tipo = "fantasma" })
	f:Hide()
	return f
end

function Au.Ofrecer()
	oferta = oferta or armarOferta()
	local f = oferta
	K.Escribir(f.Titulo, L["Vi que tienes otro monitor. ¿Pongo Alfa ahí?"])
	K.Escribir(f.Texto, L["Estiro la ventana del juego a tus dos monitores: el juego se queda en este y tus paneles de Alfa van al otro. Lo pruebas 15 segundos antes de guardar."])
	local x = ESP.l + 44 + ESP.base
	local tw = 470 - x - ESP.l
	f.Titulo:SetWidth(tw)
	local th = K.Parrafo(f.Titulo, tw, 2)
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(ESP.l + th + ESP.s))
	local y = ESP.l + th + ESP.s + K.Parrafo(f.Texto, tw, 4) + ESP.base
	f.Si:ClearAllPoints()
	f.Si:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
	f.Ahora:ClearAllPoints()
	f.Ahora:SetPoint("LEFT", f.Si, "RIGHT", ESP.s, 0)
	f.Nunca:ClearAllPoints()
	f.Nunca:SetPoint("TOPLEFT", f.Si, "BOTTOMLEFT", 0, -ESP.s)
	f:SetHeight(y + K.ALTO.boton * 2 + ESP.s + ESP.l)
	f:Show()
	return f
end
function Au.OfertaVisible() return oferta ~= nil and oferta:IsShown() end

-- Al entrar (Escritorio.lua, Es.AlEntrar): una sola vez, sin costo.
Es.OfrecerAuto = function()
	local d = datos()
	if d.noPreguntar or d.autoPreguntado or opt("ofrecer") == false then return false end
	if not Au.PuedeUnClic() then return false end
	local libre = N.AlLibre or function(_, fn) fn() end
	libre("pantallas.auto.ofrecer", function()
		if enCombate() or not Au.PuedeUnClic() then return end
		d.autoPreguntado = true
		Au.Ofrecer()
	end, 3)
	return true
end

-- El menú de Alfa y /alfa pantallas: con otro monitor libre, el aviso del clic;
-- si no, el asistente («Ajustar a mano»).
local abrirAsistente = Es.AbrirAsistente
function Es.AbrirAsistente(aMano)
	if not aMano and Au.PuedeUnClic() then return Au.Ofrecer() end
	return abrirAsistente()
end
