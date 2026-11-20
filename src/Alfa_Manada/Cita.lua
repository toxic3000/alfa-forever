-- Alfa - La Jauría: la cita de la manada (1.2.8). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Propones una salida (qué: lo que sea o una mazmorra; día y hora) desde la
-- página de La Jauría o con /alfa cita. Les llega a los lobos de tu
-- hermandad que usan Alfa: un aviso con «Voy» (y «Voy» / «No puedo» en la
-- página). (1.3.2) Ya no pide compartir tu ubicación: su permiso es
-- manada.citas (como el tablón, 1b). Su respuesta te llega por susurro oculto y en la
-- página ves quién va. Unos RECUERDA segundos antes, Lya (o un aviso) te
-- recuerda la cita, a ti y a quien dijo «Voy». Nada sale al chat.
--
-- Mensajes (Red.lua, prefijo AlfaManada):
--   1C|<id>|<cuándo>|<qué>   la cita, por la hermandad (cuándo: segundos del
--                            servidor; 0 = la cancelaste). Se repite cada
--                            REPITE para quien llegó después.
--   1D|<id>|<s|n>            por susurro, a quien la propuso: voy / no puedo
-- Se guarda en N.Datos("manada").citas y se olvida HORA después de empezar.
-- Ajuste manada.citas (recibir y proponer).
--
--   Ci.Proponer(qué, cuándo) -> ok, por qué
--   Ci.Responder(llave, si) ; Ci.Quitar(llave)
--   Ci.Lista() -> { cita }  ; Ci.CuandoTexto(cuándo) ; Ci.Cuando(día, minutos)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Ci = {}
M.Cita = Ci

local type, tonumber, tostring, pairs, ipairs, pcall, format = type, tonumber, tostring, pairs, ipairs, pcall, string.format
local floor, sort = math.floor, table.sort

local V = "1"
local RECUERDA = 900   -- el recordatorio, 15 min antes
local HORA = 3600      -- una cita se olvida una hora después de empezar
local REPITE = 600     -- tus citas se repiten (para quien llegó después)
local LEJOS = 8 * 86400
local MIAS = 3         -- citas tuyas a la vez
local TOPE = 12        -- citas guardadas

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "citas") ~= false end

Ci.version = 0
local function cambio()
	Ci.version = Ci.version + 1
	if M.Avisar then M.Avisar() end
end

local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then return K.Aviso(o) end
	U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or ""))
end

local function datos()
	local d = N.Datos(ID)
	if type(d.citas) ~= "table" then d.citas = {} end
	return d
end

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	-- Hasta 40 letras (sin partir una letra con acento; 1.3.1: U.Cortar).
	s = U.Cortar(s, 40)
	return s ~= "" and s or nil
end
Ci.Limpiar = limpiar

---------------------------------------------------------------------------
-- El tiempo
---------------------------------------------------------------------------

local function ahora() return U.Reloj() end

local function fecha(t)
	local ok, d = pcall(date, "*t", t)
	return ok and type(d) == "table" and d or nil
end

-- Los segundos de `día` (0 hoy, 1 mañana...) a `minutos` del día, hora local.
function Ci.Cuando(dia, minutos)
	local t = fecha(ahora())
	if not t then return nil end
	t.day = t.day + (tonumber(dia) or 0)
	t.hour, t.min, t.sec = floor((minutos or 0) / 60), floor((minutos or 0) % 60), 0
	t.isdst = nil
	local ok, s = pcall(time, t)
	return ok and tonumber(s) or nil
end

-- "hoy a las 21:30", "mañana a las 20:00", "el 24/11 a las 19:00".
function Ci.CuandoTexto(cuando)
	local t, h = fecha(cuando), fecha(ahora())
	if not (t and h) then return "?" end
	local hora = format("%02d:%02d", t.hour, t.min)
	-- Días de diferencia por la fecha (no por las horas).
	local a = time({ year = t.year, month = t.month, day = t.day, hour = 12 })
	local b = time({ year = h.year, month = h.month, day = h.day, hour = 12 })
	local dias = floor(((a or 0) - (b or 0)) / 86400 + 0.5)
	if dias == 0 then return format(L["hoy a las %s"], hora) end
	if dias == 1 then return format(L["mañana a las %s"], hora) end
	return format(L["el %02d/%02d a las %s"], t.day, t.month, hora)
