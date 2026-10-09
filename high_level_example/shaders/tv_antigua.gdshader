shader_type canvas_item;
// Post-proceso de "tele antigua" suave: brillo alrededor de las luces, aberración
// de color leve, grano, líneas de barrido casi invisibles, viñeta, parpadeo mínimo
// y, de vez en cuando, una franja de interferencia que baja por la pantalla
// (la mueve post_fx.gd con sweep_pos).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

group_uniforms Brillo;
uniform float bloom_strength : hint_range(0.0, 1.5) = 0.35;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float bloom_radius : hint_range(0.5, 6.0) = 2.5; // en píxeles de juego

group_uniforms Tele;
uniform float aberration : hint_range(0.0, 3.0) = 0.6; // píxeles
uniform float grain : hint_range(0.0, 0.3) = 0.045;
uniform float scanline : hint_range(0.0, 0.5) = 0.06;
uniform float vignette : hint_range(0.0, 1.5) = 0.45;
uniform float desaturate : hint_range(0.0, 1.0) = 0.12;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;
uniform vec3 tint = vec3(1.0, 0.98, 0.94); // un pelín cálido

group_uniforms Interferencia;
uniform float sweep_pos = -1.0; // 0 arriba, 1 abajo; < 0 = apagada
uniform float sweep_width : hint_range(0.002, 0.1) = 0.02;
uniform float sweep_shift : hint_range(0.0, 6.0) = 2.0; // desplazamiento lateral (px)
uniform float sweep_bright : hint_range(0.0, 0.3) = 0.09;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 bright(vec2 uv) {
	vec3 c = texture(screen_tex, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(bloom_threshold, 1.0, l);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	// Franja de interferencia: desplaza las filas que toca y las aclara un poco
	float band = 0.0;
	if (sweep_pos >= 0.0) {
		float d = (uv.y - sweep_pos) / sweep_width;
		band = exp(-d * d);
		float row = floor(uv.y / px.y);
		uv.x += (hash(vec2(row, floor(TIME * 50.0))) - 0.5) * 2.0 * sweep_shift * px.x * band;
	}

	// Aberración cromática horizontal (más fuerte dentro de la franja)
	float ab = aberration * px.x * (1.0 + band * 2.0);
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;

	// Brillo (bloom barato): media de 12 muestras de las zonas claras alrededor
	if (bloom_strength > 0.0) {
		vec3 glow = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236; // 30 grados
			float r = bloom_radius * (1.0 + float(i % 2));
			glow += bright(uv + vec2(cos(a), sin(a)) * r * px);
		}
		col += glow / 12.0 * bloom_strength;
	}

	// Color: algo menos saturado y cálido
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate) * tint;

	// Líneas de barrido (una fila sí, otra no), muy suaves
	float sl = 0.5 + 0.5 * cos(SCREEN_UV.y / px.y * 3.14159);
	col *= 1.0 - scanline * sl;

	// Grano animado
	float n = hash(SCREEN_UV * vec2(1931.0, 1171.0) + fract(TIME * 7.0) * vec2(17.0, 31.0));
	col += (n - 0.5) * grain;

	col += band * sweep_bright;

	// Parpadeo de brillo casi imperceptible
	col *= 1.0 + (hash(vec2(floor(TIME * 20.0), 3.7)) - 0.5) * flicker;

	// Viñeta
	vec2 c = SCREEN_UV - 0.5;
	col *= clamp(1.0 - dot(c, c) * vignette * 1.6, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
