# Juego de sigilo y disparos en la oscuridad (Godot 4)

Shooter 2D online para hasta 8 jugadores, estilo Duck Game pero a oscuras: cada uno lleva linterna,
se encuentran armas y objetos por el mapa y gana quien llegue primero a 5 puntos (ronda a ronda, el último vivo).
Godot 4.5 (se edita con 4.7.2). ENet, UDP **42069**. Sin juego en local.

## Estado
- **Menú principal:** crear partida, unirse por IP, opciones (volumen, pantalla completa, resolución, filtro de tele antigua).
- **Lobby:** te mueves con tu bicho, pistola de juguete (empuja, no mata), eliges color, Listo → cuenta atrás → partida.
- **Rondas:** sin nada en la mano al empezar, 3 s de margen cuando queda uno, mapa distinto cada ronda, al acabar vuelves al lobby.
- **Movimiento:** correr, sprint, agacharse, slide, backflip, salto con plataformas atravesables.
- **Armas y objetos:** 9 armas, granadas, semtex, tomahawk, humo, translocador, betty, PEM, cohete, claymore, hilo.
- **Mapas:** JSON de FlashMapMaker en `maps/`, se cargan solos (ver `DISENO.md`).
- Sprites y sonidos son provisionales.

## Controles
| Acción | Teclado y ratón | Mando |
|---|---|---|
| Moverse | A / D | stick izquierdo |
| Saltar | W / Espacio | A |
| Sprint | doble toque de dirección | stick a fondo |
| Agacharse / slide | Shift | stick izquierdo pulsado |
| Backflip | saltar dos veces seguidas | igual |
| Disparar | clic izquierdo | gatillo |
| Coger / soltar / Listo | E | RB |
| Lanzar objeto | G | B |
| Soga (mantener) | K | LT |
| Esconderse / salir | Q | Y |
| Panel de ajustes (balance) | F1 | – |

## Probar en red
1. Una instancia: **Crear partida**. Otra: IP del host (vacío = localhost) y **Unirse**.
2. En el lobby todos pulsan **Listo**. El host elige el mapa de la primera ronda.
3. Con VPN (Radmin, Hamachi...) hay que abrir el puerto 42069 UDP.

## Documentos
- `ROADMAP.md`: qué se hace y en qué orden.
- `DISENO.md`: escala, formato de mapas y sistema de rondas.
- `GAMEFEEL.md`: todos los parámetros de sensación y el registro de pruebas.
- `high_level_example/README.md`: cómo está organizado el proyecto y cómo añadir armas, objetos y mapas.
