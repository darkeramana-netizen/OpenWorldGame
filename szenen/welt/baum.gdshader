shader_type spatial;
// Bäume aus Fotoscans (werkzeuge/baum_laden.py, szenen/welt/bewuchs.gd): dieselben Texturen wie das importierte
// Material, dazu Wind. Der ganze Baum wiegt sich (mit der Höhe zunehmend, in Böen), das Laub flattert schneller und
// leichter, und gegen das Licht scheint es etwas durch.
render_mode cull_disabled;

uniform sampler2D farbe_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 farbe : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool mit_normal = false;
uniform float normal_staerke = 1.0;
// Poly-Haven-ARM: Rot Umgebungsverdeckung, Grün Rauheit
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool mit_arm = false;
uniform float rauheit = 0.85;
uniform vec2 uv_massstab = vec2(1.0);
uniform vec2 uv_versatz = vec2(0.0);
uniform bool laub = false;
uniform float alpha_schwelle = 0.25;
// Höhe des Modells (Meter, ungeskaliert): Das Wiegen ist ein Anteil davon, so schwingen große und kleine Modelle gleich
uniform float modell_hoehe = 10.0;
uniform float wind = 1.0;
// Ausschlag der Spitze als Anteil der Höhe
uniform float wiegen = 0.012;
// Flattern der Blätter (Meter im Modell)
uniform float flattern = 0.03;

void vertex() {
	vec3 ort = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float anteil = clamp(VERTEX.y / modell_hoehe, 0.0, 1.2);
	float t = TIME * 0.9 + ort.x * 0.05 + ort.z * 0.04;
	float boe = 0.55 + 0.45 * sin(TIME * 0.27 + ort.x * 0.011 + ort.z * 0.007);
	vec2 biegen = vec2(sin(t) + 0.4 * sin(t * 2.3), 0.7 * cos(t * 0.83)) * wiegen * modell_hoehe * anteil * anteil * wind * boe;
	VERTEX.xz += biegen;
	if (laub) {
		float f = sin(TIME * 4.3 + VERTEX.x * 3.1 + VERTEX.y * 2.3 + VERTEX.z * 1.7 + ort.z) * flattern * wind * (0.4 + boe);
		VERTEX += NORMAL * f * clamp(anteil * 3.0, 0.0, 1.0);
	}
}

void fragment() {
	vec2 uv = UV * uv_massstab + uv_versatz;
	vec4 c = texture(farbe_tex, uv) * farbe;
	ALBEDO = c.rgb;
	if (laub) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_schwelle;
		BACKLIGHT = c.rgb * 0.35;
	}
	if (mit_normal) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_staerke;
	}
	if (mit_arm) {
		vec3 a = texture(arm_tex, uv).rgb;
		AO = a.r;
		ROUGHNESS = a.g;
	} else {
		ROUGHNESS = rauheit;
	}
	SPECULAR = 0.3;
}
