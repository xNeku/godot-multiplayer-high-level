# FlashRacs: sigilo y disparos a oscuras (Godot 4)

Shooter 2D online para hasta 8 jugadores (personas o bots), estilo Duck Game pero a oscuras: cada uno lleva
linterna, se encuentran armas y objetos por el mapa y gana quien llegue primero a 5 puntos (ronda a ronda, el último vivo).
Godot 4.5 (se edita con 4.7.2). ENet, UDP **42069**. Sin juego en local.

## Estado
- **Título FlashRacs:** letras con ola de luz, JUGAR / OPCIONES / SALIR. Todos los menús y el HUD comparten el mismo estilo (fuente pixel, gris → verde visión nocturna).
- **Menú JUGAR:** crear partida, unirse por IP (se recuerda la última). **Opciones:** volumen, pantalla completa, ventana, filtro de tele antigua, lista de controles.
- **Lobby:** te mueves con tu mapache, pistola de juguete (empuja, no mata), color único por jugador, bots (solo host), Listo → cuenta atrás → partida.
- **Rondas:** apareces sin nada, coges armas del mapa, el último vivo suma +1, mapa distinto cada ronda, pantalla de ganador y vuelta al lobby.
- **Movimiento:** sprint, agacharse, slide, backflip, plataformas atravesables, soga con balanceo.
- **Sigilo:** linterna, sonidos con alcance, escondites (armario, rejilla, arbusto), bombillas intermitentes.
- **Armas y objetos:** 9 armas, granada, semtex, tomahawk, humo, translocador, betty, PEM, claymore, hilo. Las explosiones rompen el terreno.
- **Bots:** se mueven por el mapa, cogen armas, se encaran y disparan. Funcionan en red como un jugador más.
- **Mapas:** JSON de FlashMapMaker en `maps/` (`fabrica`, `torres`, `puerto`...), se cargan solos.
- Sprites y sonidos son provisionales (el mapache es el personaje candidato).

## Controles
| Acción | Teclado | Mando |
|---|---|---|
| Moverse | A / D | stick izquierdo |
| Saltar (mantener = apuntar arriba) | W / Espacio | A |
| Sprint | doble toque de dirección | stick a fondo |
| Agacharse / slide | Shift | LB |
| Backflip | saltar dos veces seguidas | igual |
| Disparar | J | X / RT |
| Coger / soltar / Listo | E | RB |
| Lanzar objeto (mantener para cargar) | G | B |
| Soga (mantener) | K | LT |
| Esconderse / salir | Q | Y |
| Menú del lobby | Esc | Start |
| Panel de ajustes (balance) | F1 | – |

Sin ratón: se apunta recto hacia donde miras y el arma sube mientras mantienes salto (o pegado a una pared).
Con mando los menús se navegan con cruceta/stick, A acepta y B vuelve.

## Probar en red
1. Una instancia: JUGAR → **Crear partida**. Otra: IP del host (vacío = este ordenador) y **Unirse**.
2. En el lobby el host puede añadir bots y elegir el mapa de la primera ronda. Todos pulsan **Listo**.
3. Con VPN (Radmin, Hamachi...) hay que abrir el puerto 42069 UDP.

## Actualizar el proyecto
```
git checkout project.godot
```
```
git pull
```
(Godot reescribe `project.godot` al abrirlo; el primer comando descarta esos cambios.)

## Documentos
- `ROADMAP.md`: qué está hecho, qué falta y en qué orden.
- `DISENO.md`: escala, mapas, rondas, bots, escondites, lobby e interfaz.
- `GAMEFEEL.md`: todos los parámetros de sensación y el registro de pruebas.
- `high_level_example/README.md`: cómo está organizado el código, la red y cómo añadir armas, objetos y mapas.
