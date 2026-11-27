-- Alfa - Inicio: tu ficha de cazador (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic (inspirado en la idea de un addon de profesiones que
-- reunía todo de un personaje en una vista para presumirla): «aprendamos de
-- él y agreguemos lo que no tengamos, con nuestra propia distinción; nada
-- igual». Todo es de Alfa: su diseño, su noche de fondo y sus datos, que
-- salen del propio juego (nada de bases de datos de otros sitios).
--
-- Una ventana (`/alfa ficha`, el lobo de la portada de Hoy) con dos vistas:
--   «Tu personaje»: tu personaje en 3D sobre la noche de Alfa (arrastra para
--     girarlo), tu nombre en el color de tu clase, nivel, raza, clase,
--     hermandad y zona; tu experiencia con lo descansado; cuatro cifras (oro,
--     durabilidad, espacio en bolsas, tiempo jugado); tus oficios con su barra;
--     y «Lo que sigue» con un botón cada uno. «Tomar foto» la deja lista para
--     una captura de pantalla.
--   «Tus personajes»: cada personaje de la cuenta que ya entró con Alfa: su
--     nivel, su oro, sus oficios, lo descansado y cuándo lo viste; arriba, el
--     oro de todos juntos.
-- Lo de cada personaje se anota al entrar, al subir de nivel o de oficio, al
-- cambiar tu oro y al salir: N.Datos("inicio").ficha[Nombre-Reino].
--
--   Fi.Abrir([vista])   Fi.Datos() -> lo de este personaje (para el banco)
--   Fi.Personajes() -> { pj, ... } ordenados   Fi.Anotar()   Fi.Ventana() -> v | nil

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, tonumber, tostring, format, floor, max, min, sort, concat =
	type, ipairs, pairs, pcall, tonumber, tostring, string.format, math.floor, math.max, math.min, table.sort, table.concat

local Fi = {}
M.Ficha = Fi

local DOT = "  \194\183  "
local ESP = K.ESP

-- Los oficios (línea del juego) con su ícono del juego y su orden.
Fi.OFICIOS = {
	[164] = "Interface\\Icons\\Trade_BlackSmithing", [165] = "Interface\\Icons\\Trade_LeatherWorking",
	[171] = "Interface\\Icons\\Trade_Alchemy", [182] = "Interface\\Icons\\Trade_Herbalism",
	[185] = "Interface\\Icons\\INV_Misc_Food_15", [186] = "Interface\\Icons\\Trade_Mining",
	[197] = "Interface\\Icons\\Trade_Tailoring", [202] = "Interface\\Icons\\Trade_Engineering",
	[333] = "Interface\\Icons\\Trade_Engraving", [356] = "Interface\\Icons\\Trade_Fishing",
	[393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
}
local SECUNDARIOS = { [185] = true, [356] = true, [129] = true }

-- (nunca «N.Leer(x) or x»: el «or» devolvería el secreto)
local function leer(v) return N.Leer(v) end
local function numero(v) return N.LeerNumero(v, nil) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Lo de este personaje (todo del juego, en vivo)
---------------------------------------------------------------------------
local function clave()
	local n = leer(UnitName and UnitName("player"))
	local r = N.Reino and N.Reino() or leer(GetRealmName and GetRealmName())
	if type(n) ~= "string" or n == "" then return nil end
	return n .. "-" .. (type(r) == "string" and r or "")
end

function Fi.Oficios()
	local out = {}
	local S = C_SkillInfo
	if not (S and S.GetNumSkillLines and S.GetSkillLineInfo) then return out end
	local ok, n = pcall(S.GetNumSkillLines)
	for i = 1, ok and numero(n) or 0 do
		local bien, info = pcall(S.GetSkillLineInfo, i)
		if bien and type(info) == "table" and leer(info.isHeader) ~= true then
			local linea, r, mx = numero(info.skillID), numero(info.rank), numero(info.maxRank)
			local nombre = leer(info.skillName) or leer(info.name)
			if linea and Fi.OFICIOS[linea] and r and mx and mx > 0 then
				out[#out + 1] = { linea = linea, nombre = type(nombre) == "string" and nombre or tostring(linea), r = r, m = mx,
					secundario = SECUNDARIOS[linea] or nil }
			end
		end
	end
	sort(out, function(a, b)
		if (a.secundario and 1 or 0) ~= (b.secundario and 1 or 0) then return not a.secundario end
		return a.r > b.r
	end)
	return out
end

-- -> % (0-100) y si algo está rojo, o nil sin equipo con durabilidad.
function Fi.Durabilidad()
	if not GetInventoryItemDurability then return nil end
	local cur, mx, roto = 0, 0, false
	for ranura = 1, 18 do
		local ok, c, m = pcall(GetInventoryItemDurability, ranura)
		c, m = ok and numero(c), ok and numero(m)
		if c and m and m > 0 then
			cur, mx = cur + c, mx + m
			if c / m < 0.2 then roto = true end
		end
	end
	if mx <= 0 then return nil end
	return floor(cur / mx * 100 + 0.5), roto
end

-- 1.4.2: las recargas largas de oficio (de un día o más): transmutar, la
-- tela lunar y el salero. Los nombres los da el juego en tu idioma.
-- -> { { nombre, listo (hora del servidor en que queda lista; 0 = ya) }, ... }
Fi.RECARGAS = { { hechizo = 17187 }, { hechizo = 18560 }, { objeto = 15846 } }
function Fi.Recargas()
	local out = {}
	local ahora, t = time and time() or 0, GetTime and GetTime() or 0
	for _, r in ipairs(Fi.RECARGAS) do
		local nombre, inicio, dura
		if r.hechizo then
			local sabe = IsPlayerSpell and select(2, pcall(IsPlayerSpell, r.hechizo))
			if sabe == true then
				local S = C_Spell
				local okN, n = pcall(function() return S and S.GetSpellName and S.GetSpellName(r.hechizo) end)
				nombre = okN and leer(n) or nil
				local okC, c = pcall(function() return S and S.GetSpellCooldown and S.GetSpellCooldown(r.hechizo) end)
				if okC and type(c) == "table" then inicio, dura = numero(c.startTime), numero(c.duration) end
			end
		elseif r.objeto then
			local okT, cuantos = pcall(function() return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(r.objeto) end)
			if okT and (numero(cuantos) or 0) > 0 then
				local okN, n = pcall(function() return C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.objeto) end)
				nombre = okN and leer(n) or nil
				local okC, a, b = pcall(function() return C_Container and C_Container.GetItemCooldown and C_Container.GetItemCooldown(r.objeto) end)
				if okC then inicio, dura = numero(a), numero(b) end
			end
		end
		if type(nombre) == "string" and nombre ~= "" then
			local falta = (inicio and dura and dura > 1.6) and max(0, inicio + dura - t) or 0
			out[#out + 1] = { nombre = nombre, listo = falta > 0 and floor(ahora + falta) or 0 }
		end
	end
	return out
end

-- -> libres, total (sin las bolsas especiales: munición, hierbas...)
function Fi.Bolsas()
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerNumFreeSlots) then return nil end
	local libres, total = 0, 0
	for bolsa = 0, tonumber(NUM_BAG_SLOTS) or 4 do
		local okS, n = pcall(C.GetContainerNumSlots, bolsa)
		local okF, f, fam = pcall(C.GetContainerNumFreeSlots, bolsa)
		n, f, fam = okS and numero(n) or 0, okF and numero(f) or 0, okF and numero(fam) or 0
		if n > 0 and (fam or 0) == 0 then libres, total = libres + f, total + n end
	end
	return libres, total
end

local function experiencia()
	local nivel = numero(UnitLevel and UnitLevel("player")) or 1
	local maxNivel = numero(GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
	local xp, mx = numero(UnitXP and UnitXP("player")) or 0, numero(UnitXPMax and UnitXPMax("player")) or 0
	local desc = numero(GetXPExhaustion and GetXPExhaustion()) or 0
	return { nivel = nivel, maximo = nivel >= maxNivel, xp = xp, mx = mx, descansada = mx > 0 and min(1.5, desc / mx) or 0 }
end

local function jugado()
	local J = M.Jugado
	local ok, d = pcall(function() return J and J.Datos and J.Datos() end)
	return ok and type(d) == "table" and numero(d.total) or nil
end

-- Todo lo de este personaje, en vivo.
function Fi.Datos()
	local d = {}
	d.nombre = leer(UnitName and UnitName("player"))
	local _, clase = nil, nil
	if UnitClass then d.claseNombre, clase = UnitClass("player") end
	d.claseNombre, d.clase = leer(d.claseNombre), leer(clase)
	if UnitRace then d.raza = leer((UnitRace("player"))) end
	local gremio = GetGuildInfo and leer((GetGuildInfo("player")))
	d.hermandad = type(gremio) == "string" and gremio ~= "" and gremio or nil
	local zona = GetRealZoneText and leer(GetRealZoneText())
	d.zona = type(zona) == "string" and zona ~= "" and zona or nil
	d.faccion = leer(UnitFactionGroup and UnitFactionGroup("player"))
	d.xp = experiencia()
	d.nivel = d.xp.nivel
	d.oro = numero(GetMoney and GetMoney()) or 0
	d.durabilidad, d.roto = Fi.Durabilidad()
	d.libres, d.espacio = Fi.Bolsas()
	d.jugado = jugado()
	d.oficios = Fi.Oficios()
	d.recargas = Fi.Recargas()
	return d
end

---------------------------------------------------------------------------
-- Lo de todos tus personajes (lo que se anotó al jugar con cada uno)
---------------------------------------------------------------------------
local function guardados()
	local db = N.Datos("inicio")
	db.ficha = type(db.ficha) == "table" and db.ficha or {}
	return db.ficha
end

function Fi.Anotar()
	local k = clave()
	if not k then return end
	local d = Fi.Datos()
	local of = {}
	for i, o in ipairs(d.oficios) do of[i] = { linea = o.linea, nombre = o.nombre, r = o.r, m = o.m } end
	local g = guardados()
	local antes = type(g[k]) == "table" and g[k] or {}
	g[k] = { nombre = d.nombre, reino = k:match("%-(.*)$"), clase = d.clase, claseNombre = d.claseNombre, raza = d.raza,
		faccion = d.faccion, nivel = d.nivel, oro = d.oro, oficios = of, descansada = d.xp.descansada,
		jugado = d.jugado or antes.jugado, zona = d.zona, visto = time and time() or 0, recargas = d.recargas }
end

function Fi.Personajes()
	local out = {}
	for k, p in pairs(guardados()) do
		if type(p) == "table" and type(p.nombre) == "string" then p.clave = k out[#out + 1] = p end
	end
	sort(out, function(a, b)
		if (a.nivel or 0) ~= (b.nivel or 0) then return (a.nivel or 0) > (b.nivel or 0) end
		return a.nombre < b.nombre
	end)
	return out
end

local function anotarPronto() if N.Una then N.Una("inicio.ficha.anotar", 2, function() if not enCombate() then Fi.Anotar() end end) end end
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "PLAYER_MONEY", "TIME_PLAYED_MSG", "ZONE_CHANGED_NEW_AREA" }) do
	A.RegisterEvent(ev, anotarPronto)
end
A.RegisterEvent("PLAYER_LOGOUT", function() pcall(Fi.Anotar) end)

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v, ui, vista = nil, {}, "yo"
local ESCENA_W = 280

local function colorClase(clase)
	local c = clase and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(clase)
	if c and c.GetRGB then return c:GetRGB() end
	c = clase and RAID_CLASS_COLORS and RAID_CLASS_COLORS[clase]
	if c then return c.r, c.g, c.b end
	return K.Color("texto")
end

-- Una cifra: ícono, título chico y el valor grande que nunca se sale (K.Encajar).
local function nuevaCifra(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "linea", corte = K.CORTE.control })
	c.Icono = K.Icono(c, "ic-oro", 14, "acento")
	c.Icono:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -10)
	c.Titulo = K.Texto(c, "mayus", "textoTenue")
	c.Titulo:SetPoint("LEFT", c.Icono, "RIGHT", 6, 0)
	c.Valor = K.Texto(c, "titulo", "texto")
	c.Valor:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 9)
	function c:Set(icono, titulo, valor, color)
		K.SetIcono(self.Icono, icono, "acento")
		K.Escribir(self.Titulo, K.Mayus(titulo))
		K.Escribir(self.Valor, valor)
		K.ColorTexto(self.Valor, color or "texto")
	end
	function c:Acomodar(w, h)
		self:SetSize(w, h)
		K.Encajar(self.Titulo, w - 36, { "mayus" })
		K.Encajar(self.Valor, w - 20, { "titulo", "subtitulo", "cuerpo" })
	end
	return c
