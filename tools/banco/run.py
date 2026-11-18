"""Load Alfa's engine (dist-ventanas) in a mocked client and drive the hub:
the guide selector, Lookup and the dungeon journal. Prints every Lua error."""
import os
import pathlib
import re
import sys

import lupa.lua51 as lua51

HERE = pathlib.Path(__file__).resolve().parent
DIST = pathlib.Path(sys.argv[1]).resolve()
ADDONS = sys.argv[2].split(",") if len(sys.argv) > 2 else ["Alfa"]
SCRIPT = (HERE / (sys.argv[3] if len(sys.argv) > 3 else "drive.lua")).read_text(encoding="utf-8")


def files_of(folder: pathlib.Path) -> list:
    toc = next(folder.glob("*.toc"))
    out = []

    def from_xml(xml: pathlib.Path):
        text = re.sub(r"<!--.*?-->", "", xml.read_text(encoding="utf-8", errors="replace"), flags=re.S)
        for rel in re.findall(r'<(?:Script|Include)\s+file="([^"]+)"', text):
            p = xml.parent / rel.replace("\\", "/")
            from_xml(p) if p.suffix.lower() == ".xml" else out.append(p)

    for line in toc.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n").split("\n"):
        l = line.strip()
        if not l or l.startswith("#"):
            continue
        p = folder / l.replace("\\", "/")
        from_xml(p) if p.suffix.lower() == ".xml" else out.append(p)
    return out


def toc_meta(folder: pathlib.Path) -> dict:
    toc = next(folder.glob("*.toc"))
    meta = {}
    for line in toc.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"##\s*([^:]+):\s*(.*)", line)
        if m:
            meta[m.group(1).strip()] = m.group(2).strip()
    return meta


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    named = lua.eval("function(src, name) local f, e = loadstring(src, '@' .. name) if not f then error(e) end return f() end")
    named((HERE / "mock.lua").read_text(encoding="utf-8"), "mock.lua")
    named((HERE / "api.lua").read_text(encoding="utf-8"), "api.lua")
    named((HERE / "dump.lua").read_text(encoding="utf-8"), "dump.lua")
    g = lua.globals()
    for name in ADDONS:
        folder = DIST / name
        meta = lua.table()
        for k, v in toc_meta(folder).items():
            meta[k] = v
        g.ADDON_META[name] = meta
    load = g.LOAD_FILE
    def load_addon(name):
        folder = DIST / name
        if g.LOADED[name]:
            return True
        if not folder.is_dir():
            return False
        if not g.ADDON_META[name]:
            meta = lua.table()
            for k, v in toc_meta(folder).items():
                meta[k] = v
            g.ADDON_META[name] = meta
        g.LOADED[name] = True
        ns = g.NS_OF(name)
        for f in files_of(folder):
            src = f.read_bytes()
            if src[:3] == bytes([0xEF, 0xBB, 0xBF]):
                src = src[3:]
            load(str(f.relative_to(DIST)), src, name, ns)
        g.FIRE_EVENT("ADDON_LOADED", name)
        return True

    g.PY_LOAD_ADDON = load_addon
    # Variables guardadas entre dos corridas (prueba_ajustes.lua, 1.1.9): con
    # BANCO_GUARDADAS, se cargan antes de los addons, como hace el juego, y se
    # escriben al final, como al salir o con /reload.
    guardadas = os.environ.get("BANCO_GUARDADAS")
    if guardadas and pathlib.Path(guardadas).exists():
        named(pathlib.Path(guardadas).read_text(encoding="utf-8"), "guardadas.lua")
    for name in ADDONS:
        load_addon(name)
    named(SCRIPT, 'drive.lua')
    if guardadas:
        nombres = []
        for name in ADDONS:
            meta = g.ADDON_META[name]
            for campo in ("SavedVariables", "SavedVariablesPerCharacter"):
                for n in str((meta[campo] if meta else None) or "").split(","):
                    if n.strip():
                        nombres.append(n.strip())
        volcar = lua.eval('''function(nombres)
          local out, visto = {}, {}
          local function val(v, sangria)
            local t = type(v)
            if t == "string" then return string.format("%q", v) end
            if t == "number" or t == "boolean" then return tostring(v) end
            if t ~= "table" or visto[v] then return "nil" end
            visto[v] = true
            local partes = {}
            for k, x in pairs(v) do
              local tk = type(k)
              if (tk == "string" or tk == "number") and type(x) ~= "function" and type(x) ~= "userdata" then
                local clave = tk == "string" and string.format("[%q]", k) or ("[" .. tostring(k) .. "]")
                partes[#partes + 1] = sangria .. "  " .. clave .. " = " .. val(x, sangria .. "  ") .. ","
              end
            end
            visto[v] = nil
            return "{\\n" .. table.concat(partes, "\\n") .. "\\n" .. sangria .. "}"
          end
          for i = 1, #nombres do
            local n = nombres[i]
            if rawget(_G, n) ~= nil then out[#out + 1] = n .. " = " .. val(rawget(_G, n), "") end
          end
          return table.concat(out, "\\n")
        end''')
        tabla = lua.table()
        for i, n in enumerate(nombres, 1):
            tabla[i] = n
        pathlib.Path(guardadas).write_text(volcar(tabla), encoding="utf-8")
    snaps = g.SNAPSHOTS
    if snaps:
        sys.path.insert(0, str(HERE))
        import render
        fonts = DIST / "Alfa" / "Media" / "Fonts"
        for name, snap in snaps.items():
            entries = [dict(e.items()) for e in snap.entries.values()]
            rect = (snap.l, snap.b, snap.w, snap.h)
            out = HERE / ("shot-%s.png" % name)
            render.render(entries, rect, out, fonts)
            if os.environ.get('BANCO_VOLCAR'):
                import json
                (HERE / ('shot-%s.json' % name)).write_text(json.dumps([{k: (dict(v.items()) if hasattr(v, 'items') else v) for k, v in e.items()} for e in entries], default=str), encoding='utf-8')
            print("PNG", out)
        for vista, texto, por in render.CORTES:
            print("CORTADO %s (%s): %s" % (vista, por, texto))
        if render.CORTES:
            print("cortados:", len(render.CORTES))
        for vista, texto in render.SALEN:
            print("SALE %s: %s" % (vista, texto))
    errs = list(g.ERRORS.values())
    seen = {}
    for e in errs:
        k = str(e).split("\n")[0]
        seen[k] = seen.get(k, 0) + 1
    shown = set()
    for e in errs:
        k = str(e).split("\n")[0]
        if k in shown:
            continue
        shown.add(k)
        print("ERROR x%d %s" % (seen[k], e))
    print("errors:", len(errs))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
