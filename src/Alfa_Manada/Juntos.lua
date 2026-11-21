-- Alfa - La Jauría: cazar juntos (1.2.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Quien comparte su rastro también dice a la manada qué misiones lleva (solo
-- sus números, como mucho MAX). Con los lobos de tu zona que hacen alguna
-- misión contigo: su tarjeta en la página dice «Hacen N misiones contigo» y,
-- una vez por lobo en la sesión (si no está en tu grupo), Lya o un aviso:
-- «Ana también hace “X”. ¿Cazan juntos?» con «Invitar» (tu clic).
--
-- Mensaje (Red.lua, prefijo AlfaManada, solo entre quienes comparten):
--   1M|<id>,<id>,...     tus misiones (vacío: ninguna)
-- Sale cuando cambia tu diario, como mucho una vez cada HUECO segundos, y
-- se repite cada REFRESCO para quien llegó después. Nada en combate (el
-- diario se lee al terminar). Se apaga con manada.cazarJuntos.
--
--   J.Mias() -> { [id] = título }        tus misiones ahora
--   J.Comunes(clave) -> n, { ids }       las que haces con ese lobo (de tu zona)
--   J.Enviar(forzar)                     manda tu lista si toca
--   J.De(nombre) -> { [id] = true } | nil (1.3.1) las que dijo, esté donde esté
--                                        (AlfaManada.MisionesDe)
--   J.OfrecerATodos(), J.Cuantos()       (1.3.1) cada 20 s: lo caducado se
--                                        olvida y tu zona se mira una vez
-- 1M solo se acepta por el canal o la hermandad, nunca por susurro (1.3.1).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local J = {}
M.Juntos = J

local type, tonumber, pairs, ipairs, pcall, format = type, tonumber, pairs, ipairs, pcall, string.format
local concat, sort = table.concat, table.sort

local V = "1"
local MAX = 15         -- misiones por mensaje
local HUECO = 60       -- segundos entre dos envíos
local REFRESCO = 300   -- se repite la lista (para quien llegó después)
local CADUCA = 900     -- lo que dijo otro vale esto

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return on("compartir") and N.Get(ID, "cazarJuntos") ~= false end

J.version = 0
local function cambio()
	J.version = J.version + 1
	if M.Avisar then M.Avisar() end
end

---------------------------------------------------------------------------
-- Tus misiones
---------------------------------------------------------------------------

local function leerDiario()
	local out, orden = {}, {}
	local Q = C_QuestLog
	if type(Q) == "table" and type(Q.GetNumQuestLogEntries) == "function" and type(Q.GetInfo) == "function" then
		local ok, n = pcall(Q.GetNumQuestLogEntries)
		n = ok and U.Numero(n) or 0
		for i = 1, math.min(n, 60) do
			local okI, info = pcall(Q.GetInfo, i)
			if okI and type(info) == "table" and not U.Leer(info.isHeader) and not U.Leer(info.isHidden) then
				local id = U.Numero(info.questID)
				if id and id > 0 and not out[id] then
					out[id] = U.Texto(info.title) or ""
					orden[#orden + 1] = id
				end
			end
		end
	elseif type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
		local ok, n = pcall(GetNumQuestLogEntries)
		n = ok and U.Numero(n) or 0
		for i = 1, math.min(n, 60) do
			local okI, titulo, _, _, cabeza, _, _, _, id = pcall(GetQuestLogTitle, i)
			id = okI and U.Numero(id) or nil
			if id and id > 0 and not U.Leer(cabeza) and not out[id] then
				out[id] = U.Texto(titulo) or ""
				orden[#orden + 1] = id
			end
		end
	end
	return out, orden
end

local mias, ordenMias = {}, {}
function J.Mias() return mias end

---------------------------------------------------------------------------
-- Lo que dicen los lobos
---------------------------------------------------------------------------

local suyas = {} -- clave -> { ids = { [id] = true }, at, remitente }

-- Tu zona ahora, o false (sin posición).
local function miZona()
	local map = U.MiPosicion()
	return map and U.ZonaDe(map) or false
end

-- El mismo continente y la misma zona que tú (con su última posición).
-- `zona` (1.3.1): tu zona ya calculada (una vez por vuelta, no por lobo).
local function deMiZona(clave, zona)
	if zona == nil then zona = miZona() end
	if not zona then return false end
	local G = M.Gente
	local e = G.Alfa(clave) or G.EnGrupo(clave)
	if not (e and e.map) then return false end
	return U.ZonaDe(e.map) == zona
end

function J.Comunes(clave, zona)
	local s = clave and suyas[clave]
	if not s or not activo() or U.Ahora() - s.at > CADUCA or not deMiZona(clave, zona) then return 0, {} end
	local lista = {}
	for id in pairs(s.ids) do
		if mias[id] then lista[#lista + 1] = id end
	end
	sort(lista)
	return #lista, lista
end

-- 1.3.7: los títulos de las misiones que haces con ese lobo, en corto:
-- "“A”, “B” y 2 más" (para su tarjeta en la página).
function J.Titulos(ids, tope)
	tope = tope or 2
	local t = {}
	for _, id in ipairs(ids or {}) do
		local titulo = mias[id]
		if type(titulo) == "string" and titulo ~= "" then t[#t + 1] = format(L["“%s”"], U.Cortar(titulo, 32)) end
	end
	if #t == 0 then return nil end
	if #t <= tope then
		if #t == 1 then return t[1] end
		return format(L["%s y %s"], concat(t, ", ", 1, #t - 1), t[#t])
	end
	return format(L["%s y %s"], concat(t, ", ", 1, tope), format(L["%d más"], #t - tope))
end

local dichos = {} -- clave -> true: ya se ofreció cazar juntos en esta sesión


local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then K.Aviso(o) end
end

-- Si un lobo de tu zona hace una misión contigo: la invitación, una vez.
local function ofrecer(clave, zona)
	if dichos[clave] then return end
	local n, lista = J.Comunes(clave, zona)
	if n == 0 then return end
	local s = suyas[clave]
	local remitente = s and s.remitente
	if not remitente or U.EnMiGrupo(remitente) then return end
	local titulo = mias[lista[1]]
	if not titulo or titulo == "" then return end
	dichos[clave] = true
	local quien = U.Mostrar(remitente)
	aviso({
		titulo = L["Cazar juntos"],
		texto = format(L["%s también hace “%s”. ¿Cazan juntos?"], quien, titulo),
		icono = "ic-manada", duracion = 15,
		accion = { texto = L["Invitar"], alClic = function()
			if U.Invitar(remitente) then U.Decir(format(L["Invitaste a %s a tu grupo."], quien)) end
		end },
	})
end
J.Ofrecer = ofrecer

-- (1.3.1) A todos los lobos que dijeron sus misiones, de una vez: lo que
-- caducó se olvida (la tabla no crece con cada lobo del reino) y tu zona se
-- calcula una sola vez.
local function ofrecerATodos()
	local ahora = U.Ahora()
	for clave, s in pairs(suyas) do
		if ahora - (s.at or 0) > CADUCA then suyas[clave] = nil end
	end
	if not activo() then return end
	local zona = miZona()
	for clave in pairs(suyas) do ofrecer(clave, zona) end
end
J.OfrecerATodos = ofrecerATodos

-- Para el banco y /alfa rendimiento: cuántos lobos dijeron sus misiones.
function J.Cuantos()
	local n = 0
	for _ in pairs(suyas) do n = n + 1 end
	return n
end

-- "Ana Smith-Reino" -> "Ana Smith" (1.3.1, para J.De).
local function sinReino(s) return type(s) == "string" and s:match("^(.-)%-[^%-%s]+$") or s end

local function numeros(s)
	local ids, n = {}, 0
	if type(s) ~= "string" or #s > 200 then return nil end
	for p in s:gmatch("[^,]+") do
		if not p:match("^%d+$") or #p > 9 then return nil end
		n = n + 1
		if n > MAX then break end
		ids[tonumber(p)] = true
	end
	return ids
end

M.Red.Oyentes.M = function(clave, remitente, _, f, canal)
	if canal == "WHISPER" or N.Get(ID, "cazarJuntos") == false then return end -- (1.3.1) nunca por susurro
	local ids = numeros(f[1] or "")
	if not ids then return end
	suyas[clave] = { ids = ids, at = U.Ahora(), remitente = remitente, corta = U.Clave(sinReino(remitente)) }
	cambio()
	ofrecer(clave)
end

-- (1.3.1) Las misiones que dijo un lobo: { [id] = true } (una copia), o nil
-- si no se sabe (no compartes, cazarJuntos apagado, nunca lo dijo o hace más
-- de CADUCA). Acepta "Ana Smith", "Ana-Smith" y "Ana Smith-Reino": el de otro
-- reino llega con su reino y el cuadro del grupo puede darlo sin él.
function J.De(nombre)
	if not activo() then return nil end
	local clave = U.Clave(nombre)
	if not clave then return nil end
	local s = suyas[clave]
	if not s then
		-- Sin reino de un lado: se compara sin el reino de los dos (y solo si es uno).
		local corta = U.Clave(sinReino(U.Texto(nombre)))
		for _, x in pairs(suyas) do
			if x.corta and (x.corta == corta or x.corta == clave) then
				if s then return nil end
				s = x
			end
		end
	end
	if not s or U.Ahora() - s.at > CADUCA then return nil end
	local out = {}
	for id in pairs(s.ids) do out[id] = true end
	return out
end

-- Quien deja de compartir se olvida también aquí.
local olvidarGente = M.Gente.Olvidar
M.Gente.Olvidar = function(clave, ...)
	if suyas[clave] then suyas[clave] = nil cambio() end
	return olvidarGente(clave, ...)
end

---------------------------------------------------------------------------
-- Enviar tu lista
---------------------------------------------------------------------------

local enviada, enviadaEn, programado = nil, -math.huge, false

function J.Texto()
	local ids = {}
	for i = 1, math.min(#ordenMias, MAX) do ids[i] = tostring(ordenMias[i]) end
	return V .. "M|" .. concat(ids, ",")
end

function J.Enviar(forzar)
	if not activo() then return false end
	local texto = J.Texto()
	local ahora = U.Ahora()
	if texto == enviada and not forzar then return false end
	if ahora - enviadaEn < HUECO then
		-- Muy pronto: sale cuando se cumpla el hueco.
		if not programado then
			programado = true
			A.After(HUECO - (ahora - enviadaEn) + 0.1, function()
				programado = false
				J.Enviar(forzar)
			end)
		end
		return false
	end
	if not M.Red.Enviar("M", texto) then return false end
	enviada, enviadaEn = texto, ahora
	return true
end

-- El diario cambió: se lee (fuera de combate) y sale si es otro.
local function alDiario()
	N.FueraDeCombate("manada.juntos", function()
		mias, ordenMias = leerDiario()
		J.Enviar()
		-- Con lo nuevo puede haber alguien con quien cazar.
		ofrecerATodos()
		cambio()
	end)
end
J.AlDiario = alDiario

local pendiente = false
local function luego()
	if pendiente then return end
	pendiente = true
	A.After(2, function()
		pendiente = false
		alDiario()
	end)
end

for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
	A.RegisterEvent(ev, luego)
end

A.OnLogin(function()
	A.After(25, alDiario)
	M.Cada("manada.juntos", REFRESCO, function()
		if activo() and #ordenMias > 0 then J.Enviar(true) end
	end)
	-- Su lista pudo llegar antes que su posición: se vuelve a mirar.
	-- (1.3.1) Y lo que caducó se olvida aquí.
	M.Cada("manada.juntosOfrecer", 20, function()
		if InCombatLockdown and InCombatLockdown() then return end
		ofrecerATodos()
	end)
end)

-- Para el banco: lo que dijo un lobo y lo ya ofrecido.
function J.Olvidar() suyas, dichos = {}, {} end
