-- Alfa - La Jauría: «¿Quién tiene...?» (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Buscas un objeto por su nombre y los lobos de tu hermandad que aceptaron
-- (manada.quienTiene, apagado de fábrica) te dicen si lo cargan y cuántos.
-- Nada se difunde solo: tu lista no sale nunca entera; solo cuando alguien
-- pregunta, y solo lo que coincide con su pregunta (hasta TOPE objetos), por
-- susurro oculto a quien preguntó. Lo que llevas se lee de Alfa_Bolsas (sus
-- datos guardados: bolsas y banco de este personaje; sin tocarlos) o, si no
-- está, de tus bolsas en vivo. «Susurrar» solo abre el cuadro del chat con
-- su nombre: tú escribes y envías.
--
-- Mensajes (Red.lua, solo por la hermandad y por susurro):
--   1W|<consulta>|<texto>                       por la hermandad: ¿quién tiene...?
--   1U|<consulta>|<id>|<cuántos>|<nombre>        por susurro: yo tengo esto
--
--   Qt.Buscar(texto) -> ok, motivo
--   Qt.Resultados() -> { { nombre, destino, objeto, id, cuantos } }   (por nombre)
--   Qt.Consulta() -> { texto, at } | nil
--   Qt.Mios(texto) -> { { id, nombre, cuantos } }   lo que tú contestarías

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Qt = {}
M.QuienTiene = Qt

local type, pairs, ipairs, tonumber, tostring, format, sort = type, pairs, ipairs, tonumber, tostring, string.format, table.sort

local V = "1"
local TOPE = 3            -- objetos por respuesta
local MIN_LETRAS = 3
local CADA_BUSQUEDA = 10  -- segundos entre dos búsquedas tuyas
local CADA_RESPUESTA = 5  -- a la misma persona, una respuesta cada tanto
local VIGENCIA = 120      -- segundos que vale una consulta (las respuestas tardías, no)

local function on(clave) return N.Get(ID, clave) and true or false end

Qt.version = 0
local function cambio()
	Qt.version = Qt.version + 1
	if M.Avisar then M.Avisar() end
end

Qt.MOTIVOS = {
	corto = "Escribe al menos 3 letras del objeto.",
	hermandad = "Necesitas una hermandad: «¿Quién tiene...?» pregunta a los lobos de la tuya.",
	espera = "Espera unos segundos antes de buscar otra vez.",
	red = "Ahora no se puede hablar con la manada. Prueba en un rato.",
}

local function limpiar(s, largo)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, largo or 40)
	return s ~= "" and s or nil
end

---------------------------------------------------------------------------
-- Lo que llevas
---------------------------------------------------------------------------

local function nombreDe(link)
	if type(link) ~= "string" then return nil end
	return link:match("%[(.-)%]")
end

-- Tus objetos: id -> { nombre, cuantos }. De Alfa_Bolsas (bolsas y banco
-- guardados de este personaje) o, sin ese módulo, de tus bolsas en vivo.
function Qt.Inventario()
	local out = {}
	local function sumar(id, nombre, c)
		id = tonumber(id)
		if not (id and nombre) then return end
		local e = out[id]
		if not e then e = { nombre = nombre, cuantos = 0 } out[id] = e end
		e.cuantos = e.cuantos + (tonumber(c) or 1)
	end
	local okD, d = pcall(N.Datos, "bolsas")
	local lista = okD and type(d) == "table" and rawget(d, "personajes")
	local yo
	if type(lista) == "table" then
		local nombre = UnitName and U.Texto((UnitName("player")))
		local reino = (GetNormalizedRealmName and U.Texto(GetNormalizedRealmName())) or (GetRealmName and U.Texto(GetRealmName()))
		yo = nombre and lista[reino and (nombre .. "-" .. reino) or nombre]
	end
	if type(yo) == "table" then
		for _, grupo in ipairs({ yo.bolsas, yo.banco }) do
			if type(grupo) == "table" then
				for _, b in pairs(grupo) do
					if type(b) == "table" then
						for s = 1, tonumber(b.n) or 0 do
							local e = b[s]
							if type(e) == "table" then sumar(e.i, nombreDe(e.l), e.c) end
						end
					end
				end
			end
		end
		return out
	end
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
	for bolsa = 0, 4 do
		local okN, n = pcall(C.GetContainerNumSlots, bolsa)
		for s = 1, okN and U.Numero(n) or 0 do
			local okI, info = pcall(C.GetContainerItemInfo, bolsa, s)
			if okI and type(info) == "table" then sumar(info.itemID, nombreDe(info.hyperlink), info.stackCount) end
		end
	end
	return out
