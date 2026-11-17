-- Alfa - Combate (toxic3000 / La Jauría). GPL-3.0.
--
-- Ayudas de combate que solo muestran: nada aquí aprieta, elige objetivo ni
-- decide por el jugador (docs/ARQUITECTURA.md, reglas de Forever).
--   * Rotación (Rotacion.lua): la siguiente habilidad de la ayuda oficial de
--     Blizzard (C_AssistedCombat) y las que siguen, en un ícono compacto y
--     movible; opcionalmente, el botón de tu barra resaltado.
--   * Avisos de reacción (Reacciones.lua): Abrumar, Revancha, Ejecutar...,
--     con datos de tu personaje (C_Spell.IsSpellUsable y el brillo oficial).
--   * Barra de golpe (Golpe.lua): PLAYER_SWING, sin registro de combate.
--   * Medidor de daño (Medidor.lua, Ventana.lua): el top de tu grupo o banda
--     con C_DamageMeter, el medidor oficial del juego; los valores secretos
--     se muestran sin aritmética (barras y textos que los aceptan).
--   * Marca de misión (MarcaMision.lua): un ícono y un brillo suave en la
--     placa de nombre de quien te falta para una misión.
--   * La página "combate" (Pagina.lua), en Personaje.
-- Explicaciones con tope (más abajo): cada texto explicativo (el porqué de
-- la rotación, los avisos de reacción) sale a lo sumo 4 veces por personaje,
-- uno a la vez y nunca el mismo dos veces en 30 s; se callan para siempre con
-- su × o con clic derecho, y "Volver a mostrar" los enciende de nuevo.
-- Este archivo: ajustes, utilidades, los marcos movibles, eventos y comandos.
--
-- Contrato (global): AlfaCombate.AlternarMedidor(), AlfaCombate.Mover(),
-- AlfaCombate.Abrir().

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
M.N, M.A, M.K, M.L = N, A, K, L

local ID = "combate"
M.ID = ID
M.ICONO = "ic-nivel"

local type, pairs, ipairs, pcall, floor, max, tonumber = type, pairs, ipairs, pcall, math.floor, math.max, tonumber

M.AJUSTES = {
	-- Rotación
	rotacion = true,      -- el ícono con la siguiente habilidad
	prioridadAlfa = false, -- siempre la prioridad de Alfa, aunque el juego ofrezca la de Blizzard
	despues = 2,          -- cuántas habilidades después (0 a 3)
	fuera = true,         -- también fuera de combate, con un enemigo elegido
	alfaFuera = 0.45,     -- opacidad fuera de combate
	tam = 44,             -- tamaño del ícono principal
	tecla = true,         -- la tecla sobre el ícono
	nombre = false,       -- el nombre de la habilidad debajo
	porque = true,        -- la línea corta del porqué (con tope: unas pocas veces)
	barrido = true,       -- el barrido oscuro de la recarga sobre los íconos
	rama = "auto",        -- tu especialización para la prioridad de Alfa ("auto" o su clave)
	resaltar = true,      -- resaltar el botón de tu barra (el borde de Alfa)
	-- Avisos
	avisos = true,        -- avisos de reacción de tu clase
	avisosOtros = false,  -- también cuando el juego hace brillar otra habilidad tuya
	avisosSonido = true,
	avisosPorque = true,
	-- Golpe y panel
	golpe = true,
	golpeNumero = false,  -- los segundos junto a la barra de golpe
	panel = false,
	-- Misiones
	marcaMision = true,   -- marcar en su placa de nombre a quien te falta para una misión
	marcaMisionBrillo = true, -- y un brillo suave alrededor de su barra        -- el panel de estadísticas (opcional)
	-- Medidor
	medidor = false,      -- la ventana del medidor abierta (se recuerda)
	medidorGrupo = false, -- la ventana solo cuando estás en grupo
	filas = 10,           -- cuántos en el top
	anunciar = 5,         -- cuántos se anuncian en el chat
	opacidad = 1,         -- opacidad de la ventana del medidor
	sesion = "actual",    -- actual | anterior | todo
	tipo = "dps",         -- dps | dano | curacion | cps
}

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
function M.Opt(clave) return N.Get(ID, clave) end
function M.SetOpt(clave, v) N.Set(ID, clave, v) end

