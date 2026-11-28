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
// Laub: Anteil der „Kugelnormale“ (vom Kronenmittelpunkt nach außen). Die Blattkarten liegen kreuz und quer; mit ihrer
// eigenen Normale war die Krone fleckig hell und fast schwarz (Rückmeldung 27.11.2026). So wird sie als Ganzes
// beleuchtet: oben und zur Sonne hell, innen und unten dunkler.
uniform float kugelnormale = 0.75;
// Höhe des Kronenmittelpunkts als Anteil der Modellhöhe
uniform float krone_mitte = 0.62;

varying float tonung;
varying float innen;

void vertex() {
	vec3 ort = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float anteil = clamp(VERTEX.y / modell_hoehe, 0.0, 1.2);
	float t = TIME * 0.9 + ort.x * 0.05 + ort.z * 0.04;
	float boe = 0.55 + 0.45 * sin(TIME * 0.27 + ort.x * 0.011 + ort.z * 0.007);
	vec2 biegen = vec2(sin(t) + 0.4 * sin(t * 2.3), 0.7 * cos(t * 0.83)) * wiegen * modell_hoehe * anteil * anteil * wind * boe;
	VERTEX.xz += biegen;
	if (laub) {
		vec3 zur_mitte = VERTEX - vec3(0.0, modell_hoehe * krone_mitte, 0.0);
		vec3 kugel = normalize(zur_mitte + vec3(0.0001));
		NORMAL = normalize(mix(NORMAL, kugel, kugelnormale));
		// innen in der Krone dunkler (Eigenschatten), je Baum ein anderer Grünton
		innen = clamp(length(zur_mitte) / (modell_hoehe * 0.38), 0.0, 1.0);
		tonung = fract(sin(dot(ort.xz, vec2(12.9898, 78.233))) * 43758.5453);
		float f = sin(TIME * 4.3 + VERTEX.x * 3.1 + VERTEX.y * 2.3 + VERTEX.z * 1.7 + ort.z) * flattern * wind * (0.4 + boe);
		VERTEX += NORMAL * f * clamp(anteil * 3.0, 0.0, 1.0);
	}
}

void fragment() {
	vec2 uv = UV * uv_massstab + uv_versatz;
	vec4 c = texture(farbe_tex, uv) * farbe;
	ALBEDO = c.rgb;
	if (laub) {
		ALBEDO *= mix(vec3(0.92, 1.0, 0.86), vec3(1.06, 1.02, 0.9), tonung) * mix(0.62, 1.0, innen);
		ALPHA = c.a;
		// Fernfassung: Ihr Holz liegt im Rindenfeld oben links im Laub-Atlas (16 Pixel). In den kleinen Mipmaps mischt
		// sich dort die Durchsichtigkeit der Umgebung ein, die Stämme wurden in der Ferne durchsichtig: dort immer deckend
		if (uv.x < 0.0176 && uv.y < 0.0176) {
			ALPHA = 1.0;
		}
		ALPHA_SCISSOR_THRESHOLD = alpha_schwelle;
		ALPHA_ANTIALIASING_EDGE = 0.2;
		ALPHA_TEXTURE_COORDINATE = uv * vec2(textureSize(farbe_tex, 0));
		BACKLIGHT = ALBEDO * 0.6;
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
