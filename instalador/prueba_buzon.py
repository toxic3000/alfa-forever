"""Prueba del buzón del instalador, sin Google, sin Discord y sin el juego de verdad.

Uso:  python -I instalador/prueba_buzon.py

Arma una carpeta _forever_/WTF falsa con reportes guardados como los escribe el juego y
un servidor HTTP local que hace de formulario de Google (y de Discord, el extra opcional),
con un «espera» 429 de por medio. Comprueba los campos del formulario, que se marcan
enviado = true cambiando solo esa palabra, que no se repiten, los límites (5 por apertura,
1950 letras), sin internet, con el formulario caído, con Discord fallando, con el archivo
dañado y con el archivo de solo lectura.
"""
import http.server
import importlib.util
import json
import os
import pathlib
import shutil
import stat
import sys
import tempfile
import threading
import time
import urllib.parse

AQUI = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("instalador_alfa", AQUI / "instalador.py")
I = importlib.util.module_from_spec(spec)
spec.loader.exec_module(I)
F = I.BUZON_FORMULARIO

fallas = []


def revisar(cond, que):
    print(("  ok  " if cond else "  MAL ") + que)
    if not cond:
        fallas.append(que)


# ---------------------------------------------------------------------------
# Formulario de Google y Discord falsos
# ---------------------------------------------------------------------------
class Falso(http.server.BaseHTTPRequestHandler):
    formulario = []        # campos recibidos por el formulario
    discord = []           # mensajes recibidos por Discord
    modo_form = "bien"     # bien | caido (500) | malo (400)
    modo_discord = "bien"  # bien | borrado (404)
    esperas = 0            # cuántos 429 manda el formulario antes de aceptar

    def _responder(self, codigo, cuerpo=b"", tipo="text/html"):
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.end_headers()
        self.wfile.write(cuerpo)

    def do_POST(self):
        cuerpo = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if self.path.endswith("/formResponse"):
            if self.headers.get("Content-Type") != "application/x-www-form-urlencoded":
                return self._responder(400, b"tipo raro")
            if Falso.modo_form == "caido":
                return self._responder(500, b"<html>error</html>")
            campos = urllib.parse.parse_qs(cuerpo.decode("ascii"), keep_blank_values=True, strict_parsing=True)
            campos = {k: v[0] for k, v in campos.items()}
            if Falso.modo_form == "malo" or set(campos) != {F["tipo"], F["texto"], F["datos"], F["version"]} or \
                    campos[F["tipo"]] not in ("Error", "Mejora", "Comentario"):
                return self._responder(400, b"<html>falta una respuesta obligatoria</html>")
            if Falso.esperas > 0:
                Falso.esperas -= 1
                self.send_response(429)
                self.send_header("Retry-After", "1")
                self.end_headers()
                return
            Falso.formulario.append(campos)
            return self._responder(200, b"<html>Se registr\xc3\xb3 tu respuesta</html>")
        if "/api/webhooks/" in self.path:
            if Falso.modo_discord == "borrado":
                return self._responder(404, b'{"message": "Unknown Webhook"}', "application/json")
            Falso.discord.append({"ruta": self.path, "datos": json.loads(cuerpo.decode("utf-8"))})
            return self._responder(200, b'{"id": "1"}', "application/json")
        self._responder(404)

    def log_message(self, *a):
        pass


servidor = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Falso)
threading.Thread(target=servidor.serve_forever, daemon=True).start()
PUERTO = servidor.server_address[1]
FORM = f"http://127.0.0.1:{PUERTO}/forms/d/e/prueba/formResponse"
WEBHOOK = f"http://127.0.0.1:{PUERTO}/api/webhooks/123/abc"
esperado = []


def esperar(s):
    esperado.append(s)
    time.sleep(min(s, 0.05))


