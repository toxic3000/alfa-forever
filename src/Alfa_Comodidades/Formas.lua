-- Alfa - Comodidades: la barra de una forma que está vacía (toxic3000 / La Jauría). GPL-3.0.
--
-- Al cambiar de forma o de actitud (druida: Felino, Acecho, Oso y Lechúcico;
-- guerrero: sus tres actitudes; pícaro: Sigilo), el juego cambia la barra de
-- acción principal por la página de esa forma: cada botón calcula su casilla
-- con la barra extra (GetBonusBarOffset: la página 6 + n, Blizzard_ActionBar).
-- Si esa página nunca se llenó, la barra de abajo queda vacía justo al pelear
-- y parece que desapareció. Eso es del juego, no un error.
--
-- Lo que hace Alfa (Comodidades > barraForma, encendido de fábrica):
--   * Una vez por forma y personaje, fuera de combate, un aviso del Kit
--     (K.Aviso) dice que esa barra está vacía y por qué.
--   * Su botón llena solo las casillas VACÍAS de esa página con las
--     habilidades de la forma que ya sabes, en su rango más alto (como
--     QoL/Spells.lua del motor: PickupSpell, PlaceAction, ClearCursor). Nunca
--     en combate (espera a que termine), nunca encima de algo que ya está y
--     nunca con algo en el cursor.
--
-- Cliente: C_ActionBar.GetBonusBarOffset / GetBonusBarOffset, HasAction,
-- GetActionInfo, PlaceAction, C_Spell.PickupSpell / PickupSpell, ClearCursor,
-- GetCursorInfo, HasOverrideActionBar, HasVehicleActionBar (ActionBarFrame
-- Documentation); el botón ActionButtonN.action (Shared/ActionButton.lua).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local ID = M.ID

local type, ipairs, pairs, pcall, tonumber, format, ceil = type, ipairs, pairs, pcall, tonumber, string.format, math.ceil

local function activo() return M.Get("barraForma") end

-- Una llamada al cliente que no rompe nada: -> sus valores (legibles) o nil.
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return M.Legible(a), M.Legible(b), M.Legible(c)
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Las formas y sus habilidades (rango 1; se pone el más alto que sepas).
-- La clave sale de la barra extra de la forma (GetBonusBarOffset), que es
-- la que elige la página.
---------------------------------------------------------------------------
local FORMAS = {
	DRUID = {
		-- Garra, Arañazo, Triturar, Destripar, Mordedura feroz, Furia del tigre, Fuego feérico (feral),
		-- Agazapar, Carrerilla, Acechar, Abalanzarse, Devastar
		felino = { nombre = L["Felino"], ids = { 1082, 1822, 5221, 1079, 22568, 5217, 16857, 8998, 1850, 5215, 9005, 6785 } },
		acecho = { nombre = L["Acecho"], ids = { 9005, 6785, 5221, 1822, 1082, 1850, 5215 } },
		-- Magullar, Flagelo, Gruñido, Rugido desmoralizador, Azote, Enfurecer, Regeneración frenética,
		-- Cargar feral, Fuego feérico (feral), Rugido desafiante
		oso = { nombre = L["Oso"], ids = { 6807, 779, 6795, 99, 5211, 5229, 22842, 16979, 16857, 5209 } },
		-- Cólera, Fuego lunar, Fuego estelar, Enjambre de insectos, Fuego feérico, Raíces enredadoras,
		-- Huracán, Espinas, Estimular, Piel de corteza
		lechucico = { nombre = L["Lechúcico"], ids = { 5176, 8921, 2912, 5570, 770, 339, 16914, 467, 29166, 22812 } },
	},
	WARRIOR = {
		-- Golpe heroico, Abrir herida, Cargar, Atronar, Seccionar, Abrumar, Golpe mortal, Ejecutar,
		-- Rajar, Grito de batalla, Grito desmoralizador, Sed de sangre... (lo que sepas)
		batalla = { nombre = L["Actitud de batalla"], ids = { 78, 772, 100, 6343, 1715, 7384, 12294, 5308, 845, 6673, 1160, 694, 12292, 20230, 2687 } },
		defensa = { nombre = L["Actitud defensiva"], ids = { 355, 7386, 6572, 2565, 23922, 72, 676, 871, 78, 772, 845, 6673, 1160, 2687 } },
		rabia = { nombre = L["Actitud rabiosa"], ids = { 1680, 23881, 18499, 20252, 6552, 5308, 1715, 1464, 78, 845, 1719, 6673, 2687 } },
	},
	ROGUE = {
		-- Emboscar, Garrote, Golpe bajo, Aporrear, Robar, Distraer, Esprintar, Sigilo, Puñalada,
		-- Golpe siniestro, Premeditación
		sigilo = { nombre = L["Sigilo"], ids = { 8676, 703, 1833, 6770, 921, 1725, 2983, 1784, 53, 1752, 14183 } },
	},
}
local POR_OFFSET = {
	DRUID = { "felino", "acecho", "oso", "lechucico" },
	WARRIOR = { "batalla", "defensa", "rabia" },
	ROGUE = { "sigilo" },
}
M.FORMAS = FORMAS

