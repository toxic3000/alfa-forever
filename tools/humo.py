"""Prueba de humo de los modulos propios, sin abrir el juego.

Uso:  .venv/Scripts/python -I tools/humo.py [Alfa_Modulo ...]

Carga Alfa_Nucleo y cada modulo de src/ en el orden de su .toc dentro de un
Lua 5.1 con el API del juego simulado (todo lo desconocido devuelve un "comodin"
que acepta llamadas, indices y aritmetica). Despues arma la vista de cada
pagina (construir) y dispara cada evento registrado una vez.

Reporta:
  ERROR  fallas al cargar un archivo o al armar una vista
  AVISO  fallas al disparar eventos con argumentos simulados (pueden ser falsas)
  ERROR  funciones de Alfa (A.algo) que el motor real no tiene
Sale con 1 si hay algun ERROR.
"""
import os
import pathlib
import re
import sys

import lupa.lua51 as lua51

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")

ENTORNO = r"""
local real = { string=string, table=table, math=math, pairs=pairs, ipairs=ipairs,
  type=type, tostring=tostring, tonumber=tonumber, select=select, next=next,
  pcall=pcall, xpcall=xpcall, error=error, assert=assert, unpack=unpack,
  setmetatable=setmetatable, getmetatable=getmetatable, rawget=rawget,
  rawset=rawset, rawequal=rawequal, coroutine=coroutine, os={time=os.time, date=os.date, clock=os.clock},
  loadstring=loadstring, print=function() end }

local comodin_mt = {}
local function Comodin() return setmetatable({}, comodin_mt) end
local function num() return 0 end
comodin_mt.__index = function(t, k) local c = Comodin(); rawset(t, k, c); return c end
comodin_mt.__call = function() return Comodin() end
comodin_mt.__add, comodin_mt.__sub, comodin_mt.__mul = num, num, num
comodin_mt.__div, comodin_mt.__mod, comodin_mt.__pow, comodin_mt.__unm = num, num, num, num
comodin_mt.__concat = function(a, b)
  local function s(x) return type(x) == "table" and "" or tostring(x) end
  return s(a) .. s(b) end
comodin_mt.__len = function() return 0 end
comodin_mt.__lt = function() return false end
comodin_mt.__le = function() return false end
comodin_mt.__tostring = function() return "comodin" end

local errores, avisos, usosA = {}, {}, {}
local function falla(lista, donde, err) lista[#lista + 1] = donde .. ": " .. tostring(err) end

-- Marcos simulados: guardan sus scripts y eventos para poder dispararlos.
local marcos = {}
local function Marco()
  local f = Comodin()
  local scripts, eventos = {}, {}
  rawset(f, "SetScript", function(self, que, fn) scripts[que] = fn end)
  rawset(f, "HookScript", function(self, que, fn) scripts[que] = fn end)
  rawset(f, "GetScript", function(self, que) return scripts[que] end)
  rawset(f, "RegisterEvent", function(self, ev) eventos[ev] = true end)
  rawset(f, "RegisterUnitEvent", function(self, ev) eventos[ev] = true end)
  rawset(f, "IsShown", function() return false end)
  rawset(f, "IsVisible", function() return false end)
  rawset(f, "GetWidth", function() return 300 end)
  rawset(f, "GetHeight", function() return 200 end)
  rawset(f, "GetName", function() return nil end)
  rawset(f, "IsForbidden", function() return false end)
  rawset(f, "_scripts", scripts); rawset(f, "_eventos", eventos)
  marcos[#marcos + 1] = f
  return f
end

-- Motor de Alfa simulado: lo mismo que usan los modulos de verdad.
local settings, defaults = {}, {}
local handlersA, eventosA, opciones, comandos = {}, {}, {}, {}
local function partes(path) local t = {} for p in path:gmatch("[^%.]+") do t[#t+1] = p end return t end
local function buscar(raiz, keys) local n = raiz for i = 1, #keys do if type(n) ~= "table" then return nil end n = n[keys[i]] end return n end
local A = {
  version = "0.1.0", name = "Alfa", stage = "Beta",
  RegisterDefaults = function(sec, t) defaults[sec] = defaults[sec] or {} for k, v in pairs(t) do defaults[sec][k] = v end end,
  Get = function(path) local k = partes(path) local v = buscar(settings, k) if v == nil then v = buscar(defaults, k) end return v end,
  Set = function(path, v) local k = partes(path) local n = settings for i = 1, #k - 1 do n[k[i]] = type(n[k[i]]) == "table" and n[k[i]] or {} n = n[k[i]] end n[k[#k]] = v end,
  RegisterOptions = function(spec)
    if type(spec) ~= "table" or type(spec.page) ~= "string" or type(spec.controls) ~= "table" then return false, "RegisterOptions: spec mal formado" end
    opciones[#opciones + 1] = spec return true end,
  RegisterCommand = function(name, fn) comandos[name] = fn end,
  RegisterEvent = function(ev, fn) eventosA[#eventosA + 1] = { ev, fn } return true end,
  On = function(msg, fn) handlersA[#handlersA + 1] = { msg, fn } return {} end,
  Off = function() end,
  Fire = function() end,
  Print = function() end, Debug = function() end, Log = function() end,
  L = setmetatable({}, { __index = function(_, k) return k end }),
}
local A_mt = { __index = function(t, k) usosA[k] = true local c = Comodin() rawset(t, k, c) return c end }
setmetatable(A, A_mt)

local G = {}
for k, v in pairs(real) do G[k] = v end
G._G = G
G.Alfa = A
G.CreateFrame = function() return Marco() end
G.GetLocale = function() return "esMX" end
G.GetTime = function() return 1000 end
G.time = os.time
G.date = os.date
G.InCombatLockdown = function() return false end
G.issecretvalue = function() return false end
G.canaccessvalue = function() return true end
G.hooksecurefunc = function() end
G.geterrorhandler = function() return function(e) errores[#errores + 1] = "geterrorhandler: " .. tostring(e) end end
G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
G.tinsert, G.tremove, G.format, G.strfind, G.strsub, G.strlower, G.strupper =
  table.insert, table.remove, string.format, string.find, string.sub, string.lower, string.upper
G.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
G.strsplit = function(sep, s, n)
  local t, i = {}, 1
  for p in (tostring(s) .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t+1] = p end
  return unpack(t) end
G.strjoin = function(sep, ...) return table.concat({...}, sep) end
G.floor, G.ceil, G.abs, G.max, G.min = math.floor, math.ceil, math.abs, math.max, math.min
G.bit = { band = function() return 0 end, bor = function() return 0 end, bxor = function() return 0 end,
  lshift = function() return 0 end, rshift = function() return 0 end }
setmetatable(G, { __index = function(t, k) local c = Comodin() rawset(t, k, c) return c end })

function cargar(nombre, src, addon, ns)
  local fn, err = loadstring(src, "@" .. nombre)
  if not fn then falla(errores, nombre, err) return end
  setfenv(fn, G)
  local ok, e = pcall(fn, addon, ns)
  if not ok then falla(errores, nombre, e) end
end

function rematar()
  for _, spec in ipairs(opciones) do
    if type(spec.custom) == "function" then
      local ok, e = pcall(spec.custom, Marco())
      if not ok then falla(errores, "construir(" .. tostring(spec.key) .. ")", e) end
    end
  end
  local function disparar(donde, fn, ...)
    local ok, e = pcall(fn, ...)
    if not ok then falla(avisos, donde, e) end
  end
  for _, h in ipairs(eventosA) do disparar("evento " .. h[1], h[2], h[1], Comodin(), Comodin()) end
  for _, h in ipairs(handlersA) do disparar("mensaje " .. h[1], h[2], Comodin(), Comodin()) end
  for _, f in ipairs(marcos) do
    local s = rawget(f, "_scripts")
    for ev in pairs(rawget(f, "_eventos")) do
      if s.OnEvent then disparar("OnEvent " .. ev, s.OnEvent, f, ev, Comodin(), Comodin()) end
    end
  end
  local nombres = {}
  for k in pairs(usosA) do nombres[#nombres + 1] = k end
  return errores, avisos, nombres, #opciones
end
"""


