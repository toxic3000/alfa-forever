-- Alfa - Pesca: la pestaña Pescador (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8: tu nivel de pescador de Alfa con su barra y su título, el pez de la
-- semana (dónde pescarlo, cuánto llevas y su premio) y tus récords: el más
-- grande de cada pez, con dónde y cuándo lo sacaste. Los datos y las cuentas
-- viven en Pescador.lua.

local ADDON, M = ...
local N = AlfaNucleo
local K = N.Kit
local L = M.L
local V = M.V
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "
local VISIBLES = 12

local function num(v) return tonumber(v) or 0 end

local function nombreDe(clave)
	if type(clave) == "number" then return V.NombreObjeto(clave) end
	local e = M.Diario()[clave]
	return (type(e) == "table" and e.nombre) or tostring(clave)
end

local function iconoDe(clave)
	if type(clave) == "number" then return Eq.Icono(clave) end
	local e = M.Diario()[clave]
	return type(e) == "table" and e.icono or nil
end

-- "en 3 días" / "en 5 h"
local function quedan(seg)
	seg = max(0, num(seg))
	if seg >= 86400 then return N.Plural(floor(seg / 86400 + 0.5), L["queda %d día"], L["quedan %d días"]) end
	return N.Plural(max(1, floor(seg / 3600 + 0.5)), L["queda %d hora"], L["quedan %d horas"])
end

local function tarjetaNivel()
	local Pz = M.Pez
	local p = Pz.Datos()
	local nivel, en, pide, titulo = Pz.Nivel(p.xp)
	local d = { lobo = nivel >= 10 and "aullando" or "normal", tono = "acento", sobre = L["Pescador de Alfa"],
		titulo = format(L["Nivel %d · %s"], nivel, titulo) }
	if pide then
		d.texto = format(L["Te faltan %d de experiencia para el nivel %d. Ganas más con lo raro, lo nuevo, tus récords y los bancos de peces."], pide - en, nivel + 1)
		d.progreso = { actual = en, total = pide, texto = format(L["%d de %d"], en, pide) }
	else
		d.texto = L["Llegaste al nivel más alto. La manada te cuenta entre sus leyendas."]
		d.progreso = { actual = 1, total = 1, texto = L["al máximo"] }
	end
	local t = p.temporada or {}
	d.insignias = {
		{ format(L["%d en total"], num(p.xp)), "neutro", "ic-nivel" },
		{ format(L["%s: %d"], Pz.NombreTemporada(t.id), num(t.xp)), "acento", "ic-reloj" },
	}
	return d
end

local function tarjetaSemana()
	local Pz = M.Pez
	local s = Pz.Semana()
	if not s then return nil end
	local nombres, visto = {}, {}
	for _, m in ipairs(s.mapas or {}) do
		local n = V.NombreMapa(m)
		if n and not visto[n] then visto[n] = true nombres[#nombres + 1] = n end
	end
	local lineas = {}
	if #nombres > 0 then lineas[#lineas + 1] = format(L["Dónde: %s."], table.concat(nombres, ", ")) end
	if M.BANCOS_DE[s.id] then lineas[#lineas + 1] = L["También sale en bancos de peces."] end
	lineas[#lineas + 1] = format(L["Saca %d esta semana: +%d de experiencia de pescador."], s.meta, Pz.XP.premioSemana)
	local d = { icono = Eq.Icono(s.id) or "ic-pesca", tenir = Eq.Icono(s.id) == nil, tono = s.premiado and "exito" or "oro",
		sobre = L["Pez de la semana"], titulo = V.NombreObjeto(s.id), texto = table.concat(lineas, "\n"),
		progreso = { actual = min(s.llevas, s.meta), total = s.meta, texto = s.premiado and L["¡Cumplido!"] or format(L["%d de %d"], min(s.llevas, s.meta), s.meta) },
		insignias = { { quedan(s.quedan), "neutro", "ic-reloj" } },
		accion = { texto = L["Guíame"], alClic = function() V.Guiar("item", s.id) end } }
	return d
end

local function tarjetasRecords(todos)
	local Pz = M.Pez
	local lista = {}
	for clave, r in pairs(Pz.Records()) do
		if type(r) == "table" then lista[#lista + 1] = { clave = clave, r = r } end
	end
	table.sort(lista, function(a, b) return num(a.r.g) > num(b.r.g) end)
	local out = {}
	for i = 1, todos and #lista or min(VISIBLES, #lista) do
		local x = lista[i]
		local icono = iconoDe(x.clave)
		local partes = { Pz.Texto(x.r) or Pz.Peso(x.r.g) }
		if x.r.z then partes[#partes + 1] = x.r.z end
		out[#out + 1] = { variante = "compacta", icono = icono or "ic-pesca", tenir = icono == nil, titulo = nombreDe(x.clave),
			texto = table.concat(partes, DOT), ayuda = format(L["Lo sacaste %s."], V.Hace(x.r.t)) }
	end
	return out, #lista
end

local function construir(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local ui = { todos = false }
	ui.nivel = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
	ui.semana = pila:Agregar(K.Tarjeta(pila, { variante = "normal" }), { espacio = ESP.m })
	ui.secRec = pila:Agregar(K.Seccion(pila, L["Tus récords"]))
	ui.rec = pila:Agregar(K.Rejilla(pila, { min = 340, gap = ESP.s, variante = "compacta" }), { espacio = ESP.m })
	ui.recVacio = pila:Agregar(K.Vacio(pila, { lobo = "dormido", titulo = L["Todavía no tienes récords"],
		texto = L["Cada pez que sacas tiene su tamaño: el más grande de cada especie queda aquí."] }), { espacio = ESP.m })
	ui.secXp = pila:Agregar(K.Seccion(pila, L["Cómo se gana experiencia"]))
	ui.xp = pila:Agregar(V.Parrafo(pila, "nota", "textoSuave"), { espacio = ESP.xs })
	p.antes = function()
		local Pz = M.Pez
		ui.nivel:Set(tarjetaNivel())
		local sem = tarjetaSemana()
		if sem then ui.semana:Set(sem) end
		K.Mostrar(ui.semana, sem ~= nil)
		local datos, total = tarjetasRecords(ui.todos)
		ui.rec:Llenar(datos)
		K.Mostrar(ui.rec, #datos > 0)
		K.Mostrar(ui.recVacio, #datos == 0)
		ui.secRec:Set(L["Tus récords"], { cuenta = total > 0 and total or nil,
			enlace = total > VISIBLES and { texto = ui.todos and L["Ver menos"] or format(L["Ver todos (%d)"], total), alClic = function()
				ui.todos = not ui.todos
				V.Acomodar()
			end } or nil })
		local X = Pz.XP
		ui.xp:Set(table.concat({
			format(L["Cada captura: %d. Un trofeo: +%d; uno de concurso: +%d."], X.base, X.clase.trofeo, X.clase.concurso),
			format(L["Algo nuevo en tu diario: +%d. Un récord: +%d (en una zona: +%d). Un ejemplar: +%d."], X.primera, X.record, X.recordZona, X.ejemplar),
			format(L["De un banco de peces: +%d. El pez de la semana: +%d cada uno, y +%d al sacar %d."], X.banco, X.semana, X.premioSemana, Pz.META_SEMANA),
		}, "\n"))
	end
	return p
end

V.Registrar("pescador", { nombre = L["Pescador"], icono = "ic-huella", orden = 1.5,
	cambia = { registro = true, captura = true, pescador = true }, construir = construir })