local function clase()
	local _, c = llamar(UnitClass, "player")
	return type(c) == "string" and c or nil
end

-- ¿Tu clase cambia de barra con sus formas? (la página de ajustes lo pregunta)
function M.ClaseConFormas()
	return FORMAS[clase() or ""] ~= nil
end

---------------------------------------------------------------------------
-- La página de la forma y si está vacía
---------------------------------------------------------------------------
local POR_PAGINA = 12

local function offset()
	local CA = C_ActionBar
	local v = llamar(CA and CA.GetBonusBarOffset)
	if v == nil then v = llamar(GetBonusBarOffset) end
	return tonumber(v)
end

local function hayAccion(slot)
	local CA = C_ActionBar
	if CA and type(CA.HasAction) == "function" then return llamar(CA.HasAction, slot) end
	return llamar(HasAction, slot)
end

local function sinBarraEspecial()
	local CA = C_ActionBar
	for _, k in ipairs({ "HasOverrideActionBar", "HasVehicleActionBar", "HasTempShapeshiftActionBar" }) do
		local f = (CA and CA[k]) or rawget(_G, k)
		if llamar(f) == true then return false end
	end
	if llamar(UnitHasVehicleUI, "player") == true then return false end
	return true
end

-- La forma de ahora: -> clave, página (o nil si la barra no está en una forma).
local function actual()
	local c = clase()
	local t = c and POR_OFFSET[c]
	if not t then return nil end
	local off = offset()
	local clave = off and t[off]
	if not clave or not sinBarraEspecial() then return nil end
	local pagina = (tonumber(rawget(_G, "NUM_ACTIONBAR_PAGES")) or 6) + off
	-- Lo que muestra de verdad tu barra: si la cambiaste de página a mano
	-- (Mayús+rueda), ya no es la de la forma.
	local b = rawget(_G, "ActionButton1")
	local accion = type(b) == "table" and tonumber(M.Legible(rawget(b, "action")))
	if accion and ceil(accion / POR_PAGINA) ~= pagina then return nil end
	return clave, pagina
end

-- -> true (vacía), false (tiene algo) o nil (no se pudo leer)
local function vacia(pagina)
	local base = (pagina - 1) * POR_PAGINA
	for i = 1, POR_PAGINA do
		local si = hayAccion(base + i)
		if si == nil then return nil end
		if si then return false end
	end
	return true
end

---------------------------------------------------------------------------
-- Llenar las casillas vacías
---------------------------------------------------------------------------
local function nombreDe(id)
	local S = C_Spell
	local n = llamar(S and S.GetSpellName, id)
	if type(n) ~= "string" or n == "" then n = llamar(GetSpellInfo, id) end
	return type(n) == "string" and n ~= "" and n or nil
end

local function sabe(id)
	local C = A.Compat
	if C and C.IsSpellKnown and llamar(C.IsSpellKnown, id) then return true end
	if C and C.IsPlayerSpell and llamar(C.IsPlayerSpell, id) then return true end
	return llamar(IsPlayerSpell, id) == true
end

-- El rango más alto que sabes de esa habilidad, o nil.
local function mejorRango(id, libro)
	local n = nombreDe(id)
	local b = n and libro[n]
	if type(b) == "table" and tonumber(b.id) then return tonumber(b.id), n end
	if sabe(id) then return id, n end
	return nil
end

local function libroDeHechizos()
	local Q = A.QoL and A.QoL.Spells
	if Q and type(Q.BookBest) == "function" then
		local ok, t = pcall(Q.BookBest)
		if ok and type(t) == "table" then return t end
	end
	return {}
end

local function alzar(id)
	local S = C_Spell
	local f = (S and type(S.PickupSpell) == "function" and S.PickupSpell) or rawget(_G, "PickupSpell")
	if type(f) ~= "function" then return false end
	return pcall(f, id)
end

local function soltarCursor()
	if type(ClearCursor) == "function" then pcall(ClearCursor) end
end

local esperando -- una forma que se llena al salir de combate: { clave, pagina }

