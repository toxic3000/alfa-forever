-- Alfa - Enciclopedia: monturas y mascotas (toxic3000 / La Jauría). GPL-3.0.
--
-- Los tipos "montura" y "mascota" de la enciclopedia: todos los objetos que
-- el Codex del motor pone en sus grupos "mount" y "pet" (los que enseñan el
-- hechizo de una montura o una mascota), más las monturas que son un hechizo
-- (las de clase del Codex, y las del diario de monturas del juego que el Codex
-- también conoce o que ya tienes). Nada de listas a mano: solo los datos de
-- clase que el Codex no une (qué misión da la montura de clase) y las razas
-- con su instructor de equitación y su vendedor (los PNJ del motor).
--
-- Si ya la tienes (lo primero que conteste, de lo más fiable a lo menos):
--   montura: C_MountJournal (GetMountFromItem/GetMountFromSpell y
--            GetMountInfoByID -> isCollected), luego GetCompanionInfo("MOUNT"),
--            luego el libro de hechizos (IsSpellKnown / IsPlayerSpell);
--   mascota: GetCompanionInfo("CRITTER"), luego C_PetJournal (la especie del
--            objeto y las que tienes: GetPetInfoByItemID, GetNumCollectedInfo,
--            GetOwnedPetIDs + GetPetInfoTableByPetID), luego el libro;
--   y en las dos, el objeto en tus bolsas o el banco ("úsala para aprenderla").
-- Sin ninguna de esas funciones, "no se sabe" (nil): nunca se inventa.
--
--   Col.Tiene(kind, id) -> true | false | "bolsa" | nil
--   Col.Filtro(c, i, f, ctx), Col.Contexto(tipo, f), Col.Linea(c, i, kind)
--   Col.Enriquecer(f, rec, kind, id)   la ficha de una montura o mascota
--   Col.FichaHechizo(spell)            la ficha de una montura que es un hechizo
--   Col.Equitacion() -> rango | nil, tier1, tier2 ; Col.Raza() -> datos de tu raza
--   M.FICHAS_GUIA.montura              la guía "Mi primera montura"

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Cat, F = M.Cat, M.F
local Col = {}
M.Col = Col

local type, tonumber, tostring, ipairs, pairs, pcall, select = type, tonumber, tostring, ipairs, pairs, pcall, select
local floor, max, min, format = math.floor, math.max, math.min, string.format
local sort, concat = table.sort, table.concat

---------------------------------------------------------------------------
-- Fuentes: cada fila guarda las suyas en un número (un bit por fuente).
---------------------------------------------------------------------------
Col.FUENTES = {
	{ clave = "vendor", bit = 1, texto = L["Vendedor"] },
	{ clave = "drop", bit = 2, texto = L["Botín"] },
	{ clave = "quest", bit = 4, texto = L["Misión"] },
	{ clave = "craft", bit = 8, texto = L["Profesión"] },
	{ clave = "rep", bit = 16, texto = L["Reputación"] },
	{ clave = "pvp", bit = 32, texto = L["JcJ"] },
	{ clave = "clase", bit = 64, texto = L["De clase"] },
	{ clave = "legado", bit = 128, texto = L["Legado"] },
	{ clave = "otro", bit = 256, texto = L["Otras"] },
}
local BIT = {}
for _, x in ipairs(Col.FUENTES) do BIT[x.clave] = x.bit end
-- El tipo de fuente del Codex -> la fuente de la lista.
local DE_CODEX = { vendor = "vendor", drop = "drop", world = "drop", quest = "quest", craft = "craft", rep = "rep",
	pvp = "pvp", object = "otro", container = "otro", gift = "otro" }

local function conBit(b, x) return b % (x * 2) >= x end
local function sumarBit(b, x) if x and not conBit(b, x) then return b + x end return b end
Col.ConBit = conBit

-- Las recompensas del registro del Legado (sus objetos del Codex y los
-- puntos que pide cada una, según warcraft.wiki.gg e Icy Veins; si el juego
-- dice otra cosa, manda el juego: Legado.lua lo lee de C_MajorFactions).
Col.LEGADO = { [276236] = 15, [277714] = 25, [277717] = 40, [277718] = 55 }

-- Las monturas de clase (hechizos del Codex con su clase) y la misión que las
-- da (el final de su cadena en el Codex; el motor nombra las de nivel 40).
local CLASE_MONTURA = {
	[5784] = { mision = 4490, previas = { 3631, 4489, 4487, 4488 } }, -- Brujo, nivel 40
	[23161] = { mision = 7631 },                                    -- Brujo, nivel 60
	[13819] = { mision = 4486, previas = { 1661, 4485 } },          -- Paladín, nivel 40
	[23214] = { mision = 7647 },                                    -- Paladín, nivel 60
}

