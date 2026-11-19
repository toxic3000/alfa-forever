-- Alfa - La Jauría: las notas del lobo (1.2.8). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Una nota tuya en el mapa, donde estás parado: «Nota aquí» en la página de
-- La Jauría o /alfa nota <texto>. Sale como marca en el mapa del mundo (y el
-- minimapa) con su texto en el cuadro; un clic y la flecha te lleva. Se ven,
-- se llevan y se borran desde la página. (Nada de clic derecho en el mapa:
-- tocar el mapa del juego lo puede dejar bloqueado.)
--
-- Con «Compartir con la manada» (manada.notasCompartir, apagado de fábrica)
-- tus notas nuevas van a los lobos de tu hermandad que comparten, y ves las
-- suyas. Mensaje (Red.lua, prefijo AlfaManada, por la hermandad):
--   1N|<mapa>|<x>|<y>|<texto>   (x, y en 0-100, como la flecha)
-- Se guardan en N.Datos("manada").notas: hasta MIAS tuyas y SUYAS de otros
-- (las de otros se van a los DURAN días). Ajuste manada.notas.
--
--   No.Agregar(texto) -> nota | nil, por qué    en tu lugar de ahora
--   No.Lista() -> { nota }  ; No.Borrar(id) ; No.Ir(id) ; No.Pintar(forzar)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local No = {}
M.Notas = No

local type, tonumber, tostring, pairs, ipairs, pcall, format = type, tonumber, tostring, pairs, ipairs, pcall, string.format
local sort = table.sort

local V = "1"
local CAPA = "manada.notas"
local MIAS, SUYAS = 60, 30
local DURAN = 14 * 86400
local CADA = 20 -- segundos entre dos notas de la misma persona

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "notas") ~= false end
local function compartir() return on("notasCompartir") and on("compartir") end

No.version = 0
local function cambio()
	No.version = No.version + 1
	if No.Pintar then No.Pintar(true) end
	if M.Avisar then M.Avisar() end
end

local function datos()
	local d = N.Datos(ID)
	if type(d.notas) ~= "table" then d.notas = {} end
	return d
end

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	local out, n = {}, 0
	for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		n = n + 1
		if n > 60 then break end
		out[n] = c
	end
	s = table.concat(out)
	return s ~= "" and s or nil
end

