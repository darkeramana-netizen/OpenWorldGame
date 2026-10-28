shader_type spatial;
// Bäume, Büsche und Gras: Farbe aus Eckpunktfarbe mal Tönung je Exemplar (INSTANCE_CUSTOM.rgb),
// dazu ein leichtes Wiegen im Wind, das mit der Höhe über dem Boden zunimmt (INSTANCE_CUSTOM.a: Phase).
render_mode cull_disabled;

uniform float wind = 1.0;
// Wie stark sich ein Meter Höhe im Wind bewegt (Gras viel, Baumkronen wenig).
uniform float biegsamkeit = 0.03;
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_staerke = 0.5;
uniform float rauheit = 0.9;
// Spitzen heller (Gras)
uniform float spitze_hell = 0.0;
uniform float spitze_hoehe = 1.0;
// Gras: wie der Boden beleuchten (Normale nach oben) und zum Rand des Grasbereichs hin kleiner werden.
uniform bool boden_normale = false;
uniform float ausblenden_ab = 100000.0;
uniform float ausblenden_bis = 100001.0;

varying vec3 farbe;
varying vec3 welt;
varying float anteil_hoehe;

void vertex() {
	// Eckpunktfarben sind wie Texturen in sRGB gemeint; der Shader rechnet linear.
	farbe = pow(max(COLOR.rgb * INSTANCE_CUSTOM.rgb, vec3(0.0)), vec3(2.2));
	vec3 ort0 = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float abstand = length(ort0 - CAMERA_POSITION_WORLD);
	VERTEX.y *= 1.0 - smoothstep(ausblenden_ab, ausblenden_bis, abstand);
	if (boden_normale) {
		NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	float hoehe = max(VERTEX.y - 0.3, 0.0);
	anteil_hoehe = clamp(VERTEX.y / spitze_hoehe, 0.0, 1.0);
	vec3 ort = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.4 + INSTANCE_CUSTOM.a * 6.2831 + ort.x * 0.07 + ort.z * 0.05;
	float boe = 0.6 + 0.4 * sin(TIME * 0.37 + ort.x * 0.01);
	VERTEX.x += sin(t) * biegsamkeit * hoehe * hoehe * wind * boe;
	VERTEX.z += cos(t * 0.83) * biegsamkeit * 0.7 * hoehe * hoehe * wind * boe;
	welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(detail, welt.xz * 0.5 + welt.y * 0.35).g;
	vec3 f = farbe * mix(1.0, 0.55 + d * 1.1, detail_staerke);
	f *= 1.0 + spitze_hell * anteil_hoehe * anteil_hoehe;
	ALBEDO = f;
	if (boden_normale) {
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	}
	ROUGHNESS = rauheit;
	SPECULAR = 0.15;
	BACKLIGHT = f * 0.15;
}
