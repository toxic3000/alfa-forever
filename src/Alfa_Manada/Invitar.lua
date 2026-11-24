-- Alfa - La Jauría: «Invitar al clan» en el menú del clic derecho de un
-- jugador (su retrato, su nombre en el chat, tu grupo o banda, la lista de
-- una comunidad). Se abre con tu hermandad y tus comunidades de WoW donde
-- puedes invitar. A la hermandad, un clic y la invitación le llega sin
-- escribir su nombre; a una comunidad, el nombre listo para pegar (abajo).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Se engancha con la vía oficial de los menús (Menu.ModifyMenu): no toca
-- los botones del juego, solo agrega los suyos al final. Siempre es un clic
-- de quien juega; nada se envía solo. Lo que llega "secreto" (en combate o
-- en mazmorras) se toma como desconocido y la opción no sale.
--
-- Hermandad: hace falta permiso para invitar (CanGuildInvite), que la
-- persona no esté ya en tu hermandad y que sea de tu facción.
-- Comunidades: solo las de personajes (las de Battle.net piden BattleTag) y
-- solo donde tu rango deja invitar (canSendInvitation).
--
-- 1.2.3: a una comunidad Alfa NO manda la invitación. El juego reserva
-- C_Club.SendCharacterInvitation para su propia ventana ("Invitar a
-- miembro"): llamada desde un addon sale "Alfa_Manada se ha bloqueado de
-- una acción disponible solo para la interfaz de Blizzard" (le pasó a Toxic
-- en la 1.2.2), y abrir esa ventana con los datos puestos desde Alfa también
-- la bloquea. Al elegir una comunidad, Alfa dice en el chat cómo invitarla y
-- con qué nombre. La hermandad sí se invita directo: C_GuildInfo.Invite no
-- está restringida en la documentación del juego (la de comunidades sí).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local I = {}
M.Invitar = I

local pcall, type, ipairs = pcall, type, ipairs

-- Los menús de un jugador donde sale la opción.
I.MENUS = {
	"MENU_UNIT_PLAYER",                 -- su retrato (objetivo) o su placa
	"MENU_UNIT_FOCUS",                  -- tu foco
	"MENU_UNIT_PARTY",                  -- alguien de tu grupo
	"MENU_UNIT_RAID_PLAYER",            -- alguien de tu banda
	"MENU_UNIT_RAID",                   -- los marcos de banda
	"MENU_UNIT_FRIEND",                 -- su nombre en el chat
	"MENU_UNIT_CHAT_ROSTER",            -- la lista de un canal
	"MENU_UNIT_COMMUNITIES_WOW_MEMBER", -- la lista de una comunidad
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER", -- la lista de tu hermandad (solo comunidades)
	"MENU_UNIT_GUILD",                  -- lo mismo, desde el chat de hermandad
}

-- En estos la persona ya es de tu hermandad.
local DE_LA_HERMANDAD = {
	MENU_UNIT_COMMUNITIES_GUILD_MEMBER = true,
	MENU_UNIT_GUILD = true,
}

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return U.Leer(v)
end

---------------------------------------------------------------------------
-- A quién: el nombre de la persona del menú
---------------------------------------------------------------------------

local function esJugador(unit)
	if not unit then return true end
	return llamar(UnitIsPlayer, unit) and true or false
end

local function soyYo(unit, nombre)
	if unit and llamar(UnitIsUnit, unit, "player") then return true end
	local mia = U.MiClave and U.MiClave()
	return mia ~= nil and U.Clave(nombre) == mia
end

-- { nombre, unit } o nil si el menú no es de otro jugador o no se lee.
function I.Persona(contexto)
	if type(contexto) ~= "table" then return nil end
	local unit = U.Texto(contexto.unit)
	if unit and not esJugador(unit) then return nil end
	local nombre
	if unit then
		-- Con unidad, su nombre completo ("Ana Smith"): el del menú puede
		-- venir sin apellido. Si no se lee (secreto), no hay opción.
		if not (A.Compat and A.Compat.UnitFullName) then return nil end
		nombre = U.Texto(llamar(A.Compat.UnitFullName, unit))
		if not nombre then return nil end
	else
		nombre = U.Texto(contexto.name)
		local reino = U.Texto(contexto.server)
		if nombre and reino and not nombre:find("-", 1, true) then nombre = nombre .. "-" .. reino end
	end
	if not nombre or soyYo(unit, nombre) then return nil end
	return { nombre = nombre, unit = unit }
