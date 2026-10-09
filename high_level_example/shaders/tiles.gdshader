shader_type canvas_item;
// Aspecto procedural de las piezas del mapa (provisional hasta tener tiles dibujados).
// Todo va en píxeles de mundo, así los ladrillos casan entre piezas vecinas.
// style: 0 muro de ladrillo, 1 losa de hormigón, 2 plataforma de madera,
//        3 caja de madera, 4 pared del fondo, 5 cielo

uniform int style = 0;
uniform vec2 rect_size = vec2(11.0, 11.0);
uniform vec3 base_color : source_color = vec3(0.42, 0.40, 0.42);
uniform float seed = 0.0;

varying vec2 world;
varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Borde superior iluminado y bordes laterales/inferior oscuros: da volumen
vec3 bevel(vec3 c, vec2 lp, vec2 sz) {
	if (lp.y < 1.0) return c * 1.45;
	if (lp.y < 2.0) return c * 1.2;
	if (lp.y > sz.y - 1.0) return c * 0.55;
	if (lp.x < 1.0 || lp.x > sz.x - 1.0) return c * 0.75;
	return c;
}

void fragment() {
	vec2 p = floor(world);
	vec2 lp = floor(local);
	vec3 c = base_color;
	float a = 1.0;

	if (style == 0) {
		// Ladrillos 10x5 con mortero de 1 px, filas alternas desplazadas
		float row = floor(p.y / 5.0);
		float x = p.x + mod(row, 2.0) * 5.0;
		vec2 brick = vec2(floor(x / 10.0), row);
		bool mortar = mod(p.y, 5.0) < 1.0 || mod(x, 10.0) < 1.0;
		c *= 0.88 + hash(brick + seed) * 0.24;
		c = mix(c, vec3(c.r * 1.05, c.g * 0.92, c.b * 0.88), hash(brick * 1.7)); // algunos más rojizos
		if (mortar) c = base_color * 0.55;
		c *= 0.94 + hash(p) * 0.08; // grano
		c = bevel(c, lp, rect_size);
	} else if (style == 1) {
		// Hormigón: manchas, juntas cada 4 bloques y alguna grieta
		float n = hash(floor(p / 3.0)) * 0.08 + hash(p) * 0.06;
		c *= 0.9 + n;
		if (mod(p.x, 44.0) < 1.0) c *= 0.7;
		float crack = step(0.985, hash(floor(p / vec2(6.0, 2.0)) + seed)) * step(mod(p.x + p.y, 3.0), 0.5);
		c *= 1.0 - crack * 0.35;
		c = bevel(c, lp, rect_size);
	} else if (style == 2) {
		// Plataforma: tablón de 4 px arriba y escuadras cada 3 bloques
		vec3 wood = vec3(0.55, 0.36, 0.2);
		if (lp.y < 4.0) {
			c = wood * (0.85 + hash(vec2(floor(p.x / 22.0), 3.0)) * 0.25);
			if (mod(p.x, 22.0) < 1.0) c *= 0.6; // junta entre tablones
			if (lp.y < 1.0) c *= 1.35;
			if (lp.y > 2.0) c *= 0.7;
			if (mod(p.x + 3.0, 22.0) < 1.0 && lp.y > 0.0 && lp.y < 3.0) c = vec3(0.75); // clavo
		} else {
			float bx = mod(p.x, 33.0);
			float depth = lp.y - 4.0;
			// escuadra triangular
			if (bx < 6.0 - depth || (bx > 26.0 + depth && bx < 33.0)) {
				c = vec3(0.28, 0.28, 0.3) * (0.9 + hash(p) * 0.1);
			} else {
				a = 0.0;
			}
		}
	} else if (style == 3) {
		// Caja de madera con marco y riostra en diagonal
		vec3 wood = vec3(0.62, 0.45, 0.26);
		c = wood * (0.85 + hash(vec2(floor(lp.y / 4.0), seed)) * 0.2);
		if (mod(lp.y, 4.0) < 1.0) c *= 0.8;
		bool frame = lp.x < 2.0 || lp.y < 2.0 || lp.x > rect_size.x - 3.0 || lp.y > rect_size.y - 3.0;
		float d = abs(lp.x / rect_size.x - lp.y / rect_size.y) * rect_size.x;
		if (frame || d < 1.5) c = wood * 0.7;
		if (frame && (lp.x < 1.0 || lp.y < 1.0)) c = wood * 1.1;
		c *= 0.95 + hash(p) * 0.08;
	} else if (style == 5) {
		// Cielo nocturno: degradado y alguna estrella
		float h = clamp(lp.y / rect_size.y, 0.0, 1.0);
		c = mix(base_color * 0.6, base_color * 1.6, h);
		float star = step(0.9965, hash(floor(p / 2.0)));
		c += vec3(star * 0.6);
	} else {
		// Pared del fondo: ladrillo grande y oscuro con zócalo cada 11 bloques
		float row = floor(p.y / 8.0);
		float x = p.x + mod(row, 2.0) * 8.0;
		bool mortar = mod(p.y, 8.0) < 1.0 || mod(x, 16.0) < 1.0;
		c *= 0.85 + hash(vec2(floor(x / 16.0), row) + seed) * 0.2;
		if (mortar) c *= 0.7;
		if (mod(p.y, 121.0) > 116.0) c *= 0.6;
		c *= 0.95 + hash(p) * 0.05;
	}
	COLOR = vec4(c, a);
}
