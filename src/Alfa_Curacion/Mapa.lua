-- Alfa - Curación: el mapa del ratón (Toxic / La Jauría). GPL-3.0.
--
-- Cada ranura (botón del ratón con o sin Mayús, Ctrl o Alt) hace una cosa
-- sobre el compañero que tienes bajo el ratón: un hechizo, seleccionarlo o
-- abrir su menú. Se guarda por personaje en AlfaNucleoCharDB.curacion.
--
-- Cómo llega a los botones (siempre fuera de combate, N.FueraDeCombate):
--   * Hechizo: "type1" = "spell", "spell1" = nombre del hechizo en tu idioma.
--   * Seleccionar: en el izquierdo o el derecho sin tecla, "type" = "target".
--     En las demás ranuras el juego lo ignora (SecureUnitButton_OnClick de
--     Forever exige ahí un clic de interacción de C_ClickBindings), así que va
--     como macro "/target <unidad>"; la unidad la pone el propio marco seguro
--     al cambiar de jugador (atributo refreshUnitChange), también en combate.
--   * Menú: "togglemenu", solo en el izquierdo o el derecho sin tecla.
-- La cabecera copia los mismos atributos a cualquier botón nuevo
-- (_initialAttributeNames), aunque se cree en combate.
--
-- Clic para lanzar de Blizzard (C_ClickBindings): sus atajos de hechizo
-- mandan sobre cualquier botón de unidad seguro, también los de Alfa. "Usar
-- también en los marcos de Blizzard" intenta copiar tu mapa a su perfil con
-- C_ClickBindings.SetProfileByInfo y, si no se puede, abre su ventana.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID
local secreto = M.Secreto

function M.Datos() return N.DatosPersonaje(ID) end

function M.Mapa()
	local d = M.Datos()
	if type(d.mapa) ~= "table" then d.mapa = {} end
	return d.mapa
end

-- La página se rehace cuando algo cambia (Pagina.lua pone M.alCambiar).
local avisoPendiente = false
function M.Avisar()
	if avisoPendiente or not M.alCambiar then return end
	avisoPendiente = true
	A.After(0.05, function()
		avisoPendiente = false
		if M.alCambiar then M.alCambiar() end
	end)
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
M.EnCombate = enCombate

---------------------------------------------------------------------------
-- Atributos seguros
---------------------------------------------------------------------------

-- Se ejecuta dentro del marco seguro (entorno restringido) cada vez que la
-- cabecera le da una unidad: rehace las macros de "seleccionar".
local REFRESCO = [[
	local u = self:GetAttribute("unit")
	local lista = self:GetAttribute("alfa-objetivos")
	if lista then
		for p, s in gmatch(lista, "(%S-):(%d)") do
			if u then
				self:SetAttribute(p .. "macrotext" .. s, "/target " .. u)
			else
				self:SetAttribute(p .. "macrotext" .. s, nil)
			end
		end
	end
]]
M.REFRESCO = REFRESCO

