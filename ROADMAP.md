# Roadmap

Lo que hay que hacer, en orden. Neku prueba el game feel, dibuja y hace mapas mientras se construye lo de arriba.
Rama de trabajo actual: `bots` (main no se toca hasta que se decida mergear).

## Hecho
- **Base:** netcode (servidor decide impactos; cada uno mueve su jugador), movimiento pulido, juice, panel de ajustes (F1), escala, filtro de tele antigua.
- **Mapas:** `MapLoader` de JSON (FlashMapMaker), terreno destructible, mapas `fabrica`, `torres` y `puerto` (8 jugadores, escondites, bombillas intermitentes).
- **Juego:** rondas (último vivo +1, −1 al primero en morir con 4+, 3 s de margen, reintento si juegas solo), soga con balanceo, escondites, 9 armas y 9 objetos, retroceso que empuja.
- **Personaje:** mapache con animaciones (provisionales) y color de pecho por jugador.
- **Lobby:** pistola de juguete, colores únicos repartidos por el servidor, Listo y cuenta atrás, menú con mando.
- **Bots:** cerebro en el servidor, navegación por la rejilla del mapa, cogen armas, pelean y lanzan objetos. Entrada abstracta (`PlayerInput`) compartida con las personas.
- **Interfaz:** título FlashRacs, menú JUGAR y OPCIONES con el mismo fondo y logo, tema común (`assets/ui/tema_flash.tres`), fuente pixel con minúsculas, tildes y Ñ, HUD y pantalla de ganador.
- **Limpieza (oct 2026):** código muerto fuera, helpers comunes, menos trabajo por frame, puntos con id numérico, el color ya no viaja por red, el terreno solo se reconstruye si cambia.

## Ahora
1. **Probar con gente** las rondas completas (marcador, −1 con 4+, pantalla de ganador) y apuntar en `GAMEFEEL.md`.
2. **Arte:** sprites del mapache de perfil, armas y tiles (Neku). El código ya espera los mismos nombres y tamaños de frame.
3. **Mapas:** hacen falta unos 10-12 para que no se repitan. Hechos: `fabrica`, `torres`, `puerto`.
4. **Posición del arma por arma** (cada sprite en la mano necesita su punto de agarre).

## Alpha jugable
5. **Reasignar controles** en Opciones (ahora solo se muestran).
6. **Cosméticos del lobby:** pecho y cara cuando haya arte (el color ya está).
7. **Votación de repetición** al final de cada ronda (la repetición en sí, más tarde).

## Pendiente técnico conocido
- Bots: a veces repiten saltos en escaleras estrechas (`torres`), no usan soga ni escondites, falta dificultad elegible desde el lobby.
- El aviso de esconderse no cambia de tecla si cambias de teclado a mando estando al lado del escondite.
- Entrar a mitad de partida (ahora se rechaza) y pausa de recuento cada 10 rondas.
- `request_shoot` se fía de la posición que manda el cliente (vale entre amigos; para público habría que validarla).
- Animación de coger/soltar del mapache.
- FlashMapMaker: añadir el tipo `hide` (escondites) al editor.

## Después
- **Soga como objeto** que se coge en el mapa (ahora siempre disponible).
- **Eventos de luz:** zonas que se iluminan, te iluminas si no te mueves, etc.
- Bots que se escondan y usen la soga.

## Más tarde
- Sprites y sonidos definitivos, Steam, repeticiones y kill cam, entrar a mitad de partida, ajustes de partida.