-- -> cuántas habilidades puso (nil si no se pudo ahora)
local function llenar(clave, pagina)
	local c = clase()
	local forma = c and FORMAS[c] and FORMAS[c][clave]
	if not (forma and pagina) then return nil end
	if enCombate() then
		if not esperando then
			N.Imprimir(L["Tu barra se llena al salir de combate."])
			N.FueraDeCombate(function()
				local e = esperando
				esperando = nil
				if e then llenar(e.clave, e.pagina) end
			end)
		end
		esperando = { clave = clave, pagina = pagina }
		return nil
	end
	if type(PlaceAction) ~= "function" then return nil end
	if type(GetCursorInfo) == "function" and llamar(GetCursorInfo) ~= nil then
		N.Imprimir(L["Suelta lo que tienes en el cursor y vuelve a intentarlo."])
		return nil
	end
	local base = (pagina - 1) * POR_PAGINA
	-- Lo que ya está en esa página (por nombre: cualquier rango cuenta).
	local puestas, libres = {}, {}
	for i = 1, POR_PAGINA do
		local slot = base + i
		local si = hayAccion(slot)
		if si == nil then return nil end
		if si then
			local tipo, id = llamar(GetActionInfo, slot)
			if tipo == "spell" and tonumber(id) then
				local n = nombreDe(tonumber(id))
				if n then puestas[n] = true end
			end
		else
			libres[#libres + 1] = slot
		end
	end
	local libro = libroDeHechizos()
	local n, k = 0, 1
	for _, id in ipairs(forma.ids) do
		local slot = libres[k]
		if not slot then break end
		local mejor, nombre = mejorRango(id, libro)
		if mejor and not (nombre and puestas[nombre]) then
			if alzar(mejor) then
				pcall(PlaceAction, slot)
				soltarCursor()
				if hayAccion(slot) then
					n, k = n + 1, k + 1
					if nombre then puestas[nombre] = true end
				end
			end
		end
	end
	soltarCursor()
	if n == 0 then
		N.Imprimir(format(L["No encontré habilidades de %s que ya sepas. Arrástralas desde tu libro de hechizos con la forma puesta."], forma.nombre))
	elseif n == 1 then
		N.Imprimir(format(L["Listo: 1 habilidad nueva en tu barra de %s."], forma.nombre))
	else
		N.Imprimir(format(L["Listo: %d habilidades nuevas en tu barra de %s."], n, forma.nombre))
	end
	return n
end

---------------------------------------------------------------------------
-- El aviso (una vez por forma y personaje, fuera de combate)
---------------------------------------------------------------------------
local function avisadas()
	local d = N.DatosPersonaje(ID)
	if type(d.formasAvisadas) ~= "table" then d.formasAvisadas = {} end
	return d.formasAvisadas
end

local revisar
local enCola = false

revisar = function()
	if not activo() then return end
	if enCombate() then
		-- Al pelear no sale nada: se mira otra vez al terminar.
		if not enCola then
			enCola = true
			N.FueraDeCombate(function() enCola = false revisar() end)
		end
		return
	end
	local clave, pagina = actual()
	if not clave then return end
	local vistas = avisadas()
	if vistas[clave] or vacia(pagina) ~= true then return end
	local c = clase()
	local forma = FORMAS[c][clave]
	local Kit = N.Kit
	if not (Kit and Kit.Aviso) then return end
	vistas[clave] = true
	Kit.Aviso({
		titulo = format(L["Tu barra de %s está vacía"], forma.nombre),
		texto = L["Al cambiar de forma, el juego cambia tu barra de abajo por la de esa forma, y esta todavía no tiene nada: por eso parece que desaparece. Alfa puede poner en sus casillas vacías las habilidades de esa forma que ya sabes."],
		icono = "ic-rejilla", tono = "acento", duracion = 25,
		accion = { texto = L["Llenar mi barra"], alClic = function() M.Seguro(llenar, clave, pagina) end },
	})
end

local pendiente = false
local function pronto(seg)
	if pendiente or not activo() or not M.ClaseConFormas() then return end
	pendiente = true
	A.After(seg or 0.4, function()
		pendiente = false
		M.Seguro(revisar)
	end)
end

for _, ev in ipairs({ "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_PAGE_CHANGED" }) do
	A.RegisterEvent(ev, function() pronto(0.4) end)
end
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() pronto(3) end)
M.AlCambiar({ "barraForma" }, function() if activo() then pronto(0.4) end end)

-- Para pruebas.
M.Formas = { Actual = actual, Vacia = vacia, Llenar = llenar, Revisar = function() return revisar() end, Avisadas = avisadas }
