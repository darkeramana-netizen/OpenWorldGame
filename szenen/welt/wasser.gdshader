shader_type spatial;
// Das Wächtermeer: Wellen aus mehreren Rauschlagen in verschiedenen Richtungen (keine Streifen), dunkles Blaugrün,
// Spiegelung des Himmels zum Rand hin. Dieselbe Oberfläche dient als Fernmeer bis zum Horizont (mit Aussparung).

uniform vec3 farbe_tief = vec3(0.03, 0.11, 0.15);   // tiefes Blaugrün wie im Referenzbild
uniform vec3 farbe_hell = vec3(0.08, 0.25, 0.29);
uniform float wellenhoehe = 0.15;
// Halbe Größe der Fläche (PlaneMesh): Zum Rand hin laufen die Wellen aus, damit die Naht zum Fernmeer nicht klafft.
uniform vec2 halbe_groesse = vec2(1400.0, 900.0);
// Kräuselung der Oberfläche (Normalen): Stärke nah und Entfernung, ab der sie ausläuft (sonst flimmert sie).
uniform float kraeuseln = 0.55;
uniform float kraeuseln_bis = 900.0;
// Kein Wasser innerhalb dieses Kreises: Dort steht der Unterbau des Bergfrieds.
uniform vec2 loch_mitte = vec2(250.0, 135.0);
uniform float loch_radius = 19.9;
// Ein zweiter Kreis ohne Wasser, z. B. über einem Ausstieg unter dem Wasserspiegel.
uniform vec2 loch2_mitte = vec2(0.0, 0.0);
uniform float loch2_radius = 0.0;
// Rechteck ohne Wasser (x min, z min, x max, z max): beim Fernmeer die Fläche des nahen Meeres.
uniform vec4 aussparung = vec4(0.0);

varying vec3 welt_pos;

float zufall(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(zufall(i), zufall(i + vec2(1.0, 0.0)), u.x),
		mix(zufall(i + vec2(0.0, 1.0)), zufall(i + vec2(1.0, 1.0)), u.x), u.y) * 2.0 - 1.0;
}

// Höhe der feinen Wellen: vier Lagen, jede in eigener Richtung und mit eigenem Tempo
float wellen(vec2 p, float t) {
	float h = 0.0;
	h += rauschen(p * 0.045 + vec2(t * 0.020, t * 0.011)) * 1.0;
	h += rauschen(mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 0.11 + vec2(-t * 0.035, t * 0.024)) * 0.45;
	h += rauschen(mat2(vec2(0.28, 0.96), vec2(-0.96, 0.28)) * p * 0.29 + vec2(t * 0.06, t * 0.05)) * 0.2;
	h += rauschen(mat2(vec2(-0.5, 0.87), vec2(-0.87, -0.5)) * p * 0.7 + vec2(-t * 0.09, -t * 0.07)) * 0.08;
	return h;
}

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 r = halbe_groesse - abs(VERTEX.xz);
	float auslauf = clamp(min(r.x, r.y) / 60.0, 0.0, 1.0);
	// zwei lange Dünungen schräg zueinander, damit keine Gitter- oder Streifenmuster entstehen
	float d1 = dot(welt_pos.xz, vec2(0.83, 0.56)) * 0.055 + TIME * 0.7;
	float d2 = dot(welt_pos.xz, vec2(-0.31, 0.95)) * 0.041 + TIME * 0.53;
	VERTEX.y += (sin(d1) + sin(d2 + sin(d1 * 0.5))) * wellenhoehe * auslauf;
}

void fragment() {
	if (distance(welt_pos.xz, loch_mitte) < loch_radius || distance(welt_pos.xz, loch2_mitte) < loch2_radius) {
		discard;
	}
	if (aussparung.z > aussparung.x && welt_pos.x > aussparung.x && welt_pos.x < aussparung.z
			&& welt_pos.z > aussparung.y && welt_pos.z < aussparung.w) {
		discard;
	}
	float abstand = length(VERTEX);
	float staerke = kraeuseln * (1.0 - smoothstep(kraeuseln_bis * 0.3, kraeuseln_bis, abstand));
	// Normale aus dem Gefälle der Wellenhöhe (in Weltkoordinaten)
	vec2 p = welt_pos.xz;
	float e = 0.35;
	float h0 = wellen(p, TIME);
	float hx = wellen(p + vec2(e, 0.0), TIME);
	float hz = wellen(p + vec2(0.0, e), TIME);
	vec3 n_welt = normalize(vec3(-(hx - h0) / e * staerke, 1.0, -(hz - h0) / e * staerke));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_welt, 0.0)).xyz);

	// großflächige, weiche Farbunterschiede (Strömung, Tiefe) statt regelmäßiger Bänder
	float flecken = rauschen(p * 0.004 + vec2(TIME * 0.002, 0.0)) * 0.5 + rauschen(p * 0.013) * 0.25 + 0.5;
	ALBEDO = mix(farbe_tief, farbe_hell, clamp(flecken, 0.0, 1.0) * 0.45);
	// Mit der Kräuselung darf die Oberfläche glatter sein: Die Sonne glitzert in vielen kleinen Lichtern statt
	// eines großen weißen Flecks.
	ROUGHNESS = mix(0.2, 0.06, staerke / max(kraeuseln, 0.001));
	SPECULAR = 0.5;
	// Zum Rand hin (flacher Blickwinkel) heller, wie eine Spiegelung des Himmels.
	float rand = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(ALBEDO, vec3(0.3, 0.4, 0.44), rand * 0.4);
}