def archivos_de(carpeta: pathlib.Path) -> list:
    """Archivos .lua en el orden del .toc (siguiendo los .xml)."""
    toc = next(carpeta.glob("*.toc"))
    orden = []

    def de_xml(xml: pathlib.Path):
        texto = re.sub(r"<!--.*?-->", "", xml.read_text(encoding="utf-8", errors="replace"), flags=re.S)
        for ruta in re.findall(r'<(?:Script|Include)\s+file="([^"]+)"', texto):
            p = xml.parent / ruta.replace("\\", "/")
            de_xml(p) if p.suffix.lower() == ".xml" else orden.append(p)

    for linea in toc.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n").split("\n"):
        l = linea.strip()
        if not l or l.startswith("#"):
            continue
        p = carpeta / l.replace("\\", "/")
        de_xml(p) if p.suffix.lower() == ".xml" else orden.append(p)
    return orden


def funciones_del_motor() -> set:
    nombres = set()
    for p in (DIST / "Alfa").rglob("*.lua"):
        t = p.read_bytes().decode("latin-1")
        nombres.update(re.findall(r"\bns\.([A-Za-z_][A-Za-z0-9_]*)\s*=", t))
        nombres.update(re.findall(r"function\s+ns\.([A-Za-z_][A-Za-z0-9_]*)", t))
    return nombres


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    pedidos = sys.argv[1:]
    modulos = ["Alfa_Nucleo"] + sorted(
        p.name for p in (RAIZ / "src").iterdir()
        if p.is_dir() and p.name != "Alfa_Nucleo" and (not pedidos or p.name in pedidos))
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(ENTORNO)
    cargar = lua.globals().cargar
    for nombre in modulos:
        carpeta = DIST / nombre
        if not carpeta.is_dir():
            print(f"ERROR falta dist/{nombre}: corre tools/build.py")
            return 1
        ns = lua.table()
        for archivo in archivos_de(carpeta):
            src = archivo.read_bytes()
            if src.startswith(b"\xef\xbb\xbf"):
                src = src[3:]
            cargar(str(archivo.relative_to(DIST)), src, nombre, ns)
    errores, avisos, usos, paginas = lua.globals().rematar()
    errores, avisos = list(errores.values()), list(avisos.values())
    motor = funciones_del_motor()
    for u in sorted(usos.values()):
        if u not in motor:
            errores.append(f"Alfa.{u} no existe en el motor (dist/Alfa)")
    for e in errores:
        print("ERROR", e)
    for a in avisos:
        print("AVISO", a)
    print(f"Humo: {len(modulos)} modulos, {paginas} paginas, "
          f"{len(errores)} errores, {len(avisos)} avisos")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
