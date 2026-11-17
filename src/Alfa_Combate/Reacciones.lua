-- Alfa - Combate: avisos de reacción (toxic3000 / La Jauría). GPL-3.0.
--
-- Un aviso corto cuando una habilidad de reacción de tu clase (Datos.lua) se
-- vuelve usable: Abrumar cuando el enemigo esquiva, Revancha cuando bloqueas,
-- Ejecutar cuando le queda poca vida... Se lee con datos de tu personaje:
--   * SPELL_UPDATE_USABLE y C_Spell.IsSpellUsable (de no usable a usable),
--     sin contar la recarga larga;
--   * SPELL_ACTIVATION_OVERLAY_GLOW_SHOW, el brillo oficial del hechizo (y,
--     si lo pides, el de cualquier otra habilidad tuya).
-- Solo en combate. El aviso aparece y se va solo (una animación del cliente).
-- Sin llenar la pantalla de texto: el aviso con su título y su porqué sale a
-- lo sumo 4 veces por habilidad y personaje (M.TextoPuede), uno a la vez y
-- nunca el mismo en 30 s; después, solo el ícono que late. Su × o el clic
-- derecho lo callan para siempre ("Volver a mostrar" en Combate los enciende).

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Rc = {}
M.Reacciones = Rc

local type, ipairs, pairs, pcall, max, floor = type, ipairs, pairs, pcall, math.max, math.floor
local ESP = K.ESP
local ANCHO = 300
local CHICO = 44   -- el aviso sin texto: solo el ícono
local DUR = 2.2    -- lo que se queda a la vista
local ESPERA = 1.5 -- segundos entre dos avisos de la misma habilidad

local activas = {} -- { def, id } de las que conoces
local estaba = {}  -- clave -> estaba usable
local ultimo = {}  -- clave -> cuándo avisó

