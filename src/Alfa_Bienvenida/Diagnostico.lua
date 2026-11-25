-- Alfa - Bienvenida: «Revisar Alfa», el diagnóstico (1.2.9). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- Una ventana del Kit que revisa, con un clic o con /alfa diagnostico:
--   1. otros addons que hacen lo mismo que una parte de Alfa (bolsas, barras,
--      chat, minimapa, recolección, flecha, medidores, marcos de curación,
--      guías, precios, buzón): «Apagar la parte de Alfa que choca». Nunca se
--      apaga el otro addon: eso lo decide el jugador;
--   2. partes de Alfa apagadas, que no cargaron o de otra versión
--      («Activar módulo»: se enciende para tu personaje y se ve al recargar);
--   3. ajustes raros: casi todo Alfa apagado, ajustes que llegaron vacíos;
--   4. los errores que Alfa atrapó en esta versión;
--   5. cuánto pesan los datos guardados de Alfa.
--
--   Dg.Revisar() -> { { id, tono, titulo, texto, arreglo = { texto, alClic } }, ... }
--   Dg.Abrir()   la ventana con lo que encontró

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local format, type, pairs, ipairs, pcall, tostring, tonumber = string.format, type, pairs, ipairs, pcall, tostring, tonumber

local Dg = {}
M.Diagnostico = Dg

-- Lo que choca: los addons (su carpeta), qué hace cada uno igual que Alfa y
-- los ajustes de Alfa que lo resuelven. Sin claves, solo se cuenta.
Dg.CHOQUES = {
	{ id = "bolsas", addons = { "Bagnon", "AdiBags", "ArkInventory", "Baganator", "Combuctor", "OneBag3", "Inventorian" },
		texto = "%s también cambia tus bolsas y el banco: las dos ventanas se pisan al abrirlas.",
		claves = { ["bolsas.reemplazar"] = false, ["bolsas.banco"] = false } },
	{ id = "elvui", addons = { "ElvUI", "Tukui" },
		texto = "%s ya viste tus barras, el chat y el minimapa: el estilo de Alfa se pondría encima.",
		claves = { ["comodidades.barras"] = false, ["comodidades.chat"] = false, ["comodidades.minimapaEstilo"] = false, ["comodidades.minimapa"] = false } },
	{ id = "barras", addons = { "Bartender4", "Dominos" },
		texto = "%s acomoda tus barras de acción: el estilo de barras de Alfa choca con él.",
		claves = { ["comodidades.barras"] = false } },
	{ id = "chat", addons = { "Prat-3.0", "Chatter" },
		texto = "%s ya cambia tu chat: el estilo de chat de Alfa se pondría encima.",
		claves = { ["comodidades.chat"] = false } },
	{ id = "minimapa", addons = { "SexyMap", "BasicMinimap" },
		texto = "%s ya cambia tu minimapa: el de Alfa se pondría encima.",
		claves = { ["comodidades.minimapa"] = false, ["comodidades.minimapaEstilo"] = false } },
	{ id = "recoleccion", addons = { "GatherMate2", "Gatherer" },
		texto = "%s ya marca minas y hierbas: verías cada punto dos veces en el mapa.",
		claves = { ["recoleccion.mapa"] = false, ["recoleccion.minimapa"] = false } },
	{ id = "tomtom", addons = { "TomTom" },
		texto = "Con %s salen dos flechas a la vez. Alfa puede usar la de TomTom y esconder la suya.",
		claves = { ["nav.useTomTomArrow"] = true }, boton = "Usar solo una flecha" },
	{ id = "medidor", addons = { "Details", "Recount", "Skada" },
		texto = "%s ya mide tu daño: el medidor de Alfa sobra.",
		claves = { ["combate.medidorModo"] = "apagado" } },
	{ id = "curacion", addons = { "Grid2", "VuhDo", "HealBot", "Cell" },
		texto = "%s ya pone marcos de grupo para curar: los de Alfa se pondrían encima.",
		claves = { ["curacion.activo"] = false } },
	{ id = "rotacion", addons = { "Hekili" },
		texto = "%s ya te sugiere qué habilidad usar: verías dos sugerencias.",
		claves = { ["combate.rotacion"] = false } },
	{ id = "leatrix", addons = { "Leatrix_Plus" },
		texto = "%s puede vender lo gris y reparar, igual que Alfa. Si lo tienes encendido allá, los dos lo harían a la vez.",
		claves = { ["qol.sellJunk"] = false, ["qol.autoRepair"] = false } },
	{ id = "guias", addons = { "Guidelime", "RXPGuides", "ZygorGuidesViewerClassic" },
		texto = "%s también es una guía: las dos aceptarían y entregarían tus misiones a la vez.",
		claves = { ["behavior.autoAccept"] = false, ["behavior.autoTurnin"] = false } },
	{ id = "precios", addons = { "Auctionator", "Auctioneer" },
		texto = "%s también pone precios en el cuadro de los objetos: verías dos.",
		claves = { ["comercio.tooltip"] = false } },
	{ id = "buzon", addons = { "Postal" },
		texto = "%s también arregla el buzón: dos «Tomar todo» se estorban.",
		claves = { ["comercio.buzon"] = false } },
	{ id = "questie", addons = { "Questie" },
		texto = "%s también marca tus misiones en el mapa. Conviven bien; si ves marcas dobles, apaga las de uno de los dos." },
}