end

-- Lo que coincide con `texto` (por nombre, sin acentos ni mayúsculas).
function Qt.Mios(texto)
	local q = U.Plegar(texto or "")
	if #q < MIN_LETRAS then return {} end
	local out = {}
	for id, e in pairs(Qt.Inventario()) do
		if U.Plegar(e.nombre):find(q, 1, true) then out[#out + 1] = { id = id, nombre = e.nombre, cuantos = e.cuantos } end
	end
	sort(out, function(a, b)
		if a.cuantos ~= b.cuantos then return a.cuantos > b.cuantos end
		return a.id < b.id
	end)
	for i = #out, TOPE + 1, -1 do out[i] = nil end
	return out
end

---------------------------------------------------------------------------
-- Buscar
---------------------------------------------------------------------------

local consulta -- { cid, texto, at, respuestas = { llave -> r } }
local ultimaBusqueda = -math.huge
local cuenta = 0

function Qt.Buscar(texto)
	texto = limpiar(texto, 40)
	if not texto or #U.Plegar(texto) < MIN_LETRAS then return false, "corto" end
	if not U.EnHermandad() then return false, "hermandad" end
	local ahora = U.Ahora()
	if ahora - ultimaBusqueda < CADA_BUSQUEDA then return false, "espera" end
	cuenta = (cuenta % 999) + 1
	local cid = tostring(cuenta)
	if not M.Red.EnviarHermandad("W", format("%sW|%s|%s", V, cid, texto)) then return false, "red" end
	ultimaBusqueda = ahora
	consulta = { cid = cid, texto = texto, at = ahora, respuestas = {} }
	cambio()
	return true
end

function Qt.BuscarYDecir(texto)
	local ok, por = Qt.Buscar(texto)
	if not ok and Qt.MOTIVOS[por] then U.Decir(L[Qt.MOTIVOS[por]]) end
	return ok
end

function Qt.Consulta() return consulta end

function Qt.Resultados()
	local out = {}
	if not consulta then return out end
	for _, r in pairs(consulta.respuestas) do out[#out + 1] = r end
	sort(out, function(a, b)
		if a.nombre ~= b.nombre then return a.nombre < b.nombre end
		return a.objeto < b.objeto
	end)
	return out
end

function Qt.Olvidar() consulta = nil ultimaBusqueda = -math.huge cambio() end

-- «Susurrar»: solo abre el cuadro del chat con su nombre.
function Qt.Susurrar(r)
	return r and U.Susurrar(r.destino, "") or false
end

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 9 then return nil end
	local n = tonumber(s)
	return n and n >= 1 and n <= max and n or nil
end

M.Red.Oyentes.U = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" then return end
	local c = consulta
	if not c or f[1] ~= c.cid or U.Ahora() - c.at > VIGENCIA then return end
	local id, cuantos, objeto = numero(f[2], 10000000), numero(f[3], 100000), limpiar(f[4], 60)
	if not (id and cuantos and objeto) then return end
	local llave = clave .. ":" .. id
	local n = 0
	for _ in pairs(c.respuestas) do n = n + 1 end
	if not c.respuestas[llave] and n >= 40 then return end
	c.respuestas[llave] = { nombre = U.Mostrar(remitente), destino = remitente, objeto = objeto, id = id, cuantos = cuantos }
	cambio()
end

---------------------------------------------------------------------------
-- Responder (solo con manada.quienTiene)
---------------------------------------------------------------------------

local respondidoA = {}
M.Red.Oyentes.W = function(clave, remitente, _, f, canal)
	if canal ~= "GUILD" or not on("quienTiene") then return end
	local cid = f[1]
	if type(cid) ~= "string" or not cid:match("^%d+$") or #cid > 4 then return end
	local texto = limpiar(f[2], 40)
	if not texto then return end
	local ahora = U.Ahora()
	if respondidoA[clave] and ahora - respondidoA[clave] < CADA_RESPUESTA then return end
	local mios = Qt.Mios(texto)
	if #mios == 0 then return end
	respondidoA[clave] = ahora
	local destino = U.Destino(remitente)
	for i, x in ipairs(mios) do
		M.Red.EnviarLibre("U:" .. clave .. ":" .. i, format("%sU|%s|%d|%d|%s", V, cid, x.id, x.cuantos, (x.nombre:gsub("|", ""))), destino)
	end
end
M.Red.Libres.W = true
