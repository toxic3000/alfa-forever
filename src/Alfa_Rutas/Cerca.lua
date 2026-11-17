-- Alfa - Rutas: «Buscar cerca», los lugares que más se buscan
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- El maestro de vuelo, el posadero, dónde reparar, el banco, el buzón, la
-- casa de subastas, tu entrenador, los de profesión, el vendedor, los
-- componentes y los establos: el más cercano por tiempo de camino, con la
-- flecha y la ruta. Es la versión de Alfa de los "servicios cercanos" del
-- motor (Alfa.Nav.nearby: Find da el lugar y los segundos, Go pone la flecha
-- y la ruta); el motor ya filtra por facción y por continente.
--
-- La ventana es un menú propio hecho con el Kit (como K.Menu, pero con dos
-- líneas por fila y páginas): cada fila dice, cuando ya se sabe, cuál es el
-- más cercano, su zona y el tiempo de camino. Esas búsquedas se hacen una por
-- cuadro al abrir (nunca todas de golpe) y valen un rato o hasta que te
-- mueves. Nada de esto lanza errores: lo que no se puede dice por qué.
--
-- AlfaCerca (global), para los demás módulos:
--   AlfaCerca.Menu(ancla)           abre o cierra el menú junto a `ancla` (sin ancla: junto al cursor)
--   AlfaCerca.Ir(tipo, linea) -> bool   la flecha al más cercano (y el rastreador a la vista, las
--                                       ventanas de Alfa cerradas: N.EmpezarRuta) (tipo: "flight", "innkeeper", "repair",
--                                       "bank", "mailbox", "auction", "class", "trainer", "vendor", "food",
--                                       "general", "arrows", "bullets", "ranged", "reagents", "stable" o un
--                                       alias en español: "vuelo", "posada", "banco"...; linea: la profesión
--                                       del entrenador, su línea de habilidad)
--   AlfaCerca.Tipos() -> { { tipo, nombre, icono, pagina? }, ... }   los de la portada del menú, para este personaje
--   AlfaCerca.Texto(tipo, linea) -> texto | nil   lo último que se supo ("Bera · Ventormenta · 2 min"), sin buscar
--   AlfaCerca.Nombre(tipo, linea) -> texto        su nombre para mostrar
--   AlfaCerca.Cerrar(), AlfaCerca.Visible() -> bool
-- Comando: /alfa cerca [tipo] [profesión]. Tecla: Bindings.xml.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K

local Ce = {}
M.Cerca = Ce

local type, ipairs, pairs, tostring, tonumber, pcall = type, ipairs, pairs, tostring, tonumber, pcall
local floor, max, min, format, concat, sort = math.floor, math.max, math.min, string.format, table.concat, table.sort

-- rutas.cercaBoton: el botón en el rastreador; rutas.cercaHoy: la fila en la
-- página Hoy; rutas.cercaAviso: el aviso al poner la flecha.
A.RegisterDefaults(M.ID, { cercaBoton = true, cercaHoy = true, cercaAviso = true })

local ANCHO = 312
local CAB = 50
local FILA = 40
local FILA_CORTA = 28
local GRUPO = 24
local SEPARADOR = 9
local VIGENTE = 25 -- segundos que vale una búsqueda
local MOVIDO = 40  -- o hasta que te mueves estas yardas
local RIDING = 762 -- equitación: no tiene entrenador de oficio
local DOT = "  \194\183  "

---------------------------------------------------------------------------
-- El motor
---------------------------------------------------------------------------

local function cerca()
	local Nav = A.Nav
	local nb = type(Nav) == "table" and Nav.nearby
	if type(nb) == "table" and type(nb.Find) == "function" and type(nb.Go) == "function" then return nb end
	return nil
end

local function Cp() return M.Motor("Compat") end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function clase()
	local C = Cp()
	local info = C and llamar(C.GetPlayerInfo)
	return type(info) == "table" and info.class or nil
end

-- Dónde estás: continente y yardas del mundo (nil en una instancia o sin mapa).
local function aqui()
	local C = Cp()
	local c, x, y = llamar(C and C.GetPlayerWorldPosition)
	if c and type(x) == "number" and type(y) == "number" then return c, x, y end
	return nil
end

local function codexCargado()
	local X = M.Motor("Codex")
	return X and type(X.IsLoaded) == "function" and llamar(X.IsLoaded) and true or false
end

local function zona(map)
	local C = Cp()
	local n = map and C and llamar(C.GetMapName, map)
	if type(n) == "string" and n ~= "" then return n end
	return nil