end

local function nuevoOficio(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(24, 24)
	f.Icono:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Nombre = K.Texto(f, "etiqueta", "texto")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -1)
	f.Cuenta = K.Texto(f, "numero", "textoSuave")
	f.Cuenta:SetJustifyH("RIGHT")
	f.Cuenta:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
	f.Barra = K.Progreso(f, { alto = 5, tono = "acento" })
	f.Barra:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 32, 2)
	function f:Set(o)
		self.Icono:SetTexture(Fi.OFICIOS[o.linea])
		K.Escribir(self.Nombre, o.nombre)
		K.Escribir(self.Cuenta, format("%d / %d", o.r, o.m))
		self.Barra:Set(o.r, o.m)
		self.Barra:SetTono(o.r >= o.m and "exito" or "acento")
	end
	function f:Acomodar(w)
		self:SetSize(w, 28)
		self.Barra:Acomodar(w - 32)
		K.Encajar(self.Cuenta, 70, { "numero", "pequeno" })
		K.Encajar(self.Nombre, w - 32 - K.AnchoTexto(self.Cuenta) - 8, { "etiqueta", "pequeno" })
	end
	return f
end

local function nuevaFilaSigue(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Icono = K.Icono(f, "ic-flecha", 14, "acento")
	f.Icono:SetPoint("LEFT", f, "LEFT", 10, 0)
	f.Texto = K.Texto(f, "cuerpo", "texto")
	f.Texto:SetPoint("LEFT", f, "LEFT", 32, 0)
	f.Boton = K.Boton(f, "", function() if f.alfaClic then K.Llamar(f.alfaClic) end end, { tipo = "secundario", tam = "chico" })
	f.Boton:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	function f:Set(s)
		K.SetIcono(self.Icono, s.icono or "ic-flecha", s.tono or "acento")
		K.Escribir(self.Texto, s.texto)
		self.Boton:SetTexto(s.boton or L["Ir"])
		self.alfaClic = s.alClic
		self.Boton:SetShown(s.alClic ~= nil)
	end
	function f:Acomodar(w)
		self:SetSize(w, 36)
		local bw = self.Boton:IsShown() and (self.Boton:AnchoNatural() + 16) or 8
		K.Encajar(self.Texto, w - 32 - bw, { "cuerpo", "etiqueta", "pequeno" })
	end
	return f
end

-- «Lo que sigue»: lo más útil ahora, cada uno con su botón.
function Fi.LoQueSigue(d)
	local out = {}
	local E = A.Engine
	local okG, g = pcall(function() return E and E.GetGuide and E.GetGuide() end)
	local okS, paso = pcall(function() return E and E.GetCurrentStep and E.GetCurrentStep() end)
	if okG and type(g) == "table" then
		local titulo = okS and type(paso) == "table" and leer(paso.title) or leer(g.title)
		out[#out + 1] = { icono = "ic-huella", texto = format(L["Tu guía: %s"], tostring(titulo or "")), boton = L["Seguir"],
			alClic = function() local P = M.Pagina if P and P.SeguirRuta then P.SeguirRuta() end end }
	end
	if d.durabilidad and d.durabilidad < 35 then
		out[#out + 1] = { icono = "ic-aviso", tono = "aviso", texto = format(L["Tu equipo está al %d %%: repáralo pronto"], d.durabilidad),
			boton = L["Llévame"], alClic = function() local R = rawget(_G, "AlfaRuta") if R and R.Cerca then R.Cerca("reparar") end end }
	end
	if d.libres and d.espacio and d.espacio > 0 and d.libres <= 4 then
		out[#out + 1] = { icono = "ic-bolsas", tono = "aviso", texto = format(L["Te quedan %d espacios en tus bolsas"], d.libres),
			boton = L["Ver"], alClic = function() N.Abrir("bolsas") end }
	end
	for _, r in ipairs(d.recargas or {}) do
		if r.listo == 0 then out[#out + 1] = { icono = "ic-reloj", texto = format(L["%s ya se puede usar"], r.nombre) } end
	end
	for _, o in ipairs(d.oficios) do
		if #out >= 4 then break end
		if o.r < o.m then
			out[#out + 1] = { icono = "ic-oficios", texto = format(L["Sube %s: %d / %d"], o.nombre, o.r, o.m), boton = L["Ver"],
				alClic = function() N.Abrir("comercio") end }
		end
	end
	if #out == 0 then out[1] = { icono = "ic-lobo", texto = L["Todo en orden. ¿Salimos de caza?"] } end
	return out
end

local function armar()
	v = K.Ventana({ nombre = "AlfaFicha", titulo = L["Tu ficha"], subtitulo = L["Tu personaje y la manada de tu cuenta"],
		icono = "ic-personaje", ancho = 900, alto = 620, desplazar = true })
	local c = v.Cuerpo
	ui.vistas = K.Segmentos(c, { estilo = "pildoras", valor = vista,
		opciones = { { valor = "yo", texto = L["Tu personaje"], icono = "ic-personaje" }, { valor = "todos", texto = L["Tus personajes"], icono = "ic-personajes" } },
		alCambiar = function(x) vista = x Fi.Pintar() end })
	-- La escena: la noche de Alfa y tu personaje en 3D.
	ui.escena = CreateFrame("Frame", nil, c)
	ui.escena.caja = K.Caja(ui.escena, { fondo = "hundido", borde = "linea", corte = K.CORTE.panel })
	ui.cielo = CreateFrame("Frame", nil, ui.escena)
	ui.cielo:SetPoint("TOPLEFT", ui.escena, "TOPLEFT", 1, -1)
	ui.cielo:SetPoint("BOTTOMRIGHT", ui.escena, "BOTTOMRIGHT", -1, 1)
	if ui.cielo.SetClipsChildren then ui.cielo:SetClipsChildren(true) end
	local Es = rawget(_G, "AlfaEscritorio")
	if type(Es) == "table" and type(Es.Cielo) == "function" then pcall(Es.Cielo, ui.cielo) end
	local okM, modelo = pcall(CreateFrame, "PlayerModel", nil, ui.escena)
	if okM and modelo then
		ui.modelo = modelo
		modelo:SetPoint("TOPLEFT", ui.escena, "TOPLEFT", 4, -4)
		modelo:SetPoint("BOTTOMRIGHT", ui.escena, "BOTTOMRIGHT", -4, 26)
		ui.giro = 0
		-- Arrastra para girarlo (solo mientras arrastras corre algo por cuadro).
		modelo:EnableMouse(true)
		modelo:SetScript("OnMouseDown", function(self) self.alfaX = GetCursorPosition and GetCursorPosition() or 0 end)
		modelo:SetScript("OnMouseUp", function(self) self.alfaX = nil end)
		modelo:SetScript("OnHide", function(self) self.alfaX = nil end)
		modelo:SetScript("OnUpdate", function(self)
			if not self.alfaX then return end
			local x = GetCursorPosition and GetCursorPosition() or self.alfaX
			ui.giro = (ui.giro or 0) + (x - self.alfaX) / 90
			self.alfaX = x
			if self.SetFacing then pcall(self.SetFacing, self, ui.giro) end
		end)
	end
	ui.girar = K.Texto(ui.escena, "pequeno", "textoTenue")
	ui.girar:SetPoint("BOTTOM", ui.escena, "BOTTOM", 0, 8)
	K.Escribir(ui.girar, L["Arrastra para girar"])
	-- Lo de la derecha.
	ui.nombre = K.Texto(c, "portada", "texto")
	ui.linea = K.Texto(c, "cuerpo", "textoSuave")
	ui.lugar = K.Texto(c, "nota", "textoTenue")
	ui.xpTitulo = K.Texto(c, "mayus", "textoTenue")
	ui.xpTexto = K.Texto(c, "pequeno", "textoSuave")
	ui.xpTexto:SetJustifyH("RIGHT")
	ui.xp = K.Progreso(c, { alto = 8, tono = "acento" })
	ui.descanso = K.Plano(ui.xp, "acento", "ARTWORK", 1)
	ui.descanso:SetAlpha(0.45)
	ui.cifras = {}
	for i = 1, 4 do ui.cifras[i] = nuevaCifra(c) end
	ui.secOficios = K.Texto(c, "mayus", "textoTenue")
	ui.oficios = {}
	ui.secSigue = K.Texto(c, "mayus", "textoTenue")
	ui.sigue = {}
	-- «Tus personajes».
	ui.total = K.Texto(c, "subtitulo", "texto")
	ui.filas = {}
	-- El pie.
	ui.foto = K.Boton(v, L["Tomar foto"], function() Fi.Foto() end, { tipo = "secundario", icono = "ic-grabar" })
	v:SetPie({ ui.foto }, { K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "fantasma" }) })
	K.ConInfo(ui.foto, L["Tomar foto"], L["Deja solo tu ficha a la vista y toma una captura de pantalla (queda en la carpeta Screenshots de tu WoW)."])
	v.alAcomodar = function() if v:IsShown() then Fi.Pintar() end end