function No.Lista()
	local out, t = {}, U.Reloj()
	local d = datos()
	for i = #d.notas, 1, -1 do
		local x = d.notas[i]
		if type(x) ~= "table" or not (x.map and x.x and x.y) or (x.de and t - (x.at or 0) > DURAN) then table.remove(d.notas, i) end
	end
	for _, x in ipairs(d.notas) do
		if not x.de or compartir() then out[#out + 1] = x end
	end
	sort(out, function(a, b)
		if (a.de == nil) ~= (b.de == nil) then return a.de == nil end
		return (a.at or 0) > (b.at or 0)
	end)
	return out
end

local function buscar(id)
	for i, x in ipairs(datos().notas) do if x.id == id then return x, i end end
	return nil
end

local function contar(deOtro)
	local n = 0
	for _, x in ipairs(datos().notas) do if (x.de ~= nil) == deOtro then n = n + 1 end end
	return n
end

-- Una nota nueva en tu lugar de ahora: la nota, o nil y por qué
-- ("apagado", "texto", "lugar", "muchas").
function No.Agregar(texto)
	if not activo() then return nil, "apagado" end
	texto = limpiar(texto)
	if not texto then return nil, "texto" end
	local map, x, y = U.MiPosicion()
	if not map then return nil, "lugar" end
	if contar(false) >= MIAS then return nil, "muchas" end
	local d = datos()
	d.notaN = (tonumber(d.notaN) or 0) + 1
	local nota = { id = "n" .. d.notaN, map = map, x = x, y = y, texto = texto, at = U.Reloj() }
	d.notas[#d.notas + 1] = nota
	if compartir() and U.EnHermandad() then
		if M.Red.Enviar("N:" .. nota.id, format("%sN|%d|%.2f|%.2f|%s", V, map, x, y, texto), "GUILD") then nota.compartida = true end
	end
	cambio()
	return nota
end

local MOTIVOS = {
	apagado = "Las notas del lobo están apagadas (Ajustes de La Jauría).",
	texto = "Escribe qué dice la nota: /alfa nota Aquí sale el mineral",
	lugar = "Alfa no sabe dónde estás (en una instancia no hay notas).",
	muchas = "Ya tienes 60 notas. Borra alguna en La Jauría para dejar otra.",
}
No.MOTIVOS = MOTIVOS

function No.AgregarYDecir(texto)
	local nota, por = No.Agregar(texto)
	if nota then
		U.Decir(format(L["Dejaste una nota en tu mapa: «%s»."], nota.texto)
			.. (nota.compartida and (" " .. L["La manada también la ve."]) or ""))
	elseif MOTIVOS[por] then
		U.Decir(L[MOTIVOS[por]])
	end
	return nota, por
end

function No.Borrar(id)
	local _, i = buscar(id)
	if not i then return false end
	table.remove(datos().notas, i)
	cambio()
	return true
end

function No.Ir(id)
	local x = type(id) == "table" and id or buscar(id)
	local Nav = A.Nav
	if not (x and Nav and Nav.SetTarget) then return false end
	Nav.SetTarget(x.map, x.x, x.y, x.texto)
	N.EmpezarRuta()
	return true
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+%.?%d*$") or #s > 10 then return nil end
	local n = tonumber(s)
	if not n or n > max then return nil end
	return n
end

local oidas = {} -- clave -> cuándo
M.Red.Oyentes.N = function(clave, remitente, _, f, canal)
	if canal ~= "GUILD" or not (activo() and compartir()) then return end
	local map, x, y = numero(f[1], 100000), numero(f[2], 100), numero(f[3], 100)
	local texto = limpiar(f[4])
	if not (map and x and y and texto) then return end
	local t = U.Ahora()
	if oidas[clave] and t - oidas[clave] < CADA then return end
	oidas[clave] = t
	local d = datos()
	-- La misma nota otra vez: nada.
	for _, n in ipairs(d.notas) do
		if n.de and n.texto == texto and n.map == map and math.abs(n.x - x) < 0.5 and math.abs(n.y - y) < 0.5 then return end
	end
	-- Demasiadas de otros: se va la más vieja.
	if contar(true) >= SUYAS then
		local vieja, cuando
		for i, n in ipairs(d.notas) do if n.de and (not cuando or (n.at or 0) < cuando) then vieja, cuando = i, n.at or 0 end end
		if vieja then table.remove(d.notas, vieja) end
	end
	d.notaN = (tonumber(d.notaN) or 0) + 1
	d.notas[#d.notas + 1] = { id = "n" .. d.notaN, map = math.floor(map), x = x, y = y, texto = texto, at = U.Reloj(), de = U.Mostrar(remitente) }
	cambio()
end

---------------------------------------------------------------------------
-- En el mapa
---------------------------------------------------------------------------

local function media(nombre)
	local ok, p = pcall(A.Theme.Media, nombre)
	if ok and type(p) == "string" then return p end
	return "Interface\\AddOns\\Alfa\\Media\\UI\\" .. nombre
end

local function acento()
	local ok, r, g, b = pcall(A.Theme.Accent)
	if ok and type(r) == "number" then return r, g, b end
	return 0.545, 0.878, 0.306
end

local function cuadro(x)
	return function(tip)
		local r, g, b = acento()
		tip:SetText(x.texto or "?", 1, 1, 1)
		tip:AddLine(x.de and format(L["Nota de %s"], x.de) or L["Tu nota"], r, g, b)
		local hace = U.Hace(U.Reloj() - (x.at or U.Reloj()))
		if hace then tip:AddLine(hace, 0.6, 0.6, 0.6) end
		tip:AddLine(L["Clic: la flecha te lleva aquí."], 0.4, 0.9, 0.4)
	end
end

local firma
function No.Pintar(forzar)
	local P = A.Pins
	if not (P and P.SetLayer) then return end
	local pins, partes = {}, {}
	local mini = on("minimapa")
	if activo() then
		local r, g, b = acento()
		for _, x in ipairs(No.Lista()) do
			pins[#pins + 1] = {
				map = x.map, x = x.x, y = x.y,
				icon = media("icon-note"), color = x.de and { 0.75, 0.75, 0.75, 1 } or { r, g, b, 1 }, backdrop = true,
				size = 14, minimapSize = 11, priority = 3,
				tooltip = cuadro(x),
				onClick = function(button)
					if button == "LeftButton" or button == nil then No.Ir(x) end
				end,
			}
			partes[#partes + 1] = format("%s%d:%.1f:%.1f", x.id, x.map, x.x, x.y)
		end
	end
	local f = (mini and "m" or "-") .. table.concat(partes, "|")
	if forzar or f ~= firma then
		firma = f
		pcall(P.SetLayer, CAPA, pins, { world = true, minimap = mini, edge = false })
	end
	pcall(P.SetLayerVisible, CAPA, activo())
end

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. ".") then No.Pintar(true) end
end)

A.RegisterCommand("nota", function(rest)
	rest = tostring(rest or "")
	if rest:match("^%s*$") then
		U.Decir(L[MOTIVOS.texto])
		return
	end
	No.AgregarYDecir(rest)
end, L["Deja una nota en tu mapa donde estás (/alfa nota <texto>)"])

A.OnLogin(function() A.After(2, function() No.Pintar(true) end) end)
