-- Alfa - La Jauría: ¿quién va? (1.2.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Al llegar a una zona con una mazmorra para tu nivel, si hay lobos de la
-- manada de un nivel parecido (NIVEL arriba o abajo) en esa zona o cerca
-- (CERCA yardas), Lya (o un aviso) te dice quiénes podrían ir, con
-- «Invitar»: tu clic los invita a tu grupo (C_PartyInfo.InviteUnit, sin
-- restricciones). Nada se escribe en el chat. Una vez por zona en la sesión,
-- nunca en combate ni en instancias. Ajuste manada.quienVa.
--
-- Las mazmorras (solo se leen): Alfa.Dungeons.List() del motor (zona y
-- niveles); si no está a la mano, lo que guardó Alfa_Mazmorras en
-- N.Datos("mazmorras").entradas.
--
--   Qv.Mazmorras(zona, nivel) -> { { nombre, min, max } }
--   Qv.Candidatos(zona, nivel) -> { fila de Gente }
--   Qv.Revisar() -> nombre de la mazmorra | nil, por qué

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Qv = {}
M.QuienVa = Qv

local type, tonumber, pairs, ipairs, pcall, format = type, tonumber, pairs, ipairs, pcall, string.format
local concat, sort = table.concat, table.sort

local NIVEL = 4
local CERCA = 1500
local TOPE = 3

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "quienVa") ~= false end

local function miNivel()
	if not UnitLevel then return nil end
	local ok, n = pcall(UnitLevel, "player")
	return ok and U.Numero(n) or nil
end

-- Las mazmorras (no bandas) de una zona que van con tu nivel.
function Qv.Mazmorras(zona, nivel)
	local out = {}
	if not (zona and nivel) then return out end
	local visto = {}
	local function sumar(nombre, z, mn, mx, tipo)
		mn, mx = tonumber(mn), tonumber(mx) or tonumber(mn)
		if tipo == "raid" or not (nombre and z and mn) or visto[nombre] then return end
		if U.ZonaDe(z) ~= zona then return end
		if nivel < mn - 1 or nivel > mx then return end
		visto[nombre] = true
		out[#out + 1] = { nombre = nombre, min = mn, max = mx }
	end
	local Dg = A.Dungeons
	local function delMotor()
		if type(Dg) ~= "table" or type(Dg.List) ~= "function" or (InCombatLockdown and InCombatLockdown()) then return end
		local ok, l = pcall(Dg.List)
		if not (ok and type(l) == "table") then return end
		for _, d in ipairs(l) do
			if type(d) == "table" then
				local z = d.zone or (type(d.entrance) == "table" and d.entrance.map)
				sumar(U.Texto(d.name), tonumber(z), d.minLevel, d.maxLevel, d.kind)
			end
		end
	end
	local function guardadas()
		local okD, dm = pcall(N.Datos, "mazmorras")
		local e = okD and type(dm) == "table" and dm.entradas
		if type(e) ~= "table" then return false end
		local hay = false
		for _, x in pairs(e) do
			hay = true
			if type(x) == "table" then sumar(U.Texto(x.nombre), tonumber(x.m), x.min, x.max, x.tipo) end
		end
		return hay
	end
	-- Sin cargar el Codex de más: el diario del motor si ya está cargado; si
	-- no, lo guardado por Alfa_Mazmorras; y solo sin nada de eso, el diario.
	local cargado = type(Dg) == "table" and type(Dg.Meta) == "function" and select(2, pcall(Dg.Meta)) ~= nil
	if cargado or type(Dg) == "table" and type(Dg.Meta) ~= "function" then
		delMotor()
	elseif not guardadas() then
		delMotor()
	end
	sort(out, function(a, b) return a.min < b.min end)
	return out
end

-- Los lobos de la manada (no de tu grupo) de nivel parecido, en tu zona o cerca.
function Qv.Candidatos(zona, nivel)
	local out = {}
	if not (zona and nivel) or not on("compartir") then return out end
	for _, f in ipairs(M.Gente.Manada()) do
		if f.tipo ~= "grupo" and f.conectado ~= false and f.map and f.nivel and math.abs(f.nivel - nivel) <= NIVEL
			and not U.EnMiGrupo(f.envio or f.nombre) then
			local aqui = U.ZonaDe(f.map) == zona
			if aqui or (f.dist and f.dist <= CERCA) then out[#out + 1] = f end
		end
	end
	return out
end

local dichas = {} -- zona -> true: ya se dijo en esta sesión

local function nombres(lista)
	local partes = {}
	for i = 1, math.min(#lista, TOPE) do partes[i] = lista[i].nombre or "?" end
	local t = concat(partes, ", ")
	if #lista > TOPE then t = format(L["%s y %d más"], t, #lista - TOPE) end
	return t
end

function Qv.Revisar()
	if not activo() then return nil, "apagado" end
	if InCombatLockdown and InCombatLockdown() then return nil, "combate" end
	if U.EnInstancia() then return nil, "instancia" end
	local map = U.MiPosicion()
	local zona = map and U.ZonaDe(map)
	if not zona then return nil, "lugar" end
	if dichas[zona] then return nil, "dicho" end
	local nivel = miNivel()
	-- Primero los lobos (barato): sin nadie cerca no se busca la mazmorra, así
	-- el diario del motor (el Codex, ~7 MB) no se carga solo al entrar.
	local lista = Qv.Candidatos(zona, nivel)
	if #lista == 0 then return nil, "nadie" end
	local mz = Qv.Mazmorras(zona, nivel)
	if #mz == 0 then return nil, "mazmorra" end
	dichas[zona] = true
	local d = mz[1]
	local texto = #lista == 1 and format(L["%s anda cerca y va a tu nivel. ¿Le dices?"], lista[1].nombre or "?")
		or format(L["%s andan cerca y van a tu nivel. ¿Les dices?"], nombres(lista))
	local K = N.Kit
	local o = {
		titulo = format(L["¿Quién va a %s?"], d.nombre), texto = texto, icono = "ic-mazmorra", duracion = 15,
		accion = { texto = #lista == 1 and L["Invitar"] or L["Invitarlos"], alClic = function()
			local ok = {}
			for i = 1, math.min(#lista, 4) do
				local f = lista[i]
				if U.Invitar(f.envio or f.nombre) then ok[#ok + 1] = f.nombre or "?" end
			end
			if #ok > 0 then U.Decir(format(L["Invitaste a %s a tu grupo."], concat(ok, ", "))) end
		end },
	}
	if M.U and M.U.Aviso then M.U.Aviso(o) else U.Decir(o.titulo .. " " .. texto) end
	return d.nombre
end

-- Para el banco.
function Qv.Olvidar() dichas = {} end

A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() A.After(10, function() pcall(Qv.Revisar) end) end)
A.OnLogin(function()
	-- La manada pudo llegar después que tú: se vuelve a mirar (una vez por zona).
	M.Cada("manada.quienVa", 60, function() pcall(Qv.Revisar) end)
end)