end
function Fi.Ventana() return v end

local function texto(fs, t, x, y, ancho, lineas)
	K.Escribir(fs, t or "")
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	fs:Show()
	return y + K.Parrafo(fs, ancho, lineas or 1)
end

local function pintarYo(x0, y0, ancho)
	local d = Fi.Datos()
	local escenaW = ancho >= 720 and ESCENA_W or 0
	local alto = 0
	if escenaW > 0 then
		ui.escena:ClearAllPoints()
		ui.escena:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x0, -y0)
		ui.escena:SetSize(escenaW, 420)
		ui.escena:Show()
		if ui.modelo then pcall(ui.modelo.SetUnit, ui.modelo, "player") if ui.modelo.SetFacing then pcall(ui.modelo.SetFacing, ui.modelo, ui.giro or 0) end end
		alto = 420
	else
		ui.escena:Hide()
	end
	local x = x0 + (escenaW > 0 and escenaW + ESP.l or 0)
	local w = ancho - (x - x0)
	local y = y0
	-- Nombre, línea y lugar.
	ui.nombre:SetTextColor(colorClase(d.clase))
	y = texto(ui.nombre, d.nombre or "", x, y, w, 1)
	K.Encajar(ui.nombre, w, { "portada", "titulo" })
	local partes = { format(L["Nivel %d"], d.nivel or 1) }
	if d.raza then partes[#partes + 1] = d.raza end
	if d.claseNombre then partes[#partes + 1] = d.claseNombre end
	y = texto(ui.linea, concat(partes, DOT), x, y + 4, w, 1)
	local lugar = {}
	if d.hermandad then lugar[#lugar + 1] = "<" .. d.hermandad .. ">" end
	if d.zona then lugar[#lugar + 1] = d.zona end
	y = texto(ui.lugar, concat(lugar, DOT), x, y + 2, w, 1) + ESP.m
	-- La experiencia.
	local xp = d.xp
	texto(ui.xpTitulo, K.Mayus(L["Experiencia"]), x, y, w * 0.5, 1)
	local tx
	if xp.maximo then
		tx = L["Nivel máximo"]
	else
		local pct = xp.mx > 0 and floor(xp.xp / xp.mx * 100) or 0
		tx = format(L["%d %% de experiencia"], pct)
		if xp.descansada > 0 then tx = tx .. DOT .. format(L["%d %% descansada"], floor(xp.descansada * 100 + 0.5)) end
	end
	K.Escribir(ui.xpTexto, tx)
	ui.xpTexto:ClearAllPoints()
	ui.xpTexto:SetPoint("TOPRIGHT", v.Cuerpo, "TOPLEFT", x + w, -y)
	K.Encajar(ui.xpTexto, w * 0.6, { "pequeno" })
	y = y + 16
	ui.xp:ClearAllPoints()
	ui.xp:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	ui.xp:Acomodar(w)
	ui.xp:Set(xp.maximo and 1 or xp.xp, xp.maximo and 1 or xp.mx)
	-- Lo descansado, encima de la barra (hasta donde llega).
	local frac = xp.maximo and 0 or (xp.mx > 0 and xp.xp / xp.mx or 0)
	local hasta = min(1, frac + (xp.descansada or 0))
	ui.descanso:ClearAllPoints()
	ui.descanso:SetPoint("TOPLEFT", ui.xp, "TOPLEFT", w * frac, 0)
	ui.descanso:SetPoint("BOTTOMLEFT", ui.xp, "BOTTOMLEFT", w * frac, 0)
	ui.descanso:SetWidth(max(0.01, w * (hasta - frac)))
	ui.descanso:SetShown(hasta > frac)
	y = y + 8 + ESP.l
	-- Las cuatro cifras (2 x 2 si no caben en una fila).
	local datos = {
		{ "ic-oro", L["Oro"], N.Dinero(d.oro, false) },
		{ "ic-comodidades", L["Durabilidad"], d.durabilidad and format("%d %%", d.durabilidad) or "—", d.roto and "peligro" or (d.durabilidad and d.durabilidad < 35 and "aviso") or nil },
		{ "ic-bolsas", L["Espacio en bolsas"], d.espacio and format(L["%d / %d libres"], d.libres, d.espacio) or "—", (d.libres and d.libres <= 4) and "aviso" or nil },
		{ "ic-reloj", L["Tiempo jugado"], d.jugado and N.Duracion(d.jugado, true) or "—" },
	}
	local porFila = w >= 4 * 150 + 3 * ESP.s and 4 or 2
	local cw = floor((w - (porFila - 1) * ESP.s) / porFila)
	for i, dd in ipairs(datos) do
		local cf = ui.cifras[i]
		cf:Set(dd[1], dd[2], dd[3], dd[4])
		local col, fila = (i - 1) % porFila, floor((i - 1) / porFila)
		cf:ClearAllPoints()
		cf:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x + col * (cw + ESP.s), -(y + fila * (64 + ESP.s)))
		cf:Acomodar(cw, 64)
		cf:Show()
	end
	y = y + (porFila == 4 and 64 or 2 * 64 + ESP.s) + ESP.l
	-- Los oficios (dos columnas).
	local of = d.oficios
	if #of > 0 then
		y = texto(ui.secOficios, K.Mayus(L["Tus oficios"]), x, y, w, 1) + ESP.s
		local ow = floor((w - ESP.l) / 2)
		for i, o in ipairs(of) do
			local f = ui.oficios[i] or nuevoOficio(v.Cuerpo)
			ui.oficios[i] = f
			f:Set(o)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x + ((i - 1) % 2) * (ow + ESP.l), -(y + floor((i - 1) / 2) * 36))
			f:Acomodar(ow)
			f:Show()
		end
		y = y + math.ceil(#of / 2) * 36 + ESP.m
	else
		ui.secOficios:Hide()
	end
	for i = #of + 1, #ui.oficios do ui.oficios[i]:Hide() end
	-- Lo que sigue.
	local sigue = Fi.LoQueSigue(d)
	y = texto(ui.secSigue, K.Mayus(L["Lo que sigue"]), x, y, w, 1) + ESP.s
	for i, s in ipairs(sigue) do
		local f = ui.sigue[i] or nuevaFilaSigue(v.Cuerpo)
		ui.sigue[i] = f
		f:Set(s)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		f:Acomodar(w)
		f:Show()
		y = y + 36 + ESP.xs
	end
	for i = #sigue + 1, #ui.sigue do ui.sigue[i]:Hide() end
	return max(y, y0 + alto)
end

local function nuevaFilaPj(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Nombre = K.Texto(f, "subtitulo", "texto")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -9)
	f.Linea = K.Texto(f, "pequeno", "textoSuave")
	f.Linea:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -3)
	f.Oro = K.Texto(f, "etiqueta", "texto")
	f.Oro:SetJustifyH("RIGHT")
	f.Oro:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -9)
	f.Visto = K.Texto(f, "pequeno", "textoTenue")
	f.Visto:SetJustifyH("RIGHT")
	f.Visto:SetPoint("TOPRIGHT", f.Oro, "BOTTOMRIGHT", 0, -3)
	function f:Set(p, esYo)
		K.Escribir(self.Nombre, p.nombre .. (esYo and ("  " .. L["(tú)"]) or ""))
		self.Nombre:SetTextColor(colorClase(p.clase))
		local partes = { format(L["Nivel %d"], p.nivel or 1) }
		if p.claseNombre then partes[#partes + 1] = p.claseNombre end
		local ofs = {}
		for _, o in ipairs(type(p.oficios) == "table" and p.oficios or {}) do
			if not SECUNDARIOS[o.linea] then ofs[#ofs + 1] = format("%s %d", o.nombre or "?", o.r or 0) end
		end
		if #ofs > 0 then partes[#partes + 1] = concat(ofs, ", ") end
		if (p.descansada or 0) > 0.01 then partes[#partes + 1] = format(L["%d %% descansada"], floor(p.descansada * 100 + 0.5)) end
		-- 1.4.2: sus recargas de oficio (lista o cuánto falta).
		local ahoraR = time and time() or 0
		for _, r in ipairs(type(p.recargas) == "table" and p.recargas or {}) do
			if type(r.nombre) == "string" then
				local falta = (tonumber(r.listo) or 0) - ahoraR
				partes[#partes + 1] = falta > 0 and format(L["%s: en %s"], r.nombre, N.Duracion(falta, true)) or format(L["%s: ya puedes"], r.nombre)
			end
		end
		K.Escribir(self.Linea, concat(partes, DOT))
		K.Escribir(self.Oro, N.Dinero(p.oro or 0, false))
		local ahora = time and time() or 0
		local hace = max(60, ahora - (p.visto or ahora))
		local cuando = hace >= 2 * 86400 and format(L["Hace %d días"], floor(hace / 86400)) or format(L["Hace %s"], N.Duracion(hace, true))
		K.Escribir(self.Visto, esYo and L["Ahora"] or cuando)
	end
	function f:Acomodar(w)
		self:SetSize(w, 52)
		local dw = max(K.AnchoTexto(self.Oro), K.AnchoTexto(self.Visto))
		K.Encajar(self.Nombre, w - 24 - dw - 16, { "subtitulo", "cuerpo" })
		K.Encajar(self.Linea, w - 24 - dw - 16, { "pequeno" })
	end
	return f
end

local function pintarTodos(x, y, w)
	local lista = Fi.Personajes()
	local yo = clave()
	local total = 0
	for _, p in ipairs(lista) do total = total + (tonumber(p.oro) or 0) end
	y = texto(ui.total, format(L["%s entre tus %d personajes"], N.Dinero(total, false), #lista), x, y, w, 1) + ESP.m
	for i, p in ipairs(lista) do
		local f = ui.filas[i] or nuevaFilaPj(v.Cuerpo)
		ui.filas[i] = f
		f:Set(p, p.clave == yo)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		f:Acomodar(w)
		f:Show()
		y = y + 52 + ESP.xs
	end
	for i = #lista + 1, #ui.filas do ui.filas[i]:Hide() end
	return y
end

function Fi.Pintar()
	if not (v and v:IsShown()) then return end
	pcall(Fi.Anotar)
	local m = v.margen or ESP.l
	local ancho = v:AnchoCuerpo() - 8
	local x, y = m, ESP.m
	ui.vistas:SetValor(vista)
	ui.vistas:ClearAllPoints()
	ui.vistas:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	y = y + ui.vistas:Acomodar(ancho - x) + ESP.l
	local yo = vista ~= "todos"
	for _, w in ipairs({ ui.escena, ui.nombre, ui.linea, ui.lugar, ui.xpTitulo, ui.xpTexto, ui.xp, ui.secOficios, ui.secSigue }) do w:SetShown(yo) end
	for _, c in ipairs(ui.cifras) do c:SetShown(yo) end
	for _, f in ipairs(ui.oficios) do f:SetShown(false) end
	for _, f in ipairs(ui.sigue) do f:SetShown(false) end
	ui.total:SetShown(not yo)
	for _, f in ipairs(ui.filas) do f:SetShown(false) end
	ui.foto:SetShown(yo)
	if yo then y = pintarYo(x, y, ancho - x) else y = pintarTodos(x, y, ancho - x) end
	v:SetAltoContenido(y + ESP.l)
end

function Fi.Abrir(cual)
	if not v then armar() end
	if cual == "todos" or cual == "yo" then vista = cual end
	v:Abrir()
	Fi.Pintar()
	return v
end

-- «Tomar foto»: el juego sin interfaz un momento, la captura y todo de vuelta.
function Fi.Foto()
	if enCombate() or not Screenshot then return false end
	-- Solo la ficha a la vista (Alt+Z del juego no esconde las ventanas de Alfa a medias).
	local otros = {}
	for _, w in ipairs(K.VENTANAS or {}) do
		if w ~= v and w.IsShown and w:IsShown() then otros[#otros + 1] = w w:Hide() end
	end
	if N.Una then
		N.Una("inicio.ficha.foto", 0.2, function()
			pcall(Screenshot)
			N.Una("inicio.ficha.fotoVuelve", 0.6, function() for _, w in ipairs(otros) do w:Show() end end)
		end)
	end
	return true
end

A.RegisterCommand("ficha", function(resto)
	resto = type(resto) == "string" and resto:lower() or ""
	Fi.Abrir((resto:find("todo") or resto:find("pj") or resto:find("alt")) and "todos" or "yo")
end, L["tu ficha: tu personaje en 3D, tus cifras, tus oficios y todos tus personajes"])

AlfaInicio = type(rawget(_G, "AlfaInicio")) == "table" and rawget(_G, "AlfaInicio") or {}
AlfaInicio.Ficha = function(cual) return Fi.Abrir(cual) end
