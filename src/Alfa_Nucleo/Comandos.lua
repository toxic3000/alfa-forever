-- Alfa - Núcleo: los comandos de /alfa a la mano (1.4.0, 110 y 111).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- 110. Un comando con un error de dedo (/alfa pantalas) ya no llena el chat
--      con la lista entera: Alfa dice «¿Quisiste decir /alfa pantallas?» y
--      dónde ver todos. Nunca corre el parecido por su cuenta.
-- 111. /alfa comandos: una ventana con todos los comandos y su ayuda, con
--      buscador; un clic deja el comando escrito en tu chat, listo para Enter
--      (o para agregarle lo que pida).
--
-- La lista sale del propio despachador del motor (Core/Init.lua): su ayuda
-- (/alfa help) se lee una vez, sin que salga en el chat, y se vuelve a leer
-- si llega uno que no estaba (un módulo lo registró después). Así un comando nuevo sale solo.
--   N.Comandos.Lista() -> { { nombre, ayuda }, ... }   (en el orden del motor)
--   N.Comandos.Existe(nombre) -> bool
--   N.Comandos.Parecido(nombre) -> nombre | nil
--   N.Comandos.Abrir([texto])

local _, N = ...
local A = N.A
local L = N.Textos(N.EN) -- (el Kit carga después: se pide al usarlo)
local K = setmetatable({}, { __index = function(_, k) return N.Kit[k] end })

local type, ipairs, pairs, tostring, pcall, format = type, ipairs, pairs, tostring, pcall, string.format
local min, max, floor = math.min, math.max, math.floor

local Co = {}
N.Comandos = Co

local cache -- { lista, porNombre }
local motorRun -- el despachador tal como estaba al cargar este archivo