-- Un valor secreto (combate, mazmorras, encuentros) no se compara ni se
-- opera: solo se pasa a lo que lo acepta (StatusBar:SetValue, FontString:SetText).
-- Se pregunta antes de cualquier comparación (ni siquiera con nil).
function M.Secreto(v)
	if type(issecretvalue) ~= "function" then return false end
	return issecretvalue(v) and true or false
end

-- El valor tal cual, o nil si es secreto.
function M.Legible(v)
	if M.Secreto(v) then return nil end
	return v
end

-- Una llamada al cliente que no rompe nada si falla: -> sus resultados o nil.
function M.Llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

function M.EnCombate()
	if InCombatLockdown and InCombatLockdown() then return true end
	return M.Legible(UnitAffectingCombat and M.Llamar(UnitAffectingCombat, "player")) == true
end

-- Hay un enemigo elegido y vivo.
function M.HayEnemigo()
	if M.Legible(M.Llamar(UnitExists, "target")) ~= true then return false end
	local puede = M.Legible(M.Llamar(UnitCanAttack, "player", "target"))
	local muerto = M.Legible(M.Llamar(UnitIsDeadOrGhost or UnitIsDead, "target"))
	return puede == true and muerto ~= true
end

-- El nombre de un hechizo (del cliente, en su idioma) o nil.
function M.NombreHechizo(id)
	if type(id) ~= "number" then return nil end
	local n = C_Spell and C_Spell.GetSpellName and M.Llamar(C_Spell.GetSpellName, id)
	if not M.Secreto(n) and type(n) == "string" and n ~= "" then return n end
	n = M.Llamar(GetSpellInfo, id)
	if not M.Secreto(n) and type(n) == "string" and n ~= "" then return n end
	return nil
end

function M.IconoHechizo(id)
	return A.Compat and A.Compat.SpellIcon and A.Compat.SpellIcon(id) or nil
end

function M.Conoce(id)
	if type(id) ~= "number" or not A.Compat then return false end
	return (A.Compat.IsPlayerSpell and A.Compat.IsPlayerSpell(id)) or (A.Compat.IsSpellKnown and A.Compat.IsSpellKnown(id)) or false
end

-- La clase del jugador ("WARRIOR"...).
function M.Clase()
	local _, c = M.Llamar(UnitClass, "player")
	c = M.Legible(c)
	return type(c) == "string" and c or nil
end

-- Una lista de nombres: "A, B y C".
function M.Juntar(lista)
	local n = #lista
	if n == 0 then return "" end
	if n == 1 then return lista[1] end
	return table.concat(lista, ", ", 1, n - 1) .. " " .. L["y"] .. " " .. lista[n]
end

---------------------------------------------------------------------------
-- Explicaciones con tope: lo que se escribe en pantalla al pelear no se
-- repite. Cada texto (por su clave) sale a lo sumo LIMITE veces por personaje
-- y luego se calla; el jugador puede callarlo antes (su × o clic derecho).
-- Uno solo a la vez y nunca el mismo antes de PAUSA segundos.
-- Se guarda en AlfaNucleoCharDB.combate.textos = { vistas = {}, callados = {} }.
---------------------------------------------------------------------------
M.LIMITE_TEXTO = 4
M.PAUSA_TEXTO = 30

local ultimaVez = {}  -- clave -> cuándo salió (esta sesión)
local enPantalla      -- { clave, hasta }

local function textos()
	local d = N.DatosPersonaje(ID)
	if type(d.textos) ~= "table" then d.textos = {} end
	local t = d.textos
	if type(t.vistas) ~= "table" then t.vistas = {} end
	if type(t.callados) ~= "table" then t.callados = {} end
	return t
end

