-- Alfa - Lya: la plática de los ratos tranquilos (toxic3000 / La Jauría). GPL-3.0.
--
-- Lo que Lya platica cuando no pasa nada (el latido de Cerebro.lua, cada ~3
-- minutos de silencio con "muchos"; 10 con "pocos"): va en rondas que rotan
-- entre seis cosas, barajadas en cada ronda y nunca la misma dos veces seguidas:
--   lugar      un dato de la zona donde estás que todavía no te contó (Lore.lua,
--              LoreMas.lua). Al cambiar de zona va primero.
--   lore       la historia de Azeroth (M.LORE: más de 200 notas).
--   tuyo       de tu gente, tu clase o tus profesiones (Saberes.lua): solo lo
--              que aplica a tu personaje (UnitRace, UnitClass y las líneas de
--              habilidad que tienes, leídas con pcall y sin valores secretos).
--   consejo    eventos, farmeo, economía, viajes y lo de Forever (Saberes.lua),
--              o uno de los de siempre (Frases.lua: Alfa, el juego, ánimo).
--   momento    la zona, el ambiente, que tiene hambre (Cerebro.lua).
--   salchichas lo que más le gusta en la vida.
-- Lore, tuyo y consejo nunca se agotan pero tampoco se repiten seguido: por
-- personaje se guarda cuándo dijo cada nota (lya.charla.v[id] = hora) y sale
-- primero una que nunca dijo; cuando ya dijo todas, la que dijo hace más
-- tiempo (la lista entera da la vuelta antes de repetir). Las de lugar salen
-- una vez por personaje (las comparte con Historias.lua: hist.datos).
-- Las reglas de siempre las cuida Cerebro (Ce.Decir): nunca en combate, en una
-- instancia ni mientras escribes; un globo a la vez; el espacio entre consejos;
-- silenciar 1 hora. Con lya.historias en "pedir" o "nunca", lugar, lore y tuyo
-- solo salen si los pides.
--
--   Ch.Algo()    el latido: algo para platicar -> true si habló
--   Ch.Contar()  "Cuéntame algo" (clic derecho): lore, tuyo o un consejo
--   Ch.Gente()   "Háblame de mi gente": de tu raza
--   Ch.Pedido()  al dar clic en Lya: algo de lo de arriba -> true si habló

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local Ce = M.Cerebro
local H = M.Historias

local type, tonumber, tostring, ipairs, pairs, pcall, rawget = type, tonumber, tostring, ipairs, pairs, pcall, rawget
local floor, random = math.floor, math.random

local Ch = {}
M.Charla = Ch

local RONDA = { "lugar", "lore", "tuyo", "consejo", "momento", "lore", "tuyo", "salchichas" }
local DATOS = { lugar = true, lore = true, tuyo = true } -- lo que respeta lya.historias

local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function memoria()
	local d = N.DatosPersonaje(ID)
	local c = type(d.charla) == "table" and d.charla or {}
	d.charla = c
	c.v = type(c.v) == "table" and c.v or {}
	return c
end

local function hist() return H and H.Personaje and H.Personaje() or nil end

---------------------------------------------------------------------------
-- Tu personaje
---------------------------------------------------------------------------
local function token(fn)
	if type(fn) ~= "function" then return nil end
	local ok, _, t = pcall(fn, "player")
	if not ok or type(t) ~= "string" or secreto(t) or t == "" then return nil end
	return t
end

local function raza()
	local t = token(rawget(_G, "UnitRace"))
	if t == "Undead" then t = "Scourge" end
	return t
end

local function clase() return token(rawget(_G, "UnitClass")) end

local function faccion()
	local fn = rawget(_G, "UnitFactionGroup")
	if type(fn) ~= "function" then return nil end
	local ok, f = pcall(fn, "player")
	if ok and type(f) == "string" and not secreto(f) then return f end
	return nil
end

local function nivel()
	local fn = rawget(_G, "UnitLevel")
	if type(fn) ~= "function" then return nil end
	local ok, n = pcall(fn, "player")
	if not ok or secreto(n) then return nil end
	return tonumber(n)
end

local function mes()
	local ok, m = pcall(date, "%m")
	return ok and tonumber(m) or nil
end

