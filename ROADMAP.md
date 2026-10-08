# Roadmap

Lo que hay que hacer, en orden. Neku prueba el game feel y hace mapas mientras se construye lo de arriba.
El sistema de rondas necesita mapas para tener sentido, así que va en paralelo con ellos.

## Hecho
- Netcode, movimiento pulido, juice, panel de ajustes (F1), escala, `MapLoader` de mapas JSON (FlashMapMaker),
  sprint / agacharse / slide / backflip (pendiente de balancear).

## Ahora
1. ~~Sistema de rondas~~ (hecho en versión mínima, ver `DISENO.md`; falta probar con gente y el −1 con 4+ jugadores).
2. **Pulido de game feel** (Neku prueba y apunta en `GAMEFEEL.md`).
3. **Mapas** (FlashMapMaker). Hacen falta unos 10-12 para que no se repitan.

## Alpha jugable
4. **Menú principal**: crear partida, unirse, opciones (resolución, sonido, controles...).
5. **Lobby**: se entra y se mueve el bicho, con pistola de juguete (knockback, no mata), se eligen cosméticos
   (color, pecho, cara) y se pulsa Listo; cuando todos están listos, cuenta atrás y empieza.
6. **Votación de repetición** al final de cada ronda (la repetición en sí, más tarde).

## Después
7. **Soga**: se consigue en un sitio del mapa y se queda toda la ronda. Colgarse, balancearse, subir y bajar despacio.
8. **Escondites**: armario, trampilla de aire, arbustos. Dentro no se te ve, pero las explosiones te matan.
9. **Explosiones que rompen terreno.**
10. **Eventos de luz**: zonas que se iluminan, te iluminas si no te mueves, etc.
11. **Shader de película antigua** (ruido, interferencias).

## Más tarde
- Sprites y sonidos definitivos, Steam, repeticiones y kill cam, entrar a mitad de partida, ajustes de partida.
