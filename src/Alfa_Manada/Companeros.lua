-- Alfa - La Jauría: con quién cazaste (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- «¿Cómo se llamaba el sacerdote de anoche?»: Alfa recuerda a la gente de tus
-- grupos (su nombre, clase, nivel, dónde cazaron, cuándo y cuántas veces) y
-- /alfa companeros abre «Con quién cazaste», lo más reciente primero, con
-- «Invitar» y «Susurrar» a un clic (el susurro abre la caja del chat: lo envías
-- tú). Y cuando alguien con quien ya cazaste te invita a un grupo, un aviso te
-- recuerda quién es («Ya cazaron juntos hace 2 días, en Las Minas de la
-- Muerte»). Tus amigos y tu hermandad no: a esos ya los conoces.
-- Solo lee tu grupo (GROUP_ROSTER_UPDATE, UnitName/UnitClass/UnitLevel; lo
-- secreto no se anota). Nada se envía. Por cuenta (AlfaNucleoDB.manada.
-- companeros), hasta MAX personas y DIAS días. Ajuste manada.companeros (de
-- fábrica, sí).
--
--   Cp.Anotar() -> cuántos ; Cp.Lista() -> { { clave, nombre, clase, claseNombre, nivel, zona, t, veces } }
--   Cp.De(nombre) -> registro | nil ; Cp.Hace(t) -> texto ; Cp.Tarjetas() ; Cp.Olvidar()
--   Cp.AlInvitar(nombre, guid) -> el aviso | nil ; Cp.Abrir() ; Cp.Visible()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local U, L, ID = M.U, M.L, M.ID

local Cp = {}
M.Companeros = Cp

local type, pcall, format, ipairs, pairs, sort, floor, max = type, pcall, string.format, ipairs, pairs, table.sort, math.floor, math.max

local MAX = 100
local DIAS = 60

A.RegisterDefaults(ID, { companeros = true })

local function on() return N.Get(ID, "companeros") ~= false end
local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end
local function hoy() return time and time() or 0 end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return U.Leer(a), U.Leer(b)
end

local function datos()
	local d = N.Datos(ID)
	d.companeros = type(d.companeros) == "table" and d.companeros or {}
	return d.companeros
end

---------------------------------------------------------------------------
-- Anotar a tu grupo
---------------------------------------------------------------------------
local enGrupo = {} -- quién estaba en el grupo la vez pasada: «veces» sube al llegar

local function lugar()
	if N.SiJuego(rawget(_G, "IsInInstance")) then
		local nombre = llamar(rawget(_G, "GetInstanceInfo"))
		if texto(nombre) then return nombre end
	end
	return texto((llamar(rawget(_G, "GetRealZoneText")))) or texto((llamar(rawget(_G, "GetZoneText"))))
end

local function unidades()
	local out = {}
	if N.SiJuego(rawget(_G, "IsInRaid")) then
		for i = 1, 40 do out[#out + 1] = "raid" .. i end
	else
		for i = 1, 4 do out[#out + 1] = "party" .. i end
	end
	return out
end

local function podar()
	local d = datos()
	local limite = hoy() - DIAS * 86400
	local lista = {}
	for c, x in pairs(d) do
		if type(x) ~= "table" or (x.t or 0) < limite then d[c] = nil else lista[#lista + 1] = c end
	end
	if #lista > MAX then
		sort(lista, function(a, b) return (d[a].t or 0) > (d[b].t or 0) end)
		for i = MAX + 1, #lista do d[lista[i]] = nil end
	end
end
Cp.Podar = podar

function Cp.Anotar()
	if not on() then enGrupo = {} return 0 end
	if not N.SiJuego(rawget(_G, "IsInGroup")) then enGrupo = {} return 0 end
	local d = datos()
	local donde = lugar()
	local ahora = hoy()
	local vistos, n = {}, 0
	for _, u in ipairs(unidades()) do
		if N.SiJuego(rawget(_G, "UnitExists"), u) and N.SiJuego(rawget(_G, "UnitIsPlayer"), u) and not N.SiJuego(rawget(_G, "UnitIsUnit"), u, "player") then
			local nombre, reino = llamar(rawget(_G, "UnitName"), u)
			nombre, reino = texto(nombre), texto(reino)
			if nombre then
				if reino then nombre = nombre .. "-" .. reino end
				local c = U.Clave(nombre)
				if c then
					local claseNombre, clase = llamar(rawget(_G, "UnitClass"), u)
					local nivel = N.LeerNumero((llamar(rawget(_G, "UnitLevel"), u)))
					local x = type(d[c]) == "table" and d[c] or { veces = 0 }
					if not enGrupo[c] then x.veces = (x.veces or 0) + 1 end
					x.nombre = U.Mostrar(nombre)
					x.destino = U.Destino(nombre) or nombre
					x.clase = texto(clase) or x.clase
					x.claseNombre = texto(claseNombre) or x.claseNombre
					if nivel and nivel > 0 then x.nivel = nivel end
					x.zona = donde or x.zona
					x.t = ahora
					d[c] = x
					vistos[c] = true
					n = n + 1
				end
			end
		end
	end
	enGrupo = vistos
	podar()
	return n
end

function Cp.Lista()
	local out = {}
	for c, x in pairs(datos()) do
		if type(x) == "table" then
			out[#out + 1] = { clave = c, nombre = x.nombre or c, destino = x.destino or x.nombre or c, clase = x.clase,
				claseNombre = x.claseNombre, nivel = x.nivel, zona = x.zona, t = x.t or 0, veces = x.veces or 1 }
		end
	end
	sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.nombre < b.nombre end)
	return out
end

function Cp.De(nombre)
	local c = U.Clave(nombre)
	local x = c and datos()[c]
	return type(x) == "table" and x or nil
end

function Cp.Olvidar()
	N.Datos(ID).companeros = {}
	enGrupo = {}
	if Cp.Visible() then Cp.Llenar() end
end

function Cp.Hace(t)
	local s = max(0, hoy() - (tonumber(t) or 0))
	if s < 3600 then return L["hace un rato"] end
	if s < 86400 then return N.Plural(floor(s / 3600), L["hace %d hora"], L["hace %d horas"]) end
	return N.Plural(floor(s / 86400), L["hace %d día"], L["hace %d días"])
end

---------------------------------------------------------------------------
-- Te invita alguien con quien ya cazaste
---------------------------------------------------------------------------
local function conocido(guid)
	guid = texto(guid)
	if not guid then return false end
	local F = rawget(_G, "C_FriendList")
	if type(F) == "table" and N.SiJuego(F.IsFriend, guid) then return true end
	return N.SiJuego(rawget(_G, "IsGuildMember"), guid)
end

function Cp.AlInvitar(nombre, guid)
	if not on() then return nil end
	nombre = texto(nombre)
	if not nombre or conocido(guid) then return nil end
	local x = Cp.De(nombre)
	if not x then return nil end
	local partes = { Cp.Hace(x.t) }
	if x.zona then partes[1] = format(L["%s, en %s"], partes[1], x.zona) end
	local veces = (x.veces or 1) > 1 and (" " .. format(L["(%d veces)"], x.veces)) or ""
	return U.Aviso({
		titulo = format(L["Te invita %s"], x.nombre or U.Mostrar(nombre)),
		texto = format(L["Ya cazaron juntos: %s."], partes[1]) .. veces,
		icono = "ic-manada", duracion = 15, prioridad = 2,
	})
end

---------------------------------------------------------------------------
-- La ventana «Con quién cazaste» (/alfa companeros)
---------------------------------------------------------------------------
local v, ui = nil, {}

local function colorClase(clase)
	local T = A.Theme
	if clase and T and T.ClassColor then
		local r, g, b = T.ClassColor(clase)
		if r then return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)) end
	end
	return ""
end

function Cp.Tarjetas()
	local out = {}
	for _, x in ipairs(Cp.Lista()) do
		local partes = {}
		if x.claseNombre and x.nivel then partes[#partes + 1] = format("%s %d", x.claseNombre, x.nivel)
		elseif x.claseNombre then partes[#partes + 1] = x.claseNombre end
		if x.zona then partes[#partes + 1] = x.zona end
		partes[#partes + 1] = Cp.Hace(x.t)
		local destino = x.destino
		local color = colorClase(x.clase)
		out[#out + 1] = { variante = "compacta", icono = "ic-manada", tono = "neutro",
			titulo = color ~= "" and (color .. x.nombre .. "|r") or x.nombre,
			texto = table.concat(partes, "  \194\183  "),
			valor = x.veces > 1 and format(L["%d veces"], x.veces) or nil,
			accion = { texto = L["Invitar"], alClic = function() U.Invitar(destino) end },
			secundaria = { texto = L["Susurrar"], alClic = function() U.Susurrar(destino) end } }
	end
	return out
end

local function llenar()
	if not (v and v:IsShown()) then return end
	local lista = Cp.Tarjetas()
	local hay = #lista > 0
	ui.vacio:Set({ lobo = "dormido", titulo = on() and L["Todavía no cazas con nadie"] or L["Está apagado"],
		texto = on() and L["Cuando estés en un grupo, aquí quedan tus compañeros para volver a invitarlos."]
			or L["Préndelo en Ajustes > La Jauría para que Alfa recuerde a la gente de tus grupos."],
		accion = on() and { texto = L["Ver el tablón de la manada"], alClic = function() N.Abrir(ID) end }
			or { texto = L["Prenderlo"], alClic = function() N.Set(ID, "companeros", true) llenar() end } })
	K.Mostrar(ui.vacio, not hay)
	ui.sec:Set(L["Tus compañeros de caza"], { cuenta = hay and N.Plural(#lista, L["%d persona"], L["%d personas"]) or nil,
		enlace = hay and { texto = L["Olvidar a todos"], alClic = function() Cp.Olvidar() end } or nil })
	K.Mostrar(ui.sec, hay)
	ui.lista:Llenar(lista)
	K.Mostrar(ui.lista, hay)
	local h = ui.pila:Acomodar(v:AnchoCuerpo())
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end
Cp.Llenar = llenar

function Cp.Abrir()
	if N.Permitido and not N.Permitido() then return false end
	Cp.Anotar()
	if not v then
		v = K.Ventana({ nombre = "AlfaManadaCompaneros", titulo = L["Con quién cazaste"],
			subtitulo = L["La gente de tus últimos grupos, para volver a cazar juntos"],
			icono = "ic-manada", ancho = 620, alto = 520, desplazar = true })
		v.alAcomodar = llenar
		local p = K.Pila(v.Cuerpo, { espacio = K.ESP.base })
		ui.pila = p
		ui.vacio = p:Agregar(K.Vacio(p, { lobo = "dormido", titulo = "" }))
		ui.sec = p:Agregar(K.Seccion(p, ""))
		ui.lista = p:Agregar(K.Rejilla(p, { min = 420, gap = K.ESP.xs, variante = "compacta" }), { espacio = K.ESP.s })
	end
	v:Abrir()
	llenar()
	return true
end
function Cp.Visible() return v ~= nil and v:IsShown() end
function Cp.Ventana() return v end

---------------------------------------------------------------------------
-- Cuándo
---------------------------------------------------------------------------
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	if on() then N.Una("manada.companeros", 3, function() pcall(Cp.Anotar) end) end
end)
A.RegisterEvent("PARTY_INVITE_REQUEST", function(_, nombre, ...)
	local guid = select(7, ...)
	pcall(Cp.AlInvitar, nombre, guid)
end)

AlfaManada = type(AlfaManada) == "table" and AlfaManada or {}
AlfaManada.Companeros = function() return Cp.Abrir() end

A.RegisterCommand("companeros", function() Cp.Abrir() end, L["con quién cazaste: la gente de tus últimos grupos, para invitarla otra vez"])
