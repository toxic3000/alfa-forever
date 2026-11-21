-- Alfa - Curación: el mapa del ratón (toxic3000 / La Jauría). GPL-3.0.
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
--   * 1.3.0, «Curar y seleccionar» (por personaje, prendido de fábrica): un
--     hechizo va como macro "/target <unidad>\n/cast [@<unidad>] <Hechizo>"
--     (cura Y lo deja seleccionado para tus otros poderes). La venda igual,
--     con "/use [@<unidad>] item:<id>". El texto se rehace en el entorno
--     seguro con la unidad nueva (REFRESCO), con "alfa-cmd-" y "alfa-arg-".
--     1.3.1: apagado, la venda va como "type" = "item", "item" = "item:<id>"
--     (el juego la usa sobre la unidad del botón) y no te cambia el objetivo.
-- La cabecera copia los mismos atributos a cualquier botón nuevo
-- (_initialAttributeNames), aunque se cree en combate.
--
-- Clic para lanzar de Blizzard (C_ClickBindings): sus atajos de hechizo
-- mandan sobre cualquier botón de unidad seguro, también los de Alfa. "Usar
-- también en los marcos de Blizzard" abre su ventana para que armes ahí los
-- mismos clics (C_ClickBindings.SetProfileByInfo es restringida).

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
				local m = "/target " .. u
				local cmd = self:GetAttribute("alfa-cmd-" .. p .. s)
				local arg = self:GetAttribute("alfa-arg-" .. p .. s)
				if cmd and arg then m = m .. "\n" .. cmd .. " [@" .. u .. "] " .. arg end
				self:SetAttribute(p .. "macrotext" .. s, m)
			else
				self:SetAttribute(p .. "macrotext" .. s, nil)
			end
		end
	end
]]
M.REFRESCO = REFRESCO

-- El mismo texto que arma REFRESCO, desde Lua (para los botones fuera de combate).
function M.Macro(unidad, cmd, arg)
	local m = "/target " .. unidad
	if cmd and arg then m = m .. "\n" .. cmd .. " [@" .. unidad .. "] " .. arg end
	return m
end

-- «Curar y seleccionar»: por personaje, prendido si nunca lo tocaste.
function M.CurarSelecciona() return M.Datos().curarSel ~= false end
function M.FijarCurarSelecciona(si)
	M.Datos().curarSel = si and true or false
	M.AplicarMapa()
end

-- Tu venda para los clics (se busca fuera de combate, al cambiar tus bolsas).
M.venda = nil
local TOPE_ARG = 200 -- la macro entera no pasa de 255 letras

