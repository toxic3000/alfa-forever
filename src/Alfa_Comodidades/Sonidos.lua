-- Alfa - Comodidades: silenciar sonidos molestos (grupos del juego y una
-- lista propia). GPL-3.0.
--
-- Cuatro grupos de sonidos se apagan con las variables de sonido del propio
-- juego, las mismas casillas de Opciones > Audio de Forever
-- (Blizzard_SettingsDefinitions_Shared/Audio.lua): voces de error
-- (Sound_EnableErrorSpeech, "No tengo suficiente maná"), diálogos y saludos
-- de los PNJ (Sound_EnableDialog), sonidos de mascotas (Sound_EnablePetSounds,
-- como el bostezo de los gatos de cazador) y de gestos (Sound_EnableEmoteSounds).
-- Al apagar la opción vuelve el valor que tenías.
--
-- Además, una lista propia de sonidos por su número de archivo (FileDataID):
-- /alfa silenciar <número> lo agrega, /alfa silenciar quitar <número> lo
-- quita y /alfa silenciar muestra la lista. Se silencian con MuteSoundFile y
-- vuelven con UnmuteSoundFile (no están en la documentación generada; otros
-- addons los usan en Forever). El juego olvida lo
-- silenciado al salir, así que se vuelve a aplicar al entrar.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

M.SONIDOS = {
	{ clave = "silenciarErrores", cvar = "Sound_EnableErrorSpeech" },
	{ clave = "silenciarDialogos", cvar = "Sound_EnableDialog" },
	{ clave = "silenciarMascotas", cvar = "Sound_EnablePetSounds" },
	{ clave = "silenciarGestos", cvar = "Sound_EnableEmoteSounds" },
}

for _, s in ipairs(M.SONIDOS) do
	M.AlCambiar({ s.clave }, function()
		M.ForzarCVar(s.cvar, "0", M.Get(s.clave))
	end)
end

---------------------------------------------------------------------------
-- Tu lista
---------------------------------------------------------------------------

local function lista()
	local d = N.Datos(M.ID)
	d.sonidos = type(d.sonidos) == "table" and d.sonidos or {}
	return d.sonidos
end

local silenciados = {} -- id -> true: lo que está silenciado ahora

local function silenciar(id, si)
	if si and not silenciados[id] and MuteSoundFile then
		if pcall(MuteSoundFile, id) then silenciados[id] = true end
	elseif not si and silenciados[id] and UnmuteSoundFile then
		pcall(UnmuteSoundFile, id)
		silenciados[id] = nil
	end
end

local function aplicarLista()
	local on = M.Get("silenciarLista")
	local l = lista()
	for id in pairs(silenciados) do
		if not (on and l[id]) then silenciar(id, false) end
	end
	if on then
		for id in pairs(l) do silenciar(id, true) end
	end
end

M.AlCambiar({ "silenciarLista" }, aplicarLista)

local function ordenada()
	local ids = {}
	for id in pairs(lista()) do ids[#ids + 1] = id end
	table.sort(ids)
	return ids
end

function M.MostrarListaSonidos()
	local ids = ordenada()
	if #ids == 0 then
		N.Imprimir(L["Tu lista de sonidos está vacía. Agrega uno con /alfa silenciar <número>."])
	else
		local partes = {}
		for i, id in ipairs(ids) do partes[i] = tostring(id) end
		N.Imprimir(string.format(L["Sonidos en tu lista (%d): %s"], #ids, table.concat(partes, ", ")))
	end
	if not M.Get("silenciarLista") then
		N.Imprimir(L["La lista está apagada: enciende \"Tu lista de sonidos\" en Calidad de vida > Interfaz."])
	end
end

A.RegisterCommand("silenciar", function(resto)
	resto = strtrim and strtrim(resto or "") or (resto or "")
	local quitar, numero = resto:match("^(%a*)%s*(%d+)$")
	if resto == "" or resto == "lista" then return M.MostrarListaSonidos() end
	if resto == "borrar" then
		local l = lista()
		for id in pairs(l) do l[id] = nil end
		aplicarLista()
		return N.Imprimir(L["Tu lista de sonidos quedó vacía."])
	end
	local id = tonumber(numero)
	if not id or (quitar ~= "" and quitar ~= "quitar") then
		return N.Imprimir(L["Uso: /alfa silenciar <número>, /alfa silenciar quitar <número>, /alfa silenciar borrar."])
	end
	local l = lista()
	if quitar == "quitar" then
		l[id] = nil
		N.Imprimir(string.format(L["Se quitó el sonido %d de tu lista."], id))
	else
		l[id] = true
		N.Imprimir(string.format(L["Se agregó el sonido %d a tu lista."], id))
	end
	aplicarLista()
end, L["Silenciar un sonido por su número (FileDataID)"])
