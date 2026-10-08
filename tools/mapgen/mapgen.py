"""Generador de mapas de bloques para el juego.

Un mapa es una cuadrícula de celdas de 11 px (medio personaje: el personaje mide 22 px = 2 celdas).
Se define en código (ver maps.py), se valida que todo es alcanzable con la física real del
jugador y se exporta a una escena .tscn editable en Godot.

Uso:  python3 tools/mapgen/maps.py          (genera todos los mapas + vistas previas PNG)
"""
import math, os

CELL = 11
CHAR_W, CHAR_H = 14, 22            # hitbox del jugador (px)

# Tipos de celda
SOLID_BODY = set("#OBV")            # bloquean el cuerpo
SOLID_BULLET = set("#OB")           # bloquean balas, luz y sonido (V no: la ventana deja pasar balas y luz)
ONEWAY = set("=T")
COLORS = {
    "#": (0.62, 0.68, 0.80),        # suelo / muro
    "O": (0.74, 0.64, 0.82),        # obstáculo
    "B": (0.90, 0.80, 0.58),        # caja
    "=": (0.96, 0.74, 0.55),        # plataforma traspasable
    "T": (0.96, 0.62, 0.72),        # trampilla (traspasable, para aberturas en suelos)
    "V": (0.65, 0.85, 0.95),        # ventana
}

WEAPONS = {"sniper": "Sniper", "sniper_s": "SniperSilenciosa", "deagle": "DesertEagle", "mp7": "Mp7",
           "usp": "Usp", "bazooka": "Bazooka", "escopeta": "Escopeta"}
ITEMS = {"granada": "Granada", "semtex": "Semtex", "tomahawk": "Tomahawk", "claymore": "Claymore",
         "humo": "Humo", "translocator": "Translocator", "betty": "Betty", "pem": "Pem", "hilo": "Hilo"}

# --- Física del salto (los mismos valores que el jugador) ---
V0, G_UP, G_DOWN, V_AIR = 440.0, 2000.0, 2000.0 * 1.3, 195.0   # V_AIR: vel. horizontal conservadora
APEX = V0 * V0 / (2 * G_UP)        # 48.4 px
MAX_RISE_CELLS = 4                 # 44 px < 48.4