---------------------------------------------------------------------------
-- Las de tu clase
---------------------------------------------------------------------------
function Rc.Preparar()
	activas = {}
	for _, def in ipairs(M.ReaccionesDeClase()) do
		local id
		for i = #def.ids, 1, -1 do
			if M.Conoce(def.ids[i]) then id = def.ids[i] break end
		end
		if id then activas[#activas + 1] = { def = def, id = id } end
	end
end

-- -> las definiciones de tu clase, cada una con `conocida` y su id
function Rc.Lista()
	local out = {}
	for _, def in ipairs(M.ReaccionesDeClase()) do
		local x = { def = def, id = def.ids[1], conocida = false }
		for _, a in ipairs(activas) do
			if a.def == def then x.id, x.conocida = a.id, true end
		end
		out[#out + 1] = x
	end
	return out
end

function Rc.Activas() return activas end

---------------------------------------------------------------------------
-- El aviso
---------------------------------------------------------------------------
local f

local function crear()
	if f then return f end
	f = M.Marco("Aviso", L["Avisos de reacción"], ANCHO, 52, { "CENTER", "CENTER", 0, 130 })
	f.Cuerpo = CreateFrame("Frame", nil, f)
	f.Cuerpo:SetAllPoints(f)
	f.Cuerpo.caja = K.Caja(f.Cuerpo, { fondo = "fondo", alfaFondo = 0.9, borde = "acento", alfaBorde = 0.55, corte = K.CORTE.control })
	f.Cuerpo.Franja = K.Plano(f.Cuerpo, "acento", "ARTWORK", 1)
	f.Cuerpo.Franja:SetWidth(3)
	f.Cuerpo.Franja:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", 0, -K.CORTE.control - 2)
	f.Cuerpo.Franja:SetPoint("BOTTOMLEFT", f.Cuerpo, "BOTTOMLEFT", 0, K.CORTE.control + 2)
	f.Icono = f.Cuerpo:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(32, 32)
	f.Icono:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", ESP.m, -ESP.s - 2)
	f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Titulo = K.Texto(f.Cuerpo, "subtitulo", "acento")
	f.Porque = K.Texto(f.Cuerpo, "nota", "textoSuave")
	-- "No volver a mostrar": su × (el resto del aviso no recibe el ratón, para
	-- no tapar clics en el mundo).
	local function callar()
		if f.alfaClave then M.Callar(f.alfaClave) end
		f.anim:Stop()
		f:Hide()
	end
	f.Cerrar = K.BotonIcono(f.Cuerpo, "ic-cerrar", callar, { tam = 18,
		ayuda = L["No volver a mostrar"], ayudaTexto = L["Este aviso ya no mostrará texto: solo el ícono. En Combate puedes volver a encenderlos."] })
	f.Cerrar:SetPoint("TOPRIGHT", f.Cuerpo, "TOPRIGHT", -4, -4)
	-- Aparece, se queda y se va: todo con la animación del cliente.
	local ag = f.Cuerpo:CreateAnimationGroup()
	local entra = ag:CreateAnimation("Alpha")
	entra:SetFromAlpha(0)
	entra:SetToAlpha(1)
	entra:SetDuration(0.12)
	entra:SetOrder(1)
	local sale = ag:CreateAnimation("Alpha")
	sale:SetFromAlpha(1)
	sale:SetToAlpha(0)
	sale:SetStartDelay(DUR - 0.5)
	sale:SetDuration(0.35)
	sale:SetOrder(2)
	ag:SetScript("OnFinished", function()
		if M.Desbloqueado() then f.Cuerpo:SetAlpha(1) return end
		f:Hide()
	end)
	f:SetScript("OnHide", function()
		if f.alfaClave then M.TextoFin(f.alfaClave) end
	end)
	f.anim = ag
	f:Hide()
	return f
end

-- Solo el ícono, en un cuadro pequeño (cuando el texto ya salió bastante).
local function pintarChico(icono)
	f.Icono:SetTexture(icono or K.Lobo("atento"))
	if icono then f.Icono:SetVertexColor(1, 1, 1, 1) else f.Icono:SetVertexColor(K.Color("acento")) end
	f.Icono:ClearAllPoints()
	f.Icono:SetPoint("CENTER", f.Cuerpo, "CENTER", 1, 0)
	f.Titulo:Hide()
	f.Porque:Hide()
	f.Cerrar:Hide()
	f.Cuerpo.Franja:Hide()
	f:SetSize(CHICO, CHICO)
end

local function pintar(icono, titulo, porque)
	f:SetWidth(ANCHO)
	f.Titulo:Show()
	f.Cerrar:Show()
	f.Cuerpo.Franja:Show()
	f.Icono:ClearAllPoints()
	f.Icono:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", ESP.m, -ESP.s - 2)
	f.Icono:SetTexture(icono or K.Lobo("atento"))
	if icono then f.Icono:SetVertexColor(1, 1, 1, 1) else f.Icono:SetVertexColor(K.Color("acento")) end
	local x = ESP.m + 32 + ESP.m
	local tw = ANCHO - x - ESP.m - 18
	K.Escribir(f.Titulo, titulo or "")
	f.Titulo:ClearAllPoints()
	f.Titulo:SetWidth(tw)
	local conPorque = porque and porque ~= ""
	K.Escribir(f.Porque, conPorque and porque or "")
	local h = K.AltoTexto(f.Titulo)
	local hp = 0
	if conPorque then
		hp = K.Parrafo(f.Porque, tw, 2)
		f.Porque:Show()
	else
		f.Porque:Hide()
	end
	local alto = max(32 + 2 * ESP.s + 4, h + (conPorque and (2 + hp) or 0) + 2 * ESP.m)
	local y = floor((alto - (h + (conPorque and (2 + hp) or 0))) / 2)
	f.Icono:ClearAllPoints()
	f.Icono:SetPoint("LEFT", f.Cuerpo, "LEFT", ESP.m, 0)
	f.Titulo:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", x, -y)
	f.Porque:ClearAllPoints()
	f.Porque:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -2)
	f:SetHeight(alto)
end

-- r = { def = { clave, texto, porque }, id }, prueba: aunque estén apagados.
function Rc.Mostrar(r, prueba)
	if not (M.Opt("avisos") or prueba) then return end
	local clave = r.def and r.def.clave or tostring(r.id)
	local ahora = GetTime()
	if not prueba and ultimo[clave] and ahora - ultimo[clave] < ESPERA then return end
	ultimo[clave] = ahora
	crear()
	f.anim:Stop()
	local texto = "aviso:" .. clave
	if f.alfaClave and f.alfaClave ~= texto then M.TextoFin(f.alfaClave) end
	f.alfaClave = nil
	if prueba or M.TextoPuede(texto) then
		pintar(M.IconoHechizo(r.id), r.def and r.def.texto, M.Opt("avisosPorque") and r.def and r.def.porque or nil)
		if not prueba then
			f.alfaClave = texto
			M.TextoMostrado(texto, DUR)
		end
	else
		pintarChico(M.IconoHechizo(r.id))
	end
	f.Cuerpo:SetAlpha(1)
	f:Show()
	if not M.Desbloqueado() then f.anim:Play() end
	if M.Opt("avisosSonido") and SOUNDKIT and A.PlaySound then
		pcall(A.PlaySound, SOUNDKIT.MAP_PING or 3175, "SFX")
	end
end

function Rc.Probar()
	local r = activas[1]
	if not r then
		local def = M.ReaccionesDeClase()[1]
		r = def and { def = def, id = def.ids[1] }
			or { def = { clave = "prueba", texto = L["¡Así se ve un aviso!"], porque = L["Aquí sale por qué se activó la habilidad."] } }
	end
	Rc.Mostrar(r, true)
end

---------------------------------------------------------------------------
-- Vigilar
---------------------------------------------------------------------------
-- -> true (lista), false (no), nil (no se pudo leer)
local function lista(r)
	local usable = M.Legible(M.Llamar(C_Spell and C_Spell.IsSpellUsable, r.id))
	if usable == nil then return nil end
	if not usable then return false end
	local inicio, dur = A.Compat.GetSpellCooldown(r.id)
	if dur > 1.6 and inicio + dur - GetTime() > 0.25 then return false end
	return true
end

function Rc.EntrarCombate()
	for k in pairs(estaba) do estaba[k] = nil end
	for _, r in ipairs(activas) do
		local ahora = lista(r)
		-- Lo que ya estaba usable al empezar (Ejecutar sobre un enemigo herido) también avisa.
		estaba[r.def.clave] = ahora == true and false or ahora
	end
end

local pendiente = false
local function revisar()
	pendiente = false
	if not (M.Opt("avisos") and M.EnCombate()) then return end
	for _, r in ipairs(activas) do
		local ahora = lista(r)
		if ahora == true and estaba[r.def.clave] == false then Rc.Mostrar(r) end
		if ahora ~= nil then estaba[r.def.clave] = ahora end
	end
end

-- SPELL_UPDATE_USABLE llega en ráfagas: se revisa una vez por cuadro.
function Rc.Revisar()
	if pendiente or #activas == 0 then return end
	pendiente = true
	A.After(0, revisar)
end

function Rc.Brillo(id)
	if M.Secreto(id) or type(id) ~= "number" or not M.Opt("avisos") then return end
	for _, r in ipairs(activas) do
		for _, x in ipairs(r.def.ids) do
			if x == id then Rc.Mostrar(r) return end
		end
	end
	if M.Opt("avisosOtros") and M.EnCombate() and M.Conoce(id) then
		local nombre = M.NombreHechizo(id)
		if nombre then
			Rc.Mostrar({ def = { clave = "brillo" .. id, texto = (L["¡%s!"]):format(nombre),
				porque = L["El juego la hizo brillar: es buen momento para usarla."] }, id = id })
		end
	end
end

-- Mientras mueves los marcos, el aviso se queda a la vista.
function Rc.Ver()
	if M.Desbloqueado() then
		crear()
		pintar(nil, L["¡Abrumar!"], M.Opt("avisosPorque") and L["Aquí sale por qué se activó la habilidad."] or nil)
		f.Cerrar:Hide()
		f.anim:Stop()
		f.Cuerpo:SetAlpha(1)
		f:Show()
	elseif f and not f.anim:IsPlaying() then
		f:Hide()
	end
end