-- Tu raza: su instructor de equitación, su vendedor de monturas y su ciudad
-- (para la rebaja de la reputación). Los PNJ son los del motor (QoL/Riding y
-- los vendedores del Codex); los nombres y lugares salen del Codex.
local RAZAS = {
	Human = { instructor = 4732, vendedor = 384, faccion = 72 },
	Dwarf = { instructor = 4772, vendedor = 1261, faccion = 47 },
	Gnome = { instructor = 7954, vendedor = 7955, faccion = 54 },
	NightElf = { instructor = 4753, vendedor = 4730, faccion = 69 },
	Orc = { instructor = 4752, vendedor = 3362, faccion = 76 },
	Troll = { instructor = 7953, vendedor = 7952, faccion = 530 },
	Tauren = { instructor = 3690, vendedor = 3685, faccion = 81 },
	Scourge = { instructor = 4773, vendedor = 4731, faccion = 68 },
	Undead = { instructor = 4773, vendedor = 4731, faccion = 68 },
	Skyborne = { instructor = 265756, vendedor = 265756, faccion = 2779, faccionHorda = 2778 },
}
local EQUITACION = 762 -- la línea de habilidad de equitación de Forever (Compat.SKILL_LINES)

---------------------------------------------------------------------------
-- El diario de monturas, los compañeros y las mascotas del juego
---------------------------------------------------------------------------
local secreto = A.Compat and A.Compat.IsSecret or function() return false end
-- Todos los resultados, también los que vienen después de un nil (una tabla
-- con # los perdería en Lua 5.1); nil si falla o si alguno es secreto.
local function devolver(ok, ...)
	if not ok then return nil end
	for i = 1, select("#", ...) do
		if secreto((select(i, ...))) then return nil end
	end
	return ...
end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	return devolver(pcall(fn, ...))
end

local diario       -- false: no hay diario; { [spell] = { id, nombre, tiene, oculta, lado, fuente } }
local companeros = {} -- tipo -> { [spell] = true } | false
local especies     -- { [especie] = true } de las mascotas que tienes | false
local cache = {}   -- "kind:id" -> respuesta (false se guarda como "no")

local function lado(faccion)
	-- Enum.PvPFaction: 0 Horda, 1 Alianza.
	if faccion == 0 then return "H" end
	if faccion == 1 then return "A" end
	return nil
end

local function leerDiario()
	if diario ~= nil then return diario end
	local J = C_MountJournal
	local ids = J and llamar(J.GetMountIDs)
	if type(ids) ~= "table" or #ids == 0 then diario = false return diario end
	diario = {}
	for _, mid in ipairs(ids) do
		local nombre, spell, _, _, _, _, _, especifica, faccion, oculta, tiene = llamar(J.GetMountInfoByID, mid)
		if type(spell) == "number" then
			diario[spell] = { id = mid, nombre = nombre, tiene = tiene and true or false, oculta = oculta and true or false,
				lado = especifica and lado(faccion) or nil }
		end
	end
	return diario
end
Col.Diario = leerDiario

function Col.NombreDiario(spell)
	local d = leerDiario()
	return d and d[spell] and d[spell].nombre or nil
end

-- Lo que dice el diario del juego de una montura: su texto de "Fuente".
function Col.FuenteDiario(spell)
	local d = leerDiario()
	local e = d and d[spell]
	if not e then return nil end
	local _, descripcion, fuente = llamar(C_MountJournal.GetMountInfoExtraByID, e.id)
	if type(fuente) == "string" and fuente ~= "" then return fuente, descripcion end
	return nil, descripcion
end

local function leerCompaneros(tipo)
	local c = companeros[tipo]
	if c ~= nil then return c end
	local total = llamar(GetNumCompanions, tipo)
	if type(total) ~= "number" or type(GetCompanionInfo) ~= "function" then companeros[tipo] = false return false end
	c = {}
	for i = 1, total do
		local _, _, spell = llamar(GetCompanionInfo, tipo, i)
		if type(spell) == "number" then c[spell] = true end
	end
	companeros[tipo] = c
	return c
end

local function leerEspecies()
	if especies ~= nil then return especies end
	local P = C_PetJournal
	local ids = P and llamar(P.GetOwnedPetIDs)
	if type(ids) ~= "table" or type(P.GetPetInfoTableByPetID) ~= "function" then especies = false return false end
	especies = {}
	for _, guid in ipairs(ids) do
		local info = llamar(P.GetPetInfoTableByPetID, guid)
		if type(info) == "table" and type(info.speciesID) == "number" then especies[info.speciesID] = true end
	end
	return especies
end

local function hechizoConocido(spell)
	if not spell then return nil end
	local Cp = A.Compat
	if Cp.IsSpellKnown and Cp.IsSpellKnown(spell) then return true end
	if Cp.IsPlayerSpell and Cp.IsPlayerSpell(spell) == true then return true end
	return nil
end

local function enBolsas(item)
	if not item then return false end
	local Cp = A.Compat
	local n = Cp.GetItemCount and Cp.GetItemCount(item, true)
	return type(n) == "number" and n > 0
end

local function tieneMontura(item, spell)
	local J = C_MountJournal
	if J and leerDiario() then
		local mid = item and llamar(J.GetMountFromItem, item)
		if type(mid) ~= "number" and spell then mid = llamar(J.GetMountFromSpell, spell) end
		if type(mid) == "number" then
			local tiene = select(11, llamar(J.GetMountInfoByID, mid))
			if tiene ~= nil then return tiene and true or false end
		end
		local e = spell and diario[spell]
		if e then return e.tiene end
	end
	local c = leerCompaneros("MOUNT")
	if c then
		if spell and c[spell] then return true end
		return hechizoConocido(spell) or false
	end
	return hechizoConocido(spell)
end

local function tieneMascota(item, spell)
	local c = leerCompaneros("CRITTER")
	if c and spell and c[spell] then return true end
	local P = C_PetJournal
	local especie
	if P and item then especie = select(13, llamar(P.GetPetInfoByItemID, item)) end
	if type(especie) == "number" then
		local n = llamar(P.GetNumCollectedInfo, especie)
		if type(n) == "number" then return n > 0 end
		local s = leerEspecies()
		if s then return s[especie] and true or false end
	end
	if hechizoConocido(spell) then return true end
	if c then return false end
	return nil
end

-- kind: "mount" | "pet" | "mountspell"; id: el objeto (o el hechizo).
function Col.Tiene(kind, id)
	local clave = kind .. ":" .. tostring(id)
	local v = cache[clave]
	if v ~= nil then if v == "no" then return false elseif v == "?" then return nil end return v end
	local C = M.CodexListo()
	local item, spell
	if kind == "mountspell" then spell = id
	else
		item = id
		local rec = C and C.Item(id)
		spell = rec and rec.spell
	end
	local r
	if kind == "pet" then r = tieneMascota(item, spell) else r = tieneMontura(item, spell) end
	if r ~= true and enBolsas(item) then r = "bolsa" end
	cache[clave] = r == false and "no" or (r == nil and "?" or r)
	return r
end

function Col.TieneFila(c, i) return Col.Tiene(Cat.Kind(c, i), c.id[i]) end

local function olvidar()
	cache, diario, companeros, especies = {}, nil, {}, nil
	if M.alColeccion then K.Llamar(M.alColeccion) end
end
local olvidarPronto = false
local function olvidarLuego()
	-- Los eventos llegan en ráfagas: se junta todo en uno.
	if olvidarPronto then return end
	olvidarPronto = true
	C_Timer.After(0.5, function() olvidarPronto = false olvidar() end)
end
for _, ev in ipairs({ "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "COMPANION_UNLEARNED", "NEW_PET_ADDED",
	"PET_JOURNAL_LIST_UPDATE", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED" }) do
	A.RegisterEvent(ev, olvidarLuego)
end

---------------------------------------------------------------------------
-- Equitación y tu raza
---------------------------------------------------------------------------
-- -> rango (nil: no la tienes o no se sabe), tiene la de nivel 40, tiene la de nivel 60
function Col.Equitacion()
	local rango, tope = A.Compat.GetSkillRank(EQUITACION)
	local R = A.QoL and A.QoL.Riding
	local t1, t2
	if R and type(R.HasRiding) == "function" then
		local ok, a = pcall(R.HasRiding, 1)
		local ok2, b = pcall(R.HasRiding, 2)
		t1, t2 = ok and a or false, ok2 and b or false
	else
		t1, t2 = (rango or 0) > 0, (tope or 0) >= 150
	end
	return rango, t1, t2
end

-- El costo de entrenar (cobre) con la rebaja de tu ciudad, del motor; nil si no lo sabe.
function Col.CostoEquitacion(tier, faccion)
	local R = A.QoL and A.QoL.Riding
	if not (R and type(R.EffectiveCost) == "function") then return nil end
	local ok, c = pcall(R.EffectiveCost, tier, faccion)
	return ok and tonumber(c) or nil
end

function Col.Raza()
	local p = A.Compat.GetPlayerInfo()
	local r = RAZAS[p.race or ""]
	if not r then return nil, p end
	local out = { instructor = r.instructor, vendedor = r.vendedor, faccion = r.faccion }
	if r.faccionHorda and p.faction == "Horde" then out.faccion = r.faccionHorda end
	return out, p
end

-- El nivel de equitación que pide una montura: 1 (la de nivel 40) o 2 (la
-- rápida, épica). Es lo que usa el recordatorio de equitación del motor.
local function tierDe(rec)
	if not rec then return 0 end
	if (rec.quality or 0) >= 4 or (rec.reqLevel or 0) >= 60 and (rec.quality or 0) >= 4 then return 2 end
	return 1
end
Col.Tier = tierDe

---------------------------------------------------------------------------
-- Armar las filas (Catalogo.lua llama TIPO.completar al terminar el índice)
---------------------------------------------------------------------------
-- El bando de una fuente: "A", "H" o nil (los dos, o no se sabe).
local function ladoFuente(s, C)
	if s.npc then
		local n = C.Npc(s.npc)
		local f = n and n.faction
		if f == "A" or f == "H" then return f end
		return nil
	end
	if s.type == "quest" and s.quest then
		local q = C.Quest(s.quest)
		local f = q and q.faction
		if f == "A" or f == "H" then return f end
		return nil
	end
	if s.type == "rep" and s.faction then
		local fa = C.Faction(s.faction)
		if fa and fa.side == "Alliance" then return "A" end
		if fa and fa.side == "Horde" then return "H" end
	end
	return nil
end

local function ladoDe(rec, C)
	local hay = {}
	local n = 0
	for _, s in ipairs(rec.sources or {}) do
		local l = ladoFuente(s, C)
		if not l then return nil end
		if not hay[l] then hay[l] = true n = n + 1 end
	end
	if n == 1 then return hay.A and "A" or "H" end
	return nil
end

local function datosDeRegistro(c, i, rec, C, kind)
	local id = c.id[i]
	local bits, precio = 0, nil
	for _, s in ipairs(rec and rec.sources or {}) do
		local clave = DE_CODEX[s.type]
		if s.type == "quest" and s.quest then
			-- Las misiones "Legacy Reward: ..." son las recompensas del Legado.
			-- (el nombre en inglés está en el índice de búsqueda del Codex)
			local blob = C.Index("quest")
			if Col.LEGADO[id] then clave = "legado" end
			if type(blob) == "string" and string.find(blob, "\2legacy reward[^\1]*\1" .. tostring(s.quest) .. ",") then clave = "legado" end
		end
		bits = sumarBit(bits, BIT[clave or "otro"])
		if s.type == "vendor" and type(s.cost) == "number" and s.cost > 0 then precio = min(precio or s.cost, s.cost) end
	end
	if rec and rec.repFaction then bits = sumarBit(bits, BIT.rep) end
	if Col.LEGADO[id] then bits = sumarBit(bits, BIT.legado) end
	c.src[i] = bits
	c.precio[i] = precio
	c.nivel[i] = rec and rec.reqLevel or 0
	c.spell[i] = rec and rec.spell or nil
	c.lado[i] = rec and ladoDe(rec, C) or nil
	c.tier[i] = kind == "mount" and tierDe(rec) or 0
	-- Lo que el diario sabe del bando (las de JcJ no tienen PNJ en el Codex).
	if kind == "mount" and not c.lado[i] and rec and rec.spell then
		local d = leerDiario()
		local e = d and d[rec.spell]
		if e and e.lado then c.lado[i] = e.lado end
	end
end

local function agregarFila(c, id, en, loc, q, kind)
	local fold = Cat.Plegar
	local n = c.n + 1
	c.n = n
	c.id[n] = id
	local pe = en and fold(en) or nil
	local pl = loc and fold(loc) or nil
	if pe and pl and pl ~= pe then c.nom[n] = pe .. "\1" .. pl
	else c.nom[n] = pe or pl or " ?" end
	c.q[n] = q
	return n
end

local function completar(c, C, kind)
	c.src, c.precio, c.nivel, c.spell, c.lado, c.tier, c.clase = {}, {}, {}, {}, {}, {}, {}
	local hechizos = {}
	for i = 1, c.n do
		local rec = C.Item(c.id[i])
		datosDeRegistro(c, i, rec, C, kind)
		if c.spell[i] then hechizos[c.spell[i]] = true end
	end
	if kind ~= "mount" then return end
	-- Las monturas que son un hechizo: las de clase, y las del diario del juego.
	local d = leerDiario()
	local desde = c.n + 1
	local vistos = {}
	C.Each("spell", function(sid, en)
		local s = C.Spell(sid)
		if s and s.kind == "mount" and not s.item and not hechizos[sid] then
			local e = d and d[sid]
			if s.class or (e and not e.oculta) then
				local i = agregarFila(c, sid, en, s.name ~= en and s.name or nil, 0, "mountspell")
				vistos[sid] = true
				c.src[i] = s.class and BIT.clase or BIT.otro
				c.clase[i] = s.class
				local cm = CLASE_MONTURA[sid]
				local q = cm and C.Quest(cm.mision)
				c.nivel[i] = q and q.level or 0
				c.lado[i] = (q and (q.faction == "A" or q.faction == "H") and q.faction) or (e and e.lado) or nil
				c.spell[i] = sid
				c.tier[i] = 0
			end
		end
	end)
	-- Monturas del diario que ya tienes y que el Codex no conoce.
	if d then
		for sid, e in pairs(d) do
			if e.tiene and not hechizos[sid] and not vistos[sid] and not C.Spell(sid) then
				local i = agregarFila(c, sid, nil, e.nombre, 0, "mountspell")
				c.src[i], c.nivel[i], c.lado[i], c.spell[i], c.tier[i] = BIT.otro, 0, e.lado, sid, 0
			end
		end
	end
	if c.n >= desde then c.kinds[#c.kinds + 1] = { desde, c.n, "mountspell" } end
end

M.TIPO.montura.completar = function(c, C) completar(c, C, "mount") end
M.TIPO.mascota.completar = function(c, C) completar(c, C, "pet") end

---------------------------------------------------------------------------
-- Filtros de la lista
--   f.estado: "conseguible" (se puede conseguir) | "ahora" (para ti hoy) | "retirada"
--   f.bando: "A" | "H" ; f.fuente: clave de Col.FUENTES ; f.mia: "si" | "no"
---------------------------------------------------------------------------
Col.ESTADOS = {
	{ valor = false, texto = L["Todas"] },
	{ valor = "conseguible", texto = L["Se pueden conseguir"] },
	{ valor = "ahora", texto = L["Para ti ahora"] },
	{ valor = "retirada", texto = L["Ya no se consiguen"] },
}
Col.BANDOS = { { valor = false, texto = L["Los dos bandos"] }, { valor = "A", texto = L["Alianza"] }, { valor = "H", texto = L["Horda"] } }
Col.MIAS = { { valor = false, texto = L["Tenga o no"] }, { valor = "si", texto = L["Las que tengo"] }, { valor = "no", texto = L["Las que me faltan"] } }
function Col.OpcionesFuente()
	local out = { { valor = false, texto = L["Toda fuente"] } }
	for _, x in ipairs(Col.FUENTES) do out[#out + 1] = { valor = x.clave, texto = x.texto } end
	return out
end

function Col.Contexto(tipo, f)
	local p = A.Compat.GetPlayerInfo()
	return { yo = M.MiBando(), nivel = p.level or 1, clase = p.class, bit = f.fuente and BIT[f.fuente] or nil }
end

function Col.Filtro(c, i, f, ctx)
	if not c.src then return true end
	local _, st = Cat.Calidad(c, i)
	local e = f.estado
	if (e == "conseguible" or e == "ahora") and st then return false end
	if e == "retirada" and not st then return false end
	local l = c.lado[i]
	if e == "ahora" then
		if l and ctx.yo and l ~= ctx.yo then return false end
		if c.clase[i] and c.clase[i] ~= ctx.clase then return false end
		if (c.nivel[i] or 0) > ctx.nivel then return false end
	end
	if f.bando and l and l ~= f.bando then return false end
	if ctx.bit and not conBit(c.src[i] or 0, ctx.bit) then return false end
	if f.mia then
		local t = Col.TieneFila(c, i)
		if f.mia == "si" and t ~= true then return false end
		if f.mia == "no" and t == true then return false end
	end
	return true
end

-- La primera fuente de una fila, en palabras.
local function fuentePrincipal(bits)
	for _, x in ipairs(Col.FUENTES) do if conBit(bits or 0, x.bit) then return x.texto end end
	return nil
end

-- La línea de debajo del nombre en la lista.
function Col.Linea(c, i, kind)
	if not c.src then return kind == "pet" and L["Mascota"] or L["Montura"] end
	local partes = {}
	local _, st = Cat.Calidad(c, i)
	if c.clase[i] then
		partes[#partes + 1] = format(L["De clase: %s"], M.NombreClase(c.clase[i]))
	else
		partes[#partes + 1] = fuentePrincipal(c.src[i])
	end
	if c.precio[i] then partes[#partes + 1] = N.Dinero(c.precio[i], true) end
	if (c.nivel[i] or 0) > 1 then partes[#partes + 1] = format(L["Nv %d"], c.nivel[i]) end
	if c.lado[i] then partes[#partes + 1] = M.NombreBando(c.lado[i]) end
	if st == "r" then partes[#partes + 1] = L["ya no se consigue"]
	elseif st == "n" then partes[#partes + 1] = L["sin fuente conocida"] end
	local t = Col.Tiene(Cat.Kind(c, i), c.id[i])
	if t == true then partes[#partes + 1] = K.Tenir("exito", L["ya la tienes"])
	elseif t == "bolsa" then partes[#partes + 1] = K.Tenir("acento", L["en tus bolsas"]) end
	return concat(partes, M.SEP)
end

-- Cuántas tienes de un tipo ya armado: tienes, total (de las que se consiguen), sabe
function Col.Cuenta(tipo)
	local c = Cat.Col(tipo)
	if not (c and c.src) then return nil end
	local tienes, total, sabe = 0, 0, false
	for i = 1, c.n do
		local _, st = Cat.Calidad(c, i)
		local t = Col.TieneFila(c, i)
		if t ~= nil then sabe = true end
		if t == true then tienes = tienes + 1 end
		if not st then total = total + 1 end
	end
	return tienes, total, sabe
end

---------------------------------------------------------------------------
-- La ficha de una montura o mascota (F.Objeto la llama)
---------------------------------------------------------------------------
local function insigniaTiene(f, t, kind)
	if t == true then f.insignias[#f.insignias + 1] = { L["Ya la tienes"], "exito", "ic-exito" }
	elseif t == "bolsa" then f.insignias[#f.insignias + 1] = { L["En tus bolsas: úsala para aprenderla"], "acento" }
	elseif t == false then f.insignias[#f.insignias + 1] = { L["Te falta"], "neutro" }
	else f.insignias[#f.insignias + 1] = { L["El juego no dice si la tienes"], "neutro" } end
end

local function filaNpc(id, texto)
	local C = M.CodexListo()
	local npc = C and C.Npc(id)
	if not npc then return nil end
	local Lk = A.Lookup
	local desde = A.PlayerPoint and A.PlayerPoint()
	local s, t
	if Lk and Lk.Nearest and npc.spawns then s, t = Lk.Nearest(npc.spawns, desde, true) end
	return { icono = { ic = "ic-personajes", tono = "acento" }, titulo = npc.name, color = "pnj",
		texto = F.Unir(texto, s and M.Lugar(s.map, s.x, s.y) or nil), viaje = t and F.Viaje(t) or nil,
		ir = { kind = "npc", id = id }, guia = { kind = "npc", id = id },
		punto = s and F.Punto(s.map, s.x, s.y, s.f, npc.name, "map:trainer-profession", s.z) or nil }
end
Col.FilaNpc = filaNpc

local function nombreTier(tier)
	if tier == 2 then return L["Equitación de oficial (la rápida, nivel 60)"] end
	return L["Equitación de aprendiz (nivel 40)"]
end

function Col.Enriquecer(f, rec, kind, id)
	local t = Col.Tiene(kind, id)
	insigniaTiene(f, t, kind)
	local C = M.CodexListo()
	local filas = {}
	local nivel = rec.reqLevel or 0
	local miNivel = M.MiNivel()
	filas[#filas + 1] = { L["Nivel"], nivel > 1 and format(L["%d (tú: %d)"], nivel, miNivel) or L["Cualquiera"] }
	local antes = {}
	if kind == "mount" then
		local tier = tierDe(rec)
		local rango, t1, t2 = Col.Equitacion()
		local la = (tier == 2 and t2) or (tier == 1 and t1)
		filas[#filas + 1] = { L["Equitación"], la and L["la tienes"] or (tier == 2 and L["de oficial"] or L["de aprendiz"]) }
		if not la and t ~= true then
			local r = Col.Raza()
			local fl = r and filaNpc(r.instructor, nombreTier(tier))
			if fl then
				local costo = Col.CostoEquitacion(tier, r.faccion)
				fl.valor = costo and N.Dinero(costo, true) or nil
				antes[#antes + 1] = fl
			end
			antes[#antes + 1] = { icono = { ic = "ic-huella", tono = "acento" }, titulo = L["Mi primera montura"],
				texto = L["Qué necesitas a tu nivel, paso a paso."], ir = { kind = "guia", id = "montura" } }
		end
	end
	local l = C and (function()
		local hay = {}
		for _, s in ipairs(rec.sources or {}) do
			local x = ladoFuente(s, C)
			if not x then return nil end
			hay[x] = true
		end
		if hay.A and not hay.H then return "A" elseif hay.H and not hay.A then return "H" end
		return nil
	end)()
	if not l and rec.spell then
		local d = leerDiario()
		l = d and d[rec.spell] and d[rec.spell].lado or nil
	end
	filas[#filas + 1] = { L["Bando"], l and M.NombreBando(l) or L["Los dos"] }
	if rec.repFaction then
		filas[#filas + 1] = { L["Reputación"], F.Unir(M.Nombre("faction", rec.repFaction), M.NombreReputacion(rec.repStanding)) }
	end
	local precio
	local tipos, visto = {}, {}
	for _, s in ipairs(rec.sources or {}) do
		if s.type == "vendor" and type(s.cost) == "number" and s.cost > 0 then precio = min(precio or s.cost, s.cost) end
		local clave = DE_CODEX[s.type] or "otro"
		-- La misión de una recompensa del Legado no es una misión de verdad.
		if Col.LEGADO[id] and s.type == "quest" then clave = "legado" end
		if not visto[clave] then visto[clave] = true tipos[#tipos + 1] = clave end
	end
	if precio then filas[#filas + 1] = { L["Precio"], N.Dinero(precio, true) } end
	local nombres = {}
	if Col.LEGADO[id] then visto.legado = true end
	for _, x in ipairs(Col.FUENTES) do if visto[x.clave] then nombres[#nombres + 1] = x.texto end end
	filas[#filas + 1] = { L["Cómo se consigue"], #nombres > 0 and concat(nombres, ", ") or L["no se sabe"] }
	f.datos = { titulo = L["Qué pide"], filas = filas }

	F.Seccion(f, "antes", L["Antes necesitas"], antes)
	-- Una recompensa del Legado: a la guía de los puntos.
	if Col.LEGADO[id] then
		local fl = { icono = { ic = "ic-nivel", tono = "oro" }, titulo = L["Recompensa del registro del Legado"],
			texto = format(L["Llega con %d puntos del legado ganados en tu cuenta."], Col.LEGADO[id]), ir = { kind = "guia", id = "legado" } }
		F.Seccion(f, "legado", L["Del Legado"], { fl })
		f.mejor = f.mejor or { sobre = L["Cómo se consigue"], titulo = L["Puntos del legado"], texto = fl.texto, ir = fl.ir, icono = "ic-nivel" }
	end
	-- Lo que dice el diario del juego (sus palabras, en tu idioma).
	if kind == "mount" and rec.spell then
		local fuente = Col.FuenteDiario(rec.spell)
		if fuente then f.parrafos = { { titulo = L["Lo que dice el diario de monturas"], textos = { fuente } } } end
	end
end

---------------------------------------------------------------------------
-- La ficha de una montura que es un hechizo (de clase o del diario)
---------------------------------------------------------------------------
function Col.FichaHechizo(sid)
	local C = M.CodexListo()
	if not (C and sid) then return nil end
	local s = C.Spell(sid)
	local nombre = M.Nombre("mountspell", sid)
	if not s and not Col.NombreDiario(sid) then return nil end
	local f = F.Nueva("mountspell", sid)
	f.icono = { ic = "ic-huella", tono = s and s.class and "clase" or "acento" }
	f.titulo = nombre
	f.sobre = s and s.class and L["Montura de clase"] or L["Montura"]
	local p = A.Compat.GetPlayerInfo()
	insigniaTiene(f, Col.Tiene("mountspell", sid), "mount")
	local filas = {}
	if s and s.class then
		filas[#filas + 1] = { L["Clase"], M.NombreClase(s.class) }
		if s.class ~= p.class then f.insignias[#f.insignias + 1] = { L["No es para tu clase"], "aviso" } end
	end
	local cm = CLASE_MONTURA[sid]
	local final = cm and C.Quest(cm.mision)
	if final and final.level then filas[#filas + 1] = { L["Nivel"], format(L["%d (tú: %d)"], final.level, p.level or 1) } end
	f.datos = #filas > 0 and { titulo = L["Qué pide"], filas = filas } or nil
	local pendiente
	local tuya = not (s and s.class) or s.class == p.class
	if cm then
		local qs = {}
		local mio = M.MiBando()
		local I = M.Indices
		local hechaAlguna = false
		for _, q in ipairs(cm.previas or {}) do if A.Compat.IsQuestCompleted(q) then hechaAlguna = true end end
		for _, q in ipairs(cm.previas or {}) do
			local rq = C.Quest(q)
			local otra = rq and rq.faction and mio and rq.faction ~= mio
			-- Las previas son una por ciudad: la que puedes tomar (la ruta lo sabe).
			local paraMi = not otra
			if paraMi and I and I.MisionesListas and I.MisionesListas() then
				local ok, si = pcall(I.MisionParaMi, q)
				if ok and si == false then paraMi = false end
			end
			local fl = F.FilaMision(q, otra and L["De la otra facción"] or (not paraMi and L["Todavía no es para ti"] or L["basta una de estas"]))
			if not paraMi then fl.tenue = true end
			qs[#qs + 1] = fl
			if tuya and paraMi and not hechaAlguna and not pendiente and not A.Compat.IsQuestCompleted(q) then pendiente = q end
		end
		qs[#qs + 1] = F.FilaMision(cm.mision, L["la que te da la montura"])
		if tuya and not pendiente and not A.Compat.IsQuestCompleted(cm.mision) then pendiente = cm.mision end
		F.Seccion(f, "misiones", L["Cómo se consigue"], qs)
		f.mejor = pendiente and { sobre = L["Para empezar"], titulo = M.Nombre("quest", pendiente), texto = L["Tu clase la gana con esta cadena de misiones."],
			icono = "ic-misiones", ir = { kind = "quest", id = pendiente } } or nil
	elseif s and s.class then
		f.nota = L["Es una montura de tu clase: pregunta a tu instructor de clase cuándo y cómo se consigue."]
	end
	local fuente, descripcion = Col.FuenteDiario(sid)
	if fuente or descripcion then
		f.parrafos = { { titulo = L["Lo que dice el diario de monturas"], textos = { fuente, descripcion } } }
	elseif not cm and not (s and s.class) then
		f.nota = L["El Codex no sabe de dónde sale; si ya la tienes, la ves en tu diario de monturas."]
	end
	f.acciones.guiar = pendiente and function() return F.Guiar("quest", pendiente) end or nil
	f.acciones.mapa = F.PuntosDe(f.secciones)
	return f
end

---------------------------------------------------------------------------
-- Guía: Mi primera montura
---------------------------------------------------------------------------
M.GUIAS.montura = L["Mi primera montura"]
M.FICHAS_GUIA = M.FICHAS_GUIA or {}

-- Las monturas que vende un PNJ, de la más barata a la más cara: { id, precio, tier }
local function monturasDe(vendedor)
	local C = M.CodexListo()
	local out = {}
	if not (C and vendedor) then return out end
	C.Each("mount", function(id, _, _, status)
		if status then return end
		local rec = C.Item(id)
		for _, s in ipairs(rec and rec.sources or {}) do
			if s.type == "vendor" and s.npc == vendedor then
				out[#out + 1] = { id = id, precio = s.cost or 0, tier = tierDe(rec) }
				break
			end
		end
	end)
	sort(out, function(a, b) if a.precio ~= b.precio then return a.precio < b.precio end return a.id < b.id end)
	return out
end

M.FICHAS_GUIA.montura = function()
	local f = F.Nueva("guia", "montura")
	f.icono = { ic = "ic-huella", tono = "acento" }
	f.sobre = L["Guía"]
	f.titulo = L["Mi primera montura"]
	local r, p = Col.Raza()
	local nivel = p.level or 1
	f.subtitulo = format(L["Para tu personaje de nivel %d"], nivel)
	local rango, t1, t2 = Col.Equitacion()
	local oro = A.Compat.GetMoney and A.Compat.GetMoney() or 0
	local tier = (nivel >= 60 and t1) and 2 or 1
	local nivelTier = tier == 2 and 60 or 40
	local lista = r and monturasDe(r.vendedor) or {}
	local montura
	for _, m in ipairs(lista) do if m.tier == tier then montura = montura or m end end
	local costo = r and Col.CostoEquitacion(tier, r.faccion)
	local tengoMontura, tengoRapida = false, false
	for _, m in ipairs(lista) do
		if Col.Tiene("mount", m.id) == true then
			tengoMontura = true
			if m.tier == 2 then tengoRapida = true end
		end
	end

	local filas = {
		{ L["Tu nivel"], format(L["%d de %d"], nivel, nivelTier) },
		{ L["Equitación"], rango and tostring(rango) or L["no la tienes"] },
	}
	if costo then filas[#filas + 1] = { tier == 2 and L["Entrenar la rápida"] or L["Entrenar"], N.Dinero(costo, true) } end
	if montura and montura.precio > 0 then filas[#filas + 1] = { L["La montura"], N.Dinero(montura.precio, true) } end
	local total = (costo or 0) + (montura and montura.precio or 0)
	if costo and montura then filas[#filas + 1] = { L["Total"], N.Dinero(total, true) } end
	filas[#filas + 1] = { L["Tu oro"], N.Dinero(oro, true) }
	f.datos = { titulo = tier == 2 and L["Tu montura rápida (nivel 60)"] or L["Tu primera montura (nivel 40)"], filas = filas }
	if total > 0 and oro < total then f.insignias[#f.insignias + 1] = { format(L["Te faltan %s"], N.Dinero(total - oro, true)), "aviso" } end
	if (tier == 1 and t1) or (tier == 2 and t2) then f.insignias[#f.insignias + 1] = { L["Ya tienes la equitación"], "exito" } end

	-- Lo siguiente que toca.
	local instructor = r and filaNpc(r.instructor, L["Instructor de equitación"])
	local vendedor = r and filaNpc(r.vendedor, L["Vendedor de monturas de tu raza"])
	local siguiente
	if nivel < 40 then
		f.mejor = { sobre = L["Lo siguiente"], titulo = format(L["Llega al nivel 40 (te faltan %d)"], 40 - nivel),
			texto = L["Mientras, junta el oro: con la equitación y la montura se va casi todo."], icono = "ic-nivel" }
	elseif not ((tier == 1 and t1) or (tier == 2 and t2)) then
		siguiente = r and r.instructor
		f.mejor = instructor and { sobre = L["Lo siguiente"], titulo = format(L["Aprende equitación con %s"], instructor.titulo),
			texto = F.Unir(instructor.texto, costo and N.Dinero(costo, true) or nil), icono = "ic-personajes", punto = instructor.punto, ir = instructor.ir } or nil
	elseif not tengoMontura or (tier == 2 and not tengoRapida) then
		siguiente = r and r.vendedor
		f.mejor = vendedor and { sobre = L["Lo siguiente"], titulo = format(L["Compra tu montura con %s"], vendedor.titulo),
			texto = F.Unir(vendedor.texto, montura and N.Dinero(montura.precio, true) or nil), icono = "ic-comercio", punto = vendedor.punto, ir = vendedor.ir } or nil
	else
		-- Con la rápida ya no hay "lo que sigue".
		f.mejor = { sobre = L["Listo"], titulo = L["Ya tienes tu montura"],
			texto = tier == 1 and L["A nivel 60 sigue la rápida: equitación de oficial y una montura épica."] or nil, icono = "ic-exito" }
	end

	local donde = {}
	if instructor then instructor.valor = costo and N.Dinero(costo, true) or nil donde[#donde + 1] = instructor end
	if vendedor and (not r or r.vendedor ~= r.instructor) then donde[#donde + 1] = vendedor end
	F.Seccion(f, "donde", L["A quién ir"], donde)

	-- Las monturas de tu raza (las de tu nivel primero).
	local mias = {}
	for _, m in ipairs(lista) do
		local fl = F.FilaObjeto(m.id, m.tier == 2 and L["rápida, nivel 60"] or L["nivel 40"], m.precio > 0 and N.Dinero(m.precio, true) or nil)
		local t = Col.Tiene("mount", m.id)
		if t == true then fl.texto = F.Unir(fl.texto, L["ya la tienes"]) fl.tenue = true end
		fl.orden = (m.tier == tier and 0 or 1)
		mias[#mias + 1] = fl
	end
	sort(mias, function(a, b) if a.orden ~= b.orden then return a.orden < b.orden end return false end)
	F.Seccion(f, "monturas", L["Las monturas de tu raza"], mias)

	-- La montura de tu clase, si la hay.
	local deClase = {}
	local C = M.CodexListo()
	for sid in pairs(CLASE_MONTURA) do
		local s = C and C.Spell(sid)
		if s and s.class == p.class then
			local q = C.Quest(CLASE_MONTURA[sid].mision)
			deClase[#deClase + 1] = { icono = { ic = "ic-huella", tono = "clase" }, titulo = M.Nombre("mountspell", sid),
				texto = F.Unir(q and q.level and format(L["Nivel %d"], q.level) or nil, Col.Tiene("mountspell", sid) == true and L["ya la tienes"] or L["con una cadena de misiones"]),
				ir = { kind = "mountspell", id = sid }, orden = q and q.level or 0 }
		end
	end
	sort(deClase, function(a, b) return a.orden < b.orden end)
	F.Seccion(f, "clase", L["Tu montura de clase"], deClase)

	local pasos = {
		L["1. Llega al nivel 40. La montura y la equitación se compran a la vez: junta el oro mientras subes."],
		L["2. Ve con el instructor de equitación de tu raza y aprende la de aprendiz."],
		L["3. Compra la montura con el vendedor de tu raza (al lado del instructor) y úsala para aprenderla."],
		L["4. A nivel 60, el mismo instructor enseña la de oficial y el vendedor tiene las rápidas."],
		L["Las monturas de otra raza de tu bando pueden pedir reputación con su ciudad: la de tu raza siempre se puede."],
	}
	f.parrafos = { { titulo = L["Paso a paso"], textos = pasos, arriba = false } }
	if not r then f.nota = L["Alfa no tiene el instructor de tu raza: busca «equitación» en PNJ."] end
	f.acciones.guiar = siguiente and function() return F.Guiar("npc", siguiente) end or nil
	f.acciones.mapa = F.PuntosDe(f.secciones)
	return f
end
