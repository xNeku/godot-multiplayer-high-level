# Roadmap

Lo que hay que hacer, en orden. Neku prueba el game feel y hace mapas mientras se construye lo de arriba.
El sistema de rondas necesita mapas para tener sentido, así que va en paralelo con ellos.

## Hecho
- Netcode, movimiento pulido, juice, panel de ajustes (F1), escala, `MapLoader` de mapas JSON (FlashMapMaker),
  sprint / agacharse / slide / backflip (pendiente de balancear), sistema de rondas, menú principal y lobby.
- Limpieza de código muerto y assets sin uso (oct 2026).

## Ahora
1. ~~Sistema de rondas~~ (hecho; falta probarlo con gente y el −1 con 4+ jugadores).
2. **Pulido de game feel** (Neku prueba y apunta en `GAMEFEEL.md`).
3. **Mapas** (FlashMapMaker). Hacen falta unos 10-12 para que no se repitan. Hecho: `fabrica` (grande, 8 jugadores).

## Alpha jugable
4. **Menú principal** ✅: crear partida, unirse, opciones (volumen, pantalla completa, resolución; controles solo en lectura, falta reasignarlos).
5. **Lobby** ✅: se entra y se mueve el bicho, con pistola de juguete (knockback, no mata), se eligen cosméticos
   (color ✅; pecho y cara cuando haya arte) y se pulsa Listo; cuando todos están listos, cuenta atrás y empieza ✅. Pendiente: navegación con mando en la interfaz.
6. **Votación de repetición** al final de cada ronda (la repetición en sí, más tarde).

## Pendiente técnico conocido
- Navegación por mando en menú y lobby (ahora solo ratón; E / G hacen Listo y cambiar color).
- Reasignar controles en Opciones (ahora solo se muestran).
- Entrar a mitad de partida (ahora se rechaza) y pausa de recuento cada 10 rondas.
- El aviso del HUD dice "E · Coger" fijo aunque se juegue con mando.

## Después
7. **Soga** (primera versión en la rama `soga`, siempre disponible para probar; falta que sea objeto que se coge y balancearla): se consigue en un sitio del mapa y se queda toda la ronda. Colgarse, balancearse, subir y bajar despacio.
8. **Escondites**: armario, trampilla de aire, arbustos. Dentro no se te ve, pero las explosiones te matan.
9. **Explosiones que rompen terreno.**
10. **Eventos de luz**: zonas que se iluminan, te iluminas si no te mueves, etc.
11. ~~Shader de película antigua~~ (hecho: filtro de tele antigua con interferencia ocasional, se puede quitar en Opciones).

## Más tarde
- Sprites y sonidos definitivos, Steam, repeticiones y kill cam, entrar a mitad de partida, ajustes de partida.
