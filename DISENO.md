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

## Mapas (JSON de FlashMapMaker)
Los mapas se hacen en el editor web (https://xneku.github.io/FlashMapMaker/, repo `xNeku/FlashMapMaker`) y el
juego los construye al vuelo con `scripts/map_loader.gd`, sin importar nada ni abrir el editor de Godot.
- **Oficiales:** `maps/*.json` (en el repo). **Custom:** `user://maps/*.json`. Aparecen solos en el selector del lobby.
- **Importar JSON** (botón del lobby, solo host): copia el archivo a `user://maps/` y lo selecciona.
- **Multijugador:** el host manda el texto del JSON a los clientes al empezar; no necesitan tener el archivo.
- Formato: ver el README del editor. Todo en bloques (1 bloque = 11 px), esquina superior izquierda, Y hacia abajo.
- Los tiles se fusionan en rectángulos grandes al cargar (sin costuras de colisión).
- `weapon_base` sin `item`: reparto determinista entre las armas/objetos del juego (excepto la pistola inicial).
  Con `item` ("Bazooka", "Granada"...) se busca por nombre de archivo en `Weapons/` y `Objetos/`; si no existe, la base queda vacía.
- Límites (mapas de fuera): 512 KB de texto, rejilla máx. 512×512, 5000 rectángulos, 2000 entidades; lo que cae fuera de la rejilla se descarta.
- En un export hay que añadir `*.json` a los filtros de recursos no importados para que `res://maps/` viaje en el build.
- Mapas antiguos de escena que siguen: Edificio y Pruebas de armas. Los 12 mapas generados por `tools/mapgen` se han borrado
  (el generador y su validador siguen en `tools/mapgen`, ya sin uso directo).

## Sistema de rondas (diseño, **aún sin implementar**)
- Se entra y se juega; gana quien llegue primero a **11 puntos** (en la alpha: **5**, sin recuento).
- Ganar la ronda = +1 punto. Morir el primero = −1 punto, **solo con 4 jugadores o más**.
- Cada 10 rondas hay una pausa con animación que muestra el recuento.
- No se repite ningún mapa hasta agotar la lista (hace falta una variedad amplia de mapas).
- Los ajustes personalizados de partida llegan mucho más adelante.
