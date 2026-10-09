# Game feel: parámetros y notas

Documento vivo. Aquí van **todos los parámetros que afectan al tacto del juego** y vuestras anotaciones.
Se edita directamente en el repo (`git pull` / `git push`), o desde GitHub.

**Cómo anotar:** escribe en la columna *Notas* de cada fila (o en el bloque de notas de cada sección) con tu inicial y la fecha: `N 07/10: se siente flotante`. Si cambias un valor, apunta el valor nuevo y por qué.

**Dónde se cambian:**
- En el juego, en vivo: **F1** (o el botón ⚙ arriba al centro). Sliders para jugador y arma actual. **Guardar** lo deja en tu `user://ajustes.cfg` (solo tu máquina). Restablecer vuelve a los valores por defecto.
- Fijo, para todos: en el inspector de Godot (el script / `.tres` indicado) y commit. Cuando un valor probado en el panel guste, hay que pasarlo aquí y a su archivo.

Valores = los actuales en el repo (rama `escala-y-mapas`: escala nueva, cámara zoom 0,85 ≈ 19 personajes de alto; alcances de sonido ×1,75). Unidades: px, segundos, grados, px/s.

---

## 1. Movimiento del jugador
`scripts/high_level_network_player.gd` (grupo *Movimiento*)

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `walk_speed` | 120 | Velocidad andando | |
| `run_speed` | 230 | Velocidad corriendo | |
| `acceleration` | 1400 | Qué rápido llega a la velocidad objetivo | |
| `friction` | 1400 | Qué rápido frena al soltar | |
| `jump_velocity` | -380 | Impulso del salto (negativo = arriba). Antes -440 | |
| `gravity` | 1450 | Gravedad al subir. Antes 2000 | |
| `fall_gravity_mult` | 1.3 | Gravedad extra al caer (menos flotante) | |
| `apex_threshold` | 60 | Por debajo de esta velocidad vertical se considera "pico del salto" | Nuevo |
| `apex_gravity_mult` | 0.5 | Gravedad en el pico con el salto mantenido (instante de flote para apuntar) | Nuevo |
| `max_fall_speed` | 380 | Velocidad máxima de caída (antes sin límite) | Nuevo |
| `fast_fall_speed` | 500 | Máxima manteniendo abajo | Nuevo |
| `air_control` | 0.65 | Aceleración y frenado en el aire respecto al suelo | Nuevo |
| `over_speed_decel` | 600 | Frenado si vas por encima de tu velocidad en la misma dirección (conserva impulso de slide, backflip, soga, empujones) | Nuevo |
| `jump_h_boost` | 40 | Empujón horizontal al saltar en movimiento | Nuevo |
| `jump_cut` | 0.45 | Al soltar salto subiendo, velocidad vertical × esto. Menor = salto corto más corto | |
| `coyote_time` | 0.1 | Margen para saltar tras salir de un borde | |
| `jump_buffer_time` | 0.12 | Salto pulsado justo antes de aterrizar se ejecuta al tocar suelo | |
| `drop_through_time` | 0.25 | Duración de caer a través de una plataforma (abajo + salto) | |

**Ajuste del 9-oct-2026 (referencia Celeste escalada).** Celeste tiene publicado el código de su jugador
(personaje de 11 px; gravedad 900, caída máx. 160, salto 105, control aéreo 0,65, gravedad a la mitad en el pico
con el salto mantenido, coyote 0,1 s). Nuestro personaje mide 22 px, así que distancias y velocidades ×2 con los
mismos tiempos. Medido en headless (lobby):

| Medida | Antes | Ahora | Celeste escalado |
|---|---|---|---|
| Salto mantenido | 48 px, pico 0,22 s, aire ~0,41 s | 54 px (2,5 personajes), pico 0,32 s, aire 0,60 s | ~50 px, pico ~0,3 s, aire ~0,6 s |
| Salto corto (toque) | – | 30 px, aire 0,37 s | |
| Andar: llega a tope / frena | 0,09 s / 0,09 s | 0,10 s / 0,10 s (4 px) | 0,09 s |
| Caída de 171 px | sin tope | 0,57 s, tope 380 px/s | tope 320 |

Si lo notas flotante: sube `gravity` y `jump_velocity` a la vez (mantén la altura), o baja `apex_threshold`.
Si lo notas pesado en el aire: sube `air_control`.

Notas movimiento:
-

### 1b. Sprint, agacharse, slide y backflip
Grupo *Sprint / Agacharse / Slide / Backflip* del mismo script. Todo editable en el panel F1.

