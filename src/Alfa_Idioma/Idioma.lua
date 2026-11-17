-- Alfa - Idioma: el idioma de Alfa, aunque el juego esté en otro (toxic3000 / La Jauría). GPL-3.0.
--
-- Este addon carga antes que el motor (Alfa lo tiene en OptionalDeps), así su
-- variable guardada ya está lista cuando los archivos de Alfa preguntan el
-- idioma al cargar. tools/build.py cambia en todo Alfa las llamadas a
-- GetLocale() por (AlfaIdioma or GetLocale)(): sin este addon, todo sigue con
-- el idioma del juego.
--
--   AlfaIdioma() -> "esMX" | "enUS" | ...   el elegido, o el del juego
--   AlfaPonerIdioma(loc) -> true si hace falta /reload para verlo (nil = el del juego)
--   AlfaIdiomas -> { { loc, nombre }, ... }  los que trae Alfa, cada uno en su idioma

local juego = GetLocale

AlfaIdiomas = {
	{ "esMX", "Español (Latinoamérica)" },
	{ "esES", "Español (España)" },
	{ "enUS", "English" },
	{ "deDE", "Deutsch" },
	{ "frFR", "Français" },
	{ "ptBR", "Português (Brasil)" },
	{ "ruRU", "Русский" },
	{ "koKR", "한국어" },
	{ "zhCN", "简体中文" },
	{ "zhTW", "繁體中文" },
}

local validos = {}
for _, par in ipairs(AlfaIdiomas) do validos[par[1]] = true end

-- El idioma con el que cargó esta sesión: cambiarlo a medias dejaría textos
-- de dos idiomas, así que un cambio se ve después de /reload.
local sesion

function AlfaIdioma()
	if sesion then return sesion end
	local db = rawget(_G, "AlfaIdiomaDB")
	local loc = type(db) == "table" and db.idioma
	if not (loc and validos[loc]) then loc = juego and juego() or "enUS" end
	if loc == "enGB" then loc = "enUS" end
	sesion = loc
	return loc
end

function AlfaPonerIdioma(loc)
	if loc ~= nil and not validos[loc] then return false end
	AlfaIdiomaDB = type(AlfaIdiomaDB) == "table" and AlfaIdiomaDB or {}
	AlfaIdiomaDB.idioma = loc
	local nuevo = loc or (juego and juego()) or "enUS"
	return nuevo ~= AlfaIdioma()
end
