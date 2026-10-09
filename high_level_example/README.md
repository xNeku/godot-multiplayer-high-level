# FlashRacs: cómo está organizado el proyecto

Godot 4.5 (se edita con 4.7.2). Multijugador online hasta 8 (personas + bots), un peer por persona, sin juego en local.

## Carpetas
- `scenes/` escenas: título y menús, lobby, partida, jugador, proyectiles, spawners, HUD, mapas de escena antiguos.
- `scripts/` un script por escena o por sistema (lista abajo).
- `Weapons/*.tres` armas (`WeaponData`): modo de disparo, retroceso, munición, sonido, efectos.
- `Objetos/*.tres` objetos (`ItemData`): lanzables y colocables.
- `assets/` sprites (provisionales), sonidos de relleno, luces, `ui/` (tema, fuentes, letras del título).
- `shaders/` `tiles.gdshader` (aspecto de los mapas JSON) y `tv_antigua.gdshader` (filtro).
- `lobby/lobby.json` mapa del lobby. Los mapas de partida están en `../maps/`.

## Flujo de escenas
`TitleMenu` → `Menu` (crear / unirse / opciones) → `Lobby` → `high_level_example` (una carga por ronda) → `Lobby`.
Si se cae la conexión se vuelve al título (`HighLevelNetworkHandler.leave()` limpia el estado).

## Autoloads (en este orden)
| Nombre | Script | Qué hace |
|---|---|---|
| `HighLevelNetworkHandler` | `high_level_network_handler.gd` | Crea servidor o cliente ENet (puerto 42069), `leave()` para salir |
| `GameManager` | `GameManager.gd` | Puntos, colores únicos, bots, spawns, `player_node(id)`, nombres para mostrar |
| `RoundManager` | `round_manager.gd` | Rondas, mapa de cada ronda, banners, fin de partida |
| `Settings` | `settings.gd` | Opciones guardadas (volumen, ventana, color, filtro, última IP) y nombres de teclas |
| `Fx` | `fx.gd` | Efectos locales: fogonazos, impactos, explosiones, polvo, sangre, casquillos |
| `PostFX` | `scenes/PostFX.tscn` | Filtro de tele antigua por encima de todo |

## Scripts por sistema
- **Jugador:** `high_level_network_player.gd` (movimiento, soga, escondites, disparo, objetos, muerte; todas las RPC del jugador),
  `player_input.gd` (entrada de teclado/mando o virtual para bots), `raccoon_visual.gd` (animaciones), `corpse.gd`.
- **Bots:** `bot_brain.gd` (decide qué teclas pulsa, solo en el servidor), `bot_nav.gd` (grafo de caminos del mapa JSON).
- **Armas y objetos:** `WeaponData.gd`, `ItemData.gd`, `bullet.gd`, `tracer.gd`, `casing.gd`, `thrown_projectile.gd`
  (granada, tomahawk, semtex, humo, translocador, betty, PEM, cohete), `claymore.gd`, `tripwire.gd`, `dropped_weapon.gd`, `weapon_spawner.gd`.
- **Mapas:** `map_loader.gd` (JSON → nodos, `carve()` para romper terreno), `map_settings.gd`, `hide_spot.gd`, `door.gd`,
  `light_pulse.gd`, `light_flicker.gd`, `light_switch.gd`, `glow_follow.gd`, `grid_background.gd`.
- **Partida y HUD:** `high_level_example.gd`, `high_level_player_spawner.gd`, `round_hud.gd`, `score_label.gd`, `inventory_hud.gd`,
  `kill_feed.gd`, `game_over_ui.gd`, `explosion_fx.gd`.
- **Menús:** `title_menu.gd`, `title_logo.gd`, `menu.gd`, `lobby.gd`, `ui_juice.gd` (botones con vida y botón A del mando), `tuning_panel.gd` (F1).
- **Pruebas:** `target_dummy.gd`, `walking_dummy.gd`, `impact_marker.gd` (mapa `MapaPruebas`).

## Red
- **Autoridad:** cada persona mueve su jugador (el nombre del nodo es su id de red). Los bots (ids 100-199) los mueve el servidor.
- **Lo que viaja** (`MultiplayerSynchronizer` del jugador, 60/s): posición siempre; postura, giro del cuerpo, mano y soga solo al cambiar.
  El color no viaja: lo reparte el servidor en `GameManager.colors` y cada peer lo lee.
- **El servidor decide:** impactos, muertes, recoger y soltar, lanzar, esconderse, puntos y rondas. Los clientes piden por RPC
  (`request_*`) y el servidor responde a todos. Las RPC que solo puede mandar el servidor comprueban `_from_server()`.
- **Balas:** las crea el servidor y cada cliente las simula solo. El tirador cliente ve un trazador inmediato (`tracer.gd`).
- **Efectos:** todo es local (`Fx`); el servidor avisa con `Fx.impact.rpc` y `Fx.explosion_rpc.rpc`.
- Los objetos de red que crea el servidor tienen que estar en la lista del `MultiplayerSpawner` de la escena (partida y lobby).

## Añadir cosas (desde el editor)
- **Arma:** duplicar un `.tres` de `Weapons/`, cambiar valores y sprite. Aparece sola en las bases de arma de los mapas JSON
  (o se pone con `"item": "NombreDelArchivo"`). En mapas de escena, instanciar `scenes/Spawner.tscn` y asignar el `.tres`.
- **Objeto:** igual con `Objetos/`. Si es un proyectil, su escena usa `thrown_projectile.gd` y su modo.
- **Mapa:** hacerlo en FlashMapMaker y guardar el `.json` en `../maps/` (aparece solo en el lobby). Formato y escala en `../DISENO.md`.
- **Texto de interfaz:** poner `theme = assets/ui/tema_flash.tres` en el Control raíz (o en el Label si cuelga de un CanvasLayer)
  y elegir variación (`LabelMini`, `LabelTitulo`, `LabelAviso`). Escribir normal: la fuente lo pasa a mayúsculas.

## Pruebas
Se prueban con Godot sin ventana y scripts de prueba que se cargan como autoload temporal (no están en el repo):
crean partida, añaden bots, conectan un cliente y comprueban rondas, escondites, explosiones y la interfaz con capturas.