# ---------------------------------------------------------------------------
# El archivo guardado, como lo escribe el juego
# ---------------------------------------------------------------------------
def lua_texto(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + s + '"'


def armado(tipo_juego: str, suyo: str, datos: str) -> str:
    """Como lo arma Alfa_Bienvenida/Reporte.lua (componer)."""
    return f"**[Alfa] {tipo_juego}**\n{suyo}\n```\n{datos}\n```"


def reporte(i, texto, enviado=False, tipo="error", fecha=1795500000):
    return ("\t\t\t{\n"
            f'\t\t\t\t["enviado"] = {"true" if enviado else "false"},\n'
            f'\t\t\t\t["fecha"] = {fecha},\n'
            f'\t\t\t\t["id"] = "r{i}",\n'
            f'\t\t\t\t["texto"] = {lua_texto(texto)},\n'
            f'\t\t\t\t["tipo"] = "{tipo}",\n'
            '\t\t\t\t["version"] = "1.3.9",\n'
            f"\t\t\t}}, -- [{i}]\n")


def archivo_guardado(reportes) -> str:
    return ("\nAlfaNucleoDB = {\n"
            '\t["alfaSchema"] = 7,\n'
            '\t["respaldos"] = {\n\t\t["ultimo"] = 1795400000.5,\n\t\t["lista"] = {\n\t\t},\n\t},\n'
            '\t["buzon"] = {\n'
            '\t\t["pendientes"] = {\n' + "".join(reportes) + "\t\t},\n\t},\n"
            '\t["nombre"] = "Lobo \\"Toxic\\" Darunia ñandú 🐺",\n'
            '\t["negativo"] = -3,\n'
            '\t["grande"] = 1e+20,\n'
            '\t["falso"] = false,\n'
            '\t[1] = "uno",\n'
            "}\n"
            "AlfaNucleoOtro = nil\n")


DATOS_1 = ("Alfa 1.3.9 · cliente 1.60.1 (12345) · esMX · Alfa en esMX\nGuerrero, nivel 12\nLugar: Durotar\n"
           "Errores de Lua de Alfa en esta sesión:\n  2x Alfa_Rutas/Guias.lua:120: attempt to index nil")
SUYO_2 = 'Comillas "dobles", diagonal \\ y @everyone. Acentos: áéíóú ñ ¿¡ 🐺\nY otra línea con ``` adentro'
REPORTES = [
    # (tipo guardado, texto guardado, tipo esperado, lo suyo esperado, datos esperados)
    ("error", armado("Error", "abrí las bolsas en el banco y salió el error", DATOS_1),
     "Error", "abrí las bolsas en el banco y salió el error", DATOS_1),
    ("mejora", armado("Mejora", SUYO_2, "Alfa 1.3.9 · cliente 1.60.1"), "Mejora", SUYO_2, "Alfa 1.3.9 · cliente 1.60.1"),
    ("comentario", armado("Comentario", "(sin comentario)", "Lugar: Orgrimmar"), "Comentario", "(sin texto)",
     "Lugar: Orgrimmar"),
    ("error", "Un texto suelto que no tiene la forma de siempre.", "Error", "(sin texto)",
     "Un texto suelto que no tiene la forma de siempre."),
]


def montar(base: pathlib.Path, contenido: str, cuenta="CUENTA1") -> pathlib.Path:
    sv = base / "_forever_" / "WTF" / "Account" / cuenta / "SavedVariables"
    sv.mkdir(parents=True, exist_ok=True)
    p = sv / I.BUZON_ARCHIVO
    p.write_bytes(contenido.encode("utf-8"))
    return p


def correr(base, registro, webhook=None, formulario=FORM):
    Falso.formulario, Falso.discord = [], []
    return I.enviar_buzon([base / "_forever_"], webhook, registro=registro, espera=0.01, esperar=esperar,
                          formulario=formulario)


def main() -> int:
    raiz = pathlib.Path(tempfile.mkdtemp(prefix="alfa-buzon-"))
    try:
        print("0. Constantes")
        revisar(F["url"].startswith("https://docs.google.com/forms/") and F["url"].endswith("/formResponse"),
                "la URL del formulario está en BUZON_FORMULARIO")
        revisar(len({F[k] for k in ("tipo", "texto", "datos", "version")}) == 4 and
                all(F[k].startswith("entry.") for k in ("tipo", "texto", "datos", "version")), "los 4 entry.*")

        # 1. Cuatro reportes + uno ya enviado; otra cuenta con el archivo dañado
        print("1. Cuatro reportes pendientes al formulario")
        base = raiz / "juego"
        filas = [reporte(i, t, tipo=tj) for i, (tj, t, *_r) in enumerate(REPORTES, 1)]
        filas.insert(1, reporte(9, "viejo", enviado=True))
        original = archivo_guardado(filas)
        p = montar(base, original)
        danado_txt = archivo_guardado([reporte(1, "dañado")]).replace('["tipo"]', '["tipo" =', 1)
        danado = montar(base, danado_txt, "CUENTA2")
        antes_danado = danado.read_bytes()
        Falso.esperas = 1
        res = correr(base, raiz / "registro1.json")
        revisar(res["enviados"] == 4, f"mandó 4 reportes ({res})")
        revisar(len(Falso.formulario) == 4 and not Falso.discord, "el formulario recibió 4 y Discord nada (sin webhook)")
        revisar(any(0.5 <= e <= 1.5 for e in esperado), "esperó lo que pidió el 429 (Retry-After)")
        for campos, (_tj, _t, tipo, suyo, datos) in zip(Falso.formulario, REPORTES):
            revisar(campos[F["tipo"]] == tipo, f"tipo «{tipo}»")
            revisar(campos[F["texto"]] == suyo, f"lo que escribió el jugador: {suyo[:40]!r}")
            revisar(campos[F["datos"]].startswith(datos) and "id r" in campos[F["datos"]],
                    "los datos técnicos (más id y fecha)")
            revisar(campos[F["version"]] == "1.3.9", "la versión")
        revisar(res["marcados"] == 4 and res["sin_marcar"] == 0, "los marcó enviados")
        esperado_txt = original
        for _tj, t, *_r in REPORTES:
            i = esperado_txt.index(lua_texto(t))
            j = esperado_txt.rindex('["enviado"] = false', 0, i)
            esperado_txt = esperado_txt[:j] + '["enviado"] = true' + esperado_txt[j + len('["enviado"] = false'):]
        revisar(p.read_bytes().decode("utf-8") == esperado_txt,
                "solo cambió la palabra enviado de esos 4 (el resto, byte por byte igual)")
        resp = p.with_name(p.name + ".antes-del-buzon")
        revisar(resp.is_file() and resp.read_bytes() == original.encode("utf-8"), "dejó la copia de respaldo del original")
        revisar(not list(p.parent.glob("*.tmp")), "no dejó archivos temporales")
        revisar(danado.read_bytes() == antes_danado, "el archivo dañado quedó intacto")
        revisar(not danado.with_name(danado.name + ".antes-del-buzon").exists(), "al dañado ni siquiera le hizo respaldo")
        revisar(res["dañados"] == 1, "contó el archivo dañado")

        # 2. Otra apertura (con un registro nuevo: lo que cuenta es la marca del archivo)
        print("2. Otra apertura")
        res = correr(base, raiz / "registro-nuevo.json")
        revisar(res["enviados"] == 0 and not Falso.formulario, "no vuelve a mandarlos")
        revisar(p.read_bytes().decode("utf-8") == esperado_txt, "el archivo no cambió")

        # 3. Máximo 5 por apertura y textos recortados
        print("3. Límites")
        base3 = raiz / "limite"
        largo = armado("Error", "x" * 2500, "datos")
        p3 = montar(base3, archivo_guardado([reporte(i, largo if i == 1 else f"reporte {i}") for i in range(1, 8)]))
        reg3 = raiz / "registro3.json"
        res = correr(base3, reg3)
        revisar(res["enviados"] == 5 and res["pendientes"] == 2, f"manda 5 y deja 2 para después ({res})")
        c0 = Falso.formulario[0]
        revisar(len(c0[F["texto"]]) + len(c0[F["datos"]]) <= I.BUZON_LETRAS + 100, "recorta el reporte a 1950 letras")
        res = correr(base3, reg3)
        revisar(res["enviados"] == 2, "a la siguiente manda los 2 que faltaban")
        res = correr(base3, reg3)
        revisar(res["enviados"] == 0, "y luego ya nada")
        revisar(p3.read_bytes().count(b'["enviado"] = true') == 7, "los 7 quedaron marcados")

        # 4. Sin internet: no pasa nada, se intenta la próxima vez
        print("4. Sin internet")
        base4 = raiz / "sinred"
        p4 = montar(base4, archivo_guardado([reporte(1, "uno"), reporte(2, "dos")]))
        antes = p4.read_bytes()
        res = correr(base4, raiz / "r4.json", formulario="http://127.0.0.1:9/forms/formResponse")
        revisar(res["enviados"] == 0 and p4.read_bytes() == antes, "no manda, no toca el archivo y no falla")
        res = correr(base4, raiz / "r4.json")
        revisar(res["enviados"] == 2, "con internet, a la siguiente los manda")

        # 5. Formulario caído o que no acepta: se detiene sin marcar
        print("5. Formulario caído")
        for modo in ("caido", "malo"):
            base5 = raiz / f"form-{modo}"
            p5 = montar(base5, archivo_guardado([reporte(1, "uno"), reporte(2, "dos")]))
            antes = p5.read_bytes()
            Falso.modo_form = modo
            res = correr(base5, raiz / f"r5{modo}.json")
            Falso.modo_form = "bien"
            revisar(res["enviados"] == 0 and res["pendientes"] == 2 and p5.read_bytes() == antes,
                    f"({modo}) no marca nada si el formulario no lo recibió")

        # 6. Con webhook: también a Discord; si Discord falla, el formulario manda igual
        print("6. Discord como extra")
        base6 = raiz / "discord"
        p6 = montar(base6, archivo_guardado([reporte(1, REPORTES[1][1], tipo="mejora")]))
        res = correr(base6, raiz / "r6.json", webhook=WEBHOOK)
        revisar(res["enviados"] == 1 and res["discord"] == 1 and len(Falso.discord) == 1, f"llegó a los dos ({res})")
        d0 = Falso.discord[0]["datos"] if Falso.discord else {}
        revisar(d0.get("allowed_mentions") == {"parse": []}, "en Discord sin menciones (@everyone no suena)")
        revisar(bool(Falso.discord) and "wait=true" in Falso.discord[0]["ruta"], "Discord con ?wait=true")
        base6b = raiz / "discord-borrado"
        p6b = montar(base6b, archivo_guardado([reporte(1, "uno"), reporte(2, "dos")]))
        Falso.modo_discord = "borrado"
        res = correr(base6b, raiz / "r6b.json", webhook=WEBHOOK)
        Falso.modo_discord = "bien"
        revisar(res["enviados"] == 2 and res["discord"] == 0 and res["marcados"] == 2,
                f"con el webhook borrado, el formulario manda y marca igual ({res})")

        # 7. Archivo de solo lectura: manda, no puede marcar, y el registro evita repetirlos
        print("7. Archivo de solo lectura")
        base7 = raiz / "lectura"
        p7 = montar(base7, archivo_guardado([reporte(1, "uno")]))
        os.chmod(p7, stat.S_IREAD)
        antes = p7.read_bytes()
        reg7 = raiz / "r7.json"
        res = correr(base7, reg7)
        revisar(res["enviados"] == 1 and res["sin_marcar"] == 1 and p7.read_bytes() == antes,
                f"lo manda pero no puede marcarlo ({res})")
        res = correr(base7, reg7)
        revisar(res["enviados"] == 0 and not Falso.formulario, "no lo repite (registro local)")
        os.chmod(p7, stat.S_IREAD | stat.S_IWRITE)
        res = correr(base7, reg7)
        revisar(res["enviados"] == 0 and res["marcados"] == 1 and b'["enviado"] = true' in p7.read_bytes(),
                "cuando ya se puede, lo marca sin volver a mandarlo")

        # 8. Cosas que no se entienden: no se tocan
        print("8. Archivos raros")
        base8 = raiz / "raros"
        raros = {
            "CORTADO": archivo_guardado([reporte(1, "uno")])[:-40],
            "CODIGO": archivo_guardado([reporte(1, "uno")]) + "\nprint('hola')\n",
            "SINCERRAR": archivo_guardado([reporte(1, 'uno')]).replace('"uno"', '"uno', 1),
            "VACIO": "",
            "SINBUZON": "AlfaNucleoDB = {\n\t[\"x\"] = 1,\n}\n",
        }
        antes = {c: montar(base8, t, c).read_bytes() for c, t in raros.items()}
        res = correr(base8, raiz / "r8.json")
        revisar(res["enviados"] == 0 and not Falso.formulario, f"no manda nada de archivos rotos ({res})")
        revisar(all((base8 / "_forever_/WTF/Account" / c / "SavedVariables" / I.BUZON_ARCHIVO).read_bytes() == b
                    for c, b in antes.items()), "ninguno cambió")

        # 9. El webhook (opcional) y la frase
        print("9. Webhook opcional y la frase")
        revisar(I.webhook_buzon() is None or (AQUI / "buzon_local.json").is_file(),
                "sin instalador/buzon_local.json no hay webhook")
        revisar(bool(I.BUZON_WEBHOOK.fullmatch("https://discord.com/api/webhooks/123456/AbC-d_e")), "acepta un webhook de Discord")
        revisar(not I.BUZON_WEBHOOK.fullmatch("https://ejemplo.com/api/webhooks/1/x"), "rechaza otra página")
        u = "https://discord.com/api/webhooks/123456/AbC-d_e"
        revisar(I._buzon_desofuscar(I._buzon_ofuscar(u)) == u and u not in I._buzon_ofuscar(u),
                "la URL del webhook va disfrazada dentro del .exe")
        revisar(I.frase_buzon(2) == "Envié 2 reportes a Toxic. ¡Gracias por ayudar a la manada!" and
                I.frase_buzon(1) == "Envié 1 reporte a Toxic. ¡Gracias por ayudar a la manada!", "la frase de la ventana")
    finally:
        servidor.shutdown()
        for p in raiz.rglob("*"):
            try:
                os.chmod(p, stat.S_IREAD | stat.S_IWRITE)
            except OSError:
                pass
        shutil.rmtree(raiz, ignore_errors=True)
    print()
    print("RESULTADO: todo bien" if not fallas else f"RESULTADO: {len(fallas)} fallas")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