end

---------------------------------------------------------------------------
-- A dónde: tu hermandad y tus comunidades donde puedes invitar
---------------------------------------------------------------------------

local function puedoHermandad(persona, etiqueta)
	if DE_LA_HERMANDAD[etiqueta] or not U.EnHermandad() then return nil end
	if not llamar(CanGuildInvite) then return nil end
	local unit = persona.unit
	if unit then
		if llamar(UnitIsInMyGuild, unit) then return nil end
		local suya = llamar(UnitFactionGroup, unit)
		local mia = llamar(UnitFactionGroup, "player")
		if type(suya) == "string" and type(mia) == "string" and suya ~= mia then return nil end
	end
	return U.NombreHermandad()
end

local function comunidades()
	local out = {}
	local CC = C_Club
	if type(CC) ~= "table" then return out end
	local lista = llamar(CC.GetSubscribedClubs)
	if type(lista) ~= "table" then return out end
	local personaje = (Enum and Enum.ClubType and Enum.ClubType.Character) or 1
	for _, info in ipairs(lista) do
		local id = type(info) == "table" and U.Leer(info.clubId)
		local nombre = type(info) == "table" and U.Texto(info.name)
		if id and nombre and U.Leer(info.clubType) == personaje then
			local p = llamar(CC.GetClubPrivileges, id)
			if type(p) == "table" and U.Leer(p.canSendInvitation) then
				out[#out + 1] = { id = id, nombre = nombre }
			end
		end
	end
	table.sort(out, function(a, b) return U.Plegar(a.nombre) < U.Plegar(b.nombre) end)
	return out
end

-- Los destinos: { tipo = "hermandad"|"comunidad", nombre, id }.
function I.Destinos(persona, etiqueta)
	local out = {}
	local hermandad = puedoHermandad(persona, etiqueta)
	if hermandad then out[#out + 1] = { tipo = "hermandad", nombre = hermandad } end
	for _, c in ipairs(comunidades()) do
		out[#out + 1] = { tipo = "comunidad", nombre = c.nombre, id = c.id }
	end
	return out
end

---------------------------------------------------------------------------
-- Invitar (un clic de quien juega)
---------------------------------------------------------------------------

-- Invitar a una comunidad, con lo que sí se puede (1.2.3): el nombre listo
-- para copiar (la ventanita de copiar del motor, con el texto elegido) y un
-- aviso con «Abrir Hermandad y comunidades», que pulsa el botón del juego
-- (K.Seguro: el clic lo hace el juego, sin bloqueo; en combate no se ofrece).
-- Sin la ventanita, los pasos van al chat.
function I.AyudaComunidad(persona, destino, quien)
	local nombre = U.Mostrar(persona.nombre)
	local pasos = L["Para invitar a %s a %s: abre «Hermandad y comunidades», elige %s, pulsa «Invitar a miembro» y escribe: %s"]
		:format(nombre, destino.nombre, destino.nombre, quien)
	local UI = A.UI
	local copiar = type(UI) == "table" and type(UI.ShowCopy) == "function"
	if not (copiar and pcall(UI.ShowCopy, L["Invitar a %s"]:format(destino.nombre), quien, {
		icon = "ic-manada", iconColor = "accent",
		hint = L["Cópialo con Ctrl+C. Luego abre «Hermandad y comunidades», elige %s, pulsa «Invitar a miembro» y pégalo con Ctrl+V."]:format(destino.nombre),
	})) then
		U.Decir(pasos)
	end
	local K = N.Kit
	local abrir = K and K.AbrirJuego and K.AbrirJuego("comunidades")
	if K and K.Aviso and abrir and not (InCombatLockdown and InCombatLockdown()) and not (A.GamepadUI and A.GamepadUI()) then
		M.U.Aviso({
			titulo = L["Invitar a %s"]:format(destino.nombre),
			texto = L["%s no se puede invitar desde Alfa: el juego solo lo deja desde su ventana. Ábrela aquí y pega el nombre."]:format(destino.nombre),
			icono = "ic-manada", duracion = 20,
			accion = { texto = L["Abrir Hermandad y comunidades"], seguro = abrir },
		})
	end
	return pasos
end

function I.Enviar(persona, destino)
	local quien = U.Destino(persona.nombre)
	if not quien then return false end
	local ok = false
	if destino.tipo == "hermandad" then
		if C_GuildInfo and type(C_GuildInfo.Invite) == "function" then
			ok = pcall(C_GuildInfo.Invite, quien)
		elseif type(GuildInvite) == "function" then
			ok = pcall(GuildInvite, quien)
		end
	else
		-- Una comunidad: el juego no deja que un addon la invite (arriba).
		I.AyudaComunidad(persona, destino, quien)
		return false
	end
	if ok then
		U.Decir(L["Invitación a %s para %s enviada. Si no puede unirse, el juego te dirá por qué."]:format(destino.nombre, U.Mostrar(persona.nombre)))
	else
		U.Decir(L["No se pudo enviar la invitación a %s. Prueba desde la ventana de Hermandad y comunidades."]:format(U.Mostrar(persona.nombre)))
	end
	return ok and true or false
end

---------------------------------------------------------------------------
-- El menú
---------------------------------------------------------------------------

local function texto(d)
	if d.tipo == "hermandad" then
		return "|cff40ff40" .. d.nombre .. "|r  |cff9d9d9d" .. L["hermandad"] .. "|r"
	end
	return d.nombre .. "  |cff9d9d9d" .. L["comunidad: te digo cómo"] .. "|r"
end

function I.Armar(etiqueta, raiz, contexto)
	if not N.Get(ID, "invitarMenu") then return end
	if type(raiz) ~= "table" or type(raiz.CreateButton) ~= "function" then return end
	local persona = I.Persona(contexto)
	if not persona then return end
	-- 1.2.5: su guarida abierta, distinta de la tuya: «Pedir entrar a su guarida».
	local Gu = M.Guaridas
	local v = Gu and Gu.DeLobo and Gu.DeLobo(persona.nombre)
	local mia = Gu and Gu.Actual and Gu.Actual()
	local entrar = v and v.abierta and not (mia and mia.capa == v.capa)
	local destinos = I.Destinos(persona, etiqueta)
	if #destinos == 0 and not entrar then return end
	if raiz.CreateDivider then raiz:CreateDivider() end
	if entrar then
		raiz:CreateButton(string.format(L["Pedir entrar a su guarida (%s)"], Gu.Nombre(v.capa)), function()
			local ok, por = Gu.PedirA(persona.nombre)
			if not ok and por == "grupo" then U.Decir(L["Sal de tu grupo primero: el juego te pasa a la guarida de quien te invita."]) end
		end)
	end
	if #destinos == 0 then return end
	local sub = raiz:CreateButton(L["Invitar al clan"])
	for _, d in ipairs(destinos) do
		sub:CreateButton(texto(d), function() I.Enviar(persona, d) end)
	end
end

local enganchado = false
function I.Enganchar()
	if enganchado then return end
	if A.GamepadUI and A.GamepadUI() then return end
	if not (Menu and type(Menu.ModifyMenu) == "function") then return end
	enganchado = true
	for _, etiqueta in ipairs(I.MENUS) do
		Menu.ModifyMenu(etiqueta, function(_, raiz, contexto)
			-- Un fallo aquí nunca debe romper el menú del juego.
			pcall(I.Armar, etiqueta, raiz, contexto)
		end)
	end
end

A.OnLogin(I.Enganchar)
