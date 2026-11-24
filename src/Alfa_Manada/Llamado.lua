-- Alfa - La Jauría: llamar a la manada (1.2.6). toxic3000 / La Jauría. GPL-3.0.
--
-- Pides ayuda (con un élite, un raro o lo que sea) y los lobos de tu zona que
-- comparten su rastro reciben tu lugar, con «¡Voy!»: la flecha los lleva y a
-- ti te llega quién viene. Si tienes seleccionado un élite o un raro, el
-- llamado dice cuál.
--
-- Mensajes (Red.lua, prefijo AlfaManada, solo entre quienes comparten):
--   1A|<mapa>|<x>|<y>|<qué>   el llamado (x, y en 0-100; qué: el nombre del enemigo o vacío)
--   1B                        por susurro: «¡voy!»
-- Uno por persona cada ESPERA segundos, al enviar y al recibir. Recibirlos se
-- apaga con manada.llamados. (1.3.1) 1A nunca por susurro; un 1B solo vale
-- si llamaste hace menos de VALE segundos, y uno por persona en cada llamado.
--
--   Ll.Llamar() -> ok, por qué ("compartir" | "lugar" | "pronto" | "via")

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Ll = {}
M.Llamado = Ll

local format, type, tonumber = string.format, type, tonumber
local V = "1"
local ESPERA = 60
local VALE = 300 -- (1.3.1) un «¡voy!» cuenta hasta 5 min después de tu llamado

local function on(clave) return N.Get(ID, clave) and true or false end

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then M.U.Aviso(o) else U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or "")) end
end

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = U.Cortar((s:gsub("[|\n\r]", "")), 48) -- (1.3.1) 48 letras, no bytes
	return s ~= "" and s or nil
end

-- El enemigo que tienes seleccionado, si es un élite o un raro.
local GRANDE = { elite = true, rare = true, rareelite = true, worldboss = true }
local function enemigo()
	if not (UnitExists and UnitClassification and UnitName) then return nil end
	local okE, hay = pcall(UnitExists, "target")
	if not okE or not U.Leer(hay) then return nil end
	if UnitIsPlayer then
		local okP, j = pcall(UnitIsPlayer, "target")
		if okP and U.Leer(j) then return nil end
	end
	local okC, c = pcall(UnitClassification, "target")
	c = okC and U.Leer(c) or nil
	if not GRANDE[c] then return nil end
	local okN, n = pcall(UnitName, "target")
	return okN and limpiar(n) or nil
end

local ultimo = -math.huge
local vienen = {} -- clave -> true: ya dijo «¡voy!» a este llamado (1.3.1)
function Ll.Llamar()
	if not on("compartir") then return false, "compartir" end
	local map, x, y = U.MiPosicion()
	if not map then return false, "lugar" end
	local ahora = U.Ahora()
	if ahora - ultimo < ESPERA then return false, "pronto" end
	local que = enemigo() or ""
	if not M.Red.Enviar("A", format("%sA|%d|%.2f|%.2f|%s", V, map, x, y, que)) then return false, "via" end
	ultimo = ahora
	wipe(vienen)
	aviso({ titulo = L["Llamaste a la manada"], texto = que ~= "" and format(L["Pediste ayuda con %s. Te aviso quién viene."], que)
		or L["Los lobos de tu zona saben dónde estás. Te aviso quién viene."], icono = "ic-manada", duracion = 8 })
	return true
end

local MOTIVOS = {
	compartir = "Para llamar a la manada, deja que te vean en el mapa (La Jauría).",
	lugar = "Alfa no sabe en qué zona estás.",
	pronto = "Ya llamaste a la manada hace un momento. Espera un poco.",
	via = "Ahora no se puede llamar a la manada: Alfa busca cómo unirse a ella.",
}
function Ll.LlamarYDecir()
	local ok, por = Ll.Llamar()
	if not ok and MOTIVOS[por] then U.Decir(L[MOTIVOS[por]]) end
	return ok
end

-- Para el banco: olvidar tu último llamado.
function Ll.Olvidar() ultimo = -math.huge wipe(vienen) end

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%-?%d+%.?%d*$") or #s > 10 then return nil end
	local n = tonumber(s)
	if not n or n < 0 or n > max then return nil end
	return n
end

local oidos = {} -- clave -> cuándo
M.Red.Oyentes.A = function(clave, remitente, _, f, canal)
	if canal == "WHISPER" or not on("llamados") then return end -- (1.3.1) nunca por susurro
	local map, x, y = numero(f[1], 100000), numero(f[2], 100), numero(f[3], 100)
	if not (map and x and y) then return end
	local mio = U.MiPosicion()
	if mio ~= map then return end
	local ahora = U.Ahora()
	if oidos[clave] and ahora - oidos[clave] < ESPERA then return end
	U.Podar(oidos, ESPERA, ahora) -- (1.3.1)
	oidos[clave] = ahora
	local quien = U.Mostrar(remitente)
	local que = limpiar(f[4])
	-- 1.2.7: una marca en el mapa en el lugar del llamado, 3 minutos (Mapa.lua).
	if M.Mapa and M.Mapa.Llamado then pcall(M.Mapa.Llamado, map, x, y, quien, que) end
	aviso({ titulo = format(L["%s llama a la manada"], quien),
		texto = que and format(L["Pide ayuda con %s."], que) or L["Pide ayuda donde está."],
		icono = "ic-manada", duracion = 20,
		accion = { texto = L["¡Voy!"], alClic = function()
			M.Red.Enviar("B:" .. clave, V .. "B", "WHISPER", U.Destino(remitente))
			local Nav = A.Nav
			if Nav and Nav.SetTarget then
				Nav.SetTarget(map, x, y, quien)
				N.EmpezarRuta()
			end
		end } })
end

M.Red.Oyentes.B = function(clave, remitente, _, _, canal)
	if canal ~= "WHISPER" then return end
	-- (1.3.1) Solo a tu llamado de hace poco, y una vez por lobo.
	if U.Ahora() - ultimo >= VALE or vienen[clave] then return end
	vienen[clave] = true
	aviso({ titulo = format(L["%s va en camino"], U.Mostrar(remitente)), texto = L["Respondió a tu llamado."], icono = "ic-manada", duracion = 8 })
end
