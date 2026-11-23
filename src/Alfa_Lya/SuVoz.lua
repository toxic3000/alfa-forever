-- Alfa - Lya: tus misiones en su voz (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
--   lya.misionVoz (prendido de fábrica): al tomar una misión, Lya te la
--   resume en dos líneas con sus palabras: la primera dice qué hay que hacer
--   (de los objetivos del juego: cazar, juntar, usar, hablar); la segunda, un
--   comentario suyo según el tipo de misión y la zona. Sin internet ni IA:
--   plantillas suyas. Nunca el texto largo (eso es «Contármela», Historias.lua).
--   Si Lya ya está hablando (un gancho de Historias, por ejemplo), se calla.
--
--   Sv.Resumen(questID) -> "línea 1\nlínea 2" | nil
--   AlfaLya.MisionEnSuVoz(questID) -> lo mismo

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, pcall, ipairs, format = type, tonumber, pcall, ipairs, string.format

local Sv = {}
M.SuVoz = Sv

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end

-- Lo que hay que hacer, por tipo de objetivo.
local QUE = {
	monster = "cazar %s",
	item = "juntar %s",
	object = "usar %s",
	event = "%s",
	reputation = "ganarte a %s",
	log = "%s",
	player = "%s",
}

-- Su comentario, por el tipo de la misión (el primero de sus objetivos).
Sv.CIERRES = {
	monster = {
		"Ve con cuidado: la presa también muerde.",
		"Yo huelo el rastro; tú pones los colmillos.",
		"Caza limpio y no te alejes de la manada.",
	},
	item = {
		"Revisa bien cada rincón; yo te aviso si huelo algo.",
		"Paciencia: lo que se busca con calma, se encuentra.",
		"Si sueltan poco, no te desesperes. Pasa en toda buena caza.",
	},
	object = {
		"Fíjate en lo que brilla en el suelo: ahí suele estar.",
		"Mira bien alrededor; las cosas importantes no se esconden tanto.",
	},
	event = {
		"Algo importante pasa aquí; no te lo pierdas.",
		"Esto huele a historia grande. Pon atención.",
	},
	hablar = {
		"Solo hay que llevar el recado. ¡Fácil, como pedirme una salchicha!",
		"Un paseíto y unas palabras. Así también se hace manada.",
	},
}

local function objetivos(q)
	local Q = C_QuestLog
	if not (Q and Q.GetQuestObjectives) then return {} end
	local ok, lista = pcall(Q.GetQuestObjectives, q)
	return ok and type(lista) == "table" and lista or {}
end

local function titulo(q)
	local Q = C_QuestLog
	if Q and Q.GetTitleForQuestID then
		local ok, t = pcall(Q.GetTitleForQuestID, q)
		t = ok and texto(t)
		if t then return t end
	end
	local H = M.Historias
	if H and H.Todas then
		local ok, s = pcall(H.Todas)
		local r = ok and type(s) == "table" and s[q]
		if type(r) == "table" then return texto(r.t) end
	end
	return nil
end

-- "Jabalí moteado asesinado: 0/8" -> "Jabalí moteado asesinado" (y 8).
local function limpiar(o)
	local t = texto(o.text)
	if not t then return nil end
	local nombre = t:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or t:match("^%d+%s*/%s*%d+%s+(.+)$") or t
	nombre = nombre:gsub("%s+$", "")
	if nombre == "" then return nil end
	local n = tonumber(o.numRequired)
	if n and n > 1 then nombre = format("%s (%d)", nombre, n) end
	return nombre
end

-- Escoge sin azar (la misma misión, la misma frase).
local function una(lista, q) return lista[(q % #lista) + 1] end

function Sv.Resumen(q)
	q = tonumber(q)
	if not q then return nil end
	local t = titulo(q)
	local partes, tipo = {}, nil
	for _, o in ipairs(objetivos(q)) do
		if type(o) == "table" and #partes < 2 then
			local cual = texto(o.type) or "log"
			local nombre = limpiar(o)
			if nombre then
				tipo = tipo or cual
				partes[#partes + 1] = format(L[QUE[cual] or "%s"], nombre)
			end
		end
	end
	local linea1
	if #partes == 0 then
		tipo = "hablar"
		linea1 = t and format(L["«%s»: hay que llevar el recado y hablar con quien te espera."], t)
			or L["Hay que llevar el recado y hablar con quien te espera."]
	else
		local que = #partes == 2 and (partes[1] .. L[" y "] .. partes[2]) or partes[1]
		linea1 = t and format(L["«%s»: toca %s."], t, que) or format(L["Toca %s."], que)
	end
	local cierres = Sv.CIERRES[tipo] or Sv.CIERRES.event
	return linea1 .. "\n" .. L[una(cierres, q)]
end

function Sv.Decir(q)
	if N.Get(ID, "misionVoz") == false then return false end
	local r = Sv.Resumen(q)
	local Ce = M.Cerebro
	if not (r and Ce and Ce.Decir) then return false end
	return Ce.Decir({ id = "mv." .. tostring(q), texto = r, lineas = 4 }) == true
end

A.RegisterEvent("QUEST_ACCEPTED", function(_, a, b)
	local q = tonumber(b) or tonumber(a)
	if secreto(a) or secreto(b) or not q or N.Get(ID, "misionVoz") == false then return end
	-- Después del gancho de Historias (3 s): si está hablando, no se encima.
	A.After(5, function() Sv.Decir(q) end)
end)

local API = rawget(_G, "AlfaLya")
if type(API) == "table" then
	API.MisionEnSuVoz = function(q) return Sv.Resumen(q) end
end

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.misionVoz", icono = "ic-misiones", modulo = "lya",
			pregunta = L["¿Me cuentas de qué va una misión?"],
			respuesta = L["Al tomar una misión te la resumo en dos líneas, a mi modo: qué hay que hacer y un consejito. La historia completa sigue en «Historias»."] })
	end
end)