-- ¿Puede salir ahora este texto?
function M.TextoPuede(clave)
	if type(clave) ~= "string" then return false end
	local t = textos()
	if t.callados[clave] then return false end
	if (tonumber(t.vistas[clave]) or 0) >= M.LIMITE_TEXTO then return false end
	local ahora = GetTime()
	if ultimaVez[clave] and ahora - ultimaVez[clave] < M.PAUSA_TEXTO then return false end
	if enPantalla and enPantalla.hasta > ahora and enPantalla.clave ~= clave then return false end
	return true
end

-- Salió (cuenta una vez) y ocupa la pantalla `dur` segundos.
function M.TextoMostrado(clave, dur)
	local t = textos()
	t.vistas[clave] = (tonumber(t.vistas[clave]) or 0) + 1
	local ahora = GetTime()
	ultimaVez[clave] = ahora
	enPantalla = { clave = clave, hasta = ahora + (dur or 2.5) }
end

-- Se fue antes de tiempo: deja libre la pantalla.
function M.TextoFin(clave)
	if enPantalla and enPantalla.clave == clave then enPantalla = nil end
end

-- "No volver a mostrar".
function M.Callar(clave)
	if type(clave) ~= "string" then return end
	textos().callados[clave] = true
	M.TextoFin(clave)
	M.Avisar()
end

-- Cuántas explicaciones ya no salen (calladas o que llegaron al tope).
function M.TextosCallados()
	local t, n = textos(), 0
	local vistos = {}
	for k in pairs(t.callados) do vistos[k] = true n = n + 1 end
	for k, v in pairs(t.vistas) do
		if not vistos[k] and (tonumber(v) or 0) >= M.LIMITE_TEXTO then n = n + 1 end
	end
	return n
end

-- "Volver a mostrar las explicaciones".
function M.ReiniciarTextos()
	local d = N.DatosPersonaje(ID)
	d.textos = { vistas = {}, callados = {} }
	for k in pairs(ultimaVez) do ultimaVez[k] = nil end
	enPantalla = nil
	M.Avisar()
end

---------------------------------------------------------------------------
-- Marcos en pantalla: cuelgan de la capa de Alfa (se esconden con "Ocultar
-- Alfa"), no reciben el ratón (no estorban en combate) y se arrastran solo
-- con "Mover" y fuera de combate. Su lugar va en AlfaNucleoDB.combate.pos.
---------------------------------------------------------------------------
local marcos = {}
local desbloqueado = false

local function posiciones()
	local d = N.Datos(ID)
	d.pos = type(d.pos) == "table" and d.pos or {}
	return d.pos
end

local function colocar(f)
	local p = posiciones()[f.alfaClave]
	f:ClearAllPoints()
	if type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "number" then
		f:SetPoint(p[1], UIParent, p[2] or p[1], p[3], p[4] or 0)
	else
		local d = f.alfaPunto
		f:SetPoint(d[1], UIParent, d[2], d[3], d[4])
	end
end

local function guardar(f)
	local a, _, b, x, y = f:GetPoint(1)
	if type(a) ~= "string" then return end
	posiciones()[f.alfaClave] = { a, b, floor(K.num(x, 0) + 0.5), floor(K.num(y, 0) + 0.5) }
end

-- clave: la del lugar guardado; nombre: lo que dice al moverlo.
function M.Marco(clave, nombre, ancho, alto, punto)
	local f = CreateFrame("Frame", "AlfaCombate" .. clave, K.Raiz())
	f.alfaClave, f.alfaPunto = clave, punto
	f:SetSize(ancho, alto)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(false)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if desbloqueado and not InCombatLockdown() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() guardar(self) end)
	-- Mientras se mueve: un velo de acento con su nombre encima.
	local g = CreateFrame("Frame", nil, f)
	g:SetAllPoints(f)
	g:SetFrameLevel(f:GetFrameLevel() + 30)
	g.caja = K.Caja(g, { fondo = "acento", alfaFondo = 0.16, borde = "acento", corte = K.CORTE.chico })
	g.Placa = CreateFrame("Frame", nil, g)
	g.Placa.caja = K.Caja(g.Placa, { fondo = "fondo", borde = "acento", alfaBorde = 0.6, corte = K.CORTE.chico })
	g.Placa:SetPoint("BOTTOM", g, "TOP", 0, 4)
	g.Texto = K.Texto(g.Placa, "pequeno", "texto")
	g.Texto:SetPoint("CENTER", g.Placa, "CENTER", 0, 0)
	K.Escribir(g.Texto, nombre)
	g.Placa:SetSize(K.Ajustar(g.Texto) + 16, 20)
	f.Guia = g
	-- Un marco que nace mientras se mueven los demás también se mueve.
	f:EnableMouse(desbloqueado)
	g:SetShown(desbloqueado)
	colocar(f)
	marcos[clave] = f
	return f
