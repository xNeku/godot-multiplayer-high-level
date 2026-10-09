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
- **Oficiales:** `maps/*.json` (en el repo). **Custom:** `user://maps/*.json`. Aparecen solos en el selector del lobby (solo lo ve el host).
- **Importar JSON** (botón del lobby, solo host): copia el archivo a `user://maps/` y lo selecciona.
- **Multijugador:** el host manda el texto del JSON a los clientes al empezar; no necesitan tener el archivo.
- Formato: ver el README del editor. Todo en bloques (1 bloque = 11 px), esquina superior izquierda, Y hacia abajo.
- Los tiles se fusionan en rectángulos grandes al cargar (sin costuras de colisión).
- `weapon_base` sin `item`: reparto determinista entre las armas/objetos del juego (excepto la pistola inicial).
  Con `item` ("Bazooka", "Granada"...) se busca por nombre de archivo en `Weapons/` y `Objetos/`; si no existe, la base queda vacía.
- Límites (mapas de fuera): 512 KB de texto, rejilla máx. 512×512, 5000 rectángulos, 2000 entidades; lo que cae fuera de la rejilla se descarta.
- En un export hay que añadir `*.json` a los filtros de recursos no importados para que `res://maps/` viaje en el build.
- Mapas antiguos de escena que siguen: Edificio y Pruebas de armas. Los mapas generados a mano con script se borraron
  y el generador (`tools/mapgen`) se eliminó: el editor web lo sustituye.

## Mapa "fabrica" (`maps/fabrica.json`, 150 × 48 bloques)
Hecho por script y comprobado (todas las bases y spawns alcanzables desde cualquier spawn con salto de 4 bloques).
- **Patio oeste:** andamio de plataformas hasta una caseta y la ventana de la 2ª planta. Sniper silenciosa arriba del andamio, translocador en la caseta, pistola en el suelo.
- **Edificio (4 niveles):** nave abierta en planta baja con vigas y cajas (Usp, granada); sótano bajo trampillas (bazooka en el centro, claymore e hilo en las bajadas); 1ª planta con tres despachos y puertas (escopeta, betty, pistola); 2ª planta con pasillo, entreplanta (Mp7, humo) y cámara acorazada tras puerta (Desert Eagle).
- **Azotea:** caseta de ascensor, depósito de agua con PEM arriba, semtex. Pasarela hacia el este.
- **Este:** cobertizo (tomahawk en el tejado), patio hundido (escopeta) y torre de francotirador (sniper arriba, a la vista de todos).
- Luz: solo 6 bombillas intermitentes (2 s cada 40 s, desfasadas): nave, sótano, despacho central, pasillo, caseta de la azotea y torre. El resto del mapa a oscuras.
- Escaleras: rellano de plataforma a 4 bloques + trampilla atravesable en el forjado. 8 spawns repartidos por zonas.

## Mapa "torres" (`maps/torres.json`, 160 × ~45)
Dos torres simétricas de 3 plantas (10 bloques de alto cada una, escaleras de rellanos a 3 y 6 bloques + trampilla) unidas
por un **puente-plataforma** entre azoteas. Troneras y balcón mirando al centro para dispararse de torre a torre.
Debajo del puente, escalones flotantes hasta una isla central con **Bazooka** y, encima, **Escopeta**; Desert Eagle en una
trinchera en el centro del suelo. Francotiradores en la 2ª planta de cada torre (normal a la izquierda, silenciosa a la derecha).
Escondites: armario en cada 1ª planta, rejilla en cada planta baja, arbustos fuera. 4 bombillas intermitentes.

## Mapa "puerto" (`maps/puerto.json`, 170 × ~41)
Almacén de dos plantas altas (oeste), patio de contenedores escalonados, grúa con brazo sobre el mar (sniper silenciosa y
translocador), mar con salida por plataforma (PEM en el fondo) y barco: cubierta (Desert Eagle), bodega bajo escotilla
(Bazooka), puente de mando (Betty, armario) y mástil con cofa (Sniper). 6 escondites, 4 bombillas intermitentes.
`fabrica` también tiene ahora 6 escondites (armarios en despachos, rejillas en sótano y 2ª planta, arbustos fuera).

