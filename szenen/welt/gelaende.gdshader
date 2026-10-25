shader_type spatial;
// Färbt das Gelände nach Höhe und Steilheit: Strand, Gras, Fels, Schnee.
// Die Maske (daten/gelaende/maske.png) malt Wege (Rot) und Sumpf (Grün).

uniform sampler2D maske : source_color, filter_linear;
uniform vec2 welt_ursprung = vec2(-900.0, -650.0);
uniform vec2 welt_groesse = vec2(1350.0, 1000.0);
uniform float meeresspiegel = -20.0;

uniform vec3 gras = vec3(0.27, 0.32, 0.17);
uniform vec3 gras_trocken = vec3(0.38, 0.37, 0.22);
uniform vec3 fels = vec3(0.33, 0.32, 0.31);
uniform vec3 schnee = vec3(0.86, 0.89, 0.93);
uniform vec3 sand = vec3(0.52, 0.47, 0.37);
uniform vec3 weg = vec3(0.42, 0.35, 0.26);
uniform vec3 sumpf = vec3(0.17, 0.2, 0.13);

varying vec3 welt_pos;
varying vec3 welt_normale;

float zufall(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(zufall(i), zufall(i + vec2(1, 0)), u.x),
		mix(zufall(i + vec2(0, 1)), zufall(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	welt_normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 m = texture(maske, (welt_pos.xz - welt_ursprung) / welt_groesse);
	float h = welt_pos.y;
	float steil = 1.0 - welt_normale.y;
	float flecken = rauschen(welt_pos.xz * 0.08) * 0.6 + rauschen(welt_pos.xz * 0.6) * 0.4;

	vec3 farbe = mix(gras, gras_trocken, smoothstep(0.35, 0.75, flecken));
	farbe = mix(farbe, sand, 1.0 - smoothstep(meeresspiegel + 1.0, meeresspiegel + 2.5, h));
	farbe = mix(farbe, fels, smoothstep(0.28, 0.5, steil));
	farbe = mix(farbe, schnee, smoothstep(85.0, 120.0, h + flecken * 15.0) * (1.0 - smoothstep(0.55, 0.75, steil)));
	farbe = mix(farbe, sumpf, m.g);
	farbe = mix(farbe, weg, m.r);
	farbe *= 0.9 + flecken * 0.2;

	ALBEDO = farbe;
	ROUGHNESS = 0.95;
}