Controles: **sprint** = doble toque rápido de dirección (teclado) o stick a fondo (mando) · **agacharse** = Shift (LB en mando; mantener) · **slide** = Shift estando en sprint · **backflip** = pulsar salto dos veces seguidas.

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `double_tap_time` | 0.25 | Ventana (s) entre los dos toques de dirección para el sprint | |
| `pad_sprint_threshold` | 0.9 | Inclinación del stick (0-1) que cuenta como "a fondo" | |
| `crouch_speed` | 55 | Velocidad agachado (sin ruido de pasos) | |
| `crouch_height` | 15 | Altura de la hitbox agachado (normal 22) | |
| `slide_speed` | 330 | Velocidad al empezar el slide | |
| `slide_min_speed` | 150 | Velocidad mínima para que Shift haga slide en vez de agacharse | |
| `slide_friction` | 450 | Frenado del slide (≈110 px de recorrido) | |
| `slide_exit_speed` | 60 | Por debajo de esto, pulsar dirección te saca del slide | |
| `slide_height` | 14 | Altura de la hitbox en slide (mínimo posible = 14) | |
| `backflip_window` | 0.22 | Tiempo tras empezar un salto en el que una 2ª pulsación lo convierte en backflip | |
| `backflip_height` | 72 | Altura total del backflip desde el despegue (px; salto normal ≈ 52) | |
| `backflip_speed` | 140 | Velocidad hacia atrás | |
| `backflip_time` | 0.5 | Duración de la voltereta (debería coincidir con el tiempo en el aire) | |
| `backflip_air_control` | 0.25 | Control horizontal durante el backflip (× aceleración) | |

Notas sprint/slide/backflip:
- El backflip no añade latencia al salto: el salto arranca normal y, si llega la 2ª pulsación dentro de la ventana, se transforma (todavía a pocos px del suelo).
- En slide el arma baja con el cuerpo. Te quedas tumbado hasta que vuelves a pulsar dirección (con la velocidad ya baja) o saltas.
- En backflip el arma va pegada al cuerpo y gira con él.

### 1c. Soga (siempre disponible por ahora)
`scripts/high_level_network_player.gd` (grupo *Soga*). Botón: **K** (teclado) / **LT** (mando), **mantener**.
- Apunta igual que el arma: sale recta hacia delante y sube mientras mantienes salto (hasta vertical). Pegado a una pared mirándola, apunta arriba.
- Engancha suelo, paredes, techos (capa 1) y **plataformas atravesables** (capa 4). Si no hay nada a tiro, destello corto y espera `rope_miss_cooldown`.
- Colgado: A/D empuja en la dirección del arco; la gravedad hace el péndulo. Empujar a favor del movimiento acumula velocidad (de 0 a ~520 px/s en ~3 s).
- Arriba acorta y abajo alarga. Acortar balanceándote **acelera** (se conserva el momento angular, como bombear en un columpio).
- Soltar el botón: sales con la velocidad del balanceo × `rope_release_boost`. En el aire esa inercia se conserva (frena con `over_speed_decel` × `air_control`).
- Tu soga se ve siempre; la de los demás solo si la ilumina una luz. No rodea esquinas: si algo se cruza, te suelta.

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `rope_range` | 170 | Alcance del enganche (px) | |
| `rope_climb_speed` | 70 | Subir / bajar por la soga | |
| `rope_min_length` | 24 | Largo mínimo | |
| `rope_swing_accel` | 420 | Empuje en el arco | |
| `rope_max_speed` | 520 | Velocidad máxima balanceando | |
| `rope_release_boost` | 1.1 | Multiplicador de velocidad al soltarte | |
| `rope_miss_cooldown` | 0.3 | Espera tras fallar | |

Notas de prueba de la soga:
-

## 2. Puntería y retroceso del jugador
`scripts/high_level_network_player.gd` (grupo *Puntería*)

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `aim_up_at_wall` | true | Apunta arriba al estar pegado a una pared mirándola | |
| `aim_up_max_deg` | 90 | Máximo de elevación del arma | |
| `aim_rotation_speed_deg` | 360 | Velocidad a la que sube/baja el arma. Menos = diagonales más fáciles | |
| `interact_range` | 36 | Alcance para coger (E) | |
| `arc_preview_time` | 0.45 | Cuánto del arco de lanzamiento se dibuja | |

Notas puntería:
-

## 3. Armas
`Weapons/*.tres` (recurso `WeaponData`). Los campos sin valor propio usan el defecto: `bullet_speed` 2000, `spread` 0, `recoil_max_deg` 30, `recoil_pause` 0.4, `recoil_recovery_deg_per_sec` 60, `hearing_range` 1400.