## Aspecto de los mapas JSON (provisional hasta tener tiles dibujados)
`shaders/tiles.gdshader`: muros de ladrillo, losas de hormigón (piezas anchas), plataformas de tablón con escuadras,
cajas de madera, pared de ladrillo al fondo en los interiores (casillas con techo y suelo cerca) y cielo con estrellas fuera.
Las bombillas tienen pantalla, halo y sombras suaves. Los mapas de escena antiguos (Edificio, Pruebas) siguen con colores planos.

## Escondites (implementado: `scenes/Escondite.tscn`, `scripts/hide_spot.gd`)
- Tipos: **armario** (2×4 bloques), **rejilla** de ventilación (2×2) y **arbusto** (3×2). Dibujo provisional hecho a código.
- Te acercas y aparece encima un aviso sutil "**Q** · Esconderse" (**Y** con mando). La misma tecla te saca (sin aviso).
- Dentro: no te mueves, no disparas, tu linterna se apaga; los demás no te ven y **las balas no te dan**, pero **las explosiones sí** (capa de física 6 "Escondidos").
- Uno por escondite (lo decide el servidor). Al entrar o salir el escondite se menea y suena: delata a quien mire.
- En el JSON: `{"type": "hide", "kind": "armario" | "rejilla" | "arbusto", "x", "y"}` (esquina superior izquierda, en bloques). Hay que añadirlo a FlashMapMaker.

## Sistema de rondas (implementado: `scripts/round_manager.gd`)
Flujo de una ronda:
1. Apareces **sin nada en la mano**, solo con la linterna.
2. Hay armas y objetos repartidos por el mapa: los coges y a jugar.
3. Cuando queda un solo jugador vivo, acaba la ronda. El superviviente gana **+1 punto**.
4. Voto rápido: ¿saltarse la repetición de la última kill? (la repetición solo se ve si la mayoría no la salta)
5. Siguiente ronda, otro mapa, de nuevo sin nada en la mano.

Reglas:
- Gana quien llegue primero a **11 puntos** (en la alpha: **5**, sin recuento).
- Morir el primero = −1 punto, **solo con 4 jugadores o más**.
- Cada 10 rondas hay una pausa con animación que muestra el recuento.
- No se repite ningún mapa hasta agotar la lista (hace falta una variedad amplia de mapas).
- Los ajustes personalizados de partida llegan mucho más adelante.
- Objetivo: partidas pulidas y rápidas.

Decidido:
- Sin límite de tiempo.
- Cuando queda uno vivo la ronda no acaba al instante: hay **3 s** de margen. Si el último muere dentro de ese margen, o mueren dos a la vez, nadie suma.
- Las kills ya no dan puntos: solo se puntúa ganando la ronda.
- La muerte es definitiva hasta la siguiente ronda (no hay reaparición). Con un solo jugador (pruebas) la ronda nunca acaba.
- Cada ronda recarga la escena de juego y el servidor manda el JSON del mapa nuevo. La primera ronda se elige en el lobby ("Aleatorio" o un mapa); las siguientes son aleatorias sin repetir hasta agotar la lista.
- Parámetros en `round_manager.gd`: `POINTS_TO_WIN` (5), `END_GRACE` (3 s), `BETWEEN_TIME` (3 s), `PENALTY_MIN_PLAYERS` (4).
- Sin hacer: votación de saltar la repetición (la repetición aún no existe), pausa de recuento cada 10 rondas, entrar a mitad de partida.

Ver `ROADMAP.md` para el orden de trabajo.

## Lobby (implementado: `scenes/Lobby.tscn`, `scripts/lobby.gd`)
- Al crear o unirse se entra al lobby (mapa `lobby/lobby.json`, sin oscuridad). Los jugadores se mueven y llevan la **pistola de juguete** (empuja, no mata).
- Color elegido (8 colores, se guarda en `user://opciones.cfg`) y replicado; pecho y cara quedan para cuando haya arte.
- **Listo** lo gestiona el servidor. Con todos listos y todos ya spawneados: cuenta atrás de 3 s y `RoundManager.start_match`. Si alguien cancela, se aborta.
- Durante una partida no se puede entrar (se rechaza la conexión). Al terminar la partida, todos vuelven al lobby.
