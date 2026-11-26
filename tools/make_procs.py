"""Dibuja las texturas de los procs del brujo.

- flame_glow.tga y flame_core.tga: 16 fotogramas (4x4 de 64x256) de llamas de sombra que suben, para
  una animación FlipBook que se repite sin corte: en una vuelta cada lengua sube una o dos alturas
  enteras. Trance de las Sombras (Nightfall). El brillo y el núcleo van aparte para teñir el brillo
  con tu color y dejar el núcleo casi blanco.
- wisps_glow.tga y wisps_core.tga: 16 fotogramas (4x4 de 64x256) de almas que suben con su estela,
  detrás del personaje. Cosecha de almas.
- ring_glow.tga y ring_core.tga: 16 fotogramas (4x4 de 256x128) de un anillo de llamas en el suelo,
  visto desde la cámara: cada lengua parpadea a su ritmo y la vuelta empalma. Diezmar.
- ember_glow.tga y ember_core.tga: 16 fotogramas (4x4 de 128x128) de una brasa con tres lenguas y
  tres chispas girando un tercio de vuelta. Sombra y llama (morada la de sombra, naranja la de fuego).
- proc_aura.tga: un brillo alargado detrás de cada columna de llamas.
- proc_spot.tga: un brillo redondo para el destello al salir el proc.

Todo en blanco: el color lo pone el juego (SetVertexColor) y la transparencia es la intensidad.
Uso: python -I make_procs.py <carpeta media del addon>
Necesita: pip install pillow
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4  # se dibuja grande y se reduce para suavizar bordes
COLS, ROWS = 4, 4
FRAMES = COLS * ROWS
FW, FH = 64, 256  # un fotograma: estrecho, las lenguas juntas


def stretch(img, gain):
    """Sube la intensidad sin pasar de 255"""
    return img.point(lambda v: min(255, int(v * gain)))


def white(alpha):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def brush(d, pts, widths, power):
    """Una línea de grosor variable: tramos cortos con las puntas redondas"""
    fill = int(255 * power)
    for (ax, ay), (bx, by), w in zip(pts, pts[1:], widths):
        if w <= 0.2:
            continue
        d.line((ax, ay, bx, by), fill=fill, width=max(1, round(w)))
        r = w / 2
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=fill)


def tongues(seed):
    """Las lenguas de una columna: dónde, lo largas, lo gruesas y lo rápidas que suben"""
    rng = random.Random(seed)
    out = []
    for i in range(6):
        out.append(dict(
            x=rng.uniform(-9, 9),
            length=rng.uniform(70, 120),
            width=rng.uniform(5.5, 8.5),
            laps=1 if i % 3 else 2,  # alturas enteras por vuelta: la animación empalma
            phase=rng.uniform(0, 1),
            sway=rng.uniform(3.0, 6.0),
            wobble=rng.uniform(0, math.tau),
            power=rng.uniform(0.6, 1.0),
        ))
    return out


def embers(seed):
    """Chispas pequeñas que suben más deprisa que las llamas"""
    rng = random.Random(seed)
    return [dict(x=rng.uniform(-18, 18), laps=rng.choice((2, 3)), phase=rng.uniform(0, 1),
                 size=rng.uniform(1.2, 2.2), drift=rng.uniform(-6, 6), power=rng.uniform(0.5, 0.9))
            for _ in range(9)]


def flame_layer(ts, es, t, scale, power=1.0):
    """Las llamas en el momento t (0 a 1 de la vuelta), con el grosor por scale"""
    w, h = FW * SS, FH * SS
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for g in ts:
        tip = ((g["phase"] - g["laps"] * t) % 1.0) * h  # sube: la y baja con el tiempo
        length = g["length"] * SS
        for shift in (-h, 0, h):  # la que sale por arriba entra por abajo
            top = tip + shift
            if top > h or top + length < 0:
                continue
            n = 30
            pts, widths = [], []
            for k in range(n + 1):
                s = k / n  # 0 en la punta, 1 en la cola
                y = top + s * length
                # La punta se mece más que el cuerpo, como una llama
                x = w / 2 + g["x"] * SS + g["sway"] * SS * (1.2 - 0.6 * s) * math.sin(
                    math.tau * 1.3 * y / h + g["wobble"])
                pts.append((x, y))
                # Fina en la punta, ancha abajo y apagándose en la cola
                profile = (math.sin(math.pi * min(1.0, s * 1.25)) ** 0.55) * (0.25 + 0.75 * s) * (1 - 0.6 * s * s)
                widths.append(g["width"] * scale * SS * profile)
            brush(d, pts, widths[1:], g["power"] * power)
    for e in es:
        y = ((e["phase"] - e["laps"] * t) % 1.0) * h
        x = w / 2 + (e["x"] + e["drift"] * math.sin(math.tau * y / h)) * SS
        r = e["size"] * scale * SS * 0.5
        fill = int(255 * e["power"] * power)
        for shift in (-h, 0, h):
            d.ellipse((x - r, y + shift - r, x + r, y + shift + r), fill=fill)
    return img


def fade_ends(img, edge=0.2):
    """Se apaga suave arriba y abajo, para que las llamas aparezcan y se vayan sin corte"""
    mask = Image.new("L", (1, img.size[1]))
    for y in range(img.size[1]):
        t = y / (img.size[1] - 1)
        # Abajo, donde nacen, más fuerte que arriba, donde se apagan
        e = min(t / (edge * 1.6), (1 - t) / edge)
        mask.putpixel((0, y), int(255 * min(1.0, e) ** 1.5))
    return ImageChops.multiply(img, mask.resize(img.size))


def flame_frame(ts, es, t):
    glow = ImageChops.add(stretch(flame_layer(ts, es, t, 2.6).filter(ImageFilter.GaussianBlur(4 * SS)), 2.2),
                          stretch(flame_layer(ts, es, t, 1.6).filter(ImageFilter.GaussianBlur(1.8 * SS)), 1.3))
    core = ImageChops.add(flame_layer(ts, [], t, 0.55).filter(ImageFilter.GaussianBlur(0.6 * SS)),
                          flame_layer(ts, es, t, 1.0, 0.4).filter(ImageFilter.GaussianBlur(1.2 * SS)))
    return [fade_ends(layer).resize((FW, FH), Image.LANCZOS) for layer in (glow, core)]


def flame_sheets():
    ts, es = tongues(6666), embers(1313)
    glow_sheet = Image.new("L", (FW * COLS, FH * ROWS), 0)
    core_sheet = Image.new("L", (FW * COLS, FH * ROWS), 0)
    for n in range(FRAMES):
        glow, core = flame_frame(ts, es, n / FRAMES)
        x, y = (n % COLS) * FW, (n // COLS) * FH
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


def sheets(frame, fw, fh):
    """Las dos hojas de 4x4 (brillo y núcleo) de una animación: frame(t) da las dos capas en L"""
    glow_sheet = Image.new("L", (fw * COLS, fh * ROWS), 0)
    core_sheet = Image.new("L", (fw * COLS, fh * ROWS), 0)
    for n in range(FRAMES):
        glow, core = frame(n / FRAMES)
        x, y = (n % COLS) * fw, (n // COLS) * fh
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


# ---------------------------------------------------------------- Almas (Cosecha de almas)

def souls(seed):
    rng = random.Random(seed)
    return [dict(x=rng.uniform(-16, 16), laps=1 if i % 2 else 2, phase=rng.uniform(0, 1), size=rng.uniform(2.6, 3.8),
                 tail=rng.uniform(26, 46), sway=rng.uniform(3, 7), wobble=rng.uniform(0, math.tau),
                 power=rng.uniform(0.65, 1.0)) for i in range(5)]


def wisps_layer(ss, t, scale, power=1.0):
    w, h = FW * SS, FH * SS
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for s in ss:
        head = ((s["phase"] - s["laps"] * t) % 1.0) * h
        for shift in (-h, 0, h):
            top = head + shift
            if top > h + s["tail"] * SS or top + s["tail"] * SS < -10:
                continue
            n = 18
            pts, widths = [], []
            for k in range(n + 1):
                f = k / n  # 0 en el alma, 1 al final de la estela
                y = top + f * s["tail"] * SS
                x = w / 2 + (s["x"] + s["sway"] * math.sin(math.tau * 1.2 * y / h + s["wobble"])) * SS
                pts.append((x, y))
                widths.append(s["size"] * 1.6 * scale * SS * (1 - f) ** 1.4)
            brush(d, pts, widths[1:], s["power"] * power * 0.7)
            x0, y0 = pts[0]
            r = s["size"] * scale * SS
            d.ellipse((x0 - r, y0 - r, x0 + r, y0 + r), fill=int(255 * s["power"] * power))
    return img


def wisps_frame(ss, t):
    glow = ImageChops.add(stretch(wisps_layer(ss, t, 2.4).filter(ImageFilter.GaussianBlur(4 * SS)), 2.2),
                          stretch(wisps_layer(ss, t, 1.4).filter(ImageFilter.GaussianBlur(1.6 * SS)), 1.3))
    core = wisps_layer(ss, t, 0.7).filter(ImageFilter.GaussianBlur(0.5 * SS))
    return [fade_ends(layer).resize((FW, FH), Image.LANCZOS) for layer in (glow, core)]


# ---------------------------------------------------------------- Anillo de llamas (Diezmar)

RW, RH = 256, 128  # un fotograma del anillo
SQUASH = 0.38  # un círculo en el suelo, visto desde la cámara: más ancho que alto
RX = 96  # radio del anillo en píxeles finales, a lo ancho
TONGUES = 12


def ground(angle, radius=1.0):
    """Un punto del círculo del suelo, visto desde la cámara (y hacia abajo); un poco más bajo que el
    centro para que las llamas quepan hacia arriba"""
    return (RW / 2 + RX * radius * math.cos(angle)) * SS, (RH * 0.62 + RX * SQUASH * radius * math.sin(angle)) * SS


def ring_layer(t, scale, power=1.0):
    img = Image.new("L", (RW * SS, RH * SS), 0)
    d = ImageDraw.Draw(img)
    rng = random.Random(777)
    # La base: una elipse fina
    pts = [ground(math.tau * k / 120) for k in range(121)]
    brush(d, pts, [1.2 * scale * SS] * 120, 0.55 * power)
    # Las lenguas: cada una de pie sobre el anillo, con su ritmo (vueltas enteras: empalma)
    for i in range(TONGUES):
        a = math.tau * (i + 0.5) / TONGUES
        rate, phase = rng.choice((1, 2, 3)), rng.uniform(0, 1)
        front = 0.75 + 0.25 * (1 + math.sin(a)) / 2  # las de delante, más grandes
        height = 30 * front * (0.65 + 0.35 * math.sin(math.tau * (rate * t + phase))) * SS
        bx, by = ground(a)
        sway = 3 * math.sin(math.tau * (rate * t + phase + 0.25)) * SS
        n = 14
        tpts, widths = [], []
        for k in range(n + 1):
            f = k / n  # 0 en la base, 1 en la punta
            tpts.append((bx + sway * f * f, by - f * height))
            widths.append(5.5 * front * scale * SS * (1 - f) ** 0.8)
        brush(d, tpts, widths[1:], power * (0.7 + 0.3 * front))
    return img


def ring_frame(t):
    glow = ImageChops.add(stretch(ring_layer(t, 2.2).filter(ImageFilter.GaussianBlur(4 * SS)), 2.0),
                          stretch(ring_layer(t, 1.4).filter(ImageFilter.GaussianBlur(1.4 * SS)), 1.3))
    core = ring_layer(t, 0.6).filter(ImageFilter.GaussianBlur(0.5 * SS))
    return [layer.resize((RW, RH), Image.LANCZOS) for layer in (glow, core)]


# ---------------------------------------------------------------- Brasa (Sombra y llama)

EW = EH = 128


def ember_layer(t, scale, power=1.0):
    img = Image.new("L", (EW * SS, EH * SS), 0)
    d = ImageDraw.Draw(img)
    cx, cy = EW / 2 * SS, EH * 0.56 * SS
    # El corazón de la brasa
    r = 9 * scale * SS
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(255 * power))
    # Tres lenguas que salen hacia arriba girando: un tercio de vuelta por vuelta de la animación
    for i in range(3):
        a0 = math.tau * (i / 3 + t / 3)
        n = 16
        pts, widths = [], []
        for k in range(n + 1):
            f = k / n
            a = a0 + f * 1.6
            rad = (8 + 22 * f) * SS
            pts.append((cx + rad * math.cos(a) * 0.8, cy - rad * 0.55 - 26 * f * f * SS + rad * math.sin(a) * 0.35))
            widths.append(7 * scale * SS * (1 - f) ** 0.9)
        brush(d, pts, widths[1:], power * 0.85)
    # Tres chispas en órbita
    for i in range(3):
        a = math.tau * (i / 3 + t / 3) + 0.9
        x, y = cx + 30 * SS * math.cos(a), cy + 13 * SS * math.sin(a) - 6 * SS
        rs = 2.2 * scale * SS
        d.ellipse((x - rs, y - rs, x + rs, y + rs), fill=int(255 * power * 0.9))
    return img


def ember_frame(t):
    glow = ImageChops.add(stretch(ember_layer(t, 2.0).filter(ImageFilter.GaussianBlur(5 * SS)), 2.0),
                          stretch(ember_layer(t, 1.3).filter(ImageFilter.GaussianBlur(1.6 * SS)), 1.3))
    core = ember_layer(t, 0.55).filter(ImageFilter.GaussianBlur(0.6 * SS))
    return [layer.resize((EW, EH), Image.LANCZOS) for layer in (glow, core)]


def soft(w, h, sx, sy):
    """Una campana suave que llega a cero en los bordes"""
    alpha = Image.new("L", (w, h))
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
            bell = math.exp(-(dx * dx) / sx - (dy * dy) / sy)
            edge = max(0.0, 1 - dx * dx) * max(0.0, 1 - dy * dy)
            alpha.putpixel((x, y), int(255 * bell * edge))
    return white(alpha)


if __name__ == "__main__":
    media = Path(sys.argv[1])
    glow, core = flame_sheets()
    glow.save(media / "flame_glow.tga")
    core.save(media / "flame_core.tga")
    ss = souls(2424)
    for name, made in (("wisps", sheets(lambda t: wisps_frame(ss, t), FW, FH)),
                       ("ring", sheets(ring_frame, RW, RH)),
                       ("ember", sheets(ember_frame, EW, EH))):
        made[0].save(media / f"{name}_glow.tga")
        made[1].save(media / f"{name}_core.tga")
    soft(64, 256, 0.16, 0.3).save(media / "proc_aura.tga")
    soft(128, 128, 0.22, 0.22).save(media / "proc_spot.tga")
    print("flame, wisps, ring, ember (glow y core), proc_aura, proc_spot")
