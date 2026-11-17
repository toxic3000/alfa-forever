"""Prueba de los requisitos de las misiones (src/Alfa_Rutas/Disponible.lua)
con los datos de verdad del juego (Alfa_Codex y Alfa_QuestDB), sin abrirlo.

Uso:  .venv/Scripts/python -I tools/prueba_requisitos.py

Carga en un Lua 5.1 el Codex, la base de misiones y el Lookup del motor ya
construidos (dist/, o ALFA_DIST), con un personaje simulado (raza, clase,
nivel, misiones hechas, profesiones y reputaciones), y luego Disponible.lua e
Indice.lua de Alfa_Rutas. Para cada caso dice si la ruta puede mandarte, qué
agrega antes (en orden), qué nivel pide o por qué no se puede, y si el motor
la dejaría fuera (Disp.Bloqueo) o metería su cadena (Disp.Cadena).
Sale con 1 si un caso no da lo esperado.
"""
import os
import pathlib
import re
import sys

import lupa.lua51 as lua51

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")
if not DIST.is_absolute():
    DIST = RAIZ / DIST

ENTORNO = r"""
local comodin_mt = {}
local function Comodin() return setmetatable({}, comodin_mt) end
comodin_mt.__index = function(t, k) local c = Comodin() rawset(t, k, c) return c end
comodin_mt.__call = function() return nil end

-- bit.band de verdad (la base de misiones lo usa para razas y clases).
local function band(a, b)
  local r, bitv = 0, 1
  a, b = math.floor(a), math.floor(b)
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + bitv end
    a, b, bitv = math.floor(a / 2), math.floor(b / 2), bitv * 2
  end
  return r
end
bit = { band = band }

PJ = { level = 25, race = "Human", class = "WARRIOR", faction = "Alliance", done = {}, log = {}, skills = {}, rep = {} }
TITULOS = {}

local ns = setmetatable({}, { __index = function(t, k) local c = Comodin() rawset(t, k, c) return c end })
Alfa = ns
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.Get = function() return true end
ns.Dungeons, ns.Levels, ns.UI, ns.Nav, ns.Names = false, false, false, false, false
ns.Quoted = function(s) return "«" .. tostring(s) .. "»" end
ns.StandingName = function(n) return ({ "Odiado", "Hostil", "Adverso", "Neutral", "Amistoso", "Honorable", "Reverenciado", "Exaltado" })[n] end
ns.Requisitos = {}
ns.PlayerPoint = function() return PJ.punto end
ns.DirectTravelCost = function(a, b)
  if not (a and b) then return nil end
  if a.map ~= b.map then return 3600 end
  return (((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) ^ 0.5) * 8
end
ns.Compat = {
  GetPlayerInfo = function() return { level = PJ.level, race = PJ.race, class = PJ.class, faction = PJ.faction, xp = 0, xpMax = 1000 } end,
  GetPlayerFaction = function() return PJ.faction end,
  IsQuestCompleted = function(q) return PJ.done[q] == true end,
  IsOnQuest = function(q) return PJ.log[q] == true end,
  IsQuestReadyForTurnIn = function() return false end,
  GetSkillRank = function(l) return PJ.skills[l] end,
  Supports = function() return true end,
  GetFactionStanding = function(f) return PJ.rep[f] end,
  GetQuestTitle = function(q) return TITULOS[q] end,
  MapName = function(m) return "mapa " .. tostring(m) end,
  MapToWorld = function(m, x, y) return 1, x * 10, y * 10 end,
  IsQuestTrivial = function() return false end,
}

function cargar(nombre, src)
  local fn, err = loadstring(src, "@" .. nombre)
  if not fn then error(nombre .. ": " .. tostring(err)) end
  return fn("Alfa", ns)
end

-- Alfa_Rutas: lo mínimo de Base.lua.
M = { A = ns, L = ns.L, N = {} }
function M.num(v, d) v = tonumber(v) if v == nil or v ~= v then return d end return v end
function M.Motor(n) local v = rawget(ns, n) if type(v) == "table" then return v end return nil end
function M.Citar(s) return "«" .. tostring(s) .. "»" end
function M.TituloMision(q)
  local t = TITULOS[q]
  if t then return t end
  local r = ns.Codex.Quest(q)
  return r and r.title or ("Misión " .. tostring(q))
end
function M.NombreObjeto(id) return "Objeto " .. tostring(id) end
function M.Copia(t, v)
  if type(t) ~= "table" then return t end
  v = v or {}
  if v[t] then return v[t] end
  local c = {}
  v[t] = c
  for k, x in pairs(t) do c[M.Copia(k, v)] = M.Copia(x, v) end
  return c
end
M.Tareas = { Avance = function() end }
M.Avisar = function() end

function cargarRutas(nombre, src)
  local fn, err = loadstring(src, "@" .. nombre)
  if not fn then error(nombre .. ": " .. tostring(err)) end
  return fn("Alfa_Rutas", M)
end

-- Una lista de Lua en texto.
local function lista(t)
  local o = {}
  for i, q in ipairs(t or {}) do o[i] = tostring(q) end
  return "{" .. table.concat(o, ",") .. "}"
end

-- Prepara al personaje: lo que se pide en `pj` (level, race, class, faction,
-- done = { qid... }, log = { qid... }, skills = { [linea] = rango }, rep = { [faccion] = nivel }).
function personaje(pj)
  PJ.level = pj.level or 25
  PJ.race, PJ.class, PJ.faction = pj.race or "Human", pj.class or "WARRIOR", pj.faction or "Alliance"
  PJ.done, PJ.log, PJ.skills, PJ.rep = {}, {}, pj.skills or {}, pj.rep or {}
  for _, q in ipairs(pj.done or {}) do PJ.done[q] = true end
  for _, q in ipairs(pj.log or {}) do PJ.log[q] = true end
  PJ.punto = pj.punto
  M.Disp.Limpiar()
end

-- Todo lo que dice el resolvedor de una misión, en una línea.
function caso(qid)
  local D = M.Disp
  local r = D.Resolver(qid)
  local ok, motivo, info = D.Estado(qid)
  local cad = D.Cadena(qid)
  local antes, no = D.Resumen(qid)
  local nombres = {}
  for i, q in ipairs(r.cadena or {}) do nombres[i] = M.TituloMision(q) .. " (" .. q .. ")" end
  return {
    titulo = M.TituloMision(qid),
    ok = r.ok, motivo = r.motivo, texto = (not r.ok) and D.Texto(r.motivo, r.info) or nil,
    cadena = table.concat(nombres, " > "), nivel = r.nivel,
    ahora = ok, ahoraTexto = (not ok) and D.Texto(motivo, info) or nil,
    bloqueo = D.Bloqueo(qid), cadenaMotor = cad and #cad or nil,
    antes = antes, noDisponible = no,
  }
end

-- Para buscar casos en los datos.
function buscar(fn)
  local out = {}
  ns.Codex.Each("quest", function(id)
    if type(id) == "number" then
      local q = ns.Codex.Quest(id)
      if q and fn(q) then out[#out + 1] = id end
    end
  end)
  table.sort(out)
  return out
end
"""