-- Las partes de Alfa (las que siempre cargan y las que cargan al pedirlas).
local PARTES = { "Alfa", "Alfa_Nucleo", "Alfa_Bienvenida", "Alfa_Idioma", "Alfa_Inicio", "Alfa_Rutas", "Alfa_Lya",
	"Alfa_Manada", "Alfa_Bolsas", "Alfa_Builds", "Alfa_Combate", "Alfa_Comercio", "Alfa_Comodidades", "Alfa_Curacion",
	"Alfa_Enciclopedia", "Alfa_Mazmorras", "Alfa_Mundo", "Alfa_Pesca", "Alfa_Recoleccion", "Alfa_Vista",
	-- 1.3.6: y los paquetes de datos (guías, Codex, misiones, objetos, caminos):
	-- «Revisar Alfa» los ofrece cuando faltan guías o datos.
	"Alfa_Guides", "Alfa_Guides_Alliance", "Alfa_Guides_Horde", "Alfa_Codex", "Alfa_QuestDB", "Alfa_ItemDB", "Alfa_Nav",
	-- 1.4.0: los pasos de las guías por facción y tramo, los de cualquier nivel y
	-- las dos partes del Codex (tools/tramos.py), que cargan a pedido.
	"Alfa_Guides_Horde_Pasos1", "Alfa_Guides_Horde_Pasos2", "Alfa_Guides_Horde_Pasos3",
	"Alfa_Guides_Alliance_Pasos1", "Alfa_Guides_Alliance_Pasos2", "Alfa_Guides_Alliance_Pasos3",
	"Alfa_Guides_Pasos", "Alfa_Codex_Objetos", "Alfa_Codex_Mundo" }

-- 1.3.6: sin estos (o sin las guías de tu facción) Alfa no tiene guías ni datos.
local DATOS_ESENCIALES = { "Alfa_Guides", "Alfa_Codex", "Alfa_QuestDB", "Alfa_Nav",
	-- 1.4.0: sin estos, las guías de oficios y demás salen sin pasos y las fichas del Codex vacías.
	"Alfa_Guides_Pasos", "Alfa_Codex_Objetos", "Alfa_Codex_Mundo" }

-- Los interruptores principales: si casi todos están apagados, algo pasó.
local PRINCIPALES = { "bolsas.reemplazar", "curacion.activo", "combate.rotacion", "recoleccion.mapa", "pesca.activo",
	"lya.mostrar", "nav.arrow", "comodidades.chat", "comodidades.barras", "comodidades.minimapaEstilo", "nav.routeLines",
	"behavior.autoAccept" }

local MB_AVISO = 8 -- MB de datos guardados para avisar

local function CA() return C_AddOns end
local function cargado(n)
	local c = CA()
	if not (c and c.IsAddOnLoaded) then return false end
	local ok, si = pcall(c.IsAddOnLoaded, n)
	return ok and si and true or false
end
local function meta(n, campo)
	local c = CA()
	local get = c and c.GetAddOnMetadata or GetAddOnMetadata
	if not get then return nil end
	local ok, v = pcall(get, n, campo)
	return ok and type(v) == "string" and v or nil
end
local function existe(n)
	local c = CA()
	if c and c.DoesAddOnExist then
		local ok, si = pcall(c.DoesAddOnExist, n)
		if ok then return si and true or false end
	end
	return meta(n, "Title") ~= nil
end
local function personaje()
	local n = UnitName and UnitName("player")
	if type(n) ~= "string" or (issecretvalue and issecretvalue(n)) then return nil end
	return n
end
local function encendido(n)
	local c = CA()
	if not (c and c.GetAddOnEnableState) then return true end
	local ok, e = pcall(c.GetAddOnEnableState, n, personaje())
	if not ok then ok, e = pcall(c.GetAddOnEnableState, n) end
	return not ok or (tonumber(e) or 0) > 0