class Map:
    def __init__(self, name, W, H, darkness=True, title=""):
        self.name, self.W, self.H, self.darkness, self.title = name, W, H, darkness, title or name
        self.g = [[" "] * W for _ in range(H)]
        self.boxes, self.doors, self.bulbs = [], [], []
        self.spawns, self.weapons, self.items, self.switches = [], [], [], []
        self._box_cells = set()

    # ---- dibujo ----
    def fill(self, x0, y0, x1, y1, ch="#"):
        for y in range(max(0, y0), min(self.H, y1)):
            for x in range(max(0, x0), min(self.W, x1)):
                self.g[y][x] = ch

    def hole(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, " ")

    def frame(self, t=2):
        """Muro exterior (cerrado) de grosor t."""
        self.fill(0, 0, self.W, t); self.fill(0, self.H - t, self.W, self.H)
        self.fill(0, 0, t, self.H); self.fill(self.W - t, 0, self.W, self.H)

    def slab(self, x0, x1, y, t=1, ch="#"):
        self.fill(x0, y, x1, y + t, ch)

    def oneway(self, x0, x1, y, ch="="):
        self.fill(x0, y, x1, y + 1, ch)

    def box(self, x, y):
        """Caja 2x2 con la base apoyada en la fila y-1 (x,y = esquina superior izquierda)."""
        self.fill(x, y, x + 2, y + 2, "B"); self.boxes.append((x, y))

    def window(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, "V")

    def door(self, x, y_feet):
        """Puerta de 2 de ancho y 5 de alto; y_feet = fila de los pies (el suelo está en y_feet+1)."""
        self.hole(x, y_feet - 4, x + 2, y_feet + 1)
        self.doors.append((x, y_feet))

    def bulb(self, x, y, radius=14, energy=1.1, flicker=True):
        self.bulbs.append((x, y, radius, energy, flicker))

    def spawn(self, x, y_feet): self.spawns.append((x, y_feet))
    def weapon(self, x, y_feet, key): self.weapons.append((x, y_feet, key))
    def item(self, x, y_feet, key): self.items.append((x, y_feet, key))
    def switch(self, x, y_feet): self.switches.append((x, y_feet))

    # ---- consulta ----
    def at(self, x, y):
        if x < 0 or y < 0 or x >= self.W or y >= self.H:
            return "#"
        return self.g[y][x]

    def body_free(self, x, y):
        return self.at(x, y) not in SOLID_BODY

    def stand_ok(self, x, y):
        """¿Puede un jugador estar de pie con los pies en la celda (x,y)?"""
        if not (self.body_free(x, y) and self.body_free(x, y - 1)):
            return False
        sup = self.at(x, y + 1)
        if sup not in SOLID_BODY and sup not in ONEWAY:
            return False
        # el cuerpo mide 14 px: hace falta al menos 2 celdas de ancho libres
        side = (self.body_free(x + 1, y) and self.body_free(x + 1, y - 1)) or \
               (self.body_free(x - 1, y) and self.body_free(x - 1, y - 1))
        return side

    # ---- validador ----
    def _arc_ok(self, x0, y0, x1, y1):
        """Salto de (x0,y0) a (x1,y1) (celdas de pies). Devuelve True si es posible y no choca."""
        h = y0 - y1                       # >0 = el destino está más alto
        if h > MAX_RISE_CELLS:
            return False
        hp = h * CELL
        t_up = V0 / G_UP
        drop = APEX - hp
        if drop < 0:
            return False
        T = t_up + math.sqrt(2 * drop / G_DOWN)
        dx_px = (x1 - x0) * CELL
        if abs(dx_px) > V_AIR * T:
            return False
        vx = dx_px / T
        fx0 = (x0 + 0.5) * CELL
        fy0 = (y0 + 1) * CELL - 0.01
        n = 24
        for i in range(n + 1):
            t = T * i / n
            if t <= t_up:
                y = V0 * t - 0.5 * G_UP * t * t
            else:
                td = t - t_up
                y = APEX - 0.5 * G_DOWN * td * td
            cx = fx0 + vx * t
            feet = fy0 - y
            if i == n:
                break
            # caja del cuerpo
            for cxp in (cx - 5.0, cx + 5.0):   # el jugador puede desplazarse 1-2 px dentro de su celda
                for cyp in (feet - CHAR_H + 0.5, feet - CHAR_H / 2, feet - 0.5):
                    if self.at(int(cxp // CELL), int(cyp // CELL)) in SOLID_BODY:
                        return False
        return True

    def _arc_sim(self, x0, y0, x1, y1):
        """Simula el salto con choque de cabeza contra techos (la velocidad vertical se anula)."""
        h = y0 - y1
        if h > MAX_RISE_CELLS:
            return False
        dx_px = (x1 - x0) * CELL
        sgn = 1 if dx_px >= 0 else -1
        target_feet = (y1 + 1) * CELL
        cx1 = (x1 + 0.5) * CELL
        dt = 1 / 120
        for frac in (0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 1.0):
            vx = sgn * V_AIR * frac
            x = (x0 + 0.5) * CELL
            y = (y0 + 1) * CELL - 0.01
            vy = -V0
            ok = False
            for _ in range(240):
                vy += (G_UP if vy < 0 else G_DOWN) * dt
                nx = x + vx * dt
                ny = y + vy * dt
                # choque lateral
                blocked = False
                for px in (nx - 5.0, nx + 5.0):
                    for py in (y - 0.5, y - 11.0, y - 21.5):
                        if self.at(int(px // CELL), int(py // CELL)) in SOLID_BODY:
                            blocked = True
                if blocked:
                    break
                if vy < 0:
                    for px in (nx - 5.0, nx + 5.0):
                        if self.at(int(px // CELL), int((ny - CHAR_H) // CELL)) in SOLID_BODY:
                            ny = (int((ny - CHAR_H) // CELL) + 1) * CELL + CHAR_H + 0.01
                            vy = 0.0
                            break
                if vy > 0 and ny >= target_feet and y < target_feet + 0.001:
                    ok = abs(nx - cx1) <= 5.5
                    break
                x, y = nx, ny
            if ok:
                return True
        return False

    def _fall_from(self, col, y_start):
        """Cae por la columna col desde la fila y_start (pies). Devuelve la fila de aterrizaje o None."""
        y = y_start
        while y < self.H - 1:
            if not (self.body_free(col, y) and self.body_free(col, y - 1)):
                return None
            sup = self.at(col, y + 1)
            if sup in SOLID_BODY or sup in ONEWAY:
                return y if self.stand_ok(col, y) else None
            y += 1
        return None

    def neighbors(self, node):
        x, y = node
        out = []
        for d in (-1, 1):
            nx = x + d
            if self.stand_ok(nx, y):
                out.append((nx, y))
            # salir de un borde y caer
            if self.body_free(nx, y) and self.body_free(nx, y - 1) and self.at(nx, y + 1) not in SOLID_BODY | ONEWAY:
                for k in range(1, 4):
                    col = x + d * k
                    if not (self.body_free(col, y) and self.body_free(col, y - 1)):
                        break
                    land = self._fall_from(col, y + 1)
                    if land is not None:
                        out.append((col, land))
        # atravesar una plataforma traspasable hacia abajo
        if self.at(x, y + 1) in ONEWAY:
            for off in (0, -1, 1):
                land = self._fall_from(x + off, y + 2)
                if land is not None:
                    out.append((x + off, land))
        # saltos
        for dx in range(-9, 10):
            if dx == 0:
                continue
            for dy in range(-MAX_RISE_CELLS, 9):
                tx, ty = x + dx, y - dy
                if self.stand_ok(tx, ty) and (self._arc_ok(x, y, tx, ty) or self._arc_sim(x, y, tx, ty)):
                    out.append((tx, ty))
        # saltar recto hacia arriba (por un hueco)
        for dy in range(1, MAX_RISE_CELLS + 1):
            if self.stand_ok(x, y - dy) and (self._arc_ok(x, y, x, y - dy) or self._arc_sim(x, y, x, y - dy)):
                out.append((x, y - dy))
        return out

    def standing_cells(self):
        return {(x, y) for y in range(self.H) for x in range(self.W) if self.stand_ok(x, y)}

    def validate(self):
        """Devuelve (informe, lista de problemas)."""
        problems = []
        if not self.spawns:
            return "sin spawns", ["no hay puntos de aparición"]
        start = tuple(self.spawns[0])
        if not self.stand_ok(*start):
            problems.append(f"spawn {start} no es una posición válida")
        seen = {start}
        todo = [start]
        while todo:
            n = todo.pop()
            for m in self.neighbors(n):
                if m not in seen:
                    seen.add(m)
                    todo.append(m)
        targets = [("spawn", s) for s in self.spawns] + \
                  [(f"arma {k}", (x, y)) for x, y, k in self.weapons] + \
                  [(f"objeto {k}", (x, y)) for x, y, k in self.items] + \
                  [("interruptor", s) for s in self.switches] + \
                  [("puerta", (x, y)) for x, y in self.doors]
        for label, c in targets:
            c = tuple(c)
            if label == "puerta":
                ok = any((x2, y) in seen for x2 in (c[0] - 1, c[0], c[0] + 1, c[0] + 2)
                         for y in (c[1],))
            else:
                if not self.stand_ok(*c):
                    problems.append(f"{label} en {c}: posición no válida (sin suelo o sin espacio)")
                    continue
                ok = c in seen
            if not ok:
                problems.append(f"{label} en {c}: NO alcanzable desde el primer spawn")
        stand = self.standing_cells()
        orphan = len(stand) - len(stand & seen)
        rep = f"{self.W}x{self.H} celdas ({self.W*CELL}x{self.H*CELL} px), {len(seen)} posiciones alcanzables, {orphan} no alcanzables"
        return rep, problems

    # ---- exportación ----
    def rects(self, chars):
        """Rectángulos fusionados de las celdas de los tipos dados."""
        runs = {}
        out = []
        active = {}
        for y in range(self.H + 1):
            row = []
            if y < self.H:
                x = 0
                while x < self.W:
                    if self.g[y][x] in chars and (x, y) not in self._box_cells:
                        x0 = x
                        while x < self.W and self.g[y][x] in chars and (x, y) not in self._box_cells and self.g[y][x] == self.g[y][x0]:
                            x += 1
                        row.append((x0, x, self.g[y][x0]))
                    else:
                        x += 1
            new_active = {}
            for (x0, x1, ch) in row:
                key = (x0, x1, ch)
                if key in active:
                    new_active[key] = active[key]
                else:
                    new_active[key] = y
            for key, ys in active.items():
                if key not in new_active:
                    out.append((key[0], ys, key[1], y, key[2]))
            active = new_active
        return out

    def to_tscn(self):
        self._box_cells = set()
        for (bx, by) in self.boxes:
            for yy in range(by, by + 2):
                for xx in range(bx, bx + 2):
                    self._box_cells.add((xx, yy))
        ext, sub, nodes = [], {}, []
        ext_ids = {}

        def ext_res(kind, path):
            if path not in ext_ids:
                ext_ids[path] = f"{len(ext_ids)+1}_{kind[:3].lower()}"
                ext.append(f'[ext_resource type="{kind}" path="{path}" id="{ext_ids[path]}"]')
            return ext_ids[path]

        def rect_shape(w, h):
            k = f"Rect_{w:g}x{h:g}"
            if k not in sub:
                sub[k] = f'[sub_resource type="RectangleShape2D" id="{k}"]\nsize = Vector2({w:g}, {h:g})'
            return k

        def occluder(w, h):
            k = f"Occ_{w:g}x{h:g}"
            if k not in sub:
                hw, hh = w / 2, h / 2
                sub[k] = (f'[sub_resource type="OccluderPolygon2D" id="{k}"]\n'
                          f'polygon = PackedVector2Array({-hw:g}, {-hh:g}, {hw:g}, {-hh:g}, {hw:g}, {hh:g}, {-hw:g}, {hh:g})')
            return k

        def col(c, a=1.0):
            return f"Color({c[0]:g}, {c[1]:g}, {c[2]:g}, {a:g})"

        sid = ext_res("Script", "res://high_level_example/scripts/map_settings.gd")
        gid = ext_res("Script", "res://high_level_example/scripts/grid_background.gd")
        W, H = self.W * CELL, self.H * CELL
        nodes.append(f'[node name="{self.name}" type="Node2D"]\nscript = ExtResource("{sid}")\n'
                     f'with_darkness = {"true" if self.darkness else "false"}\nshow_city_background = false\n'
                     f'camera_limits = Rect2(0, 0, {W}, {H})\n')
        nodes.append(f'[node name="Fondo" type="Node2D" parent="."]\nz_index = -10\nscript = ExtResource("{gid}")\n'
                     f'area = Rect2(0, 0, {W}, {H})\nbase_color = Color(0.2, 0.22, 0.27, 1)\n'
                     f'minor_step = 22.0\nmajor_step = 110.0\nruler_y = {H + 40}.0\n')

        # Estructura sólida (suelo, obstáculos)
        nodes.append('[node name="Estructura" type="Node2D" parent="."]\n')
        for i, (x0, y0, x1, y1, ch) in enumerate(self.rects(set("#O"))):
            w, h = (x1 - x0) * CELL, (y1 - y0) * CELL
            cx, cy = x0 * CELL + w / 2, y0 * CELL + h / 2
            nm = ("Suelo" if ch == "#" else "Obstaculo") + str(i)
            nodes.append(f'[node name="{nm}" type="StaticBody2D" parent="Estructura"]\nposition = Vector2({cx:g}, {cy:g})\ncollision_layer = 1\ncollision_mask = 0\n')
            nodes.append(f'[node name="ColorRect" type="ColorRect" parent="Estructura/{nm}"]\noffset_left = {-w/2:g}\noffset_top = {-h/2:g}\noffset_right = {w/2:g}\noffset_bottom = {h/2:g}\ncolor = {col(COLORS[ch])}\n')
            nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Estructura/{nm}"]\nshape = SubResource("{rect_shape(w, h)}")\n')
            nodes.append(f'[node name="LightOccluder2D" type="LightOccluder2D" parent="Estructura/{nm}"]\noccluder = SubResource("{occluder(w, h)}")\n')
        # Cajas
        if self.boxes:
            nodes.append('[node name="Cajas" type="Node2D" parent="."]\n')
        for i, (bx, by) in enumerate(self.boxes):
            w = h = 2 * CELL
            cx, cy = bx * CELL + w / 2, by * CELL + h / 2
            nm = f"Caja{i}"
            nodes.append(f'[node name="{nm}" type="StaticBody2D" parent="Cajas"]\nposition = Vector2({cx:g}, {cy:g})\ncollision_layer = 1\ncollision_mask = 0\n')
            nodes.append(f'[node name="ColorRect" type="ColorRect" parent="Cajas/{nm}"]\noffset_left = {-w/2:g}\noffset_top = {-h/2:g}\noffset_right = {w/2:g}\noffset_bottom = {h/2:g}\ncolor = {col(COLORS["B"])}\n')
            nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Cajas/{nm}"]\nshape = SubResource("{rect_shape(w, h)}")\n')
            nodes.append(f'[node name="LightOccluder2D" type="LightOccluder2D" parent="Cajas/{nm}"]\noccluder = SubResource("{occluder(w, h)}")\n')
        # Plataformas traspasables y trampillas (capa 4 = valor 8)
        nodes.append('[node name="Plataformas" type="Node2D" parent="."]\n')
        thick = 6
        for i, (x0, y0, x1, y1, ch) in enumerate(self.rects(set("=T"))):
            for j, yy in enumerate(range(y0, y1)):
                w = (x1 - x0) * CELL
                cx, cy = x0 * CELL + w / 2, yy * CELL + thick / 2
                nm = ("Plataforma" if ch == "=" else "Trampilla") + f"{i}_{j}"
                nodes.append(f'[node name="{nm}" type="StaticBody2D" parent="Plataformas"]\nposition = Vector2({cx:g}, {cy:g})\ncollision_layer = 8\ncollision_mask = 0\n')
                nodes.append(f'[node name="ColorRect" type="ColorRect" parent="Plataformas/{nm}"]\noffset_left = {-w/2:g}\noffset_top = {-thick/2:g}\noffset_right = {w/2:g}\noffset_bottom = {thick/2:g}\ncolor = {col(COLORS[ch])}\n')
                nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Plataformas/{nm}"]\none_way_collision = true\nshape = SubResource("{rect_shape(w, thick)}")\n')
        # Ventanas: bloquean el cuerpo (capa 4, sin one-way) pero no balas ni luz
        wr = self.rects(set("V"))
        if wr:
            nodes.append('[node name="Ventanas" type="Node2D" parent="."]\n')
        for i, (x0, y0, x1, y1, ch) in enumerate(wr):
            w, h = (x1 - x0) * CELL, (y1 - y0) * CELL
            cx, cy = x0 * CELL + w / 2, y0 * CELL + h / 2
            nm = f"Ventana{i}"
            nodes.append(f'[node name="{nm}" type="StaticBody2D" parent="Ventanas"]\nposition = Vector2({cx:g}, {cy:g})\ncollision_layer = 8\ncollision_mask = 0\n')
            nodes.append(f'[node name="ColorRect" type="ColorRect" parent="Ventanas/{nm}"]\noffset_left = {-w/2:g}\noffset_top = {-h/2:g}\noffset_right = {w/2:g}\noffset_bottom = {h/2:g}\ncolor = {col(COLORS["V"], 0.55)}\n')
            nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Ventanas/{nm}"]\nshape = SubResource("{rect_shape(w, h)}")\n')
        # Puertas
        if self.doors:
            pid = ext_res("PackedScene", "res://high_level_example/scenes/Puerta.tscn")
            nodes.append('[node name="Puertas" type="Node2D" parent="."]\n')
            for i, (x, yf) in enumerate(self.doors):
                cx, cy = (x + 1) * CELL, (yf + 1) * CELL - 27.5
                nodes.append(f'[node name="Puerta{i}" parent="Puertas" instance=ExtResource("{pid}")]\nposition = Vector2({cx:g}, {cy:g})\nscale = Vector2({22/30:g}, {55/59:g})\n')
        # Bombillas
        if self.bulbs:
            tid = ext_res("Texture2D", "res://high_level_example/assets/lights/2d_lights_and_shadows_neutral_point_light.webp")
            fid = ext_res("Script", "res://high_level_example/scripts/light_flicker.gd")
            nodes.append('[node name="Bombillas" type="Node2D" parent="."]\n')
            for i, (x, y, r, e, fl) in enumerate(self.bulbs):
                px, py = x * CELL + CELL / 2, y * CELL
                nodes.append(f'[node name="Bombilla{i}" type="Node2D" parent="Bombillas"]\nposition = Vector2({px:g}, {py:g})\n')
                nodes.append(f'[node name="Cable" type="ColorRect" parent="Bombillas/Bombilla{i}"]\noffset_left = -1.0\noffset_right = 1.0\noffset_bottom = 8.0\ncolor = Color(0.05, 0.05, 0.05, 1)\n')
                nodes.append(f'[node name="Foco" type="ColorRect" parent="Bombillas/Bombilla{i}"]\nz_index = 2\noffset_left = -3.0\noffset_top = 7.0\noffset_right = 3.0\noffset_bottom = 13.0\ncolor = Color(1, 0.9, 0.6, 1)\n')
                script = f'script = ExtResource("{fid}")\n' if fl else ""
                nodes.append(f'[node name="Luz" type="PointLight2D" parent="Bombillas/Bombilla{i}"]\nposition = Vector2(0, 11)\ncolor = Color(1, 0.82, 0.5, 1)\nenergy = {e:g}\nshadow_enabled = true\ntexture = ExtResource("{tid}")\ntexture_scale = {r*CELL*2/256:g}\n{script}')
        # Interruptores
        if self.switches:
            iid = ext_res("PackedScene", "res://high_level_example/scenes/Interruptor.tscn")
            for i, (x, yf) in enumerate(self.switches):
                nodes.append(f'[node name="Interruptor{i}" parent="." instance=ExtResource("{iid}")]\nposition = Vector2({x*CELL+CELL/2:g}, {(yf+1)*CELL-12.6:g})\nscale = Vector2(0.7, 0.7)\n')
        # Spawns de jugadores
        nodes.append('[node name="SpawnPoints" type="Node2D" parent="."]\n')
        for i, (x, yf) in enumerate(self.spawns):
            nodes.append(f'[node name="Spawn{i+1}" type="Marker2D" parent="SpawnPoints" groups=["spawn_points"]]\nposition = Vector2({x*CELL+CELL/2:g}, {(yf+1)*CELL-14:g})\n')
        # Armas y objetos
        if self.weapons or self.items:
            spid = ext_res("PackedScene", "res://high_level_example/scenes/Spawner.tscn")
            nodes.append('[node name="Armas" type="Node2D" parent="."]\n')
            for i, (x, yf, k) in enumerate(self.weapons):
                rid = ext_res("Resource", f"res://high_level_example/Weapons/{WEAPONS[k]}.tres")
                nodes.append(f'[node name="Spawner{WEAPONS[k]}{i}" parent="Armas" instance=ExtResource("{spid}")]\nposition = Vector2({x*CELL+CELL/2:g}, {(yf+1)*CELL-4:g})\nweapon = ExtResource("{rid}")\n')
            nodes.append('[node name="Objetos" type="Node2D" parent="."]\n')
            for i, (x, yf, k) in enumerate(self.items):
                rid = ext_res("Resource", f"res://high_level_example/Objetos/{ITEMS[k]}.tres")
                nodes.append(f'[node name="Spawner{ITEMS[k]}{i}" parent="Objetos" instance=ExtResource("{spid}")]\nposition = Vector2({x*CELL+CELL/2:g}, {(yf+1)*CELL-4:g})\nitem = ExtResource("{rid}")\n')

        head = f'[gd_scene load_steps={1+len(ext)+len(sub)} format=3]\n'
        return head + "\n" + "\n".join(ext) + "\n\n" + "\n\n".join(sub.values()) + "\n\n" + "\n".join(nodes)

    def dump(self, x0=0, y0=0, x1=None, y1=None):
        x1 = x1 or self.W; y1 = y1 or self.H
        ents = {}
        for (x, y) in self.spawns: ents[(x, y)] = "S"
        for (x, y, k) in self.weapons: ents[(x, y)] = "w"
        for (x, y, k) in self.items: ents[(x, y)] = "i"
        for (x, y) in self.switches: ents[(x, y)] = "I"
        for (x, y) in self.doors:
            for yy in range(y - 4, y + 1):
                for xx in (x, x + 1): ents.setdefault((xx, yy), "D")
        print("     " + "".join(str((x // 10) % 10) if x % 10 == 0 else " " for x in range(x0, x1)))
        for y in range(y0, y1):
            print(f"{y:3d}  " + "".join(ents.get((x, y), self.g[y][x] if self.g[y][x] != " " else ".") for x in range(x0, x1)))

    def preview(self, path, k=5):
        from PIL import Image, ImageDraw
        im = Image.new("RGB", (self.W * k, self.H * k), (40, 44, 54))
        d = ImageDraw.Draw(im)
        for y in range(self.H):
            for x in range(self.W):
                ch = self.g[y][x]
                if ch in COLORS:
                    c = tuple(int(v * 255) for v in COLORS[ch])
                    if ch in ONEWAY:
                        d.rectangle([x * k, y * k, x * k + k - 1, y * k + k // 2 - 1], fill=c)
                    else:
                        d.rectangle([x * k, y * k, x * k + k - 1, y * k + k - 1], fill=c)
        for (x, yf) in self.doors:
            d.rectangle([x * k, (yf - 4) * k, (x + 2) * k - 1, (yf + 1) * k - 1], outline=(150, 100, 50), fill=(110, 70, 30))
        for (x, y, r, e, fl) in self.bulbs:
            d.ellipse([x * k - 2, y * k + 2, x * k + 4, y * k + 8], fill=(255, 235, 120))
        for (x, yf) in self.spawns:
            d.rectangle([x * k, (yf - 1) * k, x * k + k, (yf + 1) * k], fill=(90, 220, 120))
        for (x, yf, key) in self.weapons:
            d.rectangle([x * k - 1, (yf - 1) * k, x * k + k + 1, (yf + 1) * k], fill=(240, 80, 80))
        for (x, yf, key) in self.items:
            d.rectangle([x * k - 1, (yf - 1) * k, x * k + k + 1, (yf + 1) * k], fill=(240, 160, 40))
        for (x, yf) in self.switches:
            d.rectangle([x * k, (yf - 2) * k, x * k + k, (yf + 1) * k], fill=(255, 255, 255))
        im.save(path)

    def save(self, folder):
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, self.name + ".tscn"), "w") as f:
            f.write(self.to_tscn())
