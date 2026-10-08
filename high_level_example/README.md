# Juego de sigilo y disparos en la oscuridad (Godot 4)

Multijugador online (hasta 8) con linternas, armas, objetos y un mapa de pruebas.
Proyecto de Godot 4.5 (se edita con 4.7.2). Un solo peer por jugador, sin juego en local.

## Cómo está organizado
- `scenes/` escenas: jugador, mapas (`Mapa*.tscn`), proyectiles, spawners, UI.
- `scripts/` un script por escena o por sistema.
- `Weapons/*.tres` armas (`WeaponData`): modo de disparo, recoil, sonido, alcance de audición…
- `Objetos/*.tres` objetos (`ItemData`): lanzables, colocables.
- `assets/` sprites (todos provisionales), sonidos de relleno y luces.

## Añadir cosas (todo desde el editor)
- **Arma nueva:** duplicar un `.tres` de `Weapons/`, cambiar valores y sprite. Para ponerla en un mapa,
  instanciar `scenes/Spawner.tscn` y arrastrar el `.tres` al campo `Weapon`.
- **Objeto nuevo:** igual con `Objetos/` y el campo `Item` del spawner. Si es un proyectil con
  trayectoria, su escena usa `thrown_projectile.gd` (modos: granada, tomahawk, semtex, humo, translocator, betty, pem, cohete).
- **Mapa nuevo:** hacerlo en FlashMapMaker y guardar el `.json` en `maps/` (aparece solo en el lobby).
  Los mapas de escena antiguos (`MapaEdificio`, `MapaPruebas`) están en el array `maps` de `Lobby.tscn`.
- **Autoloads:** `HighLevelNetworkHandler` (conexión), `GameManager` (puntos, mapa elegido), `RoundManager` (rondas, lobby), `Settings` (opciones guardadas).

## Controles
Teclado: A/D mover, Shift correr, W/Espacio saltar (mantener = apuntar arriba), S abajo,
J disparar, E coger/soltar, G objeto (mantener para cargar, soltar para lanzar).
Mando y botones táctiles equivalentes.

## Red
ENet (puerto 42069). El servidor decide impactos y explosiones; cada peer mueve su jugador.
Los objetos de red que crea el servidor deben estar en la lista del `MultiplayerSpawner` de `high_level_example.tscn`.