end

-- El continente de un lugar (los del Codex ya lo traen; el entrenador de clase no).
local function continente(p)
	if p.c then return p.c end
	local C = Cp()
	return (llamar(C and C.MapToWorld, p.map, p.x, p.y, p.f))
end

---------------------------------------------------------------------------
-- Los tipos
---------------------------------------------------------------------------

-- La clase de un tipo en el motor (Nearby.KINDS: titled, uses...).
local function claseMotor(tipo)
	local nb = cerca()
	for _, k in ipairs(nb and nb.KINDS or {}) do
		if k.key == tipo then return k end
	end
	return nil
end

-- Para quién es: los establos, para el cazador; los componentes, para las
-- clases que los usan (el guerrero y el cazador no).
local SIN_COMPONENTES = { WARRIOR = true, HUNTER = true }

local TIPOS = {
	{ tipo = "flight", nombre = L["Maestro de vuelo"], icono = "icon-fly", nota = L["Vuelos y rutas por aprender"] },
	{ tipo = "innkeeper", nombre = L["Posadero"], icono = "icon-hearth", nota = L["Tu piedra de hogar y el descanso"] },
	{ tipo = "repair", nombre = L["Reparar"], icono = "icon-craft", nota = L["Quien repara tu equipo"] },
	{ tipo = "bank", nombre = L["Banco"], icono = "icon-treasure", nota = L["Tu banco"] },
	{ tipo = "mailbox", nombre = L["Buzón"], icono = "icon-learn", nota = L["Tu correo"] },
	{ tipo = "auction", nombre = L["Casa de subastas"], icono = "ic-comercio", nota = L["Comprar y vender con otros"] },
	{ separador = true },
	{ tipo = "class", nombre = L["Entrenador de tu clase"], icono = "icon-train", nota = L["Tus habilidades nuevas"] },
	{ tipo = "trainer", nombre = L["Entrenadores de profesión"], icono = "ic-oficios", pagina = "oficios" },
	{ tipo = "vendor", nombre = L["Vendedor"], icono = "icon-buy", pagina = "vendedor", nota = L["Comida, bebida y más"] },
	{ tipo = "reagents", nombre = L["Componentes"], icono = "icon-collect", nota = L["Lo que gastan tus hechizos"],
		para = function(c) return not SIN_COMPONENTES[c or ""] end },
	{ tipo = "stable", nombre = L["Establos"], icono = "icon-mount", nota = L["Guarda o cambia tu mascota"],
		para = function(c) return c == "HUNTER" end },
}

-- La página del vendedor (lo que vende), en el orden del motor; flechas, balas
-- y armas a distancia solo para quien las usa (Nearby.Fits).
local VENDEDOR = {
	{ tipo = "food", nombre = L["Comida y bebida"], icono = "icon-buy" },
	{ tipo = "vendor", nombre = L["El vendedor más cercano"], icono = "icon-vendor" },
	{ tipo = "general", nombre = L["Mercancías generales"], icono = "icon-buy" },
	{ tipo = "arrows", nombre = L["Flechas"], icono = "icon-buy" },
	{ tipo = "bullets", nombre = L["Balas"], icono = "icon-buy" },
	{ tipo = "ranged", nombre = L["Arcos, ballestas y armas de fuego"], icono = "icon-buy" },
}

local POR_TIPO = {}
for _, d in ipairs(TIPOS) do if d.tipo then POR_TIPO[d.tipo] = d end end
for _, d in ipairs(VENDEDOR) do if not POR_TIPO[d.tipo] then POR_TIPO[d.tipo] = d end end

-- Lo que se escribe en el comando (sin acentos ni mayúsculas, M.Plegar).
local ALIAS = {
	vuelo = "flight", vuelos = "flight", volar = "flight", grifo = "flight", murcielago = "flight", wyvern = "flight",
	posada = "innkeeper", posadero = "innkeeper", posadera = "innkeeper", hogar = "innkeeper", piedra = "innkeeper", descanso = "innkeeper",
	reparar = "repair", reparacion = "repair", reparaciones = "repair",
	banco = "bank", buzon = "mailbox", correo = "mailbox", cartas = "mailbox",
	subasta = "auction", subastas = "auction", subastador = "auction",
	entrenador = "class", clase = "class", habilidades = "class",
	oficio = "trainer", oficios = "trainer", profesion = "trainer", profesiones = "trainer",
	vendedor = "vendor", comerciante = "vendor", tienda = "vendor", vender = "vendor",
	comida = "food", bebida = "food", agua = "food", comer = "food",
	mercancias = "general", generales = "general", suministros = "general",
	flechas = "arrows", flecha = "arrows", balas = "bullets", bala = "bullets", municion = "arrows",
	arcos = "ranged", arco = "ranged", ballesta = "ranged", rifle = "ranged", armas = "ranged",
	componentes = "reagents", reactivos = "reagents", reagentes = "reagents",
	establo = "stable", establos = "stable", mascota = "stable",
}

