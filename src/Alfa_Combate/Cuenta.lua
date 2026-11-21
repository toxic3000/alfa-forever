-- Alfa - Combate: la cuenta para jalar (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7. Cuando alguien de tu grupo lanza la cuenta del juego (el botón
-- «Cuenta atrás» de la banda, START_PLAYER_COUNTDOWN), un anuncio grande de
-- Alfa (K.Anuncio) con quién la lanzó y cuánto falta; si la cancelan, se va.
-- Para lanzarla tú: un botón seguro en la página de Combate que hace clic en
-- el botón del juego (C_PartyInfo.DoCountdown tiene restricciones: solo con
-- tu clic, nunca desde el código de Alfa).

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Cu = {}
M.Cuenta = Cu

local type, ipairs, floor, format, tonumber = type, ipairs, math.floor, string.format, tonumber

-- 1.3.7: el anuncio de la cuenta (la tabla): al cancelarla se quita ese y no
-- otro que haya salido después (antes quedaba «nuestra» aunque ya se hubiera ido).
local nuestra = nil

---------------------------------------------------------------------------
-- Cuando alguien la lanza
---------------------------------------------------------------------------
-- seg: lo que falta; quien: su nombre (o nil).
function Cu.Empieza(seg, quien)
	if not M.Opt("cuenta") then return false end
	if M.Secreto(seg) or type(seg) ~= "number" or seg <= 0 then return false end
	if M.Secreto(quien) or type(quien) ~= "string" or quien == "" then quien = nil end
	if quien then quien = quien:gsub("%-.*$", "") end
	local o = {
		sobre = quien and format(L["%s lanzó la cuenta"], quien) or L["Cuenta para jalar"],
		titulo = L["¡A jalar!"],
		texto = format(L["En %s"], tostring(floor(seg + 0.5))),
		lobo = "atento",
		segundos = seg + 1.5,
		cuenta = { hasta = GetTime() + seg, formato = L["En %s"], final = L["¡Ahora!"] },
		caduca = GetTime() + seg,
	}
	if nuestra and K.QuitarEsteAnuncio then K.QuitarEsteAnuncio(nuestra) end
	nuestra = o
	return K.Anuncio(o)
end

function Cu.Cancela()
	local o = nuestra
	if not o then return end
	nuestra = nil
	if K.QuitarEsteAnuncio then K.QuitarEsteAnuncio(o)
	elseif K.QuitarAnuncio then
		local ac = K.AnuncioActual and K.AnuncioActual()
		if ac and ac.titulo == o.titulo then K.QuitarAnuncio() end
	end
end

function Cu.Probar() return Cu.Empieza(10, L["Lya"]) end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento, guid, a, b, c, d)
	if evento == "START_PLAYER_COUNTDOWN" then
		-- (initiatedBy, timeRemaining, totalTime, informChat, initiatedByName)
		K.Llamar(Cu.Empieza, a, d)
	else
		K.Llamar(Cu.Cancela)
	end
end)

---------------------------------------------------------------------------
-- Lanzarla tú: el botón del juego, por el clic seguro
---------------------------------------------------------------------------
local NOMBRES = { "CompactRaidFrameManagerDisplayFrameLeaderOptionsCountdown", "CompactRaidFrameManagerDisplayFrameCountdown" }

local function botonDelJuego()
	for _, n in ipairs(NOMBRES) do
		local b = rawget(_G, n)
		if type(b) == "table" and type(b.Click) == "function" then return b end
	end
	local m = rawget(_G, "CompactRaidFrameManager")
	local d = type(m) == "table" and m.displayFrame
	local b = type(d) == "table" and ((type(d.leaderOptions) == "table" and d.leaderOptions.countdownButton) or d.countdownButton)
	if type(b) == "table" and type(b.Click) == "function" then return b end
	return nil
end

-- -> los atributos del botón seguro, o nil si el juego no tiene cómo.
function Cu.Seguro()
	local b = botonDelJuego()
	if b then return { type = "click", clickbutton = b } end
	local cmd = rawget(_G, "SLASH_COUNTDOWN1")
	if type(cmd) == "string" and cmd ~= "" then return { type = "macro", macrotext = cmd .. " 10" } end
	return nil
end

-- -> true | false, por qué
function Cu.PuedeLanzar()
	if M.Legible(M.Llamar(IsInGroup)) ~= true then return false, L["En grupo o banda puedes lanzar la cuenta para jalar."] end
	if M.Legible(M.Llamar(IsInRaid)) == true then
		local jefe = M.Legible(M.Llamar(UnitIsGroupLeader, "player")) == true
		local ayuda = M.Legible(M.Llamar(UnitIsGroupAssistant, "player")) == true
		if not (jefe or ayuda) then return false, L["En banda la lanza quien la dirige o sus ayudantes."] end
	end
	if not Cu.Seguro() then return false, L["Tu cliente no trae la cuenta del juego."] end
	return true
end

-- Para una tarjeta del Kit: { texto, alClic, seguro }.
function Cu.Accion()
	local puede = Cu.PuedeLanzar()
	if not puede then return nil end
	return { texto = L["Lanzar la cuenta (10 s)"], alClic = function() end, seguro = Cu.Seguro() }
end

A.OnLogin(function()
	M.Ensenar({ id = "combate.cuenta", icono = "ic-reloj",
		pregunta = L["¿Cómo lanzo la cuenta para jalar?"],
		respuesta = L["En grupo, abre Combate y usa «Lanzar la cuenta»: el juego cuenta 10 segundos para todos. Cuando alguien la lanza, Alfa te la enseña en grande."] })
end)
