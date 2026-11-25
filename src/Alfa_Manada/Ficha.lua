-- Alfa - La Jauría: la ficha de cada lobo (1.3.8). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Clic en la tarjeta de un lobo (página de La Jauría): su ficha en una
-- ventana chica. Lo que ya se sabe de él (nivel, clase y dónde anda, de
-- Gente.lua; lo que carga, de «¿Quién tiene...?») sale al momento; sus
-- oficios con su habilidad y lo que puede fabricarte se le preguntan a su
-- Alfa por susurro oculto, y su Alfa contesta solo si él lo permite
-- (manada.ficha, de fábrica sí) y solo a alguien de su hermandad o de su
-- grupo. Lo que se comparte: tu nivel, tu clase, tus oficios (la línea y su
-- habilidad) y hasta OBJETOS de lo que fabricas (de las recetas que guardó
-- Comercio al abrir tus profesiones; sin tocarlas). Nada sale al chat.
-- Desde la ficha: «Susurrar», «Invitar» y compartirle tu plan o tu guía
-- (Compartir.lua).
--
-- Mensajes (Red.lua, solo por susurro, con tu facción):
--   1h|?                                          ¿me enseñas tu ficha?
--   1h|f|<nivel>|<CLASE>|<l>:<r>:<m>,...|<id>,...|<guía>|<paso>
--                                                 mi ficha (línea, habilidad, máximo; objetos;
--                                                 1.4.0: la guía que sigo y su paso, 54)
-- (1.4.0) Un Alfa 1.3.x no manda los dos últimos: la ficha dice que su Alfa no
-- cuenta su guía. Con la tuya en la mano, «Seguir la misma» (Compartir.lua).
-- Y «Silenciar sus avisos» (Callados.lua, 56).
-- Un pedido por persona cada PEDIR s; una respuesta por persona cada RESPONDER s.
--
--   Fi.Pedir(f) -> ok   Fi.De(clave) -> ficha | nil   Fi.Mia() -> lo que contestarías
--   Fi.Abrir(f)   Fi.Texto(f) -> texto de la ficha (para la ventana y el banco)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local U, L, ID = M.U, M.L, M.ID

local type, tonumber, tostring, pairs, ipairs, pcall, format, concat, sort = type, tonumber, tostring, pairs, ipairs, pcall, string.format, table.concat, table.sort

local Fi = {}
M.Ficha = Fi

local V = "1"
local PEDIR = 20      -- segundos entre dos pedidos a la misma persona
local RESPONDER = 30  -- segundos entre dos respuestas a la misma persona
local ESPERA = 8      -- segundos esperando su respuesta
local OBJETOS = 12    -- objetos que fabricas, como mucho
local LARGO = 230     -- (1.4.0) lo más que mide la ficha (la Red le suma su versión y la facción)
local OFICIOS = { [164] = true, [165] = true, [171] = true, [182] = true, [185] = true, [186] = true, [197] = true,
	[202] = true, [333] = true, [356] = true, [393] = true, [129] = true }
local NOMBRES = { [164] = "Herrería", [165] = "Peletería", [171] = "Alquimia", [182] = "Herboristería", [185] = "Cocina",
	[186] = "Minería", [197] = "Sastrería", [202] = "Ingeniería", [333] = "Encantamiento", [356] = "Pesca",
	[393] = "Desuello", [129] = "Primeros auxilios" }

local function activo() return N.Get(ID, "ficha") ~= false end
local function num(v) v = U.Leer(v) return tonumber(v) end

---------------------------------------------------------------------------
-- Lo mío
---------------------------------------------------------------------------