end
local function bajoPedido(n)
	local c = CA()
	if not (c and c.IsAddOnLoadOnDemand) then return false end
	local ok, si = pcall(c.IsAddOnLoadOnDemand, n)
	return ok and si and true or false
end

local function avisoRecargar(titulo)
	K.Aviso({ titulo = titulo, texto = L["Se ve completo al recargar."], icono = "ic-exito",
		accion = { texto = L["Recargar ahora"], alClic = function() if ReloadUI then ReloadUI() end end } })
end

---------------------------------------------------------------------------
-- Lo que se revisa
---------------------------------------------------------------------------
local function choques(out)
	for _, c in ipairs(Dg.CHOQUES) do
		local quien
		for _, a in ipairs(c.addons) do if cargado(a) then quien = a break end end
		if quien then
			local nombre = (meta(quien, "Title") or quien):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local pendientes = {}
			for clave, v in pairs(c.claves or {}) do
				if A.GetDefault(clave) ~= nil and A.Get(clave) ~= v then pendientes[clave] = v end
			end
			if not c.claves then
				out[#out + 1] = { id = "choque." .. c.id, tono = "info", titulo = format(L["%s y Alfa"], nombre), texto = format(L[c.texto], nombre) }
			elseif next(pendientes) then
				out[#out + 1] = { id = "choque." .. c.id, tono = "aviso", titulo = format(L["%s choca con Alfa"], nombre),
					texto = format(L[c.texto], nombre),
					arreglo = { texto = L[c.boton or "Apagar la parte de Alfa que choca"], alClic = function()
						for clave, v in pairs(pendientes) do A.Set(clave, v) end
						K.Aviso({ titulo = L["Listo"], texto = format(L["Alfa ya no se pone encima de %s. %s sigue como estaba."], nombre, nombre), icono = "ic-exito" })
					end } }
			end
		end
	end
end

local function partes(out)
	local version = tostring(A.version or N.version or "dev")
	local apagadas, otras, sinCargar = {}, {}, {}
	for _, n in ipairs(PARTES) do
		if existe(n) then
			if not encendido(n) then
				apagadas[#apagadas + 1] = n
			elseif not cargado(n) and not bajoPedido(n) then
				sinCargar[#sinCargar + 1] = n
			end
			local v = meta(n, "Version")
			if v and v ~= "dev" and version ~= "dev" and v ~= version then otras[#otras + 1] = format("%s %s", n, v) end
		end
	end
	-- 1.3.6: los paquetes de datos que ni siquiera están instalados.
	local faltan = {}
	local esenciales = {}
	for i, n in ipairs(DATOS_ESENCIALES) do esenciales[i] = n end
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if f == "Alliance" or f == "Horde" then
		esenciales[#esenciales + 1] = "Alfa_Guides_" .. f
		-- 1.4.0: y los pasos de tus guías, por tramo de nivel.
		for i = 1, 3 do esenciales[#esenciales + 1] = "Alfa_Guides_" .. f .. "_Pasos" .. i end
	end
	for _, n in ipairs(esenciales) do
		if not existe(n) then faltan[#faltan + 1] = n end
	end
	if #faltan > 0 then
		out[#out + 1] = { id = "partes.faltan", tono = "aviso", titulo = L["Faltan partes de Alfa"],
			texto = format(L["No están en tu carpeta de addons: %s. Sin ellas faltan guías o datos. Reinstala Alfa completo (el zip entero o el instalador)."], table.concat(faltan, ", ")) }
	end
	if #apagadas > 0 then
		out[#out + 1] = { id = "partes.apagadas", tono = "aviso", titulo = L["Partes de Alfa apagadas"],
			texto = format(L["Están apagadas en tu lista de addons: %s. Sin ellas faltan páginas de Alfa."], table.concat(apagadas, ", ")),
			arreglo = { texto = #apagadas == 1 and L["Activar módulo"] or L["Activar módulos"], alClic = function()
				local c = CA()
				for _, n in ipairs(apagadas) do
					if c and c.EnableAddOn then
						local ok = pcall(c.EnableAddOn, n, personaje())
						if not ok then pcall(c.EnableAddOn, n) end
					end
				end
				avisoRecargar(L["Módulos activados"])
			end } }
	end
	if #sinCargar > 0 then
		out[#out + 1] = { id = "partes.sincargar", tono = "aviso", titulo = L["Partes de Alfa que no cargaron"],
			texto = format(L["Están encendidas pero el juego no las cargó: %s. Recarga; si siguen así, reinstala Alfa completo."], table.concat(sinCargar, ", ")),
			arreglo = { texto = L["Recargar ahora"], alClic = function() if ReloadUI then ReloadUI() end end } }
	end
	if #otras > 0 then
		out[#out + 1] = { id = "partes.version", tono = "aviso", titulo = L["Partes de Alfa de otra versión"],
			texto = format(L["Alfa es la %s, pero estas son de otra: %s. Reinstala Alfa completo para que todo sea de la misma."], version, table.concat(otras, ", ")) }
	end
end

local function ajustes(out)
	local hay, apagados = 0, 0
	for _, clave in ipairs(PRINCIPALES) do
		if A.GetDefault(clave) ~= nil then
			hay = hay + 1
			if A.Get(clave) == false then apagados = apagados + 1 end
		end
	end
	if hay >= 6 and apagados >= hay * 0.8 then
		out[#out + 1] = { id = "ajustes.apagado", tono = "aviso", titulo = L["Casi todo Alfa está apagado"],
			texto = format(L["%d de %d de sus partes principales están apagadas. Si no fue a propósito, revisa tu configuración."], apagados, hay),
			arreglo = { texto = L["Abrir la configuración"], alClic = function() M.Abrir("pedido", "asistente") end } }
	end
	local r = N.AjustesDanados and N.AjustesDanados()
	if r and M.Respaldos then
		local i
		for j, x in ipairs(M.Respaldos.Lista()) do if x == r then i = j end end
		out[#out + 1] = { id = "ajustes.vacios", tono = "aviso", titulo = L["Tus ajustes de Alfa llegaron vacíos"],
			texto = format(L["Puede que el archivo se dañara. Tienes un respaldo del %s."], tostring(r.cuando or "?")),
			arreglo = i and { texto = L["Restaurar"], alClic = function() M.Respaldos.Restaurar(i) end } or nil }
	end
end

local function errores(out)
	local l = N.Errores and N.Errores() or {}
	local v, n, veces = tostring(N.version or "dev"), 0, 0
	for _, e in ipairs(l) do
		if type(e) == "table" and e.v == v then n = n + 1 veces = veces + (tonumber(e.n) or 1) end
	end
	if n > 0 then
		out[#out + 1] = { id = "errores", tono = "aviso", titulo = L["Alfa atrapó errores"],
			texto = format(L["%d errores distintos en esta versión (%d veces). Mándalos en un reporte y toxic3000 los arregla."], n, veces),
			arreglo = { texto = L["Reportar"], alClic = function() M.AbrirReporte("error") end } }
	end
end

-- Bytes aproximados de una tabla guardada (con tope, para no trabar el juego).
local function peso(t, quedan)
	if type(t) ~= "table" then return 0 end
	local total, pila, vistos = 0, { t }, {}
	while #pila > 0 and quedan.n > 0 do
		local x = table.remove(pila)
		if not vistos[x] then
			vistos[x] = true
			for k, v in pairs(x) do
				quedan.n = quedan.n - 1
				if quedan.n <= 0 then break end
				total = total + (type(k) == "string" and #k + 4 or 8)
				local tv = type(v)
				if tv == "table" then pila[#pila + 1] = v total = total + 6
				elseif tv == "string" then total = total + #v + 4
				else total = total + 8 end
			end
		end
	end
	return total
end
Dg.Peso = peso

local function datosGuardados(out)
	local quedan = { n = 400000 }
	local total, mayor, mayorPeso = 0, nil, 0
	for _, nombre in ipairs({ "AlfaDB", "AlfaCharDB", "AlfaNucleoDB", "AlfaNucleoCharDB", "AlfaIdiomaDB" }) do
		total = total + peso(rawget(_G, nombre), quedan)
	end
	local db = rawget(_G, "AlfaNucleoDB")
	if type(db) == "table" then
		for k, v in pairs(db) do
			local p = peso(v, { n = 100000 })
			if p > mayorPeso then mayor, mayorPeso = k, p end
		end
	end
	local mb = total / (1024 * 1024)
	Dg.ultimoPeso = total
	out[#out + 1] = { id = "datos", tono = mb >= MB_AVISO and "aviso" or "bien", titulo = L["Tus datos guardados"],
		texto = mb >= MB_AVISO
			and format(L["Alfa guarda unos %.1f MB. Es mucho: el juego tarda más en entrar. Lo que más pesa: %s."], mb, tostring(mayor or "?"))
			or format(L["Alfa guarda unos %.1f MB. Todo bien."], mb) }
end

function Dg.Revisar()
	local out = {}
	for _, fn in ipairs({ choques, partes, ajustes, errores, datosGuardados }) do
		local ok, e = pcall(fn, out)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end
	return out
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v
local ui = {}

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = ui.pila:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * ESP.base)
end

local function parrafo(pila, texto, rol, color)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, rol or "texto", color or "textoSuave")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	K.Escribir(b.Texto, texto)
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	return pila:Agregar(b)
end

local ICONO = { aviso = "ic-alerta", info = "ic-info", bien = "ic-exito" }

local function llenar()
	local p = ui.pila
	p:Vaciar()
	local lista = Dg.Revisar()
	ui.lista = lista
	local problemas = 0
	for _, x in ipairs(lista) do if x.tono == "aviso" then problemas = problemas + 1 end end
	parrafo(p, problemas == 0 and L["Todo en orden: nada choca con Alfa."]
		or (problemas == 1 and L["Encontré 1 cosa que revisar."] or format(L["Encontré %d cosas que revisar."], problemas)), "cuerpo", "texto")
	local g = K.GrupoAjustes(p, { titulo = L["Lo que revisé"] })
	for _, x in ipairs(lista) do
		g:Fila({
			titulo = x.titulo, texto = x.texto,
			control = x.arreglo and function(fila)
				return K.Boton(fila, x.arreglo.texto, function()
					K.Llamar(x.arreglo.alClic)
					-- Lo arreglado ya no sale.
					if v and v:IsShown() then K.Despues(0.1, function() llenar() acomodar() end) end
				end, { tipo = "secundario", icono = ICONO.bien })
			end or nil,
		})
	end
	p:Agregar(g, { espacio = ESP.l })
	parrafo(p, L["Alfa nunca apaga otros addons: eso lo decides tú en tu lista de addons."], "nota", "textoTenue")
	g:Refrescar()
end

local function armar()
	v = K.Ventana({ nombre = "AlfaDiagnostico", titulo = L["Revisar Alfa"],
		subtitulo = L["Lo que choca con Alfa y cómo arreglarlo"], icono = "ic-info", ancho = 660, alto = 560, desplazar = true })
	v.alAcomodar = acomodar
	ui.pila = K.Pila(v.Cuerpo, { espacio = ESP.m })
	v:SetPie({
		K.Boton(v, L["Revisar otra vez"], function() llenar() acomodar() end, { tipo = "secundario", icono = "ic-buscar" }),
		K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" }),
	})
end

function Dg.Abrir()
	-- En combate no se mide nada pesado: al terminar.
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Revisar Alfa espera a que termine el combate."])
		N.FueraDeCombate("alfa.diagnostico", Dg.Abrir)
		return
	end
	if not v then armar() end
	v:Abrir()
	llenar()
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
	K.Despues(0.05, acomodar)
end
function Dg.Visible() return v ~= nil and v:IsShown() end

A.RegisterCommand("diagnostico", function() Dg.Abrir() end, L["revisa si algo choca con Alfa y cómo arreglarlo"])

-- 1.3.6: para otros módulos («Revisar Alfa» en la Enciclopedia).
AlfaBienvenida = type(AlfaBienvenida) == "table" and AlfaBienvenida or {}
function AlfaBienvenida.Diagnostico() return Dg.Abrir() end

-- Lya sabe contar lo de la 1.2.9 (Pregúntale a Lya).
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Ensenar) == "function") then return end
	for _, p in ipairs({
		{ id = "bienvenida.diagnostico", icono = "ic-buscar", pregunta = L["Algo de Alfa no funciona, ¿qué reviso?"],
			respuesta = L["Escribe /alfa diagnostico: reviso si otro addon choca con Alfa, si falta una parte o si un ajuste quedó raro, y te doy el arreglo a un clic."] },
		{ id = "bienvenida.respaldos", icono = "ic-reloj", pregunta = L["¿Y si pierdo mis ajustes?"],
			respuesta = L["Cada semana guardo una copia de tus ajustes y perfiles. En Ajustes > Estilo y sonido, en «Respaldos», vuelves a una con un clic."] },
		{ id = "bienvenida.modo", icono = "ic-huella", pregunta = L["Alfa tiene muchas páginas, ¿se puede más sencillo?"],
			respuesta = L["Sí: en Ajustes > Estilo y sonido elige «Sencillo» en «Cómo ves Alfa». Dejo a la vista solo lo esencial y te aviso menos."] },
		{ id = "bienvenida.errores", icono = "ic-alerta", pregunta = L["¿Cómo le mando un error a toxic3000?"],
			respuesta = L["Con /alfa reportar: yo ya junté los errores que atrapé, con su versión y cuántas veces salieron. Tú solo le das «Enviar»."] },
	}) do
		p.modulo = M.ID
		pcall(Lya.Ensenar, p)
	end
end)