-- -> lista { { nombre, valor }, ... } de los atributos de clic, para una unidad.
local function atributos(unidad)
	local mapa = M.Mapa()
	local t, objetivos = {}, {}
	for _, r in ipairs(M.RANURAS) do
		local p, s = M.Partes(r)
		local e = mapa[r]
		local tipo, hechizo, macro
		if type(e) == "table" then
			if e.t == "spell" then
				local n = M.NombreHechizo(e.id)
				if n then tipo, hechizo = "spell", n end
			elseif e.t == "target" then
				if p == "" and (s == "1" or s == "2") then
					tipo = "target"
				else
					tipo = "macro"
					objetivos[#objetivos + 1] = p .. ":" .. s
					if type(unidad) == "string" then macro = "/target " .. unidad end
				end
			elseif e.t == "menu" and M.PermiteMenu(r) then
				tipo = "togglemenu"
			end
		end
		t[#t + 1] = { p .. "type" .. s, tipo }
		t[#t + 1] = { p .. "spell" .. s, hechizo }
		t[#t + 1] = { p .. "macrotext" .. s, macro }
	end
	t[#t + 1] = { "alfa-objetivos", #objetivos > 0 and table.concat(objetivos, " ") or nil }
	t[#t + 1] = { "refreshUnitChange", REFRESCO }
	return t
end

-- Los atributos de un botón seguro. Solo fuera de combate.
function M.AplicarABoton(b)
	if enCombate() or not b then return false end
	local okU, unidad = pcall(b.GetAttribute, b, "unit")
	local lista = atributos(okU and unidad or nil)
	for i = 1, #lista do b:SetAttribute(lista[i][1], lista[i][2]) end
	return true
end

-- Los mismos atributos en la cabecera, para los botones que cree después.
function M.AplicarACabecera(h)
	if enCombate() or not h then return false end
	local lista = atributos(nil)
	local nombres = {}
	-- Sin que la cabecera se rehaga con cada atributo (no cambian su forma).
	local antes = h:GetAttribute("_ignore")
	h:SetAttribute("_ignore", "alfa")
	for i = 1, #lista do
		local nombre = lista[i][1]
		nombres[#nombres + 1] = nombre
		h:SetAttribute("_initialAttribute-" .. nombre, lista[i][2])
	end
	h:SetAttribute("_initialAttributeNames", table.concat(nombres, ","))
	h:SetAttribute("_ignore", antes)
	return true
end

local avisoCombate = false
function M.AplicarMapa()
	M.Avisar()
	if avisoCombate then return end -- ya espera al final del combate
	if enCombate() then
		avisoCombate = true
		N.Imprimir(L["Tus clics de Curación se aplican al salir de combate."])
	end
	N.FueraDeCombate(function()
		avisoCombate = false
		for _, b in ipairs(M.botones) do M.AplicarABoton(b) end
		if M.cabecera then M.AplicarACabecera(M.cabecera) end
		M.Avisar()
	end)
end

---------------------------------------------------------------------------
-- Cambiar el mapa
---------------------------------------------------------------------------

-- entry: { t = "spell", id } | { t = "target" } | { t = "menu" } | { t = "nada" }
function M.FijarRanura(ranura, entrada)
	local mapa = M.Mapa()
	if type(entrada) ~= "table" then return end
	local e = { t = entrada.t, id = entrada.id }
	mapa[ranura] = e
	M.AplicarMapa()
end

function M.AplicarPreajuste(pre, callado)
	local d = M.Datos()
	pre = M.PREAJUSTES[pre] and pre or M.Recomendado()
	d.preajuste = pre
	d.mapa = M.Resolver(pre, d.izqSel == true)
	d.rechazos = {}
	M.AplicarMapa()
	if not callado then
		N.Imprimir(string.format(L["Preajuste «%s» listo para tus clics."], M.PREAJUSTES[pre].nombre))
	end
end

function M.IzquierdoSelecciona() return M.Datos().izqSel == true end

-- El clic izquierdo solo selecciona: se vuelve a aplicar tu preajuste.
function M.FijarIzquierdoSelecciona(si)
	local d = M.Datos()
	d.izqSel = si and true or false
	M.AplicarPreajuste(d.preajuste or M.Recomendado(), true)
end

-- Primera vez con este personaje: el preajuste de su clase, listo para usar.
-- Si el libro de hechizos todavía no cargó (un curandero sin ninguna cura),
-- se espera al siguiente SPELLS_CHANGED; a la tercera se aplica igual.
local intentos = 0
function M.Inicial()
	local d = M.Datos()
	if type(d.mapa) == "table" and d.preajuste then
		M.listo = true
		return true
	end
	if not M.Clase() then return false end
	local pre = M.Recomendado()
	local hay = false
	for _, e in pairs(M.Resolver(pre, d.izqSel == true)) do
		if e.t == "spell" then hay = true break end
	end
	intentos = intentos + 1
	if pre == "curar" and not hay and intentos < 3 then return false end
	M.AplicarPreajuste(pre, true)
	M.listo = true
	return true
end

---------------------------------------------------------------------------
-- Hechizo nuevo: ofrecerlo, nunca cambiarlo solo
---------------------------------------------------------------------------

local programada, esperando = false, false

-- -> { { ranura, nuevo, antes, clave }, ... }
local function ofertas()
	local d = M.Datos()
	local pre = d.preajuste
	if not pre or type(d.mapa) ~= "table" then return {} end
	local nuevo = M.Resolver(pre, d.izqSel == true)
	local fuente = M.Candidatos(pre, d.izqSel == true)
	local rech = type(d.rechazos) == "table" and d.rechazos or {}
	local t = {}
	for _, r in ipairs(M.RANURAS) do
		local n, a = nuevo[r], d.mapa[r]
		if n and n.t == "spell" then
			local libre = a == nil
			-- Solo si de verdad es mejor: va antes en la lista de la ranura, o
			-- el que tenías ya no está en tu libro.
			local delPreajuste = false
			if type(a) == "table" and a.p == true and a.t == "spell" and a.k ~= n.k then
				local ln, la = M.Lugar(fuente, r, n.k), M.Lugar(fuente, r, a.k)
				delPreajuste = (ln ~= nil and la ~= nil and ln < la) or (la == nil) or M.Conocido(a.k) == nil
			end
			local clave = r .. "=" .. tostring(n.k)
			if (libre or delPreajuste) and not rech[clave] then
				t[#t + 1] = { ranura = r, nuevo = n, antes = a, clave = clave }
			end
		end
	end
	return t
end

local function dialogoAbierto()
	local velo = rawget(_G, "AlfaKitVelo")
	return type(velo) == "table" and velo.IsShown and velo:IsShown() and true or false
end

local function ofrecer(lista)
	local K = N.Kit
	local lineas = {}
	for _, o in ipairs(lista) do
		local nombre = M.NombreHechizo(o.nuevo.id) or "?"
		local antes = o.antes and o.antes.t == "spell" and M.NombreHechizo(o.antes.id)
		if antes then
			lineas[#lineas + 1] = string.format(L["%s: %s (antes %s)"], M.NombreRanura(o.ranura), nombre, antes)
		else
			lineas[#lineas + 1] = string.format(L["%s: %s"], M.NombreRanura(o.ranura), nombre)
		end
	end
	local texto = L["Aprendiste un hechizo que le queda mejor a tus clics:"] .. "\n" .. table.concat(lineas, "\n")
	N.Imprimir(L["Hechizo nuevo para tus clics de Curación. Ábrelo en /alfa curacion."])
	local function usar()
		local d = M.Datos()
		local mapa = M.Mapa()
		for _, o in ipairs(lista) do mapa[o.ranura] = o.nuevo end
		d.rechazos = d.rechazos or {}
		M.AplicarMapa()
	end
	local function rechazar()
		local d = M.Datos()
		d.rechazos = type(d.rechazos) == "table" and d.rechazos or {}
		for _, o in ipairs(lista) do d.rechazos[o.clave] = true end
	end
	if not (K and K.Dialogo) then return rechazar() end
	K.Dialogo({
		titulo = L["¿Usar tu hechizo nuevo?"], icono = "ic-curacion", texto = texto,
		aceptar = L["Usarlo"], cancelar = L["Ahora no"],
		alAceptar = usar, alCancelar = rechazar,
	})
end

function M.RevisarMejoras()
	if esperando then return end
	local lista = ofertas()
	if #lista == 0 then return end
	if enCombate() or dialogoAbierto() then
		esperando = true
		local function luego()
			esperando = false
			M.ProgramarRevision()
		end
		if enCombate() then N.FueraDeCombate(luego) else A.After(10, luego) end
		return
	end
	ofrecer(lista)
end

function M.ProgramarRevision()
	if programada then return end
	programada = true
	A.After(2, function()
		programada = false
		M.RevisarMejoras()
	end)
end

---------------------------------------------------------------------------
-- Clic para lanzar de Blizzard (C_ClickBindings)
---------------------------------------------------------------------------

-- Los bits de Mayús, Ctrl y Alt de C_ClickBindings, sacados del propio juego
-- (GetStringFromModifiers): Forever no los documenta. -> { shift, ctrl, alt } o nil.
local bitsCache
local function bitsModificadores()
	if bitsCache ~= nil then return bitsCache or nil end
	bitsCache = false
	if type(GetStringFromModifiers) ~= "function" then return nil end
	local buscar = {
		shift = { "SHIFT", rawget(_G, "SHIFT_KEY_TEXT") },
		ctrl = { "CTRL", rawget(_G, "CTRL_KEY_TEXT") },
		alt = { "ALT", rawget(_G, "ALT_KEY_TEXT") },
	}
	local hallado, b = {}, 1
	for _ = 1, 16 do
		local ok, s = pcall(GetStringFromModifiers, b)
		if ok and not secreto(s) and type(s) == "string" and s ~= "" then
			local u = s:upper():gsub("%-$", "")
			for clave, palabras in pairs(buscar) do
				for _, w in ipairs(palabras) do
					if type(w) == "string" and w ~= "" and u:find(w:upper(), 1, true) then
						local exacto = (u == w:upper())
						local h = hallado[clave]
						if not h or (exacto and not h.exacto) then hallado[clave] = { b = b, exacto = exacto } end
					end
				end
			end
		end
		b = b * 2
	end
	local sh, ct, al = hallado.shift, hallado.ctrl, hallado.alt
	if sh and ct and al and sh.b ~= ct.b and sh.b ~= al.b and ct.b ~= al.b then
		bitsCache = { [""] = 0, ["shift-"] = sh.b, ["ctrl-"] = ct.b, ["alt-"] = al.b }
	end
	return bitsCache or nil
end

local BOTON_BLIZZARD = {}
for _, bt in ipairs(M.BOTONES) do BOTON_BLIZZARD[bt.s] = bt.blizzard end

-- El spellID base del libro (el que guarda C_ClickBindings).
local function idBase(id)
	local B = C_SpellBook
	if not (B and B.FindSpellBookSlotForSpell and B.GetSpellBookItemInfo) then return id end
	local ok, ranura = pcall(B.FindSpellBookSlotForSpell, id)
	if not (ok and not secreto(ranura) and type(ranura) == "number") then
		local nombre = M.NombreHechizo(id)
		if nombre then ok, ranura = pcall(B.FindSpellBookSlotForSpell, nombre) end
	end
	if ok and not secreto(ranura) and type(ranura) == "number" then
		local banco = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		local ok2, info = pcall(B.GetSpellBookItemInfo, ranura, banco)
		if ok2 and type(info) == "table" and type(info.actionID) == "number" then return info.actionID end
	end
	return id
end

local function tiposClick()
	local E = Enum and Enum.ClickBindingType
	local I = Enum and Enum.ClickBindingInteraction
	if not (E and I) then return nil end
	return E, I
end

-- Tus atajos de hechizo de Blizzard que caen en una ranura de tu mapa (esos
-- mandan sobre los marcos de Alfa). -> número
function M.ChoquesBlizzard()
	local C = C_ClickBindings
	local bits = bitsModificadores()
	local E = tiposClick()
	if not (C and C.GetProfileInfo and bits and E) then return 0 end
	local ok, perfil = pcall(C.GetProfileInfo)
	if not ok or type(perfil) ~= "table" then return 0 end
	local mapa, n = M.Mapa(), 0
	for i = 1, #perfil do
		local e = perfil[i]
		if type(e) == "table" and (e.type == E.Spell or e.type == E.Macro) then
			for _, r in ipairs(M.RANURAS) do
				local p, s = M.Partes(r)
				local mia = mapa[r]
				if e.button == BOTON_BLIZZARD[s] and e.modifiers == bits[p] then
					local mismo = type(mia) == "table" and mia.t == "spell" and e.type == E.Spell
						and e.actionID == idBase(mia.id)
					if not mismo then n = n + 1 end
				end
			end
		end
	end
	return n
end

local function abrirVentanaBlizzard()
	if enCombate() then return false end
	if A.GamepadUI and A.GamepadUI() then return false end
	local abrir = rawget(_G, "ToggleClickBindingFrame")
	if type(abrir) ~= "function" then return false end
	local visible = rawget(_G, "ClickBindingFrame")
	if type(visible) == "table" and visible.IsShown and visible:IsShown() then return true end
	return pcall(abrir) == true
end
M.AbrirVentanaBlizzard = abrirVentanaBlizzard

-- -> true | false, y un texto para la página.
function M.UsarEnBlizzard()
	local d = M.Datos()
	local function fin(ok, texto)
		d.blizzard = { ok = ok, texto = texto }
		M.Avisar()
		return ok, texto
	end
	if enCombate() then return fin(false, L["Sal de combate y vuelve a intentarlo."]) end
	local C = C_ClickBindings
	local E, I = tiposClick()
	local bits = bitsModificadores()
	if not (C and C.SetProfileByInfo and C.GetProfileInfo and E and I and bits) then
		if abrirVentanaBlizzard() then
			return fin(false, L["Este cliente no deja copiar tu mapa solo: se abrió la ventana de clic para lanzar de Blizzard para que lo armes ahí."])
		end
		return fin(false, L["Este cliente no tiene el clic para lanzar de Blizzard. Tus clics funcionan en los marcos de Alfa."])
	end
	-- Lo tuyo, ranura por ranura. Tus 12 clics quedan en Blizzard igual que
	-- en tu mapa, también los que dejaste sin acción; los demás (otros botones
	-- del ratón, otras combinaciones) no se tocan.
	local mapa = M.Mapa()
	local mio, ocupado, inter, saltados = {}, {}, {}, 0
	for _, r in ipairs(M.RANURAS) do
		local p, s = M.Partes(r)
		local e = mapa[r]
		local boton, mods = BOTON_BLIZZARD[s], bits[p]
		ocupado[boton .. ":" .. mods] = true
		local nueva
		if type(e) == "table" and e.t == "spell" then
			local base = idBase(e.id)
			local puede = true
			if C.CanSpellBeClickBound then
				local okP, si = pcall(C.CanSpellBeClickBound, base)
				puede = okP and not secreto(si) and si == true
			end
			if puede then
				nueva = { type = E.Spell, actionID = base, button = boton, modifiers = mods }
			else
				saltados = saltados + 1
			end
		elseif type(e) == "table" and e.t == "target" and not inter[I.Target] then
			nueva = { type = E.Interaction, actionID = I.Target, button = boton, modifiers = mods }
			inter[I.Target] = true
		elseif type(e) == "table" and e.t == "menu" and M.PermiteMenu(r) and not inter[I.OpenContextMenu] then
			nueva = { type = E.Interaction, actionID = I.OpenContextMenu, button = boton, modifiers = mods }
			inter[I.OpenContextMenu] = true
		end
		if nueva then mio[#mio + 1] = nueva end
	end
	if #mio == 0 then return fin(false, L["Tu mapa del ratón está vacío: elige algo en una ranura primero."]) end
	-- Lo que ya tenías en Blizzard y no choca con lo tuyo se queda.
	local okP, actual = pcall(C.GetProfileInfo)
	local perfil = {}
	if okP and type(actual) == "table" then
		for i = 1, #actual do
			local e = actual[i]
			if type(e) == "table" and type(e.button) == "string" and type(e.modifiers) == "number" then
				local choca = ocupado[e.button .. ":" .. e.modifiers]
				if e.type == E.Interaction and inter[e.actionID] then choca = true end
				if not choca then
					perfil[#perfil + 1] = { type = e.type, actionID = e.actionID, button = e.button, modifiers = e.modifiers }
				end
			end
		end
	end
	for i = 1, #mio do perfil[#perfil + 1] = mio[i] end
	local ok = pcall(C.SetProfileByInfo, perfil)
	-- Se comprueba leyendo el perfil de vuelta.
	local bien = false
	if ok then
		local okL, leido = pcall(C.GetProfileInfo)
		if okL and type(leido) == "table" then
			bien = true
			for i = 1, #mio do
				local m, esta = mio[i], false
				for j = 1, #leido do
					local e = leido[j]
					if type(e) == "table" and e.type == m.type and e.actionID == m.actionID
						and e.button == m.button and e.modifiers == m.modifiers then
						esta = true
						break
					end
				end
				if not esta then bien = false break end
			end
		end
	end
	if bien then
		local texto = L["Listo: tu mapa también funciona en los marcos de Blizzard."]
		if saltados > 0 then
			texto = texto .. " " .. string.format(L["%d hechizo(s) no se pueden poner en el clic para lanzar."], saltados)
		end
		N.Imprimir(texto)
		return fin(true, texto)
	end
	if abrirVentanaBlizzard() then
		return fin(false, L["Blizzard no dejó copiar tu mapa desde un addon. Se abrió su ventana de clic para lanzar: arma ahí los mismos clics."])
	end
	return fin(false, L["Blizzard no dejó copiar tu mapa desde un addon. Ábrelo en el menú del juego: Opciones, Clic para lanzar."])
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", function() M.ProgramarRevision() end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() M.ProgramarRevision() end)
A.RegisterEvent("SPELLS_CHANGED", function()
	if M.listo then M.ProgramarRevision() else M.Inicial() end
	M.Avisar()
end)