end

function M.Desbloqueado() return desbloqueado end

function M.Desbloquear(on)
	if on and InCombatLockdown() then
		N.Imprimir(L["Los marcos se mueven fuera de combate."])
		return
	end
	desbloqueado = on and true or false
	for _, f in pairs(marcos) do
		f:EnableMouse(desbloqueado)
		f.Guia:SetShown(desbloqueado)
	end
	M.Refrescar()
end

function M.ReiniciarPosiciones()
	local d = N.Datos(ID)
	d.pos = {}
	for _, f in pairs(marcos) do colocar(f) end
end

---------------------------------------------------------------------------
-- Refrescar: cada parte decide si se ve. La página se rehace si está abierta.
---------------------------------------------------------------------------
local PARTES = { "Rotacion", "Reacciones", "Golpe", "Panel", "Ventana", "MarcaMision" }

function M.Refrescar()
	for _, p in ipairs(PARTES) do
		local x = M[p]
		if x and x.Ver then K.Llamar(x.Ver) end
	end
	M.Avisar()
end

-- La página (Pagina.lua pone M.alCambiar).
function M.Avisar()
	if M.alCambiar then K.Llamar(M.alCambiar) end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local function cada(fn) return function(...) K.Llamar(fn, ...) end end

A.RegisterEvent("PLAYER_REGEN_DISABLED", cada(function()
	if desbloqueado then M.Desbloquear(false) end
	if M.Reacciones then M.Reacciones.EntrarCombate() end
	M.Refrescar()
end))
A.RegisterEvent("PLAYER_REGEN_ENABLED", cada(function()
	if M.Rotacion then M.Rotacion.PrepararBarras() end
	if M.Panel then M.Panel.Pedir() end
	M.Refrescar()
end))
A.RegisterEvent("PLAYER_TARGET_CHANGED", cada(function()
	if M.Prioridad then M.Prioridad.NuevoObjetivo() end
	if M.Rotacion then M.Rotacion.Ver() end
end))
A.RegisterEvent("PLAYER_LEVEL_UP", cada(function()
	if M.Prioridad then M.Prioridad.Olvidar() end
	M.Avisar()
end))
A.RegisterEvent("SPELLS_CHANGED", cada(function()
	if M.Prioridad then M.Prioridad.Olvidar() end
	if M.Rotacion then M.Rotacion.Olvidar() end
	if M.Reacciones then M.Reacciones.Preparar() end
	M.Avisar()
end))
for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_BINDINGS" }) do
	A.RegisterEvent(ev, cada(function() if M.Rotacion then M.Rotacion.OlvidarBarras() end end))
end
A.RegisterEvent("SPELL_UPDATE_USABLE", cada(function() if M.Reacciones then M.Reacciones.Revisar() end end))
A.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", cada(function(_, id)
	if M.Prioridad then M.Prioridad.Brillo(id, true) end
	if M.Reacciones then M.Reacciones.Brillo(id) end
end))
A.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", cada(function(_, id) if M.Prioridad then M.Prioridad.Brillo(id, false) end end))
A.RegisterEvent("PLAYER_SWING", cada(function(_, dur, tipo) if M.Golpe then M.Golpe.Golpe(dur, tipo) end end))
for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "GROUP_JOINED", "GROUP_LEFT" }) do
	A.RegisterEvent(ev, cada(function() if M.Ventana then M.Ventana.Ver() end M.Avisar() end))
