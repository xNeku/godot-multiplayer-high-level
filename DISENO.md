# Diseño: escala, mapas y rondas

## Escala (todo se mide en "personajes")
- Personaje: hitbox **14 × 22 px** (capsule). Celda de mapa: **11 px** (medio personaje alto).
- Cámara: zoom 0,85 → se ven unos **753 × 424 px** = ~19 personajes de alto, ~34 de ancho.
- Salto: sube **~2,2-2,4 personajes** (48-52 px). Peldaño máximo para subir: **4 celdas (44 px)**.
- Distancia de salto en llano: ~4-5 celdas andando, ~7-8 corriendo.
- Salas: **6 celdas libres de alto** (3 personajes). Separación entre suelos: **7 celdas** (el suelo ocupa 1).
- Pasos mínimos: **2 celdas de ancho** (el personaje mide 1,3). Puertas: **2 × 5 celdas**. Cajas: **2 × 2**.
- Subir una planta: hueco en el suelo de arriba con un **peldaño a 4 celdas** debajo (o pila de 2 cajas).
- Cámara y mapa: el mapa mide como mínimo 69 × 39 celdas para que la cámara nunca vea el vacío.

## Colores de los mapas de bloques
Suelo / muro = azul pastel · Plataforma traspasable = naranja · Trampilla (traspasable, para huecos de suelo) = rosa ·
Obstáculo = lila · Caja = amarillo · Ventana = celeste (bloquea cuerpos, deja pasar balas y luz) · Puerta = marrón.
Verde = spawn de jugador · Rojo = arma · Naranja = objeto · Amarillo = bombilla.

## Mapas (generados con `tools/mapgen`)
Cada mapa se define en `tools/mapgen/maps.py`, se valida con la física real del salto (todo spawn, arma y objeto
tiene que ser alcanzable) y se exporta a `high_level_example/scenes/mapas/*.tscn` (editables en Godot).
Para regenerar: `python3 tools/mapgen/maps.py` (necesita Pillow para las vistas previas). Ojo: regenerar
**sobrescribe** los `.tscn`; si editas un mapa a mano en Godot y quieres conservarlo, cámbiale el nombre.

| # | Mapa | Estilo | Tamaño | Luz |
|---|---|---|---|---|
| 01 | Cuadrilátero | Pequeño y rápido, todos a rushear (2-4) | 72×42 | encendida |
| 02 | Almacén | Nave grande con pasarelas, cajas, dos salas laterales | 110×40 | oscuro |
| 03 | Torre | Vertical, 9 plantas, escaleras alternas | 72×67 | oscuro |
| 04 | Dos edificios | Dos torres, patio y zigurat central con la recompensa | 170×44 | oscuro |
| 05 | Pasillos | Sigilo: 3 plantas de pasillos con puertas, armas silenciosas, hilos | 150×40 | oscuro |
| 06 | Cueva | Montaña central, ascenso en diagonal a la cumbre, estalactitas | 100×46 | oscuro |
| 07 | Oficina | Cubículos de cristal abajo, pasillo con puertas, despachos | 130×40 | oscuro |
| 08 | Azoteas | Saltos entre tejados, escaleras de incendios en los callejones | 150×42 | oscuro |
| 09 | Fábrica | Grande y lento: máquinas, 3 niveles de pasarelas | 200×46 | oscuro |
| 10 | Cruce | Pozo central en zigzag y salas a ambos lados en 4 niveles | 100×60 | oscuro |
| 11 | Faro y trinchera | Torre de francotirador vs meseta con trinchera y búnker | 120×48 | oscuro |
| 12 | Laberinto | Habitaciones pequeñas, puertas y trampillas entre plantas | 140×40 | oscuro |

Armas y objetos: cada mapa lleva su propio reparto (los que uses en un mapa fijan su ritmo: p. ej. 05 es de silenciadas,
04 y 09 tienen bazooka en el centro/arriba, 03 reparte un arma por planta).

## Sistema de rondas (diseño, **aún sin implementar**)
- Se entra y se juega; gana quien llegue primero a **11 puntos** (en la alpha: **5**, sin recuento).
- Ganar la ronda = +1 punto. Morir el primero = −1 punto, **solo con 4 jugadores o más**.
- Cada 10 rondas hay una pausa con animación que muestra el recuento.
- No se repite ningún mapa hasta agotar la lista (hace falta una variedad amplia de mapas).
- Los ajustes personalizados de partida llegan mucho más adelante.