end

-- Las opciones de la página: los próximos 7 días y la hora cada media hora.
function Ci.OpcionesDia()
	local out = {}
	for i = 0, 6 do
		local t = fecha(ahora() + i * 86400)
		local texto = i == 0 and L["Hoy"] or (i == 1 and L["Mañana"]) or (t and format("%02d/%02d", t.day, t.month) or tostring(i))
		out[#out + 1] = { valor = i, texto = texto }
	end
	return out
end

function Ci.OpcionesHora()
	local out = {}
	for m = 0, 23 * 60 + 30, 30 do out[#out + 1] = { valor = m, texto = format("%02d:%02d", floor(m / 60), m % 60) } end
	return out
end

-- 1.3.0: el calendario de la semana. Siete días desde hoy, cada uno con sus
-- citas por hora: { { dia, titulo, fecha, citas = { { hora, cita } } } }.
local DIAS_SEMANA = { "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" }
function Ci.Semana()
	local out = {}
	local hoy = fecha(ahora())
	if not hoy then return out end
	local base = time({ year = hoy.year, month = hoy.month, day = hoy.day, hour = 12 }) or ahora()
	local porDia = {}
	for i = 0, 6 do
		local t = fecha(base + i * 86400)
		local nombre = t and L[DIAS_SEMANA[(t.wday or 1)]] or tostring(i)
		local titulo = i == 0 and L["Hoy"] or (i == 1 and L["Mañana"]) or nombre
		local d = { dia = i, titulo = titulo, fecha = t and format("%02d/%02d", t.day, t.month) or "", citas = {} }
		out[#out + 1] = d
		if t then porDia[format("%d-%d-%d", t.year, t.month, t.day)] = d end
	end
	for _, c in ipairs(Ci.Lista()) do
		local t = fecha(c.cuando)
		local d = t and porDia[format("%d-%d-%d", t.year, t.month, t.day)]
		if d then d.citas[#d.citas + 1] = { hora = format("%02d:%02d", t.hour, t.min), cita = c } end
	end
	for _, d in ipairs(out) do sort(d.citas, function(a, b) return a.cita.cuando < b.cita.cuando end) end
	return out
end

---------------------------------------------------------------------------
-- Las citas
---------------------------------------------------------------------------

local function llave(clave, id) return tostring(clave) .. ":" .. tostring(id) end

-- Olvida las que ya pasaron (y las de más, si hay demasiadas).
local function caducar()
	local c = datos().citas
	local t, hubo = ahora(), false
	for k, x in pairs(c) do
		if type(x) ~= "table" or not tonumber(x.cuando) or t > x.cuando + HORA then c[k] = nil hubo = true end
	end
	return hubo
end

function Ci.Lista()
	caducar()
	local out = {}
	for k, x in pairs(datos().citas) do x.llave = k out[#out + 1] = x end
	sort(out, function(a, b)
		if a.cuando ~= b.cuando then return a.cuando < b.cuando end
		return a.llave < b.llave
	end)
	return out
end

-- Quiénes van a una cita tuya: lista de nombres que van, y de quienes no.
function Ci.Quienes(c)
	local si, no = {}, {}
	for _, r in pairs(c and c.resp or {}) do
		if r.si then si[#si + 1] = r.nombre else no[#no + 1] = r.nombre end
	end
	sort(si) sort(no)
	return si, no
end

local function enviarCita(c)
	if not U.EnHermandad() then return false end
	-- (1.3.2) Por la hermandad con su propio permiso, sin pedir compartir.
	return M.Red.EnviarHermandad("C:" .. c.id, format("%sC|%d|%d|%s", V, c.id, c.cancelada and 0 or c.cuando, c.cancelada and "" or c.que))
end

-- Propones una cita: ok, o false y por qué ("apagado", "compartir",
-- "hermandad", "que", "pasada", "muchas", "via").
function Ci.Proponer(que, cuando)
	if not activo() then return false, "apagado" end
	if not U.EnHermandad() then return false, "hermandad" end
	que = limpiar(que)
	if not que then return false, "que" end
	cuando = tonumber(cuando)
	local t = ahora()
	if not cuando or cuando < t - 60 or cuando > t + LEJOS then return false, "pasada" end
	caducar()
	local d = datos()
	local mias = 0
	for _, x in pairs(d.citas) do if x.mia then mias = mias + 1 end end
	if mias >= MIAS then return false, "muchas" end
	d.citaN = ((tonumber(d.citaN) or 0) % 9999) + 1
	local c = { id = d.citaN, mia = true, de = L["Tú"], que = que, cuando = floor(cuando), resp = {} }
	if not enviarCita(c) then return false, "via" end
	d.citas[llave(U.MiClave(), c.id)] = c
	aviso({ titulo = L["Propusiste una cita"], texto = format(L["%s, %s. Te aviso quién va."], que, Ci.CuandoTexto(c.cuando)),
		icono = "ic-reloj", duracion = 8 })
	cambio()
	return true
end

local MOTIVOS = {
	apagado = "Las citas de la manada están apagadas (Ajustes de La Jauría).",
	compartir = "Para proponer una cita, deja que la manada te vea en el mapa.",
	hermandad = "Las citas van a los lobos de tu hermandad: necesitas una.",
	que = "Escribe qué van a hacer (una mazmorra, una misión, lo que sea).",
	pasada = "Elige un día y una hora que aún no pasen (hasta una semana).",
	muchas = "Ya tienes 3 citas propuestas. Quita una para proponer otra.",
	via = "Ahora no se puede avisar a la manada. Inténtalo en un momento.",
}
Ci.MOTIVOS = MOTIVOS

function Ci.ProponerYDecir(que, cuando)
	local ok, por = Ci.Proponer(que, cuando)
	if not ok and MOTIVOS[por] then U.Decir(L[MOTIVOS[por]]) end
	return ok, por
end

-- Contestas una cita de otro lobo: «Voy» (si) o «No puedo».
function Ci.Responder(k, si)
	local c = datos().citas[k]
	if not c or c.mia then return false end
	c.mi = si and true or false
	if c.envio then M.Red.EnviarLibre("D:" .. k, format("%sD|%d|%s", V, c.id, si and "s" or "n"), U.Destino(c.envio)) end
	U.Decir(si and format(L["Le dijiste a %s que vas: %s."], c.de or "?", c.que or "")
		or format(L["Le dijiste a %s que esta vez no puedes."], c.de or "?"))
	cambio()
	return true
end

-- Quitas una cita: la tuya se cancela para todos; la de otro, solo de tu lista.
function Ci.Quitar(k)
	local d = datos()
	local c = d.citas[k]
	if not c then return false end
	if c.mia then
		c.cancelada = true
		enviarCita(c)
	end
	d.citas[k] = nil
	cambio()
	return true
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local function entero(s, max)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 11 then return nil end
	local n = tonumber(s)
	if not n or n > max then return nil end
	return n
end

M.Red.Oyentes.C = function(clave, remitente, _, f, canal)
	if canal ~= "GUILD" or not activo() then return end
	local id, cuando = entero(f[1], 9999), entero(f[2], 4102444800)
	if not (id and cuando) then return end
	local d = datos()
	local k = llave(clave, id)
	local c = d.citas[k]
	if cuando == 0 then
		if c then d.citas[k] = nil cambio() end
		return
	end
	local que = limpiar(f[3])
	local t = ahora()
	if not que or cuando < t - 60 or cuando > t + LEJOS then return end
	if c then
		-- La misma cita otra vez (se repite cada 10 min): se pone al día, sin aviso.
		local cambiada = c.que ~= que or c.cuando ~= cuando
		c.que, c.cuando, c.envio, c.de = que, cuando, remitente, U.Mostrar(remitente)
		if cambiada then c.recordada = nil cambio() end
		return
	end
	caducar()
	local n = 0
	for _ in pairs(d.citas) do n = n + 1 end
	if n >= TOPE then return end
	c = { id = id, de = U.Mostrar(remitente), envio = remitente, que = que, cuando = cuando }
	d.citas[k] = c
	aviso({
		titulo = format(L["%s propone una cita"], c.de), texto = format(L["%s, %s."], que, Ci.CuandoTexto(cuando)),
		icono = "ic-reloj", duracion = 20,
		accion = { texto = L["Voy"], alClic = function() Ci.Responder(k, true) end },
	})
	cambio()
end

M.Red.Oyentes.D = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" then return end
	local id = entero(f[1], 9999)
	local c = id and datos().citas[llave(U.MiClave(), id)]
	if not (c and c.mia) then return end
	local si = f[2] == "s"
	c.resp = type(c.resp) == "table" and c.resp or {}
	local antes = c.resp[clave]
	c.resp[clave] = { nombre = U.Mostrar(remitente), si = si }
	if not antes or antes.si ~= si then
		aviso({ titulo = format(si and L["%s va a tu cita"] or L["%s no puede ir a tu cita"], U.Mostrar(remitente)),
			texto = c.que, icono = "ic-reloj", duracion = 8 })
	end
	cambio()
end
-- (1.3.2) Las citas llegan aunque no compartas tu ubicación (su permiso: manada.citas).
M.Red.Libres.C = true

---------------------------------------------------------------------------
-- El recordatorio y la repetición
---------------------------------------------------------------------------

function Ci.Recordar()
	if not activo() then return 0 end
	local t, n = ahora(), 0
	for _, c in ipairs(Ci.Lista()) do
		local falta = c.cuando - t
		if (c.mia or c.mi == true) and not c.recordada and falta <= RECUERDA and falta > -600 then
			c.recordada = true
			n = n + 1
			local min = math.max(0, floor(falta / 60 + 0.5))
			local texto = min > 0 and format(L["%s empieza en %d min."], c.que, min) or format(L["%s empieza ya."], c.que)
			if c.mia then
				local si = Ci.Quienes(c)
				if #si > 0 then texto = texto .. " " .. format(L["Van: %s."], table.concat(si, ", ")) end
			end
			aviso({ titulo = L["Tu cita con la manada"], texto = texto, icono = "ic-reloj", duracion = 15 })
		end
	end
	if n > 0 then cambio() end
	return n
end

local function repetir()
	if not activo() then return end
	local t = ahora()
	for _, c in ipairs(Ci.Lista()) do
		if c.mia and c.cuando > t then enviarCita(c) end
	end
end
Ci.Repetir = repetir

---------------------------------------------------------------------------
-- /alfa cita [hoy|mañana] <hh:mm> <qué>
---------------------------------------------------------------------------

local DIAS = { hoy = 0, today = 0, ["mañana"] = 1, manana = 1, tomorrow = 1 }

-- -> qué, cuándo | nil
function Ci.Leer(texto)
	texto = tostring(texto or "")
	local dia = 0
	local p, resto = texto:match("^%s*(%S+)%s*(.-)%s*$")
	if p and DIAS[U.Plegar(p)] then dia, texto = DIAS[U.Plegar(p)], resto end
	local h, m, que = texto:match("^%s*(%d%d?):(%d%d)%s+(.+)$")
	if not h then
		h, que = texto:match("^%s*(%d%d?)%s+(.+)$")
		m = "0"
	end
	h, m = tonumber(h), tonumber(m)
	if not (h and m and que) or h > 23 or m > 59 then return nil end
	local cuando = Ci.Cuando(dia, h * 60 + m)
	-- Una hora de hoy que ya pasó: mañana.
	if cuando and dia == 0 and cuando < ahora() - 60 then cuando = Ci.Cuando(1, h * 60 + m) end
	return que, cuando
end

A.RegisterCommand("cita", function(rest)
	rest = tostring(rest or "")
	if rest:match("^%s*$") then
		if M.Pagina then M.Pagina.Abrir() end
		return
	end
	local que, cuando = Ci.Leer(rest)
	if not que then
		U.Decir(L["Así: /alfa cita mañana 21:30 Minas de la Muerte"])
		return
	end
	Ci.ProponerYDecir(que, cuando)
end, L["Propón una salida a la manada (/alfa cita mañana 21:30 Minas)"])

A.OnLogin(function()
	caducar()
	M.Cada("manada.citaRecordar", 30, Ci.Recordar)
	M.Cada("manada.citaRepetir", REPITE, repetir)
end)
