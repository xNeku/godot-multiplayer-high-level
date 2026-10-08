"""Definición de los mapas. Ejecutar:  python3 tools/mapgen/maps.py
Reglas de escala (ver README): celda = 11 px, personaje = 2 celdas de alto,
altura libre de sala = 6 celdas, separación entre suelos = 7 celdas, peldaño máximo = 4 celdas,
paso mínimo = 2 celdas de ancho, puertas 2x5."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from mapgen import Map

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "high_level_example", "scenes", "mapas")
PREV = os.path.join(os.path.dirname(__file__), "previews")
MAPS = []


def register(fn):
    MAPS.append(fn)
    return fn


def stack(m, x, ys, n=2):
    """Pila de n cajas sobre un suelo cuya fila de soporte es ys (sirve de escalón)."""
    for i in range(n):
        m.box(x, ys - 2 * (i + 1))



def lvl(Y, i):
    """Fila de soporte (suelo) del nivel i. Separación entre niveles: 7 celdas."""
    return Y - 7 * i


def building(m, x0, x1, Y, L, roof_t=2):
    """Edificio de L niveles: muros de 2, suelos sólidos entre niveles y tejado."""
    top = Y - 7 * L
    m.fill(x0, top, x0 + 2, Y + 1)
    m.fill(x1 - 2, top, x1, Y + 1)
    for i in range(1, L):
        m.slab(x0 + 2, x1 - 2, lvl(Y, i))
    m.fill(x0, top - roof_t + 1, x1, top + 1)


def hatch(m, x, S, w=8, kind="hole", step_w=4, side="left"):
    """Abertura en el suelo situado 7 celdas sobre el nivel con suelo en S, con un peldaño
    a 4 celdas para poder subir. kind: 'hole' = hueco abierto, 'T' = trampilla traspasable."""
    row = S - 7
    m.hole(x, row, x + w, row + 1)
    if kind == "T":
        m.fill(x, row, x + w, row + 1, "T")
    sx = x if side == "left" else x + w - step_w
    m.oneway(sx, sx + step_w, S - 4)


def partition(m, x, S, door=False, window=False, t=2):
    """Tabique de altura de sala (6 celdas) sobre el suelo S."""
    m.fill(x, S - 6, x + t, S, "#")
    if door:
        m.door(x, S - 1)
    if window:
        m.window(x, S - 5, x + t, S - 2)


def fill_top(m, Y, L):
    """Rellena de sólido por encima del tejado del nivel L."""
    m.fill(0, 0, m.W, Y - 7 * L + 1)

@register
def m01_cuadrilatero():
    m = Map("Mapa01_Cuadrilatero", 72, 42, darkness=False)
    m.frame(2)
    Y = 40                                   # suelo (fila de soporte)
    # escalones de cajas y plataformas a 7 / 14 celdas
    stack(m, 12, Y); stack(m, 58, Y)
    m.oneway(4, 24, Y - 7); m.oneway(48, 68, Y - 7)
    m.oneway(24, 48, Y - 14)
    stack(m, 22, Y - 7, 2); stack(m, 48, Y - 7, 2)      # sube de cada lado a la plataforma central
    m.oneway(31, 41, Y - 21)
    stack(m, 36, Y - 14, 2)
    m.box(34, Y - 2); m.box(37, Y - 2)                   # cobertura central en el suelo
    for x in (6, 14, 30, 42, 58, 66):
        pass
    m.spawn(5, Y - 1); m.spawn(66, Y - 1); m.spawn(17, Y - 8); m.spawn(52, Y - 8)
    m.spawn(30, Y - 15); m.spawn(40, Y - 15)
    m.weapon(36, Y - 22, "escopeta")
    m.weapon(8, Y - 8, "usp"); m.weapon(62, Y - 8, "deagle")
    m.weapon(28, Y - 1, "mp7"); m.weapon(44, Y - 1, "escopeta")
    m.item(28, Y - 15, "granada"); m.item(16, Y - 1, "semtex"); m.item(55, Y - 1, "tomahawk")
    m.bulb(36, 2, 18, 0.9, False)
    return m



@register
def m02_almacen():
    m = Map("Mapa02_Almacen", 110, 40, darkness=True)
    m.frame(2)
    Y = 38
    m.fill(2, 2, 108, 11)                                   # techo macizo
    # sala izquierda y derecha con techo sólido (también es pasarela)
    m.slab(2, 20, 31); m.oneway(20, 36, 31)
    m.slab(90, 108, 31); m.oneway(74, 90, 31)
    partition(m, 18, Y, door=True); partition(m, 90, Y, door=True)
    stack(m, 36, Y); stack(m, 72, Y)
    m.oneway(14, 96, 24)
    stack(m, 10, 31); stack(m, 98, 31)
    m.oneway(26, 40, 17); m.oneway(70, 84, 17)
    stack(m, 22, 24); stack(m, 88, 24)
    for x in (28, 46, 62, 80):
        m.box(x, Y - 2)
    stack(m, 52, Y); m.box(44, Y - 2)
    m.box(56, 22); m.box(58, 22)
    for x, y in ((40, Y - 1), (56, Y - 1), (66, Y - 1), (30, 23), (80, 23), (80, 30)):
        m.spawn(x, y)
    m.weapon(44, Y - 5, "mp7") if False else None
    m.weapon(32, Y - 1, "mp7"); m.weapon(60, Y - 1, "usp")
    m.weapon(28, 30, "deagle"); m.weapon(62, 23, "escopeta")
    m.weapon(30, 16, "sniper"); m.weapon(78, 16, "bazooka")
    m.weapon(6, Y - 1, "sniper_s"); m.weapon(102, Y - 1, "mp7")
    m.item(26, Y - 1, "granada"); m.item(84, Y - 1, "semtex"); m.item(10, Y - 1, "claymore")
    m.item(66, 23, "pem"); m.item(84, 30, "betty"); m.item(96, 30, "humo"); m.item(34, 16, "translocator")
    for bx, by in ((10, 32), (100, 32), (28, 32), (82, 32), (55, 25), (30, 25), (80, 25), (33, 11), (77, 11), (55, 11)):
        m.bulb(bx, by)
    m.switch(104, 30)
    return m


@register
def m03_torre():
    L = 9
    m = Map("Mapa03_Torre", 72, 7 * L + 4, darkness=True)
    m.frame(2)
    Y = m.H - 2
    building(m, 0, 72, Y, L)
    for i in range(L):
        S = lvl(Y, i)
        partition(m, 34, S, door=True)
        if i < L - 1:
            if i % 2 == 0:
                hatch(m, 4, S, 8, "hole", 4, "left")
            else:
                hatch(m, 60, S, 8, "hole", 4, "right")
        m.bulb(18, S - 6); m.bulb(52, S - 6, 12)
    # spawns, armas, objetos
    for (x, i) in ((20, 0), (50, 0), (16, 1), (56, 2), (24, 2), (46, 1)):
        m.spawn(x, lvl(Y, i) - 1)
    W = {0: [(26, "usp"), (46, "mp7")], 1: [(24, "deagle")], 2: [(40, "escopeta")], 3: [(20, "sniper_s")],
         4: [(50, "deagle")], 5: [(26, "mp7")], 6: [(48, "bazooka")], 7: [(22, "usp")], 8: [(22, "sniper")]}
    for i, lst in W.items():
        for x, k in lst:
            m.weapon(x, lvl(Y, i) - 1, k)
    IT = {0: [(8, "claymore"), (62, "granada")], 1: [(40, "semtex")], 2: [(14, "humo")], 3: [(54, "tomahawk")],
          4: [(24, "betty")], 5: [(40, "pem")], 6: [(14, "granada")], 7: [(60, "translocator")], 8: [(56, "semtex")]}
    for i, lst in IT.items():
        for x, k in lst:
            m.item(x, lvl(Y, i) - 1, k)
    m.switch(30, lvl(Y, 4) - 1)
    return m


@register
def m04_dos_edificios():
    m = Map("Mapa04_DosEdificios", 170, 44, darkness=True)
    m.frame(2)
    Y = 42
    # los dos edificios (3 plantas, tejado con trampilla)
    for x0, x1, flip in ((0, 56, False), (114, 170, True)):
        building(m, x0, x1, Y, 3, roof_t=1)
        if not flip:
            hatch(m, 6, lvl(Y, 0), 8, "hole", 4, "left")
            hatch(m, 40, lvl(Y, 1), 8, "hole", 4, "right")
            hatch(m, 6, lvl(Y, 2), 8, "T", 4, "left")
            partition(m, 28, lvl(Y, 0), door=True); partition(m, 28, lvl(Y, 1), door=True); partition(m, 28, lvl(Y, 2), door=True)
            m.door(54, Y - 1)
            for S in (lvl(Y, 1), lvl(Y, 2)):
                m.window(54, S - 5, 56, S - 2)
        else:
            hatch(m, 156, lvl(Y, 0), 8, "hole", 4, "right")
            hatch(m, 122, lvl(Y, 1), 8, "hole", 4, "left")
            hatch(m, 156, lvl(Y, 2), 8, "T", 4, "right")
            partition(m, 142, lvl(Y, 0), door=True); partition(m, 142, lvl(Y, 1), door=True); partition(m, 142, lvl(Y, 2), door=True)
            m.door(114, Y - 1)
            for S in (lvl(Y, 1), lvl(Y, 2)):
                m.window(114, S - 5, 116, S - 2)
    # zigurat central (la recompensa)
    m.fill(70, 38, 100, 42); m.fill(74, 34, 96, 38); m.fill(78, 30, 92, 34)
    m.box(84, 28)
    # cobertura en el patio
    for x in (62, 66, 104, 108):
        m.box(x, Y - 2)
    m.box(64, Y - 4) if False else None
    # tejados: cajas
    m.box(20, 19); m.box(40, 19); m.box(130, 19); m.box(150, 19)
    for x, y in ((14, Y - 1), (38, Y - 1), (44, lvl(Y, 1) - 1), (156, Y - 1), (132, Y - 1), (126, lvl(Y, 1) - 1)):
        m.spawn(x, y)
    m.weapon(20, Y - 1, "usp"); m.weapon(46, lvl(Y, 1) - 1, "mp7"); m.weapon(20, lvl(Y, 2) - 1, "deagle")
    m.weapon(150, Y - 1, "mp7"); m.weapon(124, lvl(Y, 1) - 1, "escopeta"); m.weapon(150, lvl(Y, 2) - 1, "usp")
    m.weapon(30, 20, "sniper"); m.weapon(140, 20, "deagle")
    m.weapon(80, 29, "bazooka"); m.weapon(89, 29, "sniper_s")
    m.item(18, lvl(Y, 1) - 1, "granada"); m.item(36, lvl(Y, 2) - 1, "betty"); m.item(150, lvl(Y, 1) - 1, "semtex")
    m.item(134, lvl(Y, 2) - 1, "claymore"); m.item(82, 29, "pem"); m.item(91, 29, "translocator")
    m.item(68, Y - 1, "humo"); m.item(48, 20, "tomahawk")
    for S in (Y, lvl(Y, 1), lvl(Y, 2)):
        for bx in (14, 42, 128, 156):
            m.bulb(bx, S - 6)
    m.switch(101, Y - 1)
    return m


@register
def m05_pasillos():
    m = Map("Mapa05_Pasillos", 150, 40, darkness=True)
    m.frame(2)
    Y = 38
    building(m, 0, 150, Y, 3)
    fill_top(m, Y, 3)
    for i in range(3):
        S = lvl(Y, i)
        for x in (30, 60, 90, 120):
            partition(m, x, S, door=True)
    hatch(m, 8, lvl(Y, 0), 8, "hole", 4, "left"); hatch(m, 134, lvl(Y, 0), 8, "hole", 4, "right")
    hatch(m, 68, lvl(Y, 1), 8, "hole", 4, "left")
    for i in range(3):
        S = lvl(Y, i)
        for bx in (16, 46, 76, 106, 136):
            m.bulb(bx, S - 6, 12)
    sp = [(40, 0), (100, 0), (20, 1), (130, 1), (70, 1), (110, 2)]
    for x, i in sp:
        m.spawn(x, lvl(Y, i) - 1)
    m.weapon(20, Y - 1, "usp"); m.weapon(80, Y - 1, "mp7"); m.weapon(140, Y - 1, "deagle")
    m.weapon(46, lvl(Y, 1) - 1, "sniper_s"); m.weapon(100, lvl(Y, 1) - 1, "usp"); m.weapon(146, lvl(Y, 1) - 1, "escopeta")
    m.weapon(20, lvl(Y, 2) - 1, "mp7"); m.weapon(84, lvl(Y, 2) - 1, "sniper"); m.weapon(130, lvl(Y, 2) - 1, "usp")
    m.item(28, Y - 1, "hilo"); m.item(58, Y - 1, "hilo"); m.item(116, Y - 1, "humo")
    m.item(22, lvl(Y, 1) - 1, "claymore"); m.item(88, lvl(Y, 1) - 1, "pem"); m.item(126, lvl(Y, 1) - 1, "betty")
    m.item(40, lvl(Y, 2) - 1, "granada"); m.item(88, lvl(Y, 2) - 1, "semtex"); m.item(120, lvl(Y, 2) - 1, "tomahawk")
    m.switch(144, Y - 1)
    return m


@register
def m06_cueva():
    m = Map("Mapa06_Cueva", 100, 46, darkness=True)
    Y = 44
    m.fill(0, 0, 100, 46)
    m.hole(2, 4, 98, Y)
    # montaña central escalonada
    m.fill(36, 40, 64, Y); m.fill(40, 36, 60, 40); m.fill(44, 32, 56, 36)
    # escalones laterales
    m.fill(2, 40, 14, Y); m.fill(2, 36, 8, 40)
    m.fill(86, 40, 98, Y); m.fill(92, 36, 98, 40)
    # subida en diagonal a la cumbre
    m.oneway(8, 22, 33); m.oneway(24, 32, 29); m.oneway(34, 42, 25)
    m.oneway(78, 92, 33); m.oneway(68, 76, 29); m.oneway(58, 66, 25)
    m.oneway(44, 56, 21)
    # estalactitas
    m.fill(28, 4, 32, 18, "O"); m.fill(68, 4, 72, 18, "O"); m.fill(47, 4, 53, 10, "O")
    m.box(20, Y - 2); m.box(78, Y - 2); m.box(46, 30) if False else None
    for x, y in ((11, 39), (88, 39), (18, Y - 1), (80, Y - 1), (48, 31), (14, 32)):
        m.spawn(x, y)
    m.weapon(50, 31, "bazooka"); m.weapon(50, 20, "sniper"); m.weapon(24, Y - 1, "mp7"); m.weapon(72, Y - 1, "usp")
    m.weapon(12, 32, "deagle"); m.weapon(88, 32, "escopeta"); m.weapon(28, 28, "sniper_s")
    m.item(30, Y - 1, "granada"); m.item(68, Y - 1, "semtex"); m.item(38, 24, "pem"); m.item(62, 24, "claymore")
    m.item(4, 35, "betty"); m.item(95, 35, "humo")
    for bx, by in ((18, 4), (82, 4), (50, 12), (30, 20), (70, 20)):
        m.bulb(bx, by, 16, 1.2)
    return m


@register
def m07_oficina():
    m = Map("Mapa07_Oficina", 130, 40, darkness=True)
    m.frame(2)
    Y = 38
    building(m, 0, 130, Y, 3)
    fill_top(m, Y, 3)
    # planta baja: cubículos separados por cristal; se entra desde el pasillo de arriba
    for x in (26, 52, 78, 104):
        partition(m, x, Y, window=True)
    for x in (6, 32, 58, 84, 110):
        hatch(m, x, Y, 8, "T", 4, "left")
    # primera planta: pasillo con puertas
    for x in (40, 90):
        partition(m, x, lvl(Y, 1), door=True)
    hatch(m, 14, lvl(Y, 1), 8, "hole", 4, "left"); hatch(m, 110, lvl(Y, 1), 8, "hole", 4, "right")
    # segunda planta: despachos
    for x in (45, 85):
        partition(m, x, lvl(Y, 2), door=True)
    for x, S in ((14, Y), (40, Y), (66, Y), (92, Y), (116, Y)):
        m.bulb(x + 4, S - 6, 10)
    for x in (20, 66, 110):
        m.bulb(x, lvl(Y, 1) - 6, 13); m.bulb(x, lvl(Y, 2) - 6, 13)
    for x, i in ((16, 0), (88, 0), (30, 1), (100, 1), (64, 2), (26, 2)):
        m.spawn(x, lvl(Y, i) - 1)
    m.weapon(22, Y - 1, "usp"); m.weapon(48, Y - 1, "deagle"); m.weapon(74, Y - 1, "mp7"); m.weapon(100, Y - 1, "escopeta"); m.weapon(124, Y - 1, "sniper_s")
    m.weapon(60, lvl(Y, 1) - 1, "mp7"); m.weapon(120, lvl(Y, 1) - 1, "usp")
    m.weapon(30, lvl(Y, 2) - 1, "sniper"); m.weapon(100, lvl(Y, 2) - 1, "deagle")
    m.item(46, Y - 1, "granada"); m.item(72, Y - 1, "humo"); m.item(98, Y - 1, "betty"); m.item(20, Y - 1, "claymore")
    m.item(14, lvl(Y, 1) - 1, "semtex"); m.item(80, lvl(Y, 1) - 1, "pem"); m.item(66, lvl(Y, 2) - 1, "translocator"); m.item(120, lvl(Y, 2) - 1, "tomahawk")
    m.switch(64, Y - 1)
    return m


@register
def m08_azotea():
    m = Map("Mapa08_Azotea", 150, 42, darkness=True)
    m.frame(2)
    Y = 40
    tops = [(0, 30, 30), (35, 60, 27), (65, 85, 31), (90, 118, 28), (123, 150, 25)]
    for x0, x1, t in tops:
        m.fill(x0, t, x1, Y)
    # escaleras de incendios en los callejones
    for (gx, rows) in ((30, ((36, 31, 35), (32, 30, 34), (28, 31, 35))),):
        for r, a, b in rows:
            m.oneway(a, b, r)
    m.oneway(60, 64, 36); m.oneway(61, 65, 32) if False else None
    m.oneway(60, 65, 36); m.oneway(60, 65, 32)
    m.oneway(85, 90, 36); m.oneway(85, 90, 32)
    m.oneway(118, 123, 36); m.oneway(118, 123, 32); m.oneway(118, 123, 28)
    # obstáculos en azoteas
    m.box(8, 28); m.box(44, 25); m.box(52, 25); m.box(72, 29); m.box(100, 26); m.box(108, 26); m.box(134, 23)
    m.fill(18, 28, 22, 30, "O"); m.fill(96, 26, 100, 28, "O") if False else None
    m.fill(128, 23, 132, 25, "O") if False else None
    for x, y in ((10, 29), (50, 26), (76, 30), (104, 27), (140, 24), (40, 26)):
        m.spawn(x, y)
    m.weapon(26, 29, "deagle"); m.weapon(56, 26, "sniper_s"); m.weapon(80, 30, "mp7"); m.weapon(112, 27, "sniper")
    m.weapon(144, 24, "usp"); m.weapon(62, Y - 1, "escopeta"); m.weapon(120, Y - 1, "mp7")
    m.item(15, 29, "tomahawk"); m.item(46, 26, "translocator"); m.item(76, 30, "claymore")
    m.item(94, 27, "granada"); m.item(128, 24, "humo"); m.item(88, Y - 1, "semtex"); m.item(32, Y - 1, "betty")
    for bx, by in ((20, 18), (62, 15), (96, 17), (132, 14), (76, 20), (42, 17)):
        m.bulb(bx, by, 15, 1.2, False)
    return m


@register
def m09_fabrica():
    m = Map("Mapa09_Fabrica", 200, 46, darkness=True)
    m.frame(2)
    Y = 44
    m.fill(2, 2, 198, 17)
    # máquinas
    m.fill(20, 40, 32, Y, "O"); m.fill(70, 40, 90, Y, "O"); m.fill(106, 40, 110, Y, "O"); m.fill(110, 36, 130, Y, "O")
    m.fill(160, 40, 176, Y, "O"); m.fill(94, 40, 106, Y, "O")
    # pasarelas
    m.oneway(6, 58, 37); m.oneway(142, 194, 37)
    stack(m, 60, Y); stack(m, 138, Y)
    m.oneway(30, 96, 30); m.oneway(104, 170, 30)
    stack(m, 50, 37); stack(m, 150, 37)
    m.oneway(70, 130, 23)
    stack(m, 76, 30); stack(m, 124, 30)
    for x in (44, 140, 100):
        m.box(x, Y - 2)
    for x, y in ((8, Y - 1), (50, Y - 1), (150, Y - 1), (190, Y - 1), (20, 36), (180, 36)):
        m.spawn(x, y)
    m.weapon(100, 22, "bazooka"); m.weapon(14, 36, "sniper"); m.weapon(186, 36, "sniper_s")
    m.weapon(60, 29, "deagle"); m.weapon(140, 29, "escopeta"); m.weapon(26, 39, "mp7"); m.weapon(176, Y - 1, "usp")
    m.weapon(100, 39, "mp7") if False else None
    m.item(40, 36, "granada"); m.item(160, 36, "semtex"); m.item(90, 29, "pem"); m.item(80, 22, "claymore")
    m.item(120, 22, "betty"); m.item(12, Y - 1, "humo"); m.item(188, Y - 1, "translocator"); m.item(98, 39, "tomahawk")
    for bx in range(14, 198, 16):
        m.bulb(bx, 18, 16, 1.0)
    for bx in (50, 100, 150):
        m.bulb(bx, 31, 13, 1.0)
    m.switch(100, 39)
    return m


@register
def m10_cruce():
    m = Map("Mapa10_Cruce", 100, 60, darkness=True)
    Y = 58
    m.fill(0, 0, 100, 60)
    m.hole(42, 2, 58, Y)                                   # pozo central
    for r in (54, 46, 38, 30, 22, 14):
        m.oneway(42, 50, r)
    for r in (50, 42, 34, 26, 18):
        m.oneway(50, 58, r)
    for r in (Y, 46, 30, 14):                              # salas izquierda
        m.hole(4, r - 6, 42, r)
    for r in (Y, 50, 34, 18):                              # salas derecha
        m.hole(58, r - 6, 96, r)
    m.box(14, Y - 2); m.box(84, Y - 2)
    for x, y in ((8, Y - 1), (92, Y - 1), (8, 45), (92, 49), (8, 29), (92, 33)):
        m.spawn(x, y)
    m.weapon(20, Y - 1, "mp7"); m.weapon(78, Y - 1, "usp"); m.weapon(24, 45, "deagle"); m.weapon(74, 49, "escopeta")
    m.weapon(30, 29, "sniper_s"); m.weapon(70, 33, "mp7"); m.weapon(20, 13, "sniper"); m.weapon(80, 17, "bazooka")
    m.item(30, Y - 1, "granada"); m.item(70, Y - 1, "semtex"); m.item(12, 45, "claymore"); m.item(88, 49, "humo")
    m.item(36, 29, "betty"); m.item(64, 33, "pem"); m.item(30, 13, "tomahawk"); m.item(70, 17, "translocator")
    for r in (Y, 46, 30, 14):
        m.bulb(22, r - 6, 14)
    for r in (Y, 50, 34, 18):
        m.bulb(78, r - 6, 14)
    for r in (44, 28, 12):
        m.bulb(50, r, 12, 1.0, False)
    return m


@register
def m11_faro():
    m = Map("Mapa11_FaroYTrinchera", 120, 48, darkness=True)
    m.frame(2)
    Y = 46
    L = 5
    building(m, 0, 34, Y, L)
    m.fill(2, 2, 32, Y - 7 * L)
    for i in range(L):
        S = lvl(Y, i)
        if i < L - 1:
            if i % 2 == 0:
                hatch(m, 4, S, 8, "hole", 4, "left")
            else:
                hatch(m, 22, S, 8, "hole", 4, "right")
        if i > 0:
            m.window(32, S - 5, 34, S - 2)
        m.bulb(18, S - 6, 12)
    m.hole(32, Y - 4, 34, Y + 1); m.door(32, Y - 1)
    m.fill(36, 42, 120, 46)                                  # meseta
    m.hole(70, 42, 86, 46)                                   # trinchera
    m.box(60, 40); m.box(76, 44); m.box(100, 40)
    # búnker
    m.fill(100, 35, 102, 42); m.hole(100, 37, 102, 42); m.door(100, 41)
    m.fill(100, 35, 120, 36)
    m.box(48, 40)
    for x, y in ((10, 45), (24, 38), (16, 31), (50, 41), (108, 41), (112, 41)):
        m.spawn(x, y)
    m.weapon(20, 45, "mp7"); m.weapon(10, lvl(Y, 2) - 1, "usp"); m.weapon(24, lvl(Y, 3) - 1, "deagle"); m.weapon(16, lvl(Y, 4) - 1, "sniper")
    m.weapon(40, 41, "escopeta"); m.weapon(78, 45, "mp7"); m.weapon(112, 41, "sniper_s"); m.weapon(116, 41, "bazooka")
    m.item(14, 45, "granada"); m.item(28, lvl(Y, 1) - 1, "semtex"); m.item(20, lvl(Y, 3) - 1, "pem")
    m.item(56, 41, "claymore"); m.item(90, 41, "betty"); m.item(104, 41, "humo"); m.item(80, 45, "tomahawk"); m.item(20, lvl(Y, 4) - 1, "translocator")
    for bx in (50, 90, 108):
        m.bulb(bx, 20 if bx != 108 else 36, 14, 1.0, False)
    return m


@register
def m12_laberinto():
    m = Map("Mapa12_Laberinto", 140, 40, darkness=True)
    m.frame(2)
    Y = 38
    building(m, 0, 140, Y, 3)
    fill_top(m, Y, 3)
    xs = [18, 34, 50, 66, 82, 98, 114]
    starts = [2] + [x + 2 for x in xs]
    for i in range(3):
        S = lvl(Y, i)
        for j, x in enumerate(xs):
            if (i + j) % 2 == 0:
                partition(m, x, S, door=True)
            else:
                partition(m, x, S)
    # trampillas verticales
    for i in range(2):
        S = lvl(Y, i)
        for j, a in enumerate(starts):
            if (i + j) % 3 == 0 or (i == 0 and j == 5):
                hatch(m, a + 2, S, 8, "T", 4, "left")
            elif (i + j) % 3 == 1:
                hatch(m, a + 4, S, 8, "T", 4, "right")
    for i in range(3):
        S = lvl(Y, i)
        for a in starts:
            m.bulb(a + 6, S - 6, 11)
    for x, i in ((10, 0), (60, 0), (118, 0), (28, 1), (90, 1), (130, 2)):
        m.spawn(x, lvl(Y, i) - 1)
    wl = ["mp7", "usp", "deagle", "escopeta", "sniper_s", "usp", "mp7", "deagle", "sniper", "escopeta", "usp", "mp7"]
    k = 0
    for i in range(3):
        for j in range(0, 8, 3):
            a = starts[j]
            m.weapon(a + 11, lvl(Y, i) - 1, wl[k % len(wl)]); k += 1
    il = ["granada", "humo", "claymore", "hilo", "betty", "pem", "semtex", "tomahawk", "translocator", "granada", "hilo", "pem"]
    k = 0
    for i in range(3):
        for j in range(1, 8, 3):
            a = starts[j]
            m.item(a + 10, lvl(Y, i) - 1, il[k % len(il)]); k += 1
    return m


def build_all():
    os.makedirs(PREV, exist_ok=True)
    ok = True
    for fn in MAPS:
        m = fn()
        rep, problems = m.validate()
        print(f"{m.name}: {rep}")
        for p in problems:
            print("   !", p)
            ok = False
        m.save(OUT)
        m.preview(os.path.join(PREV, m.name + ".png"))
    return ok


if __name__ == "__main__":
    sys.exit(0 if build_all() else 1)
