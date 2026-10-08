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
| `jump_velocity` | -440 | Impulso del salto (negativo = arriba). Altura ≈ 48-52 px = 2,2-2,4 personajes | |
| `gravity` | 2000 | Gravedad al subir | |
| `fall_gravity_mult` | 1.3 | Gravedad extra al caer (menos flotante) | |
| `jump_cut` | 0.45 | Al soltar salto subiendo, velocidad vertical × esto. Menor = salto corto más corto | |
| `coyote_time` | 0.1 | Margen para saltar tras salir de un borde | |
| `jump_buffer_time` | 0.12 | Salto pulsado justo antes de aterrizar se ejecuta al tocar suelo | |
| `drop_through_time` | 0.25 | Duración de caer a través de una plataforma (abajo + salto) | |

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
| `hit_stop_time` | 0.07 | Congelado al matar o morir | |
| `corpse_force` | 380 | Fuerza con la que sale volando el cadáver | |
| `life_time` (cadáver) | 4.0 | Cuánto dura el cadáver (`scripts/corpse.gd`) | |
| `entry_time` (kill feed) | 4.0 | Cuánto dura cada línea (`scripts/kill_feed.gd`) | |
| Explosiones | máx. 18 | Sacudida según cercanía (`scripts/explosion_fx.gd`) | |
| Polvo al aterrizar | – | Partículas en `_land_fx` (cantidad según velocidad de caída) | |

Notas juice:
-

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
| Puntos para ganar | 10 | `hit()` en el script del jugador | |
| Duración vida de bala | 10 | `scripts/bullet.gd` | |

---

## Registro de pruebas
Una línea por sesión de prueba: fecha, quién, dispositivo/mando, qué se probó y qué se cambió.

| Fecha | Quién | Setup | Qué se probó | Cambios / conclusiones |
|---|---|---|---|---|
| | | | | |

## Ideas y problemas sueltos
-