local function misOficios()
	local out = {}
	local S = C_SkillInfo
	if not (S and S.GetNumSkillLines and S.GetSkillLineInfo) then return out end
	local ok, n = pcall(S.GetNumSkillLines)
	for i = 1, ok and num(n) or 0 do
		local bien, info = pcall(S.GetSkillLineInfo, i)
		if bien and type(info) == "table" and U.Leer(info.isHeader) ~= true then
			local linea, r, mx = num(info.skillID), num(info.rank), num(info.maxRank)
			if linea and OFICIOS[linea] and r and mx and mx > 0 then out[#out + 1] = { linea = linea, r = r, m = mx } end
		end
	end
	sort(out, function(a, b) return a.r > b.r end)
	return out
end

-- Lo que fabricas: las recetas que guardó Comercio para este personaje.
local function misObjetos()
	local out, vistos = {}, {}
	local d = N.Datos("comercio")
	local recetas = type(d) == "table" and type(d.recetas) == "table" and d.recetas or {}
	local yo = UnitName and U.Leer(UnitName("player")) or nil
	local mia
	for _, f in pairs(recetas) do
		if type(f) == "table" and f.nombre == yo and type(f.r) == "table" then mia = f break end
	end
	if not mia then return out end
	local calidad = C_Item and C_Item.GetItemQualityByID
	for _, rec in pairs(mia.r) do
		local id = type(rec) == "table" and tonumber(rec.o)
		if id and not vistos[id] then
			vistos[id] = true
			local q = 1
			if type(calidad) == "function" then
				local ok, v = pcall(calidad, id)
				q = ok and num(v) or 1
			end
			out[#out + 1] = { id = id, q = q or 1 }
		end
	end
	sort(out, function(a, b) if a.q ~= b.q then return a.q > b.q end return a.id > b.id end)
	for i = #out, OBJETOS + 1, -1 do out[i] = nil end
	return out
end

function Fi.Mia()
	local _, clase = nil, nil
	if UnitClass then _, clase = UnitClass("player") end
	clase = type(U.Leer(clase)) == "string" and clase or ""
	-- 1.4.0 (54): la guía que sigues y su paso (si sigues una).
	local guia, paso
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.GuiaActual) == "function" then
		local ok, g = pcall(R.GuiaActual)
		if ok and type(g) == "table" and type(g.id) == "string" then
			guia = g.id:gsub("[|%c]", "")
			if guia == "" or #guia > 120 then guia = nil end
		end
	end
	if guia then
		local E = A.Engine
		local ok, n = pcall(function() return E and E.GetStepIndex and E.GetStepIndex() end)
		paso = ok and num(n) or nil
	end
	return { nivel = num(UnitLevel and UnitLevel("player")) or 0, clase = clase, oficios = misOficios(), objetos = misObjetos(),
		guia = guia, paso = paso }
end

local function armar(m)
	local of, ob = {}, {}
	for _, o in ipairs(m.oficios) do of[#of + 1] = format("%d:%d:%d", o.linea, o.r, o.m) end
	for _, o in ipairs(m.objetos or {}) do ob[#ob + 1] = tostring(o.id) end
	local function texto(n, conGuia)
		local t = format("%sh|f|%d|%s|%s|%s", V, m.nivel, m.clase, concat(of, ","), concat(ob, ",", 1, n))
		if conGuia and m.guia then t = t .. "|" .. m.guia .. "|" .. tostring(m.paso or 0) end
		return t
	end
	-- (1.4.0) Que quepa en un mensaje: primero se quitan objetos; si aun así no
	-- cabe, sale sin la guía.
	for n = #ob, 0, -1 do
		local t = texto(n, true)
		if #t <= LARGO then return t end
	end
	for n = #ob, 0, -1 do
		local t = texto(n, false)
		if #t <= LARGO then return t end
	end
	return texto(0, false)
end
Fi.Armar = armar

---------------------------------------------------------------------------
-- ¿Es de mi hermandad o de mi grupo?
---------------------------------------------------------------------------

local function deMiHermandad(remitente)
	if not U.EnHermandad() then return false end
	local clave = U.Clave(remitente)
	local n = GetNumGuildMembers and select(2, pcall(GetNumGuildMembers))
	n = tonumber(U.Leer(n)) or 0
	for i = 1, n do
		local ok, nombre = pcall(GetGuildRosterInfo, i)
		if ok and U.Clave(nombre) == clave then return true end
	end
	return false
end
Fi.DeMiHermandad = deMiHermandad

---------------------------------------------------------------------------
-- Pedir y recibir
---------------------------------------------------------------------------

local fichas = {}    -- clave -> { nivel, clase, oficios = { { linea, r, m } }, objetos = { id }, at }
local pedidos = {}   -- clave -> GetTime del pedido
local respondi = {}  -- clave -> GetTime de mi respuesta
Fi.version = 0

local abierta -- la fila de Gente de la ficha a la vista

function Fi.De(clave) return clave and fichas[clave] or nil end
function Fi.Pedido(clave) return clave and pedidos[clave] or nil end

function Fi.Pedir(f)
	local destino = f and (f.envio or f.nombre)
	local clave = f and (f.clave or U.Clave(destino))
	if not (destino and clave) then return false end
	local ahora = U.Ahora()
	if pedidos[clave] and ahora - pedidos[clave] < PEDIR then return false end
	pedidos[clave] = ahora
	return M.Red.EnviarLibre("h?:" .. clave, V .. "h|?", destino)
end

local function leerFicha(f)
	local nivel = f[2] and f[2]:match("^%d+$") and tonumber(f[2]) or nil
	local clase = f[3] and f[3]:match("^%u+$") or nil
	local out = { nivel = nivel and nivel > 0 and nivel <= 200 and nivel or nil, clase = clase, oficios = {}, objetos = {}, at = U.Ahora() }
	for l, r, m in tostring(f[4] or ""):gmatch("(%d+):(%d+):(%d+)") do
		l, r, m = tonumber(l), tonumber(r), tonumber(m)
		if OFICIOS[l] and r <= 1000 and m <= 1000 and #out.oficios < 12 then out.oficios[#out.oficios + 1] = { linea = l, r = r, m = m } end
	end
	for id in tostring(f[5] or ""):gmatch("(%d+)") do
		id = tonumber(id)
		if id and id < 10000000 and #out.objetos < OBJETOS then
			out.objetos[#out.objetos + 1] = id
			if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
		end
	end
	-- 1.4.0 (54): la guía que sigue (un Alfa 1.3.x no la manda: nil).
	local g = f[6]
	if type(g) == "string" and g ~= "" and #g <= 120 and not g:find("%c") then
		out.guia = g
		out.paso = f[7] and f[7]:match("^%d+$") and tonumber(f[7]) or nil
	end
	return out
end

M.Red.Oyentes.h = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" then return end
	if f[1] == "?" then
		if not activo() then return end
		if not (U.EnMiGrupo(remitente) or deMiHermandad(remitente)) then return end
		local ahora = U.Ahora()
		if respondi[clave] and ahora - respondi[clave] < RESPONDER then return end
		U.Podar(respondi, RESPONDER, ahora)
		respondi[clave] = ahora
		M.Red.EnviarLibre("hf:" .. clave, armar(Fi.Mia()), remitente)
	elseif f[1] == "f" then
		if not pedidos[clave] then return end -- solo lo que pedí
		fichas[clave] = leerFicha(f)
		Fi.version = Fi.version + 1
		if abierta and abierta.clave == clave then Fi.Pintar() end
	end
end

---------------------------------------------------------------------------
-- La ficha en texto
---------------------------------------------------------------------------

local function nombreOficio(l)
	local E = rawget(_G, "AlfaEnciclopedia")
	if type(E) == "table" and type(E.NombreProfesion) == "function" then
		local ok, n = pcall(E.NombreProfesion, l)
		if ok and type(n) == "string" and n ~= "" and not U.Secreto(n) then return n end
	end
	return L[NOMBRES[l] or "Oficio"]
end

local function nombreObjeto(id)
	local n
	if C_Item and C_Item.GetItemNameByID then
		local ok, v = pcall(C_Item.GetItemNameByID, id)
		if ok then n = v end
	end
	if (type(n) ~= "string" or n == "") and GetItemInfo then
		local ok, v = pcall(GetItemInfo, id)
		if ok then n = v end
	end
	if type(n) ~= "string" or n == "" or U.Secreto(n) then return nil end
	return n
end

-- -> { cabeza, oficios, objetos, lleva, estado }: líneas para la ventana.
function Fi.Texto(f)
	local x = f and fichas[f.clave]
	local partes = {}
	local nivel = (x and x.nivel) or f.nivel
	local clase = (x and x.clase) or f.clase
	if nivel then partes[#partes + 1] = format(L["Nivel %d"], nivel) end
	if clase and clase ~= "" then partes[#partes + 1] = U.NombreClase(clase) end
	if f.map then partes[#partes + 1] = U.NombreMapa(f.map) end
	-- 1.4.0: qué Alfa usa (si se sabe por su saludo).
	local ver = M.Red.VersionDe and M.Red.VersionDe(f.clave)
	if ver and ver.version then partes[#partes + 1] = format(L["Alfa %s"], ver.version) end
	local t = { cabeza = concat(partes, "  \194\183  ") }
	t.guia, t.guiaId = Fi.TextoGuia(f, x)
	if x then
		local of = {}
		for _, o in ipairs(x.oficios) do of[#of + 1] = format(L["%s: %d de %d"], nombreOficio(o.linea), o.r, o.m) end
		t.oficios = #of > 0 and concat(of, "\n") or L["No tiene oficios todavía."]
		local ob, faltan = {}, 0
		for _, id in ipairs(x.objetos) do
			local n = nombreObjeto(id)
			if n then ob[#ob + 1] = n else faltan = faltan + 1 end
		end
		if #ob == 0 then
			t.objetos = faltan > 0 and L["Cargando los nombres…"] or L["Todavía no sé qué fabrica (abre sus profesiones con Alfa)."]
		else
			t.objetos = concat(ob, ", ") .. (faltan > 0 and (" " .. format(L["y %d más"], faltan)) or "")
		end
	elseif pedidos[f.clave] then
		t.estado = U.Ahora() - pedidos[f.clave] < ESPERA and format(L["Le pregunto a %s por su ficha…"], f.nombre or "?")
			or L["No contestó: quizá no usa Alfa o no comparte su ficha."]
	end
	-- Lo que carga (de «¿Quién tiene...?»).
	local Qt = M.QuienTiene
	if Qt and Qt.Resultados then
		local lleva = {}
		for _, r in ipairs(Qt.Resultados() or {}) do
			if U.Clave(r.destino or r.nombre) == f.clave and r.objeto then lleva[#lleva + 1] = format("%s ×%d", r.objeto, tonumber(r.cuantos) or 1) end
		end
		if #lleva > 0 then t.lleva = concat(lleva, ", ") end
	end
	return t
end

-- 1.4.0 (54): la guía que sigue, en palabras. -> texto | nil, id de la guía
-- (solo si tú también la tienes: con ella, «Seguir la misma»).
function Fi.TextoGuia(f, x)
	x = x or (f and fichas[f.clave])
	if not x then return nil end
	if not x.guia then
		local nuevo = M.Red.EsNuevo and M.Red.EsNuevo(f.clave)
		if nuevo == false then return L["Su Alfa es de antes de la 1.4: no cuenta qué guía sigue."] end
		return L["Ahora no sigue ninguna guía."]
	end
	local R = rawget(_G, "AlfaRuta")
	local nombre = type(R) == "table" and type(R.NombreGuia) == "function" and R.NombreGuia(x.guia) or nil
	if type(nombre) ~= "string" or nombre == "" then return L["Sigue una guía que tu Alfa no tiene (quizá es de la otra facción)."] end
	if x.paso and x.paso > 0 then return format(L["Sigue «%s», en el paso %d."], nombre, x.paso), x.guia end
	return format(L["Sigue «%s»."], nombre), x.guia
end

-- «Seguir la misma»: la guía de ese lobo, en tu Alfa.
function Fi.SeguirSuGuia(f)
	local _, id = Fi.TextoGuia(f)
	if not (id and M.Compartir and M.Compartir.AceptarGuia) then return false end
	return M.Compartir.AceptarGuia(id, f.nombre)
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local v
local function armarVentana()
	if v then return v end
	v = K.Ventana({ nombre = "AlfaManadaFicha", titulo = L["Ficha del lobo"], icono = "ic-huella", ancho = 420, alto = 380, desplazar = true })
	local c = v.Cuerpo
	v.Cabeza = K.Texto(c, "nota", "textoSuave")
	v.Estado = K.Texto(c, "nota", "textoTenue")
	v.bloques = {}
	for _, k in ipairs({ "guia", "oficios", "objetos", "lleva" }) do
		local b = { Titulo = K.Texto(c, "subtitulo", "texto"), Texto = K.Texto(c, "texto", "textoSuave") }
		b.Texto:SetWordWrap(true)
		v.bloques[k] = b
	end
	K.Escribir(v.bloques.guia.Titulo, L["Su guía"])
	-- 1.4.0 (54, 56): seguir su misma guía y silenciar sus avisos.
	v.Misma = K.Boton(c, L["Seguir la misma"], function() if abierta then Fi.SeguirSuGuia(abierta) end end, { tipo = "secundario", tam = "chico", icono = "ic-flecha" })
	v.Callar = K.Boton(c, L["Silenciar sus avisos"], function()
		if abierta and M.Callados then M.Callados.Alternar(abierta.envio or abierta.nombre or abierta.clave) Fi.Pintar() end
	end, { tipo = "secundario", tam = "chico", icono = "ic-filtro" })
	K.Escribir(v.bloques.oficios.Titulo, L["Sus oficios"])
	K.Escribir(v.bloques.objetos.Titulo, L["Puede fabricarte"])
	K.Escribir(v.bloques.lleva.Titulo, L["Lleva"])
	v.Compartir = K.Boton(c, L["Compartirle mi plan"], function() if abierta and M.Compartir then M.Compartir.Plan(abierta) end end, { tipo = "secundario", tam = "chico", icono = "ic-lista" })
	v.Guia = K.Boton(c, L["Compartirle mi guía"], function() if abierta and M.Compartir then M.Compartir.Guia(abierta) end end, { tipo = "secundario", tam = "chico", icono = "ic-guia" })
	v.Susurrar = K.Boton(v, L["Susurrar"], function() if abierta then U.Susurrar(abierta.envio or abierta.nombre, "") end end, { tipo = "secundario" })
	v.Invitar = K.Boton(v, L["Invitar"], function()
		if abierta and U.Invitar(abierta.envio or abierta.nombre) then U.Decir(format(L["Invitaste a %s a tu grupo."], abierta.nombre or "?")) end
	end, { tipo = "primario" })
	v:SetPie({ v.Susurrar, v.Invitar })
	v.alAcomodar = function() Fi.Pintar() end
	v.alCerrar = function() abierta = nil end
	return v
end

function Fi.Pintar()
	if not (v and v:IsShown() and abierta) then return end
	local f = abierta
	local t = Fi.Texto(f)
	local m = v.margen or 24
	local ancho = v:AnchoCuerpo()
	local y = K.ESP.m
	local function poner(fs, texto, lineas)
		if not texto or texto == "" then fs:Hide() return end
		K.Escribir(fs, texto)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		y = y + K.Parrafo(fs, ancho, lineas or 8) + K.ESP.s
		fs:Show()
	end
	poner(v.Cabeza, t.cabeza, 2)
	poner(v.Estado, t.estado, 3)
	v.Misma:Hide()
	for _, k in ipairs({ "guia", "oficios", "objetos", "lleva" }) do
		local b = v.bloques[k]
		if t[k] then
			y = y + K.ESP.s
			poner(b.Titulo, b.Titulo:GetText(), 1)
			poner(b.Texto, t[k], 12)
			if k == "guia" and t.guiaId then
				v.Misma:ClearAllPoints()
				v.Misma:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
				v.Misma:Show()
				y = y + K.ALTO.botonChico + K.ESP.s
			end
		else
			b.Titulo:Hide()
			b.Texto:Hide()
		end
	end
	y = y + K.ESP.m
	local hay = M.Compartir ~= nil
	v.Compartir:SetShown(hay)
	v.Guia:SetShown(hay)
	if hay then
		v.Compartir:ClearAllPoints()
		v.Compartir:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		v.Guia:ClearAllPoints()
		v.Guia:SetPoint("LEFT", v.Compartir, "RIGHT", K.ESP.s, 0)
		local conGuia = M.Compartir.PuedeGuia and M.Compartir.PuedeGuia()
		local conPlan = M.Compartir.PuedePlan and M.Compartir.PuedePlan()
		v.Compartir:SetActivo(conPlan and true or false)
		v.Guia:SetActivo(conGuia and true or false)
		-- Si no caben juntos, uno abajo del otro.
		if K.num(v.Compartir:GetWidth(), 0) + K.ESP.s + K.num(v.Guia:GetWidth(), 0) > ancho then
			v.Guia:ClearAllPoints()
			v.Guia:SetPoint("TOPLEFT", v.Compartir, "BOTTOMLEFT", 0, -K.ESP.s)
			y = y + K.ALTO.botonChico + K.ESP.s
		end
		y = y + K.ALTO.botonChico + K.ESP.m
	end
	-- 1.4.0 (56): silenciar (o volver a oír) sus avisos.
	local Ca = M.Callados
	v.Callar:SetShown(Ca ~= nil)
	if Ca then
		local callado = Ca.Esta(f.clave)
		v.Callar:SetTexto(callado and L["Volver a oír sus avisos"] or L["Silenciar sus avisos"])
		v.Callar:ClearAllPoints()
		v.Callar:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		y = y + K.ALTO.botonChico + K.ESP.m
	end
	v:SetAltoContenido(y)
	local fuera = f.conectado == false
	v.Invitar:SetActivo(not fuera and not U.EnMiGrupo(f.envio or f.nombre))
	v.Susurrar:SetActivo(not fuera)
end

function Fi.Abrir(f)
	if type(f) ~= "table" or not f.clave then return false end
	armarVentana()
	abierta = f
	v:SetTitulo(f.nombre or L["Ficha del lobo"], L["Ficha del lobo"], "ic-huella")
	if not v:IsShown() then v:Abrir() end
	if f.conectado ~= false and not fichas[f.clave] then
		Fi.Pedir(f)
		A.After(ESPERA + 0.5, function() Fi.Pintar() end)
	end
	Fi.Pintar()
	return true
end
function Fi.Ventana() return v end
function Fi.Abierta() return abierta end

-- Para el banco.
function Fi.Olvidar() fichas, pedidos, respondi, abierta = {}, {}, {}, nil end