-- ¿Tiene esta profesión? (el rango de la línea de habilidad, como Alfa_Pesca y Alfa_Recoleccion)
local function rango(linea)
	local C = A.Compat
	if C and type(C.GetSkillRank) == "function" then
		local ok, r = pcall(C.GetSkillRank, linea)
		if ok and not secreto(r) and type(r) == "number" then return r end
	end
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, linea)
		if ok and type(info) == "table" and not secreto(info.rank) then return tonumber(info.rank) end
	end
	return nil
end

local function oficios()
	local mios = {}
	for linea in pairs(M.OFICIO or {}) do
		local r = rango(linea)
		if r and r > 0 then mios[#mios + 1] = linea end
	end
	return mios
end

---------------------------------------------------------------------------
-- Elegir sin repetir seguido
---------------------------------------------------------------------------
local function texto(e) return type(e) == "table" and e.t or e end

-- ¿Aplica la nota ahora? (sus condiciones: meses, bando, nivel)
local function aplica(e)
	if type(e) ~= "table" then return type(e) == "string" end
	if type(e.t) ~= "string" then return false end
	if e.fac and e.fac ~= faccion() then return false end
	if e.nv then
		local n = nivel()
		if not n or n < e.nv then return false end
	end
	if type(e.meses) == "table" then
		local m, si = mes(), false
		for _, x in ipairs(e.meses) do if x == m then si = true end end
		if not si then return false end
	end
	if e.accion == "legado" then
		-- Solo en Forever (o donde haya Legado): lo sabe la Enciclopedia.
		local E = rawget(_G, "AlfaEnciclopedia")
		if not (type(E) == "table" and type(E.Abrir) == "function") then return false end
	end
	return true
end

-- -> índice nunca dicho (al azar) o el dicho hace más tiempo; nil si no hay.
-- soloNuevas: solo las que nunca dijo.
local function elegir(lista, prefijo, soloNuevas)
	if type(lista) ~= "table" then return nil end
	local v = memoria().v
	local hp = hist()
	local nuevas, viejo, viejoT = {}, nil, nil
	for i, e in ipairs(lista) do
		if aplica(e) then
			local id = prefijo .. i
			local t = tonumber(v[id]) or (hp and hp.datos and hp.datos[id] and 1) or nil
			if not t then
				nuevas[#nuevas + 1] = i
			elseif not viejoT or t < viejoT then
				viejo, viejoT = i, t
			end
		end
	end
	if #nuevas > 0 then return nuevas[random(#nuevas)], true end
	if soloNuevas then return nil end
	return viejo, false
end

-- Las que todavía no dijo (para preferir las listas con algo nuevo).
local function quedan(lista, prefijo)
	local i, nueva = elegir(lista, prefijo, true)
	return i ~= nil and nueva
end

---------------------------------------------------------------------------
-- Decir
---------------------------------------------------------------------------
local function abrirLegado()
	local E = rawget(_G, "AlfaEnciclopedia")
	if type(E) == "table" and type(E.Abrir) == "function" then pcall(E.Abrir, "guia", "legado") end
end

-- opts = { pedido, dato (lo comparte con Historias: hist.datos), acciones, cara, pose }
-- -> true, o false y el motivo de Cerebro (nil si no había nada que decir)
local function decir(id, e, opts)
	local t = L[texto(e)]
	if type(t) ~= "string" or t == "" then return false end
	local acciones = opts.acciones
	if type(e) == "table" and e.accion == "legado" and not acciones then
		acciones = { { texto = L["Ver el Legado"], fn = abrirLegado } }
	end
	local c = {
		texto = t, pedido = opts.pedido, lineas = 5, ancho = 360, cara = opts.cara, pose = opts.pose,
		clase = "charla", -- 1.2.8: su tipo, para «Consejos que callaste» (Aprende.lua)
		segundos = 9 + floor(#t / 28), acciones = acciones,
		alDecir = function()
			memoria().v[id] = reloj()
			if opts.dato then
				local hp = hist()
				if hp and hp.datos then
					hp.datos[id] = true
					if not opts.pedido then hp.ultimaDato = reloj() end
				end
			end
		end,
	}
	local ok, por = Ce.Decir(c)
	return ok == true, por
end

local function deLista(lista, prefijo, opts, soloNuevas)
	local i = elegir(lista, prefijo, soloNuevas)
	if not i then return false end
	return decir(prefijo .. i, lista[i], opts)
end

---------------------------------------------------------------------------
-- Cada cosa de la ronda: -> true si habló; false, motivo si Lya no pudo
-- hablar (para no gastar el turno); false si no había nada que decir.
---------------------------------------------------------------------------
local function lugar(opts)
	local z = H and H.ZonaActual and H.ZonaActual()
	local lista = z and M.DATOS_ZONA and M.DATOS_ZONA[z]
	if not lista then return false end
	opts.dato = true
	return deLista(lista, "z" .. tostring(z) .. ".", opts, not opts.pedido)
end

local function lore(opts)
	opts.dato = true
	return deLista(M.LORE, "l", opts)
end

-- De tu gente, tu clase o tus profesiones (las tres por igual: una profesión al
-- azar de las que tienes); prefiere lo que todavía no te dijo.
local function tuyo(opts)
	local fuentes = {}
	local r, c = raza(), clase()
	if r and M.RAZA and M.RAZA[r] then fuentes[#fuentes + 1] = { { M.RAZA[r], "r" .. r .. "." } } end
	if c and M.CLASE and M.CLASE[c] then fuentes[#fuentes + 1] = { { M.CLASE[c], "c" .. c .. "." } } end
	local of = {}
	for _, linea in ipairs(oficios()) do of[#of + 1] = { M.OFICIO[linea], "o" .. linea .. "." } end
	if #of > 0 then fuentes[#fuentes + 1] = of end
	if #fuentes == 0 then return false end
	-- Dentro de cada fuente, primero las listas con algo nuevo.
	local conNuevas, todas = {}, {}
	for _, fuente in ipairs(fuentes) do
		local nuevas = {}
		for _, l in ipairs(fuente) do if quedan(l[1], l[2]) then nuevas[#nuevas + 1] = l end end
		if #nuevas > 0 then conNuevas[#conNuevas + 1] = nuevas end
		todas[#todas + 1] = fuente
	end
	local grupo = #conNuevas > 0 and conNuevas or todas
	local fuente = grupo[random(#grupo)]
	local l = fuente[random(#fuente)]
	return deLista(l[1], l[2], opts)
end

local function consejoNuevo(opts)
	local grupos, nuevos = {}, {}
	for _, g in ipairs(M.CONSEJOS or {}) do
		local pre = "k" .. g.id .. "."
		if elegir(g.lista, pre) then
			grupos[#grupos + 1] = g
			if quedan(g.lista, pre) then nuevos[#nuevos + 1] = g end
		end
	end
	local lista = #nuevos > 0 and nuevos or grupos
	if #lista == 0 then return false end
	local g = lista[random(#lista)]
	return deLista(g.lista, "k" .. g.id .. ".", opts)
end

local function consejo(opts)
	-- A veces uno de los de siempre (Alfa, el juego, ánimo: 3 veces cada uno como mucho).
	if Ce.Suelto and random() < 0.35 then
		local ok, por = Ce.Suelto(opts.pedido)
		if ok then return true end
		if por then return false, por end
	end
	return consejoNuevo(opts)
end

local function momento(opts)
	if not Ce.DelMomento then return false end
	return Ce.DelMomento()
end

local function salchichas(opts)
	if not Ce.DecirDe then return false end
	local cat = random() < 0.6 and "salchichas" or "hambre"
	local ok, por = Ce.DecirDe(cat, { pose = "pedir", pedido = opts.pedido })
	if ok == true then return true end
	return false, por
end

local HACER = { lugar = lugar, lore = lore, tuyo = tuyo, consejo = consejo, momento = momento, salchichas = salchichas }

local function hacer(cat, pedido)
	local fn = HACER[cat]
	if not fn then return false end
	local ok, hablo, por = pcall(fn, { pedido = pedido })
	if not ok then
		if geterrorhandler then geterrorhandler()(hablo) end
		return false
	end
	return hablo == true, por
end

---------------------------------------------------------------------------
-- La ronda
---------------------------------------------------------------------------
local function barajar(ultima)
	local r = {}
	for i, v in ipairs(RONDA) do r[i] = v end
	for i = #r, 2, -1 do
		local j = random(i)
		r[i], r[j] = r[j], r[i]
	end
	-- Que la ronda nueva no empiece con lo último que dijo (ni repita dos seguidas).
	for i = 1, #r do
		local antes = (i == 1) and ultima or r[i - 1]
		if r[i] == antes then
			for j = i + 1, #r do
				if r[j] ~= antes and (j == #r or r[j + 1] ~= r[i]) then r[i], r[j] = r[j], r[i] break end
			end
		end
	end
	return r
end

local function datosPermitidos()
	local modo = H and H.Modo and H.Modo() or "aveces"
	return modo == "siempre" or modo == "aveces"
end

-- El latido de Cerebro: algo para platicar. -> true si habló.
function Ch.Algo()
	local m = memoria()
	local permitidos = datosPermitidos()
	-- Al llegar a otra zona, primero lo de ese lugar.
	local z = H and H.ZonaActual and H.ZonaActual()
	if z and z ~= m.zona then
		local hablo, por = false, nil
		if permitidos then hablo, por = hacer("lugar", false) end
		if hablo then m.zona, m.ultima = z, "lugar" return true end
		if por then return false end -- no pudo hablar: lo intenta en el próximo latido
		m.zona = z
	end
	if type(m.ronda) ~= "table" or #m.ronda ~= #RONDA then m.ronda, m.paso = barajar(m.ultima), 0 end
	local paso = tonumber(m.paso) or 0
	for _ = 1, #RONDA do
		if paso >= #m.ronda then m.ronda, paso = barajar(m.ultima), 0 end
		paso = paso + 1
		local cat = m.ronda[paso]
		if cat ~= m.ultima and (permitidos or not DATOS[cat]) then
			local hablo, por = hacer(cat, false)
			if hablo then
				m.paso, m.ultima = paso, cat
				return true
			end
			if por then
				-- Lya no podía hablar (otro globo, muy pronto, combate): no se gasta el turno.
				m.paso = paso - 1
				return false
			end
		end
	end
	m.paso = paso
	return false
end

-- Botones del globo de lo que pediste.
local function botonesContar()
	return { { texto = L["Otra cosa"], fn = function() K.Despues(0.4, function() Ch.Contar() end) end },
		{ texto = L["Háblame de mi gente"], fn = function() K.Despues(0.4, function() Ch.Gente() end) end } }
end

-- "Cuéntame algo": lore, de lo tuyo o un consejo de amiga (lo que pides sale siempre).
function Ch.Contar()
	if not Ce.Activa() then return end
	local orden = random() < 0.5 and { lore, tuyo, consejoNuevo } or { tuyo, lore, consejoNuevo }
	if random() < 0.25 then orden = { consejoNuevo, lore, tuyo } end
	for _, fn in ipairs(orden) do
		local ok, hablo = pcall(fn, { pedido = true, acciones = botonesContar() })
		if ok and hablo then return true end
	end
	return false
end

-- "Háblame de mi gente": lo de tu raza.
function Ch.Gente()
	if not Ce.Activa() then return end
	local r = raza()
	local lista = r and M.RAZA and M.RAZA[r]
	if lista then
		local acciones = { { texto = L["Más de mi gente"], fn = function() K.Despues(0.4, function() Ch.Gente() end) end },
			{ texto = L["Otra cosa"], fn = function() K.Despues(0.4, function() Ch.Contar() end) end } }
		if deLista(lista, "r" .. r .. ".", { pedido = true, acciones = acciones }) then return true end
	end
	Ce.Decir({ texto = L["De tu gente todavía no sé mucho. ¿Te cuento otra cosa?"], pedido = true,
		acciones = { { texto = L["Cuéntame algo"], fn = function() K.Despues(0.4, function() Ch.Contar() end) end } } })
	return true
end

-- Clic en Lya: de vez en cuando, en vez de un consejo, algo de esto. -> true si habló.
function Ch.Pedido()
	local orden = random() < 0.5 and { "lore", "tuyo", "consejo" } or { "tuyo", "consejo", "lore" }
	for _, cat in ipairs(orden) do
		if hacer(cat, true) then return true end
	end
	return false
end

local API = rawget(_G, "AlfaLya")
if type(API) == "table" then
	-- AlfaLya.Contar(): "Cuéntame algo".  AlfaLya.Gente(): "Háblame de mi gente".
	function API.Contar() Ch.Contar() end
	function API.Gente() Ch.Gente() end
end
