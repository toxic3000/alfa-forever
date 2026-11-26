-- Alfa - Bolsas: tus conjuntos de equipo (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- Guarda con un nombre lo que llevas puesto (curar, daño, pesca...) y te lo
-- vuelve a poner con un clic, siempre fuera de combate: en combate el juego
-- no deja cambiar la armadura, así que el cambio espera al final de la pelea
-- (N.FueraDeCombate). Cada pieza se busca en tus bolsas (el mismo enlace o,
-- si no, el mismo objeto) y se pone con C_Item.EquipItemByName(enlace,
-- ranura) (ItemDocumentation.lua: sin HasRestrictions), una tras otra, como
-- «Ponte esto». Lo que no está en tus bolsas (en el banco, vendido) se dice.
-- No usa C_EquipmentSet: el gestor de equipo del juego no está en todas las
-- versiones de Forever, y esto funciona igual en todas.
-- Por personaje: N.DatosPersonaje("bolsas").conjuntos =
--   { { n = nombre, t = time(), p = { [ranura] = { i = id, l = enlace } } }, ... }
-- Ajuste bolsas.conjuntos (de fábrica, encendido).
--   Cj.Lista() ; Cj.Guardar(nombre) ; Cj.Poner(nombre) ; Cj.Olvidar(nombre)
--   Cj.Estado(c) -> puestas, enBolsas, faltan, total ; Cj.Puesto() -> nombre | nil
-- 1.3.1: una pieza en su ranura gemela (anillos 11↔12, abalorios 13↔14, armas
-- 16↔17) cuenta como puesta (Cj.DondeLaLlevas), y lo que quedó debajo de otra
-- pieza al cambiar se pone en una segunda pasada (PLAYER_EQUIPMENT_CHANGED).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, ipairs, tonumber, format, sort = type, pairs, ipairs, tonumber, string.format, table.sort

local Cj = {}
M.Conjuntos = Cj

-- Las ranuras que se guardan: cabeza a la distancia, sin la camisa ni el tabardo.
local RANURAS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAX = 10
local ORIGEN = { 0, 1, 2, 3, 4 }
-- 1.3.1: las ranuras gemelas (anillos, abalorios, las dos manos): una pieza
-- puesta en la otra cuenta como puesta.
local GEMELA = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
Cj.GEMELA = GEMELA
local SEGUNDA = 5 -- segundos: lo que queda de la segunda pasada después de esto ya no se pone

local OTRO = "\1otro" -- el valor del menú para «Otro nombre…»

-- Nombres listos para elegir (el menú de la ventana y la página).
Cj.NOMBRES = { L["Curación"], L["Daño"], L["Tanque"], L["Pesca"], L["Recolectar"], L["Ciudad"] }

local function encendido() return M.Get("conjuntos") ~= false end

local function datos()
	local d = N.DatosPersonaje(M.ID)
	if type(d.conjuntos) ~= "table" then d.conjuntos = {} end
	return d.conjuntos
end

local function buscar(nombre)
	if type(nombre) ~= "string" then return nil end
	local lista = datos()
	for i, c in ipairs(lista) do
		if type(c) == "table" and c.n == nombre then return c, i end
	end
	-- Sin distinguir mayúsculas ni acentos (desde el comando).
	local O = M.Objetos
	local buscado = O and O.Doblar(nombre) or nombre:lower()
	for i, c in ipairs(lista) do
		if type(c) == "table" and type(c.n) == "string" and (O and O.Doblar(c.n) or c.n:lower()) == buscado then return c, i end
	end
	return nil
end
Cj.Buscar = buscar

function Cj.Lista()
	local out = {}
	for _, c in ipairs(datos()) do
		if type(c) == "table" and type(c.n) == "string" and type(c.p) == "table" then out[#out + 1] = c end
	end
	return out
end

local function puesto(ranura)
	local id = GetInventoryItemID and M.Num(M.Llamar(GetInventoryItemID, "player", ranura))
	local link = GetInventoryItemLink and M.Texto(M.Llamar(GetInventoryItemLink, "player", ranura))
	return id, link
end

-- 1.3.3: el nombre se corta por letras completas (UTF-8), no por bytes: antes
-- un nombre largo con acentos podía quedar con media letra («Curación de la
-- manada élit\195»).
Cj.MAX_LETRAS = 32
function Cj.Cortar(s, n)
	n = n or Cj.MAX_LETRAS
	local out, i = {}, 0
	for letra in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		i = i + 1
		if i > n then break end
		out[i] = letra
	end
	return table.concat(out)
end

-- -> el conjunto guardado | nil, por qué
function Cj.Guardar(nombre)
	if type(nombre) ~= "string" then return nil end
	nombre = nombre:gsub("^%s+", ""):gsub("%s+$", "")
	if nombre == "" then return nil end
	nombre = Cj.Cortar(nombre)
	local p, n = {}, 0
	for _, r in ipairs(RANURAS) do
		local id, link = puesto(r)
		if id then
			p[r] = { i = id, l = link }
			n = n + 1
		end
	end
	if n == 0 then
		N.Imprimir(L["No llevas nada puesto que guardar."])
		return nil
	end
	local c = buscar(nombre)
	local lista = datos()
	if not c then
		if #lista >= MAX then
			N.Imprimir(format(L["Ya tienes %d conjuntos: olvida uno primero."], MAX))
			return nil
		end
		c = { n = nombre }
		lista[#lista + 1] = c
	end
	c.p, c.t = p, time and time() or nil
	N.Imprimir(format(L["Guardaste «%s» con %d piezas."], c.n, n))
	M.Avisar("CONJUNTOS")
	return c
end

function Cj.Olvidar(nombre)
	local c, i = buscar(nombre)
	if not c then return false end
	table.remove(datos(), i)
	M.Avisar("CONJUNTOS")
	return true
end

-- Lo que llevas en tus bolsas: -> { { bolsa, casilla, id, link }, ... }
local function enBolsas()
	local C = C_Container
	local out = {}
	if not C then return out end
	for _, b in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, b)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, b, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id then out[#out + 1] = { bolsa = b, casilla = s, id = id, link = M.Texto(info.hyperlink) } end
		end
	end
	return out
end

-- La casilla de una pieza (el mismo enlace primero, luego el mismo objeto).
local function hallar(pieza, lista, usadas)
	for k, x in ipairs(lista) do
		if not usadas[k] and x.id == pieza.i and pieza.l and x.link == pieza.l then return k, x end
	end
	for k, x in ipairs(lista) do
		if not usadas[k] and x.id == pieza.i then return k, x end
	end
	return nil
end

-- 1.3.1: dónde llevas cada pieza del conjunto: en su ranura o, si no, en su
-- gemela (anillos al revés, el anillo que comparte con otro conjunto). Primero
-- las de su ranura, para que una gemela no le gane el lugar a la dueña.
-- -> { [ranura del conjunto] = ranura donde la llevas }
local function dondeLaLlevas(c)
	local donde, ocupadas = {}, {}
	for _, r in ipairs(RANURAS) do
		local pieza = c.p[r]
		if type(pieza) == "table" and pieza.i and puesto(r) == pieza.i then
			donde[r], ocupadas[r] = r, true
		end
	end
	for _, r in ipairs(RANURAS) do
		local pieza, g = c.p[r], GEMELA[r]
		if g and not donde[r] and not ocupadas[g] and type(pieza) == "table" and pieza.i and puesto(g) == pieza.i then
			donde[r], ocupadas[g] = g, true
		end
	end
	return donde
end
Cj.DondeLaLlevas = dondeLaLlevas

-- 1.3.2: tus bolsas leídas una vez, para varias llamadas de un mismo cuadro
-- (la página y el menú piden el estado de cada conjunto y cuál llevas).
Cj.LeerBolsas = enBolsas

-- Lo que falta de un conjunto: -> puestas, enBolsas, faltan, total
-- lista: tus bolsas ya leídas (Cj.LeerBolsas), o nil para leerlas.
function Cj.Estado(c, lista)
	local puestas, bolsas, faltan, total = 0, 0, 0, 0
	if type(c) ~= "table" or type(c.p) ~= "table" then return 0, 0, 0, 0 end
	-- (Cj.Estado(Cj.Buscar(n)) pasa también el índice: solo una tabla cuenta)
	if type(lista) ~= "table" then lista = enBolsas() end
	local usadas = {}
	local donde = dondeLaLlevas(c)
	for _, r in ipairs(RANURAS) do
		local pieza = c.p[r]
		if type(pieza) == "table" and pieza.i then
			total = total + 1
			if donde[r] then
				puestas = puestas + 1
			else
				local k = hallar(pieza, lista, usadas)
				if k then
					usadas[k] = true
					bolsas = bolsas + 1
				else
					faltan = faltan + 1
				end
			end
		end
	end
	return puestas, bolsas, faltan, total
end

-- El conjunto que llevas puesto entero (el primero), o nil.
function Cj.Puesto(lista)
	if type(lista) ~= "table" then lista = enBolsas() end
	for _, c in ipairs(Cj.Lista()) do
		local puestas, _, _, total = Cj.Estado(c, lista)
		if total > 0 and puestas == total then return c.n end
	end
	return nil
end

-- Pone desde tus bolsas lo que falta del conjunto (lo que llevas en su ranura
-- o en la gemela no se toca). -> puestas, faltan, desplazadas (las piezas del
-- conjunto que estaban en una ranura que ahora ocupa otra: van a tus bolsas y
-- se ponen en la segunda pasada)
-- 1.3.7: sinArmas: las armas ya las cambió el botón seguro (Cambio.lua).
local ARMAS = { [16] = true, [17] = true, [18] = true }
Cj.ARMAS = ARMAS
local function deBolsas(c, sinArmas)
	local CI = C_Item
	local donde = dondeLaLlevas(c)
	local prestada = {} -- ranura -> true: lo que lleva cuenta para su gemela
	for r, s in pairs(donde) do if s ~= r then prestada[s] = true end end
	local lista, usadas = enBolsas(), {}
	local puestas, faltan, desplazadas = 0, 0, 0
	for _, r in ipairs(RANURAS) do
		local pieza = c.p[r]
		if type(pieza) == "table" and pieza.i and not donde[r] and not (sinArmas and ARMAS[r]) then
			local k, x = hallar(pieza, lista, usadas)
			if k then
				usadas[k] = true
				M.Seguro(CI.EquipItemByName, x.link or pieza.l or pieza.i, r)
				puestas = puestas + 1
				if prestada[r] then desplazadas = desplazadas + 1 end
			else
				faltan = faltan + 1
			end
		end
	end
	return puestas, faltan, desplazadas
end

-- 1.3.1: la segunda pasada. Una pieza que estaba en la gemela y quedó debajo
-- de otra (dos conjuntos con el mismo anillo en ranuras distintas) cae a tus
-- bolsas al cambiar el equipo; al llegar PLAYER_EQUIPMENT_CHANGED se pone en
-- su ranura (N.Una, fuera de combate). Una sola vez por clic.
local segunda -- { n = nombre, hasta = GetTime() } | nil

local function ahora() return GetTime and GetTime() or 0 end

local function segundaPasada()
	local s = segunda
	segunda = nil
	if not (s and ahora() <= s.hasta and encendido()) then return end
	local c = buscar(s.n)
	local CI = C_Item
	if not (c and CI and CI.EquipItemByName) then return end
	local _, faltan = deBolsas(c)
	if faltan > 0 then N.Imprimir(format(L["Faltan %d que no están en tus bolsas (¿en el banco?)."], faltan)) end
	M.Avisar("CONJUNTOS")
end
Cj.SegundaPasada = segundaPasada
function Cj.SegundaPendiente() return segunda ~= nil end

A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
	if not segunda then return end
	if ahora() > segunda.hasta then segunda = nil return end
	-- Con la misma clave: varias piezas que cambian juntas, una sola pasada.
	N.Una("bolsas.conjuntoSegunda", 0.3, segundaPasada, { fueraDeCombate = true })
end)

-- -> true (se puso), "espera" (en combate: al terminar), false
-- 1.3.7: opts = { armasYa = true }: el botón seguro (Cambio.lua) ya cambió
-- las armas; en combate lo dice así, y fuera de combate no las vuelve a poner.
Cj.esperando = nil -- el conjunto que espera al fin del combate
function Cj.Poner(nombre, opts)
	if not encendido() then return false end
	opts = type(opts) == "table" and opts or {}
	local c = buscar(nombre)
	if not c then
		N.Imprimir(format(L["No tienes un conjunto llamado «%s»."], tostring(nombre)))
		return false
	end
	if M.EnCombate() then
		if opts.armasYa then
			N.Imprimir(format(L["Te cambié las armas de «%s»; lo demás, al terminar el combate."], c.n))
		else
			N.Imprimir(format(L["En combate no se puede cambiar el equipo: te pongo «%s» al terminar."], c.n))
		end
		Cj.esperando = c.n
		N.FueraDeCombate("bolsas.conjunto", function()
			Cj.esperando = nil
			Cj.Poner(c.n)
		end)
		return "espera"
	end
	local CI = C_Item
	if not (CI and CI.EquipItemByName) then return false end
	local puestas, faltan, desplazadas = deBolsas(c, opts.armasYa)
	segunda = desplazadas > 0 and { n = c.n, hasta = ahora() + SEGUNDA } or nil
	if puestas == 0 and faltan == 0 and opts.armasYa then
		N.Imprimir(format(L["Te pusiste «%s»."], c.n))
	elseif puestas == 0 and faltan == 0 then
		N.Imprimir(format(L["Ya llevas puesto «%s»."], c.n))
	else
		-- Las que vuelven en la segunda pasada también se cuentan.
		local texto = format(L["Te pusiste «%s»: %d piezas."], c.n, puestas + desplazadas)
		if faltan > 0 then texto = texto .. " " .. format(L["Faltan %d que no están en tus bolsas (¿en el banco?)."], faltan) end
		N.Imprimir(texto)
	end
	M.Avisar("CONJUNTOS")
	return true
end

-- El menú de la ventana de bolsas: ponerte un conjunto o guardar lo que llevas.
function Cj.Menu(ancla)
	local K = N.Kit
	if not (K and K.Menu) then return end
	local ops = {}
	local bolsas = enBolsas()
	local actual = Cj.Puesto(bolsas)
	for _, c in ipairs(Cj.Lista()) do
		local _, _, faltan = Cj.Estado(c, bolsas)
		local texto = c.n
		if c.n == actual then texto = texto .. "  " .. L["(puesto)"] end
		if faltan > 0 then texto = texto .. "  " .. format(L["(faltan %d)"], faltan) end
		ops[#ops + 1] = { valor = "poner:" .. c.n, texto = texto, icono = "ic-personaje" }
	end
	if #ops > 0 then ops[#ops + 1] = { separador = true } end
	ops[#ops + 1] = { valor = "guardar", texto = L["Guardar lo que llevas…"], icono = "ic-mas" }
	K.Menu(ancla, ops, nil, function(v)
		if type(v) ~= "string" then return end
		if v == "guardar" then
			M.Luego(0, function() Cj.MenuGuardar(ancla) end)
			return
		end
		local nombre = v:match("^poner:(.+)$")
		if nombre then Cj.Poner(nombre) end
	end, 240)
end

-- Los nombres para guardar: los de siempre y los que ya tienes (se reemplazan).
function Cj.MenuGuardar(ancla)
	local K = N.Kit
	if not (K and K.Menu) then return end
	local ops, vistos = {}, {}
	for _, c in ipairs(Cj.Lista()) do
		vistos[c.n] = true
		ops[#ops + 1] = { valor = c.n, texto = format(L["Reemplazar «%s»"], c.n) }
	end
	for _, n in ipairs(Cj.NOMBRES) do
		if not vistos[n] then ops[#ops + 1] = { valor = n, texto = n } end
	end
	-- 1.3.3: tu propio nombre, en una caja de texto del Kit.
	ops[#ops + 1] = { separador = true }
	ops[#ops + 1] = { valor = OTRO, texto = L["Otro nombre…"], icono = "ic-mas" }
	K.Menu(ancla, ops, nil, function(v)
		if v == OTRO then
			M.Luego(0, function() Cj.PedirNombre() end)
			return
		end
		Cj.Guardar(v)
	end, 240)
end

-- 1.3.3: la ventanita para escribir el nombre (Enter o «Guardar»).
local pedir
function Cj.PedirNombre()
	local K = N.Kit
	if not (K and K.Ventana and K.Buscador and K.Boton) then return nil end
	if not pedir then
		local v = K.Ventana({ nombre = "AlfaBolsasNombreConjunto", titulo = L["Guardar lo que llevas"], icono = "ic-personaje", ancho = 380, alto = 176 })
		v:SetTitulo(L["Guardar lo que llevas"], L["Escribe un nombre para este conjunto."], "ic-personaje")
		local function guardar()
			local t = v.Campo:Texto()
			if t == "" then return end
			if Cj.Guardar(t) then v:Cerrar() end
		end
		local campo = K.Buscador(v.Cuerpo, { ayuda = L["Nombre del conjunto"], retraso = 0, alEnter = guardar })
		-- Es una caja para escribir, no un buscador: sin la lupa.
		if campo.Lupa then campo.Lupa:Hide() end
		if campo.Campo then
			campo.Campo:ClearAllPoints()
			campo.Campo:SetPoint("LEFT", campo, "LEFT", 12, 0)
			campo.Campo:SetPoint("RIGHT", campo, "RIGHT", -30, 0)
			if campo.Campo.SetMaxLetters then campo.Campo:SetMaxLetters(Cj.MAX_LETRAS) end
		end
		if campo.Ayuda then
			campo.Ayuda:ClearAllPoints()
			campo.Ayuda:SetPoint("LEFT", campo, "LEFT", 12, 0)
		end
		campo:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen or 16, -(v.margen or 16))
		campo:SetPoint("TOPRIGHT", v.Cuerpo, "TOPRIGHT", -(v.margen or 16), -(v.margen or 16))
		v.Campo = campo
		v.Guardar = K.Boton(v, L["Guardar"], guardar, { tipo = "primario", icono = "ic-exito" })
		v.Cancelar = K.Boton(v, L["Cancelar"], function() v:Cerrar() end, { tipo = "fantasma" })
		v:SetPie({ v.Cancelar, v.Guardar })
		pedir = v
	end
	pedir.Campo:SetTexto("", true)
	pedir:Abrir()
	if pedir.Campo.Campo and pedir.Campo.Campo.SetFocus then pedir.Campo.Campo:SetFocus() end
	return pedir
end