def archivos_toc(carpeta: pathlib.Path) -> list:
    toc = next(carpeta.glob("*.toc"))
    out = []
    for linea in toc.read_text(encoding="utf-8", errors="replace").splitlines():
        l = linea.strip()
        if l and not l.startswith("#"):
            out.append(carpeta / l.replace("\\", "/"))
    return out


def leer(p: pathlib.Path) -> bytes:
    b = p.read_bytes()
    return b[3:] if b.startswith(b"\xef\xbb\xbf") else b


def titulos_es() -> dict:
    """Los títulos de misión en español (esMX) del paquete de nombres."""
    texto = leer(DIST / "Alfa_esMX" / "Names.lua").decode("utf-8")
    out = {}
    for bloque in re.finditer(r'R\("quest", \d+, \d+, \[\[(.*?)\]\]\)', texto, re.S):
        for linea in bloque.group(1).split("\n"):
            if "\t" in linea:
                i, n = linea.split("\t", 1)
                if i.isdigit():
                    out[int(i)] = re.sub(r"%([0-9A-Fa-f]{2})", lambda m: chr(int(m.group(1), 16)), n)
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(ENTORNO)
    G = lua.globals()
    for rel in ("Core/LuaChunks.lua", "Quests/QuestDB.lua", "Lookup/Codex.lua", "Lookup/Sources.lua", "Lookup/Guide.lua"):
        G.cargar(rel, leer(DIST / "Alfa" / rel))
    for pack in ("Alfa_Codex", "Alfa_QuestDB"):
        for p in archivos_toc(DIST / pack):
            G.cargar(f"{pack}/{p.name}", leer(p))
    tit = titulos_es()
    T = G.TITULOS
    for k, v in tit.items():
        T[k] = v
    for rel in ("Disponible.lua", "Indice.lua"):
        G.cargarRutas(rel, leer(DIST / "Alfa_Rutas" / rel))
    assert lua.eval("Alfa.Codex.IsLoaded()") and lua.eval("Alfa.QuestDB.IsLoaded()"), "datos sin cargar"
    assert lua.eval("Alfa.Requisitos.Bloqueo ~= nil and Alfa.Requisitos.Cadena ~= nil"), "Disponible no se registro en el motor"

    def tabla(d):
        t = lua.table()
        for k, v in d.items():
            if isinstance(v, (list, tuple)):
                t[k] = lua.table(*v)
            elif isinstance(v, dict):
                s = lua.table()
                for a, b in v.items():
                    s[a] = b
                t[k] = s
            else:
                t[k] = v
        return t

    def mostrar(etiqueta, qid, pj, espera=None):
        G.personaje(tabla(pj))
        r = G.caso(qid)
        partes = [f"{etiqueta}: {r.titulo} ({qid})"]
        if r.ok:
            partes.append(f"se puede: {r.cadena}")
            if r.nivel:
                partes.append(f"pide nivel {r.nivel}")
        else:
            partes.append(f"NO: {r.texto}")
        partes.append(f"ya mismo: {'sí' if r.ahora else r.ahoraTexto}")
        partes.append(f"motor: {'fuera (' + r.bloqueo + ')' if r.bloqueo else 'no la cierra'}"
                      + (f", cadena de {r.cadenaMotor} pasos" if r.cadenaMotor else ""))
        if r.antes:
            partes.append(f"Antes: {r.antes}")
        if r.noDisponible:
            partes.append(f"No disponible: {r.noDisponible}")
        print(" | ".join(partes))
        fallo = False
        if espera is not None:
            fallo = not espera(r)
            if fallo:
                print("   ^ FALLA: no da lo esperado")
        return r, fallo

    fallas = 0
    humano = {"race": "Human", "class": "WARRIOR", "faction": "Alliance", "level": 25,
              "punto": {"map": 1437, "x": 10.5, "y": 59.5}}

    print("== Puerto de Menethil (Humedal), guerrero humano de nivel 25 sin nada hecho ==")
    menethil = list(G.buscar(lua.eval(
        "function(q) for _, n in ipairs(q.start.npc or {}) do local r = Alfa.Codex.Npc(n)"
        " for _, s in ipairs(r and r.spawns or {}) do if s.map == 1437 and s.x < 14 and s.y > 54 and s.y < 66 then return true end end end"
        " return false end")).values())
    for qid in menethil:
        _, f = mostrar("Menethil", qid, humano)
        fallas += f

    print("\n== Casos pedidos ==")
    # Las misiones nuevas de Forever no tienen nombre en español en los datos:
    # se buscan por su nombre en inglés (el del Codex).
    INGLES = {"Desde las cenizas": "From the Ashes", "La flor de los cielos": "Bloom of the Heavens"}
    for buscado in ("Desde las cenizas", "La caída de Dun Modr", "La flor de los cielos", "Conocimiento en las Cavernas"):
        ids = [k for k, v in tit.items() if v.lower() == buscado.lower()]
        if not ids and buscado in INGLES:
            ids = list(G.buscar(lua.eval(f"function(q) return q.title == '{INGLES[buscado]}' end")).values())
        if not ids:
            print(f"{buscado}: no está en los datos")
        for qid in ids:
            mostrar(buscado, qid, humano)
            mostrar(buscado + " (nivel 20)", qid, dict(humano, level=20))
    # Lo que la guía de la Alianza pide después de ellas (su `pre` compilado).
    fallas += mostrar("Pide «Desde las cenizas»", 465, humano, lambda r: r.ok and "98221" in (r.cadena or "") and r.cadenaMotor)[1]
    fallas += mostrar("Pide «La flor de los cielos»", 98209, humano, lambda r: r.ok and "98208" in (r.cadena or "") and r.cadenaMotor)[1]
    fallas += mostrar("Pide «La flor de los cielos», ya hecha", 98209, dict(humano, done=[98208]), lambda r: r.ok and not r.antes)[1]
    fallas += mostrar("Mazmorra, en el registro", 971, dict(humano, log=[971]), lambda r: r.ok and r.bloqueo is None)[1]

    # Una de otra clase: la primera misión solo de magos.
    mago = list(G.buscar(lua.eval("function(q) return q.classes == 128 and (q.minLevel or 0) <= 20 and q.faction ~= 'H' end")).values())
    if mago:
        _, f = mostrar("Solo magos, para un guerrero", mago[0], humano, lambda r: (not r.ok) and r.bloqueo is not None)
        fallas += f
        _, f = mostrar("Solo magos, para un mago", mago[0], dict(humano, **{"class": "MAGE"}), lambda r: r.bloqueo is None)
        fallas += f

    # Otra facción.
    horda = list(G.buscar(lua.eval("function(q) return q.faction == 'H' and (q.minLevel or 0) <= 20 end")).values())
    if horda:
        _, f = mostrar("De la Horda, para un humano", horda[0], humano, lambda r: (not r.ok) and r.bloqueo is not None)
        fallas += f

    # Pide más nivel: una de nivel mínimo 40 sin previas.
    alta = list(G.buscar(lua.eval("function(q) return (q.minLevel or 0) >= 40 and q.faction == 'A' and #(q.pre or {}) == 0 and #(q.preAny or {}) == 0 and not q.classes end")).values())
    if alta:
        _, f = mostrar("Pide nivel 40", alta[0], humano, lambda r: r.ok and r.nivel and r.nivel >= 40 and r.bloqueo is None)
        fallas += f

    # Una cadena larga: la de más previas "todas" de la Alianza.
    larga = list(G.buscar(lua.eval("function(q) return q.faction == 'A' and #(q.pre or {}) >= 1 and (q.minLevel or 0) <= 25 and not q.classes end")).values())
    if larga:
        _, f = mostrar("Con previas", larga[0], humano, lambda r: r.ok and r.antes)
        fallas += f

    # "Una de": la primera con preAny para la Alianza.
    una = list(G.buscar(lua.eval("function(q) return q.faction ~= 'H' and #(q.preAny or {}) >= 2 and (q.minLevel or 0) <= 30 and not q.classes end")).values())
    if una:
        mostrar("Con «una de»", una[0], humano)
        r0 = G.caso(una[0])
        alt = list(lua.eval(f"Alfa.Codex.Quest({una[0]}).preAny").values())
        _, f = mostrar("Con «una de» (una hecha)", una[0], dict(humano, done=[alt[-1]]),
                       lambda r: r.ok and str(alt[-1]) not in (r.cadena or ""))
        fallas += f

    # Excluyente: una con `excl` en la base, con la otra hecha.
    excl = lua.eval("(function() local Q = Alfa.QuestDB for _, id in ipairs(Q.QuestIds()) do local r = Q.QuestRecord(id)"
                    " if r and r[Q.F.EXCL] and (r[Q.F.FACTION] or 1) == 1 and not r[Q.F.CLASSES] and not r[Q.F.PRE] and not r[Q.F.PRE_ALL] then"
                    " local x = r[Q.F.EXCL] return id, type(x) == 'table' and x[1] or x end end end)()")
    if excl and excl[0]:
        qid, otra = excl
        _, f = mostrar("Excluyente (la otra hecha)", qid, dict(humano, level=60, done=[otra]),
                       lambda r: (not r.ok) and r.bloqueo is not None)
        fallas += f

    # Profesión: una que pide una profesión, sin tenerla y teniéndola.
    prof = lua.eval("(function() local Q = Alfa.QuestDB for _, id in ipairs(Q.QuestIds()) do local r = Q.QuestRecord(id)"
                    " if r and r[Q.F.SKILL] and (r[Q.F.FACTION] or 1) == 1 and not r[Q.F.CLASSES] and not r[Q.F.PRE] and not r[Q.F.PRE_ALL] and not r[Q.F.EXCL] then return id, r[Q.F.SKILL] end end end)()")
    if prof and prof[0]:
        qid, linea = prof
        _, f = mostrar("Profesión (sin ella)", qid, dict(humano, level=60), lambda r: (not r.ok) and r.bloqueo is not None)
        fallas += f
        _, f = mostrar("Profesión (con ella)", qid, dict(humano, level=60, skills={linea: 150}), lambda r: r.bloqueo is None)
        fallas += f

    # Reputación: una del Codex que pide una reputación.
    rep = list(G.buscar(lua.eval("function(q) return q.repFaction ~= nil and q.faction ~= 'H' and not q.classes and #(q.pre or {}) == 0 and #(q.preAny or {}) == 0 end")).values())
    if rep:
        qid = rep[0]
        fac = lua.eval(f"Alfa.Codex.Quest({qid}).repFaction")
        nec = lua.eval(f"Alfa.Codex.Quest({qid}).repStanding")
        _, f = mostrar("Reputación (sin alcanzarla)", qid, dict(humano, level=60, rep={fac: max(1, nec - 1)}),
                       lambda r: (not r.ok) and r.bloqueo is not None)
        fallas += f
        _, f = mostrar("Reputación (alcanzada)", qid, dict(humano, level=60, rep={fac: nec}), lambda r: r.bloqueo is None)
        fallas += f

    print(f"\nPrueba de requisitos: {fallas} fallas")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