-- -> lista { { nombre, valor }, ... } de los atributos de clic, para una unidad.
local function atributos(unidad)
	local mapa = M.Mapa()
	local t, objetivos = {}, {}
	for _, r in ipairs(M.RANURAS) do
		local p, s = M.Partes(r)
		local e = mapa[r]
		local tipo, hechizo, macro, cmd, arg, objeto
		local sel = M.CurarSelecciona()
		if type(e) == "table" then
			if e.t == "spell" then
				local n = M.NombreHechizo(e.id)
				if n and sel and #n <= TOPE_ARG then
					tipo, cmd, arg = "macro", "/cast", n
				elseif n then
					tipo, hechizo = "spell", n
				end
			elseif e.t == "venda" then
				if sel then
					tipo, cmd = "macro", "/use"
					if M.venda then arg = "item:" .. M.venda end
				elseif M.venda then
					-- 1.3.1: sin «Curar y seleccionar», solo la venda sobre ese
					-- compañero (el tipo "item" la usa en la unidad del botón), sin /target.
					tipo, objeto = "item", "item:" .. M.venda
				end
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
		if cmd then
			objetivos[#objetivos + 1] = p .. ":" .. s
			if type(unidad) == "string" then macro = M.Macro(unidad, cmd, arg) end
		end
		t[#t + 1] = { p .. "type" .. s, tipo }
		t[#t + 1] = { p .. "spell" .. s, hechizo }
		t[#t + 1] = { p .. "item" .. s, objeto }
		t[#t + 1] = { p .. "macrotext" .. s, macro }
		t[#t + 1] = { "alfa-cmd-" .. p .. s, arg and cmd or nil }
		t[#t + 1] = { "alfa-arg-" .. p .. s, arg }
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
		for _, h in ipairs(M.cabeceras or {}) do M.AplicarACabecera(h) end
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
	if entrada.t == "venda" and not M.EnCombate() then M.venda = M.MejorVenda() end
	local e = { t = entrada.t, id = entrada.id, k = entrada.id and M.ClaveDe(entrada.id) or nil }
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
		N.Imprimir(string.format(L["Preajuste «%s» listo para tus clics."], M.NombrePreajuste(pre)))
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
	if not M.EnCombate() then M.venda = M.MejorVenda() end
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

-- Un diálogo del Kit a la vista o esperando a que termine el combate.
local function dialogoAbierto()
	local K = N.Kit
	if K and K.DialogoAbierto then return K.DialogoAbierto() and true or false end
	local velo = rawget(_G, "AlfaKitVelo")
	return type(velo) == "table" and velo.IsShown and velo:IsShown() and true or false
end

local ofrecidas = {} -- 1.3.7: lo ya ofrecido en la sesión (un aviso que se fue no vuelve con cada cambio del libro)
local function ofrecer(lista)
	local K = N.Kit
	local nuevas = {}
	for _, o in ipairs(lista) do if not ofrecidas[o.clave] then nuevas[#nuevas + 1] = o end end
	if #nuevas == 0 then return end
	lista = nuevas
	for _, o in ipairs(lista) do ofrecidas[o.clave] = true end
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
	local texto = table.concat(lineas, "\n")
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
	if not (K and K.Aviso) then return rechazar() end
	-- 1.3.7: un solo aviso con «Usarlo / Ahora no» (antes, un aviso y además un
	-- diálogo con velo que tapaba la pantalla al subir de nivel). Espera a que
	-- termine la animación del juego (K.Aviso, Momentos.lua). Si se va sin
	-- respuesta, se vuelve a ofrecer la próxima vez que cambie tu libro.
	K.Aviso({ titulo = L["Hechizo nuevo para tus clics de Curación"], icono = "ic-curacion", texto = texto,
		duracion = 20, lya = false, importante = true, id = "curacion.mejoras",
		acciones = { { texto = L["Usarlo"], alClic = usar }, { texto = L["Ahora no"], alClic = rechazar } } })
end

function M.RevisarMejoras()
	if esperando then return end
	local lista = ofertas()
	if #lista == 0 then return end
	-- 1.3.3: al entrar no se ofrece: espera a que termine la entrada o la primera pelea.
	if M.Entrando() then
		M.TrasEntrar("mejoras", M.ProgramarRevision)
		return
	end
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

-- La ventana de clic para lanzar de Blizzard. Alfa nunca la abre desde su
-- código: al abrirse, abre también el libro de hechizos, y el juego lo
-- marcaría como tocado por un addon (después bloquearía lanzar desde él). El
-- botón de la página la abre con un botón seguro (K.Seguro) que corre el
-- comando del juego, como si lo escribieras tú.
function M.SeguroBlizzard() return N.Kit.AbrirJuego("clicLanzar") end

local function guardarBlizzard(ok, texto)
	local d = M.Datos()
	d.blizzard = { ok = ok, texto = texto }
	M.Avisar()
	return ok, texto
end

-- Después del clic seguro: el comando del juego abre o cierra su ventana
-- (es un interruptor). Solo se lee si quedó a la vista; nada se toca.
function M.TrasAbrirBlizzard()
	local f = rawget(_G, "ClickBindingFrame")
	if type(f) == "table" and f.IsShown and not f:IsShown() then
		return guardarBlizzard(false, L["Se cerró la ventana de clic para lanzar de Blizzard. Vuelve a pulsar «Abrir clic para lanzar» para abrirla."])
	end
	return guardarBlizzard(false, L["Blizzard no deja que un addon copie tu mapa. Se abrió su ventana de clic para lanzar: arma ahí los mismos clics."])
end

-- -> true | false, y un texto para la página (el clic normal: en combate,
-- con teclado o mando, o con /alfa curacion blizzard).
-- C_ClickBindings.SetProfileByInfo es restringida (HasRestrictions): un addon
-- no puede escribir el perfil de Blizzard.
function M.UsarEnBlizzard()
	if enCombate() then return guardarBlizzard(false, L["Sal de combate y vuelve a intentarlo."]) end
	if type(rawget(_G, "ToggleClickBindingFrame")) ~= "function" then
		return guardarBlizzard(false, L["Este cliente no tiene el clic para lanzar de Blizzard. Tus clics funcionan en los marcos de Alfa."])
	end
	local cmd = rawget(_G, "SLASH_CLICKCASTING1")
	if type(cmd) == "string" and cmd ~= "" then
		return guardarBlizzard(false, string.format(L["Blizzard no deja que un addon copie tu mapa. Abre su ventana con el botón «Abrir clic para lanzar» o escribe %s en el chat, y arma ahí los mismos clics."], cmd))
	end
	return guardarBlizzard(false, L["Blizzard no deja que un addon copie tu mapa. Ábrelo en el menú del juego: Opciones, Clic para lanzar."])
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", function() M.ProgramarRevision() end)

-- Tu venda: si cambia la mejor que llevas, los clics se rehacen (fuera de combate).
function M.RevisarVenda()
	local v = M.MejorVenda()
	if v == M.venda then return false end
	M.venda = v
	local usa = false
	for _, e in pairs(M.Mapa()) do if type(e) == "table" and e.t == "venda" then usa = true break end end
	if usa then M.AplicarMapa() end
	return true
end
-- 1.3.7: subir Primeros auxilios puede abrir una venda mejor.
A.RegisterEvent("SKILL_LINES_CHANGED", function()
	N.FueraDeCombate("curacion.vendaNivel", function() M.RevisarVenda() end)
end)

-- 1.3.7: un clic de venda sin venda que puedas usar te lo dice (una vez cada
-- 30 s). Va enganchado después del clic (HookScript): no atrapa nada.
local BOTON = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }
local ultimoSinVenda = -999
function M.RanuraDelClic(boton)
	local s = BOTON[boton or ""]
	if not s then return nil end
	local p = ""
	if IsShiftKeyDown and IsShiftKeyDown() then p = "shift-"
	elseif IsControlKeyDown and IsControlKeyDown() then p = "ctrl-"
	elseif IsAltKeyDown and IsAltKeyDown() then p = "alt-" end
	return p .. s
end
function M.AlClic(_, boton)
	if M.venda then return end
	local r = M.RanuraDelClic(boton)
	local e = r and M.Mapa()[r]
	if not (type(e) == "table" and e.t == "venda") then return end
	local ahora = GetTime and GetTime() or 0
	if ahora - ultimoSinVenda < 30 then return end
	ultimoSinVenda = ahora
	N.Imprimir(M.LlevasVendas() and L["Tus vendas piden más Primeros auxilios del que tienes: sube tu oficio o lleva vendas más sencillas."]
		or L["No llevas vendas en las bolsas: el clic de venda no hace nada hasta que tengas una."])
	return true
end

local vendaPendiente = false
A.RegisterEvent("BAG_UPDATE_DELAYED", function()
	if vendaPendiente then return end
	vendaPendiente = true
	N.FueraDeCombate("curacion.venda", function()
		vendaPendiente = false
		M.RevisarVenda()
	end)
end)
A.RegisterEvent("PLAYER_LEVEL_UP", (N.TrasNivel or function(_, f) return f end)("curacion.revision", function() M.ProgramarRevision() end)) -- 1.3.7
A.RegisterEvent("SPELLS_CHANGED", function()
	if M.listo then M.ProgramarRevision() else M.Inicial() end
	M.Avisar()
end)