Modo: AUTO = mantener, SEMI = un disparo por pulsación, BOLT = cerrojo.

| Arma | Modo | `fire_rate` (s) | Munición | `bullet_speed` | `spread` ° | Balas | Retroceso/disparo ° | Máx ° | Pausa (s) | Recuperación °/s | Silenciada | Alcance sonido | Notas |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Pistola (inicial) | SEMI | 0.4 | ∞ | 2000 | 0 | 1 | 3 | 15 | 0.5 | 60 | no | 1400 | |
| Escopeta | SEMI | 0.8 | 8 | 2000 | 10 | 3 | 10 | 25 | 1.0 | 60 | no | 2450 | |
| Sniper | BOLT | 1.5 | 5 | 3000 | 0 | 1 | 0 | – | – | – | no | 3850 | |
| Sniper silenciosa | BOLT | 1.6 | 5 | 4000 | 0 | 1 | 0 | – | – | – | sí | 610 | |
| Desert Eagle | SEMI | 0.35 | 7 | 2400 | 0 | 1 | 14 | 50 | 0.7 | 50 | no | 2620 | |
| MP7 | AUTO | 0.07 | 40 | 2000 | 2 | 1 | 5 | 70 | 0.2 | 70 | sí | 520 | |
| USP | AUTO | 0.14 | 20 | 2000 | 1 | 1 | 1.2 | 20 | 0.3 | 60 | sí | 380 | |
| Bazooka | SEMI | 1.0 | 1 | 900 | 0 | 1 | 0 | – | – | – | no | 3500 | gravedad proyectil 500 |

Notas armas (por arma, cómo se siente el retroceso, ritmo, alcance del sonido...):
-

## 4. Objetos lanzables
`Objetos/*.tres` (recurso `ItemData`) y escenas `*.tscn` (`ThrownProjectile`). Defecto de lanzamiento: `min_speed` 300, `max_speed` 800, `charge_time` 0.8, `lob_deg` 12, `gravity` 1400.

| Objeto | Cómo se usa | Diferencias respecto al defecto | Notas |
|---|---|---|---|
| Granada | Lanzar (carga) | rebota, explota por tiempo | |
| Semtex | Lanzar | se pega | |
| Tomahawk | Lanzar | `max_speed` 900, `lob_deg` 8, rebota 2 veces | |
| Humo | Lanzar | pendiente: que reviente al primer impacto | |
| Translocator | Lanzar | te teletransporta | |
| Bouncy Betty | Lanzar | `max_speed` 700 | |
| Pem | Lanzar | apaga luces/puertas/linternas | |
| Claymore | Se coloca en el suelo | `place_only` | |
| Hilo decapitador | Se coloca en puerta | `place_only` + `place_in_door` | |

Parámetros del proyectil (`scripts/thrown_projectile.gd`, ajustables por escena):

| Parámetro | Valor defecto | Qué hace | Notas |
|---|---|---|---|
| `bounce_damping` | 0.55 | Energía que conserva al rebotar | |
| `max_bounces` | 99 | Rebotes máximos | |
| `fuse_time` | 2.5 | Tiempo hasta explotar | |
| `explosion_radius` | 70 | Radio de la explosión | |
| `spin_deg` | 600 | Giro en vuelo | |
| `arm_time` (Betty) | 1.0 | Tiempo hasta armarse | |
| `trigger_radius` (Betty) | 26 | Radio de activación | |
| `pop_height` (Betty) | 40 | Altura del salto antes de explotar | |
| `emp_radius` (Pem) | 260 | Radio del pulso | |
| `emp_duration` (Pem) | 6.0 | Duración del apagón | |

Notas objetos:
-

## 5. Juice (feedback)
`scripts/high_level_network_player.gd` (grupo *Juice*) y otros.

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `shake_per_shot` | 2.0 | Sacudida de cámara al disparar (se suma según retroceso del arma) | |
| `shake_on_death` | 14 | Sacudida al morir | |
| `shake_decay` | 40 | Velocidad a la que se apaga la sacudida | |
| `shake_roll_deg` | 1.2 | Giro de cámara con la sacudida máxima | Nuevo: la sacudida usa ruido suave + giro |
| `shake_frequency` | 28 | Rapidez del temblor | Nuevo |
| `hit_stop_time` | 0.07 | Congelado al matar o morir | |
| `corpse_force` | 380 | Fuerza con la que sale volando el cadáver | |
| `life_time` (cadáver) | 4.0 | Cuánto dura el cadáver (`scripts/corpse.gd`) | |
| `entry_time` (kill feed) | 4.0 | Cuánto dura cada línea (`scripts/kill_feed.gd`) | |
| Explosiones | 18 cerca → 4 lejos | La sienten **todos** los jugadores del mapa; baja con la distancia (`scripts/explosion_fx.gd`). PEM: 6 → 1,5 | |
| Aplastamiento al aterrizar | 0.28 | `land_squash` en `scripts/player_visual.gd`, según velocidad de caída | Nuevo |
| Polvo en el aire | 28 partículas | Nodo `Polvo` del jugador: motas que solo se ven donde da la luz | Nuevo |
| Polvo al aterrizar | – | Partículas en `_land_fx` (cantidad según velocidad de caída) | |