-- tipo (del motor o un alias) -> tipo del motor | nil
local function resolver(tipo)
	if type(tipo) ~= "string" or tipo == "" then return nil end
	local t = M.Plegar(tipo)
	if ALIAS[t] then return ALIAS[t] end
	if POR_TIPO[t] or claseMotor(t) then return t end
	return t
end

---------------------------------------------------------------------------
-- Profesiones
---------------------------------------------------------------------------

local function nombreOficio(linea)
	local nb = cerca()
	local n = nb and llamar(nb.ProfessionName, linea)
	if type(n) == "string" and n ~= "" then return n end
	return tostring(linea)
end

-- Las profesiones con entrenador: las tuyas primero, luego las demás (por nombre).
local function oficios()
	local C = Cp()
	local mias, otras = {}, {}
	for _, linea in pairs(C and type(C.SKILL_LINES) == "table" and C.SKILL_LINES or {}) do
		if type(linea) == "number" and linea ~= RIDING then
			local rango = llamar(C.GetSkillRank, linea)
			if type(rango) == "number" and rango > 0 then mias[#mias + 1] = linea else otras[#otras + 1] = linea end
		end
	end
	local function porNombre(a, b) return nombreOficio(a) < nombreOficio(b) end
	sort(mias, porNombre)
	sort(otras, porNombre)
	return mias, otras
end

-- "Minería" escrita como sea ("mineria", "MINING") -> su línea.
local function oficioDe(texto)
	local t = M.Plegar(texto or "")
	if t == "" then return nil end
	local C = Cp()
	for clave, linea in pairs(C and type(C.SKILL_LINES) == "table" and C.SKILL_LINES or {}) do
		if linea ~= RIDING and (t == M.Plegar(clave) or t == M.Plegar(nombreOficio(linea))) then return linea end
	end
	return nil
end

function Ce.Nombre(tipo, linea)
	tipo = resolver(tipo)
	if tipo == "trainer" and linea then return format(L["Entrenador de %s"], nombreOficio(linea)) end
	local d = POR_TIPO[tipo or ""]
	if d then return d.nombre end
	local k = tipo and claseMotor(tipo)
	return k and k.label or tostring(tipo)
end

---------------------------------------------------------------------------
-- Buscar: lo más cercano de cada tipo, guardado un rato
---------------------------------------------------------------------------

local guardado = {} -- "tipo:linea" -> { place, seg, por, t, c, x, y }

local function clave(tipo, linea) return tipo .. ":" .. tostring(linea or "") end

local function ahora() return GetTime and GetTime() or 0 end

local function vigente(e)
	if not e or ahora() - e.t > VIGENTE then return false end
	local c, x, y = aqui()
	if c ~= e.c then return false end
	if c and e.x and ((x - e.x) ^ 2 + (y - e.y) ^ 2) > MOVIDO * MOVIDO then return false end
	return true
end

-- Busca de verdad (el Codex se carga la primera vez, fuera de combate).
-- -> { place, seg } | { por = motivo }
local function buscar(tipo, linea)
	local nb = cerca()
	local e
	if not nb then
		e = { por = "motor" }
	else
		local ok, place, seg = pcall(nb.Find, tipo, linea)
		if not ok then
			e = { por = "error" }
		elseif type(place) == "table" then
			e = { place = place, seg = type(seg) == "number" and seg == seg and seg or nil }
		else
			e = { por = type(seg) == "string" and seg or "none" }
		end
	end
	e.t = ahora()
	e.c, e.x, e.y = aqui()
	-- "En combate" (el Codex sin cargar) no se guarda: al salir se vuelve a buscar.
	if e.por ~= "combat" then guardado[clave(tipo, linea)] = e end
	return e
end

local function sabido(tipo, linea)
	local e = guardado[clave(tipo, linea)]
	if vigente(e) then return e end
	return nil
end

-- El nombre del lugar: "Keina (Arquera)" para los vendedores, como el motor.
-- Un buzón no tiene nombre (el motor lo llama "Buzón"): nil.
local function nombreLugar(tipo, p)
	if tipo == "mailbox" then return nil end
	local n = type(p.name) == "string" and p.name ~= "" and p.name or "?"
	local k = claseMotor(tipo)
	if k and k.titled and type(p.sub) == "string" and p.sub ~= "" then n = format("%s (%s)", n, p.sub) end
	return n
end

local function lejos(p)
	local c = aqui()
	local pc = continente(p)
	return c ~= nil and pc ~= nil and c ~= pc
end

-- La línea corta de una fila: lugar, zona y tiempo. -> texto, color
local function lineaCorta(tipo, e)
	if e.place then
		local partes = {}
		partes[#partes + 1] = nombreLugar(tipo, e.place)
		local z = zona(e.place.map)
		if z then partes[#partes + 1] = z end
		if lejos(e.place) then
			partes[#partes + 1] = L["otro continente"]
		elseif e.seg then
			partes[#partes + 1] = M.Minutos(e.seg)
		end
		return concat(partes, DOT), "textoSuave"
	end
	local por = e.por
	if por == "combat" then return L["Después del combate"], "aviso" end
	if por == "none" then return L["Ninguno conocido para tu facción"], "textoTenue" end
	if por == "motor" or por == "error" then return L["No disponible"], "textoTenue" end
	return L["Faltan los datos del mundo"], "aviso"
end

-- El lugar más cercano de un tipo (lo sabido, o busca ahora) -> place | nil, motivo.
-- Lo usa Mis planes para saber cuándo llegaste.
function Ce.Lugar(tipo, linea)
	local t = resolver(tipo)
	if not t or not claseMotor(t) then return nil, "kind" end
	local e = sabido(t, linea) or buscar(t, linea)
	return e.place, e.por
end

function Ce.Texto(tipo, linea)
	tipo = resolver(tipo)
	local e = tipo and sabido(tipo, linea)
	if not (e and e.place) then return nil end
	return (lineaCorta(tipo, e))
end

-- Por qué no se pudo, en una frase para el jugador.
local function motivoLargo(tipo, linea, por)
	if por == "kind" then
		return L["No conozco ese lugar. Prueba: vuelo, posada, reparar, banco, buzón, subasta, entrenador, oficio, vendedor, comida, componentes o establo."]
	elseif por == "combat" then
		return L["En combate no puedo buscar: inténtalo al terminar la pelea."]
	elseif por == "missing" then
		return L["Faltan los datos del mundo de Alfa (la carpeta Alfa_Codex): instala todas las carpetas de Alfa."]
	elseif por == "disabled" then
		return L["Los datos del mundo de Alfa están apagados: activa «Alfa Codex» en la lista de addons."]
	elseif por == "empty" then
		return L["No pude leer los datos del mundo de Alfa: vuelve a instalar Alfa."]
	elseif por == "none" then
		return format(L["No conozco ningún lugar de «%s» para tu facción."], Ce.Nombre(tipo, linea))
	elseif por == "motor" then
		return L["La búsqueda de lugares cercanos no está disponible."]
	end
	return format(L["No pude cargar los datos del mundo de Alfa (%s)."], tostring(por))
end

---------------------------------------------------------------------------
-- Ir: la flecha y la ruta al más cercano
---------------------------------------------------------------------------

local function guiaAbierta()
	local E = A.Engine
	return E and type(E.GetGuide) == "function" and llamar(E.GetGuide) ~= nil
end

local function volverAGuia()
	local Nav = A.Nav
	if type(Nav) == "table" and type(Nav.EndTrip) == "function" then llamar(Nav.EndTrip) end
end

local function enViaje()
	local Nav = A.Nav
	local t = type(Nav) == "table" and type(Nav.Trip) == "function" and llamar(Nav.Trip)
	return type(t) == "table" and t or nil
end

local function tiempoTexto(seg)
	if not seg then return nil end
	if seg < 60 then return L["a menos de un minuto"] end
	return format(L["a unos %s"], M.Minutos(seg))
end

-- auto: lo pide Mis planes al llegarle el turno a una meta (no cierra ventanas).
function Ce.Ir(tipo, linea, auto)
	local t = resolver(tipo)
	local nb = cerca()
	if not nb then
		M.Aviso(L["Buscar cerca"], motivoLargo(t, linea, "motor"), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if not t or not claseMotor(t) then
		M.Aviso(L["Buscar cerca"], motivoLargo(t, linea, "kind"), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	linea = tonumber(linea)
	local e = buscar(t, linea)
	if not e.place then
		M.Aviso(Ce.Nombre(t, linea), motivoLargo(t, linea, e.por), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	-- El motor pone la flecha, arma la ruta y lo dice en el chat. Si algo
	-- falla después de poner la flecha, el viaje nuevo dice que sí quedó.
	local antes = enViaje()
	local ok, puesto = pcall(nb.Go, t, linea)
	if not ok and geterrorhandler then geterrorhandler()(puesto) end
	local viaje = enViaje()
	if not (ok and puesto) and not (viaje and viaje ~= antes) then
		M.Aviso(Ce.Nombre(t, linea), L["No pude poner la flecha ahí. Inténtalo otra vez en un momento."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	Ce.Cerrar()
	if not auto then M.Empezar() end
	if A.Get(M.ID .. ".cercaAviso") ~= false then
		local p = e.place
		local lugar, z = nombreLugar(t, p) or L["Un buzón"], zona(p.map) or "?"
		local texto
		if lejos(p) then
			texto = format(L["%s, en %s. Está en otro continente: la ruta te lleva."], lugar, z)
		elseif tiempoTexto(e.seg) then
			texto = format(L["%s, en %s (%s)."], lugar, z, tiempoTexto(e.seg))
		else
			texto = format(L["%s, en %s."], lugar, z)
		end
		local d = POR_TIPO[t]
		M.Aviso(Ce.Nombre(t, linea), texto, { icono = d and d.icono or "ic-flecha", tono = "acento",
			accion = guiaAbierta() and { texto = L["Volver a la guía"], alClic = volverAGuia } or nil })
	end
	return true
end

---------------------------------------------------------------------------
-- El menú
---------------------------------------------------------------------------

local F, atrapa
local filas = {}
local est = { pagina = "inicio", dueno = nil, turno = 0 }

local function cerrar()
	if F then F:Hide() end
	if atrapa then atrapa:Hide() end
end
Ce.Cerrar = cerrar

function Ce.Visible() return F ~= nil and F:IsShown() end

-- Las filas de cada página. Una fila: { tipo, linea, nombre, icono, nota,
-- pagina, vista = { tipo, linea } (lo que se busca para su línea), accion,
-- corta } | { separador = true } | { grupo = texto }.
local function filasInicio()
	local out = {}
	local viaje = enViaje()
	if viaje then
		out[#out + 1] = { nombre = L["Volver a la guía"], icono = "ic-huella",
			nota = type(viaje.name) == "string" and format(L["Ahora vas a: %s"], viaje.name) or nil, accion = volverAGuia }
		out[#out + 1] = { separador = true }
	end
	local c = clase()
	for _, d in ipairs(TIPOS) do
		if d.separador then
			out[#out + 1] = d
		elseif not d.para or d.para(c) then
			local f = { tipo = d.tipo, nombre = d.nombre, icono = d.icono, nota = d.nota, pagina = d.pagina }
			if d.pagina == "oficios" then
				local mias = oficios()
				local nombres = {}
				for i, l in ipairs(mias) do if i <= 3 then nombres[#nombres + 1] = nombreOficio(l) end end
				f.nota = #nombres > 0 and concat(nombres, ", ") or L["Elige una profesión"]
			elseif d.pagina == "vendedor" then
				f.vista = { tipo = "vendor" }
			else
				f.vista = { tipo = d.tipo }
			end
			out[#out + 1] = f
		end
	end
	return out
end

local function filasOficios()
	local out = {}
	local mias, otras = oficios()
	out[#out + 1] = { tipo = "trainer", nombre = L["Cualquier profesión"], icono = "ic-oficios",
		nota = L["El entrenador de oficio más cercano"], vista = { tipo = "trainer" } }
	if #mias > 0 then
		out[#out + 1] = { grupo = L["Tus profesiones"] }
		for _, l in ipairs(mias) do
			out[#out + 1] = { tipo = "trainer", linea = l, nombre = nombreOficio(l), icono = "ic-oficios", vista = { tipo = "trainer", linea = l } }
		end
	end
	if #otras > 0 then
		out[#out + 1] = { grupo = #mias > 0 and L["Las demás"] or L["Todas las profesiones"] }
		for _, l in ipairs(otras) do
			out[#out + 1] = { tipo = "trainer", linea = l, nombre = nombreOficio(l), icono = "ic-oficios", corta = true }
		end
	end
	return out
end

local function filasVendedor()
	local out = {}
	local nb = cerca()
	for _, d in ipairs(VENDEDOR) do
		local k = claseMotor(d.tipo)
		local sirve = k ~= nil
		if sirve and nb and type(nb.Fits) == "function" then
			local ok, si = pcall(nb.Fits, k)
			sirve = not ok or si and true or false
		end
		if sirve then
			out[#out + 1] = { tipo = d.tipo, nombre = d.nombre, icono = d.icono, vista = { tipo = d.tipo } }
		end
	end
	return out
end

local PAGINAS = {
	inicio = { titulo = L["Buscar cerca"], filas = filasInicio },
	oficios = { titulo = L["Entrenadores de profesión"], filas = filasOficios },
	vendedor = { titulo = L["Vendedor"], filas = filasVendedor },
}

local pintar -- adelante

local function elegir(d)
	if not d then return end
	if d.accion then
		cerrar()
		K.Llamar(d.accion)
	elseif d.pagina then
		est.pagina = d.pagina
		pintar()
	elseif d.tipo then
		Ce.Ir(d.tipo, d.linea)
	end
end

local function fila(i)
	local f = filas[i]
	if f then return f end
	f = CreateFrame("Button", nil, F)
	f:RegisterForClicks("LeftButtonUp")
	f.velo = K.Velo(f, K.CORTE.control, 0.06)
	f.Icono = K.Icono(f, "ic-cerca", 16, "acento")
	f.Icono:SetPoint("LEFT", f, "LEFT", 10, 0)
	f.Flecha = K.Icono(f, "chevron-right", 12, "textoTenue")
	f.Flecha:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Grupo = K.Texto(f, "mayus", "textoTenue")
	f.Grupo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 5)
	f.Separador = K.Linea(f, "linea")
	f.Separador:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.Separador:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	f:SetScript("OnEnter", function(self) if self.alfaDato and not self.alfaInerte then self.velo:Show() end end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() end)
	f:SetScript("OnClick", function(self) if not self.alfaInerte then elegir(self.alfaDato) end end)
	filas[i] = f
	return f
end

-- La línea de abajo de una fila: lo que se sabe, "Buscando…" o su nota.
local function pintarSub(f)
	local d = f.alfaDato
	if not d or d.corta then return end
	local texto, color
	if d.vista then
		local e = sabido(d.vista.tipo, d.vista.linea)
		if e then
			texto, color = lineaCorta(d.vista.tipo, e)
		elseif f.alfaBuscando then
			texto, color = L["Buscando..."], "textoTenue"
		end
	end
	if not texto then texto, color = d.nota or L["Clic: la flecha te lleva"], "textoTenue" end
	K.Escribir(f.Sub, texto)
	K.ColorTexto(f.Sub, color)
end

local function pintarFila(f, d, y)
	f.alfaDato, f.alfaBuscando = d, nil
	local sep, grupo = d.separador and true or false, d.grupo ~= nil
	f.alfaInerte = (sep or grupo) and true or nil
	f.velo:Hide()
	f.Separador:SetShown(sep)
	f.Grupo:SetShown(grupo)
	f.Icono:SetShown(not (sep or grupo))
	f.Titulo:SetShown(not (sep or grupo))
	f.Sub:SetShown(not (sep or grupo or d.corta))
	f.Flecha:SetShown(d.pagina ~= nil)
	local alto
	if sep then
		alto = SEPARADOR
	elseif grupo then
		alto = GRUPO
		K.Escribir(f.Grupo, K.Mayus and K.Mayus(d.grupo) or d.grupo:upper())
	else
		alto = d.corta and FILA_CORTA or FILA
		K.SetIcono(f.Icono, d.icono or "ic-flecha", d.accion and "acento" or "textoSuave")
		K.Escribir(f.Titulo, d.nombre or "")
		f.Titulo:ClearAllPoints()
		local derecha = d.pagina and f.Flecha or f
		if d.corta then
			f.Titulo:SetPoint("LEFT", f, "LEFT", 36, 0)
		else
			f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -5)
			f.Sub:ClearAllPoints()
			f.Sub:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -3)
			f.Sub:SetPoint("RIGHT", derecha, d.pagina and "LEFT" or "RIGHT", d.pagina and -6 or -10, 0)
		end
		f.Titulo:SetPoint("RIGHT", derecha, d.pagina and "LEFT" or "RIGHT", d.pagina and -6 or -10, 0)
		pintarSub(f)
	end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", F, "TOPLEFT", 4, -y)
	f:SetSize(ANCHO - 8, alto)
	f:Show()
	return alto
end

-- Las búsquedas de la página, una por cuadro: el menú abre al instante y cada
-- fila se completa cuando llega lo suyo.
local function buscarFilas(n)
	est.turno = est.turno + 1
	local turno = est.turno
	local cola = {}
	local combate = enCombate() and not codexCargado()
	for i = 1, n do
		local f = filas[i]
		local v = f and f.alfaDato and f.alfaDato.vista
		if not v or sabido(v.tipo, v.linea) then
			-- Ya está pintada con lo que se sabe (o no busca nada).
		elseif not combate then
			f.alfaBuscando = true
			pintarSub(f)
			cola[#cola + 1] = f
		else
			K.Escribir(f.Sub, L["Después del combate"])
			K.ColorTexto(f.Sub, "aviso")
		end
	end
	local k = 0
	local function siguiente()
		if turno ~= est.turno or not (F and F:IsShown()) then return end
		k = k + 1
		local f = cola[k]
		if not f then return end
		local v = f.alfaDato and f.alfaDato.vista
		if v then buscar(v.tipo, v.linea) end
		f.alfaBuscando = nil
		pintarSub(f)
		A.After(0.02, siguiente)
	end
	if #cola > 0 then A.After(0.05, siguiente) end
end

local function colocar()
	F:ClearAllPoints()
	local ancla = est.dueno
	if ancla and ancla.GetBottom and ancla:IsVisible() then
		local escala = K.num(ancla:GetEffectiveScale(), 1) / max(0.01, K.num(UIParent:GetEffectiveScale(), 1))
		local abajo = K.num(ancla:GetBottom(), 0) * escala
		if abajo - F:GetHeight() < 16 then
			F:SetPoint("BOTTOMLEFT", ancla, "TOPLEFT", 0, 4)
		else
			F:SetPoint("TOPLEFT", ancla, "BOTTOMLEFT", 0, -4)
		end
	else
		local x, y = 0, 0
		if GetCursorPosition then x, y = GetCursorPosition() end
		local s = max(0.01, K.num(UIParent:GetEffectiveScale(), 1))
		F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", K.num(x, 0) / s - 24, K.num(y, 0) / s + 12)
	end
end

function pintar()
	if not F then return end
	local pag = PAGINAS[est.pagina] or PAGINAS.inicio
	local enInicio = est.pagina == "inicio"
	F.Atras:SetShown(not enInicio)
	F.Icono:SetShown(enInicio)
	K.Escribir(F.Titulo, pag.titulo)
	K.Escribir(F.Sub, L["El más cercano, por tiempo de camino"])
	F.Titulo:ClearAllPoints()
	F.Titulo:SetPoint("TOPLEFT", F, "TOPLEFT", 40, -9)
	F.Titulo:SetPoint("RIGHT", F.Cerrar, "LEFT", -6, 0)
	local lista = pag.filas()
	local y = CAB
	for i, d in ipairs(lista) do y = y + pintarFila(fila(i), d, y) end
	for i = #lista + 1, #filas do filas[i]:Hide() end
	F:SetHeight(y + 6)
	colocar()
	buscarFilas(#lista)
end

local function construir()
	atrapa = CreateFrame("Button", nil, UIParent)
	atrapa:SetAllPoints(UIParent)
	atrapa:SetFrameStrata("FULLSCREEN_DIALOG")
	atrapa:RegisterForClicks("AnyUp")
	atrapa:SetScript("OnClick", cerrar)
	atrapa:Hide()
	F = CreateFrame("Frame", "AlfaCercaMenu", UIParent)
	F:SetFrameStrata("FULLSCREEN_DIALOG")
	F:SetFrameLevel(atrapa:GetFrameLevel() + 10)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetWidth(ANCHO)
	F.caja = K.Caja(F, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel, rol = "panel" })
	F.Marca = K.Marca(F, K.CORTE.panel)
	F.Cerrar = K.BotonIcono(F, "ic-cerrar", cerrar, { tam = 22, icono = 10, ayuda = L["Cerrar"] })
	F.Cerrar:SetPoint("TOPRIGHT", F, "TOPRIGHT", -8, -8)
	F.Atras = K.BotonIcono(F, "chevron-left", function() est.pagina = "inicio" pintar() end, { tam = 22, icono = 12, ayuda = L["Volver"] })
	F.Atras:SetPoint("TOPLEFT", F, "TOPLEFT", 10, -8)
	F.Icono = K.Icono(F, "ic-cerca", 16, "acento")
	F.Icono:SetPoint("TOPLEFT", F, "TOPLEFT", 14, -11)
	F.Titulo = K.Texto(F, "encabezado", "texto")
	F.Sub = K.Texto(F, "pequeno", "textoTenue")
	F.Sub:SetPoint("TOPLEFT", F, "TOPLEFT", 14, -30)
	F.Sub:SetPoint("RIGHT", F, "RIGHT", -12, 0)
	F.Linea = K.Linea(F, "linea")
	F.Linea:SetPoint("TOPLEFT", F, "TOPLEFT", 12, -(CAB - 4))
	F.Linea:SetPoint("TOPRIGHT", F, "TOPRIGHT", -12, -(CAB - 4))
	F:SetScript("OnHide", function()
		if atrapa then atrapa:Hide() end
		est.turno = est.turno + 1
	end)
	F:Hide()
	-- Esc lo cierra.
	if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "AlfaCercaMenu" end
	K.AlRepintar(function() if F and F:IsShown() then pintar() end end)
end

function Ce.Menu(ancla, pagina)
	if not F then construir() end
	if F:IsShown() and est.dueno == ancla and not pagina then cerrar() return end
	K.CerrarMenu()
	est.dueno = type(ancla) == "table" and ancla or nil
	est.pagina = PAGINAS[pagina or ""] and pagina or "inicio"
	atrapa:Show()
	F:Show()
	pintar()
end

-- Los tipos de la portada del menú, para este personaje.
function Ce.Tipos()
	local out = {}
	local c = clase()
	for _, d in ipairs(TIPOS) do
		if d.tipo and (not d.para or d.para(c)) then
			out[#out + 1] = { tipo = d.tipo, nombre = d.nombre, icono = d.icono, pagina = d.pagina }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- /alfa cerca [tipo] [profesión]
---------------------------------------------------------------------------

local function ayuda()
	A.Print(L["Buscar cerca:"])
	A.Print("  /alfa cerca  \194\183  " .. L["abre el menú"])
	A.Print("  /alfa cerca vuelo | posada | reparar | banco | buzon | subasta  \194\183  " .. L["la flecha al más cercano"])
	A.Print("  /alfa cerca entrenador | vendedor | comida | componentes | establo  \194\183  " .. L["lo mismo"])
	A.Print("  /alfa cerca oficio [" .. L["profesión"] .. "]  \194\183  " .. L["un entrenador de profesión (también: /alfa cerca minería)"])
end

A.RegisterCommand("cerca", function(resto)
	local texto = type(resto) == "string" and resto:match("^%s*(.-)%s*$") or ""
	local palabra, mas = texto:match("^(%S+)%s*(.-)$")
	if not palabra then return Ce.Menu() end
	local p = M.Plegar(palabra)
	if p == "ayuda" or p == "help" or p == "?" then return ayuda() end
	local t = resolver(palabra)
	if t and claseMotor(t) then
		local linea
		if t == "trainer" and mas ~= "" then
			linea = oficioDe(mas)
			if not linea then
				M.Aviso(L["Buscar cerca"], format(L["No conozco la profesión «%s»."], mas), { icono = "ic-aviso", tono = "aviso" })
				return
			end
		end
		Ce.Ir(t, linea)
		return
	end
	-- Una profesión sola: su entrenador.
	local linea = oficioDe(texto)
	if linea then return Ce.Ir("trainer", linea) end
	Ce.Ir(palabra)
end, L["El maestro de vuelo, la posada, reparar, el banco... el más cercano (/alfa cerca ayuda)."])

-- La tecla (Bindings.xml).
BINDING_NAME_ALFA_RUTAS_CERCA = L["Buscar cerca (vuelo, posada, reparar...)"]

---------------------------------------------------------------------------
-- AlfaCerca (global)
---------------------------------------------------------------------------

local G = AlfaCerca or {}
AlfaCerca = G
G.Menu = function(ancla, pagina) return Ce.Menu(ancla, pagina) end
G.Ir = function(tipo, linea) return Ce.Ir(tipo, linea) end
G.Tipos = function() return Ce.Tipos() end
G.Texto = function(tipo, linea) return Ce.Texto(tipo, linea) end
G.Nombre = function(tipo, linea) return Ce.Nombre(tipo, linea) end
G.Cerrar = function() return Ce.Cerrar() end
G.Visible = function() return Ce.Visible() end