end
A.RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", cada(function(_, tipo, id) if M.Medidor then M.Medidor.Actualizada(tipo, id) end end))
A.RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", cada(function() if M.Medidor then M.Medidor.Nueva() end end))
A.RegisterEvent("DAMAGE_METER_RESET", cada(function() if M.Medidor then M.Medidor.Borrada() end end))

A.On("SETTING_CHANGED", function(path)
	if path == "" or (type(path) == "string" and path:find("^" .. ID .. "%.")) then
		if path == ID .. ".rama" and M.Prioridad then M.Prioridad.Olvidar() end
		K.Llamar(M.Refrescar)
	end
end)

---------------------------------------------------------------------------
-- Una sola vez: los ajustes de combate que vivían en Builds pasan aquí
-- (solo los que el jugador había cambiado) y también el lugar de sus marcos.
---------------------------------------------------------------------------
local DE_BUILDS = {
	{ "sugerencia", "rotacion" }, { "sugerenciaFuera", "fuera" }, { "sugerenciaNombre", "nombre" },
	{ "resaltado", "resaltar" }, { "tamSugerencia", "tam" }, { "alertas", "avisos" },
	{ "alertasSonido", "avisosSonido" }, { "alertasPorque", "avisosPorque" }, { "golpe", "golpe" }, { "panel", "panel" },
}
local LUGARES_BUILDS = { Sugerencia = "Rotacion", Alerta = "Aviso", Golpe = "Golpe", Panel = "Panel" }

local function migrar()
	local d = N.Datos(ID)
	if d.migradoBuilds then return end
	d.migradoBuilds = true
	for _, par in ipairs(DE_BUILDS) do
		local v = A.Get("builds." .. par[1])
		if type(v) == "number" and par[2] == "tam" then
			N.Set(ID, "tam", math.max(32, math.min(64, floor(v))))
		elseif type(v) == "boolean" then
			N.Set(ID, par[2], v)
		end
	end
	-- Sus lugares (AlfaNucleoDB.builds.pos), sin tocar sus datos.
	local db = type(AlfaNucleoDB) == "table" and AlfaNucleoDB.builds
	local viejos = type(db) == "table" and db.pos
	if type(viejos) == "table" then
		local pos = posiciones()
		for viejo, nuevo in pairs(LUGARES_BUILDS) do
			local p = viejos[viejo]
			if type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "number" and pos[nuevo] == nil then
				pos[nuevo] = { p[1], p[2], p[3], p[4] }
			end
		end
	end
end

A.OnLogin(function()
	K.Llamar(migrar)
	if M.Rotacion and M.Rotacion.Presentar then A.After(6, function() K.Llamar(M.Rotacion.Presentar) end) end
	if M.Reacciones then M.Reacciones.Preparar() end
	if M.Rotacion then M.Rotacion.PrepararBarras() end
	M.Refrescar()
end)

---------------------------------------------------------------------------
-- Comandos: /alfa combate [mover | aviso | medidor], /alfa dps
---------------------------------------------------------------------------
local function comando(resto)
	local sub = type(resto) == "string" and resto:match("^%s*(%S+)") or nil
	sub = sub and sub:lower()
	if sub == "mover" then
		M.Desbloquear(not desbloqueado)
	elseif sub == "aviso" then
		if M.Reacciones then M.Reacciones.Probar() end
	elseif sub == "medidor" or sub == "dps" then
		if M.Ventana then M.Ventana.Alternar() end
	else
		N.Abrir(ID)
	end
end
A.RegisterCommand("combate", comando, L["abre Combate (también: mover, aviso, medidor)"])
A.RegisterCommand("dps", function() if M.Ventana then M.Ventana.Alternar() end end, L["abre o cierra el medidor de daño"])

-- Para otros módulos (Hoy, el menú): lo mínimo, sin tocar nada por dentro.
AlfaCombate = {
	AlternarMedidor = function() if M.Ventana then M.Ventana.Alternar() end end,
	Mover = function() M.Desbloquear(not desbloqueado) end,
	Abrir = function() N.Abrir(ID) end,
	VentanaMedidor = function() return M.Ventana and M.Ventana.Marco() end,
}
