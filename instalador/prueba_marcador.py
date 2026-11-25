"""Prueba del marcador por bando del instalador (Alfa 1.4.0, plan 9), sin el juego de verdad.

Uso:  python -I instalador/prueba_marcador.py

Arma una carpeta _forever_/WTF falsa con tres cuentas: una de la Horda (contó 4 en vivo y su
censo oyó a 6 lobos de la Horda), una de la Alianza (contó 3) y una sin datos de La Jauría.
Comprueba que cada cuenta recibe el número del otro bando en AlfaNucleoDB.jauria.bandos con
fuente = "instalador", que su propio número en vivo no se pisa, que el resto del archivo queda
igual (con su fin de línea), que una segunda vez no cambia nada, que lo viejo (más de 30 días)
no cuenta y que un archivo dañado no se toca.
"""
import importlib.util
import pathlib
import shutil
import sys
import tempfile

AQUI = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("instalador_alfa", AQUI / "instalador.py")
I = importlib.util.module_from_spec(spec)
spec.loader.exec_module(I)

fallas = []


def revisar(cond, que):
    print(("  ok  " if cond else "  MAL ") + que)
    if not cond:
        fallas.append(que)


AHORA = 1_764_000_000
HOY = AHORA - 3600
VIEJO = AHORA - 40 * 86400

HORDA = f"""
AlfaNucleoDB = {{
["buzon"] = {{
["pendientes"] = {{
}},
}},
["jauria"] = {{
["bandos"] = {{
["H"] = {{
["n"] = 4,
["fecha"] = {HOY},
["fuente"] = "vivo",
["dia"] = "2025-11-24",
["max"] = 5,
}},
}},
}},
["manada"] = {{
["censo"] = {{
["Uno-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Dos-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Tres-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Cuatro-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Cinco-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Seis-Reino"] = {{ ["t"] = {HOY}, ["f"] = "H", ["version"] = "1.4.0", }},
["Viejo-Reino"] = {{ ["t"] = {VIEJO}, ["f"] = "H", ["version"] = "1.3.9", }},
["SinBando-Reino"] = {{ ["t"] = {HOY}, ["version"] = "1.3.9", }},
}},
}},
}}
AlfaNucleoCharDB = nil
"""

ALIANZA = f"""
AlfaNucleoDB = {{
["jauria"] = {{
["bandos"] = {{
["A"] = {{
["n"] = 3,
["fecha"] = {HOY - 100},
["fuente"] = "vivo",
}},
["H"] = {{
["n"] = 2,
["fecha"] = {VIEJO},
["fuente"] = "vivo",
}},
}},
}},
["otra"] = "con \\"comillas\\" y é",
}}
"""

VACIA = """AlfaNucleoDB = {
["modulos"] = {
["x"] = true,
},
}
"""


def cuenta(raiz, nombre, texto, crlf=False):
    p = raiz / "WTF" / "Account" / nombre / "SavedVariables"
    p.mkdir(parents=True)
    f = p / "Alfa_Nucleo.lua"
    datos = texto.replace("\n", "\r\n") if crlf else texto
    f.write_bytes(datos.encode("utf-8"))
    return f


def bandos(f):
    g = I.leer_lua(f.read_bytes().decode("utf-8"))
    return I._plano(g)["AlfaNucleoDB"].get("jauria", {}).get("bandos", {})


def main() -> int:
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="alfa_marcador_"))
    try:
        raiz = tmp / "_forever_"
        h = cuenta(raiz, "HORDA", HORDA)
        a = cuenta(raiz, "ALIANZA", ALIANZA, crlf=True)
        v = cuenta(raiz, "VACIA", VACIA)
        mal = cuenta(raiz, "DANADA", 'AlfaNucleoDB = { ["jauria"] = { ')
        antes_mal = mal.read_bytes()
        antes_h = I._plano(I.leer_lua(h.read_bytes().decode("utf-8")))

        print("contar")
        c = I.contar_bandos(I.archivos_buzon([raiz]), AHORA)
        revisar(c.get("H", {}).get("n") == 6, f"la Horda: 6 lobos (el censo gana a los 5 en vivo): {c.get('H')}")
        revisar(c.get("A", {}).get("n") == 3, f"la Alianza: 3: {c.get('A')}")

        print("llevar")
        res = I.llevar_marcador([raiz], AHORA)
        revisar(res["cuentas"] == 4, f"vio las 4 cuentas: {res}")
        bh, ba, bv = bandos(h), bandos(a), bandos(v)
        revisar(bh.get("A", {}).get("n") == "3" and bh["A"].get("fuente") == "instalador", f"la cuenta de la Horda ve a la Alianza: {bh.get('A')}")
        revisar(bh.get("H", {}).get("fuente") == "vivo", "lo vivo de la Horda no se pisó (es igual de nuevo)")
        revisar(ba.get("H", {}).get("n") == "6" and ba["H"].get("fuente") == "instalador", f"la Alianza ve a la Horda (su dato viejo se cambió): {ba.get('H')}")
        revisar(ba.get("A", {}).get("fuente") == "vivo", "lo vivo de la Alianza no se pisó")
        revisar(bv.get("H", {}).get("n") == "6" and bv.get("A", {}).get("n") == "3", f"la cuenta sin La Jauría recibe los dos: {bv}")
        revisar(I._plano(I.leer_lua(v.read_bytes().decode("utf-8")))["AlfaNucleoDB"]["modulos"] == {"x": True}, "lo demás de la cuenta vacía quedó igual")
        texto_a = a.read_bytes().decode("utf-8")
        revisar(texto_a.count("\n") == texto_a.count("\r\n"), "el archivo con CRLF sigue con CRLF")
        revisar(I._plano(I.leer_lua(texto_a))["AlfaNucleoDB"]["otra"] == 'con "comillas" y é', "los textos con comillas y acentos quedaron igual")
        despues_h = I._plano(I.leer_lua(h.read_bytes().decode("utf-8")))
        despues_h["AlfaNucleoDB"]["jauria"]["bandos"].pop("A", None)
        revisar(despues_h == antes_h, "en la cuenta de la Horda solo cambió el bando A")
        revisar((h.parent / "Alfa_Nucleo.lua.antes-del-marcador").exists(), "dejó copia de respaldo")
        revisar(mal.read_bytes() == antes_mal, "el archivo dañado no se tocó")

        print("otra vez")
        crudo = {f: f.read_bytes() for f in (h, a, v)}
        res2 = I.llevar_marcador([raiz], AHORA)
        revisar(res2["escritos"] == 0 and all(f.read_bytes() == b for f, b in crudo.items()), f"una segunda vez no cambia nada: {res2}")

        print("más tarde, sin datos nuevos de nadie")
        res3 = I.llevar_marcador([raiz], AHORA + 60 * 86400)
        revisar(res3["bandos"] == {}, f"lo de hace más de 30 días ya no cuenta: {res3}")
        revisar(all(f.read_bytes() == b for f, b in crudo.items()), "y no borra lo que ya sabía cada cuenta")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("RESULTADO:", "todo bien" if not fallas else f"{len(fallas)} fallas")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
