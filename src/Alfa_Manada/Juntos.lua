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

-- El mismo continente y la misma zona que tú (con su última posición).
local function deMiZona(clave)
	local G = M.Gente
	local map = U.MiPosicion()
	if not map then return false end
	local e = G.Alfa(clave) or G.EnGrupo(clave)
	if not (e and e.map) then return false end
	return U.ZonaDe(e.map) == U.ZonaDe(map)
end

function J.Comunes(clave)
	local s = clave and suyas[clave]
	if not s or not activo() or U.Ahora() - s.at > CADUCA or not deMiZona(clave) then return 0, {} end
	local lista = {}
	for id in pairs(s.ids) do
		if mias[id] then lista[#lista + 1] = id end
	end
	sort(lista)
	return #lista, lista
end

local dichos = {} -- clave -> true: ya se ofreció cazar juntos en esta sesión

local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then K.Aviso(o) end
end

-- Si un lobo de tu zona hace una misión contigo: la invitación, una vez.
local function ofrecer(clave)
	if dichos[clave] then return end
	local n, lista = J.Comunes(clave)
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

M.Red.Oyentes.M = function(clave, remitente, _, f)
	if N.Get(ID, "cazarJuntos") == false then return end
	local ids = numeros(f[1] or "")
	if not ids then return end
	suyas[clave] = { ids = ids, at = U.Ahora(), remitente = remitente }
	cambio()
	ofrecer(clave)
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
		for clave in pairs(suyas) do ofrecer(clave) end
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
	A.NewTicker(REFRESCO, function()
		if activo() and #ordenMias > 0 then J.Enviar(true) end
	end)
	-- Su lista pudo llegar antes que su posición: se vuelve a mirar.
	A.NewTicker(20, function()
		if not activo() or (InCombatLockdown and InCombatLockdown()) then return end
		for clave in pairs(suyas) do ofrecer(clave) end
	end)
end)

-- Para el banco: lo que dijo un lobo y lo ya ofrecido.
function J.Olvidar() suyas, dichos = {}, {} end
