-- Alfa - Comodidades: te escribieron mientras peleabas (1.4.2).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- En plena pelea (o ausente, /afk) un susurro se pierde entre el combate y
-- se queda sin respuesta. Con «susurrosPendientes» (de fábrica, sí) Alfa
-- anota quién te escribió mientras peleabas o no estabas y, al terminar la
-- pelea (o al volver), un aviso te lo dice: quién, lo que dijo (corto) y
-- «Responder a <nombre>», que abre la caja del chat con «/w nombre» listo
-- (lo envías tú con Intro: nada se manda solo). «Ver todos» los muestra
-- completos en el cuadro de copiar. Solo susurros de personajes (no de
-- Battle.net); un mensaje o un nombre secreto no se lee.
--
--   Pd.Lista() -> { { nombre, texto, t } } ; Pd.AlSusurro(evento, msg, quien)
--   Pd.Mostrar(porque) -> el aviso | nil ; Pd.Responder(nombre) ; Pd.Olvidar()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local Pd = {}
M.Pendientes = Pd

local type, pcall, format, ipairs, concat = type, pcall, string.format, ipairs, table.concat

local MAX = 20
local CORTO = 60

local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end
local function ahora() return GetTime and GetTime() or 0 end

local lista = {}
local motivo -- "combate" | "ausente"

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function ausente() return N.SiJuego(rawget(_G, "UnitIsAFK"), "player") end

function Pd.Lista() return lista end
function Pd.Olvidar() lista, motivo = {}, nil end

local function sinCodigos(s)
	local Ch = M.Charla
	if Ch and Ch.SinCodigos then return Ch.SinCodigos(s) end
	return s
end

local function mostrarNombre(nombre)
	if Ambiguate then
		local ok, v = pcall(Ambiguate, nombre, "none")
		if ok and texto(v) then return v end
	end
	return nombre
end

function Pd.AlSusurro(_, msg, quien)
	if not M.Get("susurrosPendientes") then return false end
	msg, quien = texto(msg), texto(quien)
	if not (msg and quien) then return false end
	local por = enCombate() and "combate" or (ausente() and "ausente" or nil)
	if not por then return false end
	motivo = motivo or por
	lista[#lista + 1] = { nombre = mostrarNombre(quien), texto = sinCodigos(msg), t = ahora() }
	while #lista > MAX do table.remove(lista, 1) end
	return true
end

function Pd.Responder(nombre)
	nombre = texto(nombre)
	if not nombre then return false end
	local t = "/w " .. nombre .. " "
	local CFU = rawget(_G, "ChatFrameUtil")
	if type(CFU) == "table" and type(CFU.OpenChat) == "function" and pcall(CFU.OpenChat, t) then return true end
	local abrir = rawget(_G, "ChatFrame_OpenChat")
	if type(abrir) == "function" and pcall(abrir, t) then return true end
	return false
end

local function cortar(s)
	if #s <= CORTO then return s end
	return s:sub(1, CORTO):gsub("[\128-\191]+$", ""):gsub("[\192-\255]$", "") .. "…"
end

function Pd.VerTodos(copia)
	local filas = {}
	for _, x in ipairs(copia) do filas[#filas + 1] = x.nombre .. ": " .. x.texto end
	local Ch = M.Charla
	if Ch and Ch.MostrarCopia then
		return Ch.MostrarCopia(L["Te escribieron mientras peleabas"], concat(filas, "\n"), L["Solo tú ves esto. Cópialo con Ctrl+C; Esc para cerrar."])
	end
	N.Imprimir(concat(filas, " | "))
	return false
end

function Pd.Mostrar()
	if #lista == 0 or enCombate() then return nil end
	local copia, por = lista, motivo
	lista, motivo = {}, nil
	local quienes, ya = {}, {}
	for i = #copia, 1, -1 do
		local x = copia[i]
		if not ya[x.nombre] then ya[x.nombre] = true quienes[#quienes + 1] = x.nombre end
	end
	local ultimo = copia[#copia]
	local lineas = {}
	for i = #copia, math.max(1, #copia - 2), -1 do
		local x = copia[i]
		lineas[#lineas + 1] = x.nombre .. ": " .. cortar(x.texto)
	end
	if #copia > 3 then lineas[#lineas + 1] = format(L["y %d más"], #copia - 3) end
	local o = {
		titulo = por == "ausente" and L["Te escribieron mientras no estabas"] or L["Te escribieron mientras peleabas"],
		texto = concat(lineas, "\n"), icono = "ic-comunidad", duracion = 30, prioridad = 2, modulo = "comodidades",
		acciones = {
			{ texto = format(L["Responder a %s"], ultimo.nombre), alClic = function() Pd.Responder(ultimo.nombre) end },
		},
	}
	if #copia > 1 then o.acciones[2] = { texto = L["Ver todos"], alClic = function() Pd.VerTodos(copia) end } end
	if K and K.Aviso then K.Aviso(o) else N.Imprimir(o.titulo .. " " .. concat(lineas, " | ")) end
	return o, quienes
end

local function pronto() N.Una("comodidades.pendientes", 1.5, function() M.Seguro(Pd.Mostrar) end) end

local registrado = false
M.AlCambiar({ "susurrosPendientes" }, function()
	if registrado or not M.Get("susurrosPendientes") then return end
	registrado = true
	A.RegisterEvent("CHAT_MSG_WHISPER", function(...) M.Seguro(Pd.AlSusurro, ...) end)
	A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if #lista > 0 and motivo == "combate" then pronto() end end)
	A.RegisterEvent("PLAYER_FLAGS_CHANGED", function(_, u)
		if u == "player" and #lista > 0 and motivo == "ausente" and not ausente() then pronto() end
	end)
end)