-- Lee la ayuda del motor sin que se escriba nada en el chat.
local function leer()
	local lista, porNombre = {}, {}
	local cf = rawget(_G, "DEFAULT_CHAT_FRAME")
	local run = motorRun or (A and A.RunCommand)
	if type(cf) ~= "table" or type(run) ~= "function" then return { lista = lista, porNombre = porNombre } end
	local antes = rawget(cf, "AddMessage")
	local antesPrint = A.Print
	rawset(cf, "AddMessage", function(_, msg)
		if type(msg) ~= "string" then return end
		local nombre, ayuda = msg:match("^%s*/alfa%s+(%S+)%s*(.-)%s*$")
		if not nombre then return end
		nombre = nombre:lower()
		ayuda = (ayuda or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		if not porNombre[nombre] then
			local c = { nombre = nombre, ayuda = ayuda }
			lista[#lista + 1] = c
			porNombre[nombre] = c
		end
	end)
	A.Print = function() end
	local ok, err = pcall(run, "help")
	rawset(cf, "AddMessage", antes)
	A.Print = antesPrint
	if not ok and N.Debug then pcall(N.Debug, "comandos: " .. tostring(err)) end
	return { lista = lista, porNombre = porNombre }
end

local function datos()
	if not cache then cache = leer() end
	return cache
end

function Co.Lista() return datos().lista end
function Co.Existe(nombre)
	if type(nombre) ~= "string" then return false end
	nombre = nombre:lower()
	if nombre == "help" or datos().porNombre[nombre] ~= nil then return true end
	cache = nil
	return datos().porNombre[nombre] ~= nil
end
function Co.Olvidar() cache = nil end

-- Distancia de edición (letras cambiadas, de más o de menos), con tope.
local function distancia(a, b, tope)
	local la, lb = #a, #b
	if math.abs(la - lb) > tope then return tope + 1 end
	local prev, cur = {}, {}
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		cur[0] = i
		local mejor = i
		local ca = a:byte(i)
		for j = 1, lb do
			local costo = (ca == b:byte(j)) and 0 or 1
			local v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + costo)
			cur[j] = v
			if v < mejor then mejor = v end
		end
		if mejor > tope then return tope + 1 end
		prev, cur = cur, prev
	end
	return prev[lb]
end

-- Algunas palabras que se escriben en español y el comando que las hace.
local SINONIMOS = { ajustes = "options", opciones = "options", configuracion = "options", ["configuración"] = "options",
	config = "options", guias = "guides", ["guías"] = "guides", talentos = "talents", mazmorras = "dungeons",
	raros = "rares", ocultar = "hide", mostrar = "show", siguiente = "next", anterior = "prev", reportar = "report",
	lista = "comandos", comando = "comandos", ayudas = "ayuda" }

function Co.Parecido(nombre)
	if type(nombre) ~= "string" or nombre == "" then return nil end
	nombre = nombre:lower()
	local d = datos()
	local s = SINONIMOS[nombre]
	if s and d.porNombre[s] then return s end
	-- Lo que empieza igual (y es uno solo).
	if #nombre >= 3 then
		local uno
		for _, c in ipairs(d.lista) do
			if c.nombre:sub(1, #nombre) == nombre then
				if uno then uno = false break end
				uno = c.nombre
			end
		end
		if uno then return uno end
	end
	local tope = #nombre <= 4 and 1 or 2
	local mejor, dm = nil, tope + 1
	for _, c in ipairs(d.lista) do
		local x = distancia(nombre, c.nombre, tope)
		if x < dm then mejor, dm = c.nombre, x end
	end
	return mejor
end

local function tenir(t)
	local Kit = N.Kit
	if Kit and Kit.Tenir then return Kit.Tenir("acento", t) end
	return t
end

local function decir(t)
	if N.Imprimir then N.Imprimir(t) elseif A and A.Print then A.Print(t) end
end

-- -> el texto que se dijo (para el banco)
function Co.Desconocido(nombre)
	local p = Co.Parecido(nombre)
	local c = p and datos().porNombre[p]
	local t
	if c then
		t = format(L["No conozco «/alfa %s». ¿Quisiste decir %s?"], nombre, tenir("/alfa " .. p))
		if c.ayuda ~= "" then t = t .. " (" .. c.ayuda .. ")" end
	else
		t = format(L["No conozco «/alfa %s»."], nombre)
	end
	t = t .. " " .. format(L["Todos los comandos: %s."], tenir("/alfa comandos"))
	decir(t)
	Co.ultimo = t
	return t
end

---------------------------------------------------------------------------
-- El despachador: lo desconocido pasa por aquí antes de llegar al motor.
---------------------------------------------------------------------------
if A and type(A.RunCommand) == "function" then
	motorRun = A.RunCommand
	A.RunCommand = function(msg, ...)
		local nombre = type(msg) == "string" and msg:match("^%s*(%S+)") or nil
		if nombre and not Co.Existe(nombre) then
			-- (una lista vacía, si el motor cambiara su ayuda: entonces manda él)
			if #datos().lista > 0 then return Co.Desconocido(nombre:lower()) end
		end
		return motorRun(msg, ...)
	end
	if SlashCmdList and SlashCmdList.ALFA == motorRun then SlashCmdList.ALFA = A.RunCommand end
end
-- (Sin envolver A.RegisterCommand: un comando que no está en la lista guardada
-- hace que se vuelva a leer una vez, por si un módulo lo registró después.)

---------------------------------------------------------------------------
-- 111. La ventana de los comandos
---------------------------------------------------------------------------
local v, ui = nil, {}

local function plegar(s)
	s = tostring(s or ""):lower()
	return (s:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ñ", "n"))
end

-- Deja «/alfa nombre » escrito en el chat (Enter lo corre).
function Co.Escribir(nombre)
	local t = "/alfa " .. tostring(nombre) .. " "
	if type(ChatFrame_OpenChat) == "function" and pcall(ChatFrame_OpenChat, t) then return true end
	return false
end

-- Las filas: «/alfa nombre» a la izquierda y su ayuda a la derecha (envuelta,
-- nunca cortada); el ratón encima la ilumina y su clic la deja en tu chat.
local COL, FILA_PAD = 150, 6
local function nuevaFila(padre)
	local f = CreateFrame("Button", nil, padre)
	f.Fondo = K.Plano(f, "elevado", "BACKGROUND", 0)
	f.Fondo:SetAllPoints(f)
	f.Fondo:Hide()
	f.Nombre = K.Texto(f, "cuerpo", "acento")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", K.ESP.s, -FILA_PAD)
	f.Ayuda = K.Texto(f, "nota", "textoSuave")
	f.Ayuda:SetPoint("TOPLEFT", f, "TOPLEFT", K.ESP.s + COL, -FILA_PAD)
	f:SetScript("OnEnter", function(self) self.Fondo:Show() end)
	f:SetScript("OnLeave", function(self) self.Fondo:Hide() end)
	f:SetScript("OnClick", function(self) if self.alfaNombre then Co.Escribir(self.alfaNombre) end end)
	K.ConInfo(f, function(self) return "/alfa " .. tostring(self.alfaNombre), L["Clic: lo dejo escrito en tu chat; pulsa Enter para usarlo."] end)
	return f
end

local function nuevaLista(padre)
	local l = CreateFrame("Frame", nil, padre)
	l.filas, l.datos = {}, {}
	function l:Llenar(datos) self.datos = datos or {} end
	function l:Acomodar(ancho)
		local y = 0
		for i, c in ipairs(self.datos) do
			local f = self.filas[i] or nuevaFila(self)
			self.filas[i] = f
			f.alfaNombre = c.nombre
			K.Escribir(f.Nombre, "/alfa " .. c.nombre)
			-- (con mayúscula al empezar: la ayuda de unos módulos va en minúscula)
			K.Escribir(f.Ayuda, (c.ayuda:gsub("^%l", string.upper)))
			-- Un nombre que no cabe en su columna se lleva la ayuda abajo.
			local wn = K.AnchoTexto(f.Nombre)
			local abajo = wn > COL - K.ESP.s
			f.Ayuda:ClearAllPoints()
			local h
			if abajo then
				f.Ayuda:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -2)
				h = K.Parrafo(f.Nombre, ancho - 2 * K.ESP.s) + 2 + K.Parrafo(f.Ayuda, ancho - 2 * K.ESP.s)
			else
				f.Ayuda:SetPoint("TOPLEFT", f, "TOPLEFT", K.ESP.s + COL, -FILA_PAD)
				h = max(K.Parrafo(f.Nombre, COL - K.ESP.s), K.Parrafo(f.Ayuda, ancho - COL - 2 * K.ESP.s))
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			f:SetSize(ancho, h + 2 * FILA_PAD)
			f:Show()
			y = y + h + 2 * FILA_PAD + 1
		end
		for i = #self.datos + 1, #self.filas do self.filas[i]:Hide() end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return l
end

local function llenar()
	if not (v and ui.rejilla) then return end
	local q = plegar(ui.buscador and ui.buscador:Texto() or "")
	local items = {}
	for _, c in ipairs(Co.Lista()) do
		if c.nombre ~= "debug" and (q == "" or plegar(c.nombre):find(q, 1, true) or plegar(c.ayuda):find(q, 1, true)) then
			items[#items + 1] = c
		end
	end
	table.sort(items, function(a, b) return a.nombre < b.nombre end)
	ui.rejilla:Llenar(items)
	K.Mostrar(ui.rejilla, #items > 0)
	if ui.vacio.Set then
		ui.vacio:Set({ lobo = "vacio", titulo = L["Ningún comando dice eso"], texto = L["Prueba con otra palabra, en español o en inglés."],
			accion = { texto = L["Ver todos"], alClic = function() ui.buscador:SetTexto("") end } })
	end
	K.Mostrar(ui.vacio, #items == 0)
	K.Escribir(ui.cuenta.Texto, N.Plural(#items, L["%d comando"], L["%d comandos"]) .. "  \194\183  " .. L["Clic en uno y queda escrito en tu chat."])
	if v.alAcomodar then v.alAcomodar() end
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo()
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end

local function armar()
	v = K.Ventana({ nombre = "AlfaComandos", titulo = L["Comandos de Alfa"], icono = "ic-lista", ancho = 640, alto = 560, desplazar = true })
	v:SetTitulo(L["Comandos de Alfa"], L["Todo lo que puedes escribir después de /alfa"], "ic-lista")
	v.alAcomodar = acomodar
	local p = K.Pila(v.Cuerpo, { espacio = K.ESP.base })
	ui.pila = p
	ui.buscador = p:Agregar(K.Buscador(p, { ayuda = L["Busca un comando o lo que quieres hacer"], alCambiar = llenar }))
	local cuenta = CreateFrame("Frame", nil, p)
	cuenta.Texto = K.Texto(cuenta, "pequeno", "textoTenue")
	cuenta.Texto:SetPoint("TOPLEFT")
	function cuenta:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
	ui.cuenta = p:Agregar(cuenta, { espacio = K.ESP.s })
	ui.rejilla = p:Agregar(nuevaLista(p), { espacio = K.ESP.s })
	ui.vacio = p:Agregar(K.Vacio(p, {}), { espacio = K.ESP.l })
	v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "primario" }) })
end

function Co.Abrir(texto)
	if not N.Kit then return nil end
	Co.Olvidar() -- (lo más nuevo: un módulo pudo registrar uno)
	if not v then armar() end
	v:Abrir()
	ui.buscador:SetTexto(type(texto) == "string" and texto or "", true)
	llenar()
	if N.Una then N.Una("nucleo.comandosOtraVez", 0, function() if v and v:IsShown() then llenar() end end) end
	return v
end
function Co.Ventana() return v end

if A and A.RegisterCommand then
	A.RegisterCommand("comandos", function(resto)
		local q = type(resto) == "string" and resto:match("^%s*(.-)%s*$") or ""
		Co.Abrir(q)
	end, L["todos los comandos de Alfa en una ventana, con buscador"])
end