Notas juice:
-

## 5b. Filtro de tele antigua (`scenes/PostFX.tscn`, `shaders/tv_antigua.gdshader`)
Autoload por encima de todo (juego y HUD). Se quita en Opciones → "Filtro de tele antigua".
Parámetros en el material de `PostFX.tscn` (inspector): brillo alrededor de luces (`bloom_*`), aberración 0,6 px,
grano 0,045, líneas 0,06, viñeta 0,45, desaturación 0,12, parpadeo 0,012, tinte cálido.
Interferencia: franja que baja en 1,4 s cada 12-30 s (`post_fx.gd`), desplaza filas 2 px y aclara 0,09.

## 6. Sonido
Todos los sonidos son **placeholders generados**. En un juego de sigilo el sonido es clave, así que aquí van las distancias.

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `step_distance` | 34 | Píxeles recorridos entre pasos | |
| `step_range_walk` | 660 | Alcance del paso andando | |
| `step_range_run` | 1200 | Alcance del paso corriendo (y aterrizaje) | |
| Salto | alcance = `step_range_walk` | | |
| Muerte | alcance = `step_range_run` + 200 | | |
| `hearing_range` por arma | ver sección 3 | Silenciadas se oyen a corta distancia | |

Notas sonido (qué falta, qué suena mal, qué no se oye a la distancia justa):
-

## 7. Red (sensación online)
`scripts/high_level_network_player.gd` (grupo *Red*)

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `remote_smoothing` | 30 | Suavizado de los otros jugadores. Más = más pegado a la posición recibida, menos = más suave pero con retraso visual | |
| `remote_snap_distance` | 120 | Si la copia remota se desvía más, salta directa | |
| Disparo propio | – | Sonido, fogonazo y trazador al instante; la bala real llega del servidor | |
| Autoridad de disparo | – | El cliente solo manda posición y ángulo; velocidad, dispersión y nº de balas salen del arma que tiene el servidor | Evita trampas y duplicados |

Notas red (latencia, tirones, cosas que no cuadran entre jugadores):
-

## 8. Animación del personaje
`scripts/player_visual.gd`. Los sprites son temporales; el formato (piezas Chest/Face/Feet/Hands) se mantiene.

| Parámetro | Valor | Qué hace | Notas |
|---|---|---|---|
| `base_scale` | 0.6 | Tamaño del personaje | |
| `step_length` | 26 | Largo del paso en la animación | |
| `foot_swing` | 6 | Balanceo de los pies | |
| `foot_lift` | 4 | Altura del pie al andar | |
| `hand_swing` | 5 | Balanceo de la mano libre | |
| `walk_bob` | 1.5 | Rebote del torso al andar | |
| `air_foot_lift` | 4 | Pies recogidos en el aire | |
| `air_hand_lift` | 5 | Mano libre en el aire | |
| `air_stretch` | 0.12 | Estiramiento del cuerpo en el aire | |
| `breath_speed` | 2.2 | Velocidad de respiración en reposo | |
| `breath_amount` | 0.025 | Amplitud de respiración | |

Notas animación:
-

## 9. Otros
| Parámetro | Valor | Dónde | Notas |
|---|---|---|---|
| `respawn_time` de armas | 5.0 | `scripts/weapon_spawner.gd` | |
| Puntos para ganar | 5 | `POINTS_TO_WIN` en `scripts/round_manager.gd` | Ver `DISENO.md` |
| Pistola de juguete (lobby) | knockback 280 | `scenes/BalaJuguete.tscn` (`knockback`) y `Weapons/PistolaJuguete.tres` | Empuja, no mata. Impulso horizontal + salto pequeño (-90) |
| Duración vida de bala | 10 | `scripts/bullet.gd` | |

---

## Registro de pruebas
Una línea por sesión de prueba: fecha, quién, dispositivo/mando, qué se probó y qué se cambió.

| Fecha | Quién | Setup | Qué se probó | Cambios / conclusiones |
|---|---|---|---|---|
| | | | | |

## Ideas y problemas sueltos
-
