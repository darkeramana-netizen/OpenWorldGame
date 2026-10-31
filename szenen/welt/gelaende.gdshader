shader_type spatial;
// Das Gelände aus Texturen (werkzeuge/texturen_erzeugen.py): Gras, Erde, Fels, Sand, Schnee und Sumpf,
// gemischt nach Höhe, Steilheit und Rauschen. Fels liegt triplanar auf Steilhängen, damit er nicht verzerrt.
// Jede Textur wird in zwei Größen gelesen und gemischt, so sieht man keine Kachelmuster.
// Die Maske (daten/<gelaende>/maske.png) malt Wege (Rot) und Sumpf (Grün).

uniform sampler2D maske : source_color, filter_linear;
uniform vec2 welt_ursprung = vec2(-900.0, -650.0);
uniform vec2 welt_groesse = vec2(1350.0, 1000.0);
uniform float meeresspiegel = -20.0;
// Ab dieser Höhe liegt Schnee (Gravecrest, die Berge im Rahmen).
uniform float schneegrenze = 85.0;

uniform sampler2D gras_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gras_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D erde_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D erde_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fels_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fels_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D schnee_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sumpf_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pflaster_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pflaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Grauer, geschichteter Fels für Steilwände und Klippen (ambientCG Rock028); Moos bleibt auf Absätzen und flacheren
// Hängen (fels_farbe). Ältere Regionen ohne diese Textur lassen mit_klippe aus.
uniform sampler2D klippe_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D klippe_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool mit_klippe = false;

// Gepflasterte Flächen (Städte, Burghöfe): bis zu vier Vielecke, aneinandergehängt in "pflaster_punkte",
// "pflaster_laengen" sagt, wie viele Punkte zu jedem gehören.
uniform vec2 pflaster_punkte[64];
uniform int pflaster_laengen[4];

// Färbung, z. B. trockeneres Gras in Ashenveil
uniform vec3 gras = vec3(1.0, 1.0, 1.0);
uniform vec3 gras_trocken = vec3(1.12, 1.05, 0.82);
uniform vec3 fels = vec3(1.0, 1.0, 1.0);
uniform vec3 schnee = vec3(1.0, 1.0, 1.0);
uniform vec3 sand = vec3(1.0, 1.0, 1.0);
uniform vec3 weg = vec3(1.0, 1.0, 1.0);
uniform vec3 sumpf = vec3(1.0, 1.0, 1.0);

// Kachelgrößen in Metern (Fotoscans von Poly Haven, siehe texturen/groessen.json). In der Ferne wird jede Textur
// zusätzlich 6,5-mal größer daruntergemischt, das bricht die Wiederholung.
const float M_GRAS = 2.0;
const float M_ERDE = 3.2;
const float M_SAND = 8.0;
const float M_SUMPF = 2.4;
const float M_SCHNEE = 4.0;
const float M_PFLASTER = 1.6;
const float M_FELS = 18.0;
const float M_KLIPPE = 7.0;
const float FERN = 6.5;

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

// Zwei Größen gemischt gegen Kachelmuster
vec3 zwei(sampler2D t, vec2 p, float meter) {
	return mix(texture(t, p / meter).rgb, texture(t, p / (meter * FERN) + 0.37).rgb, 0.35);
}

bool im_vieleck(vec2 p, int anfang, int anzahl) {
	bool innen = false;
	for (int i = 0; i < anzahl; i++) {
		vec2 a = pflaster_punkte[anfang + i];
		vec2 b = pflaster_punkte[anfang + (i + 1) % anzahl];
		if ((a.y > p.y) != (b.y > p.y) && p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) {
			innen = !innen;
		}
	}
	return innen;
}

float gepflastert(vec2 p) {
	int anfang = 0;
	for (int k = 0; k < 4; k++) {
		int n = pflaster_laengen[k];
		if (n >= 3 && im_vieleck(p, anfang, n)) {
			return 1.0;
		}
		anfang += n;
	}
	return 0.0;
}

vec3 dreiseitig(sampler2D t, vec3 p, vec3 gewicht, float massstab) {
	return texture(t, p.zy * massstab).rgb * gewicht.x
		+ texture(t, p.xz * massstab).rgb * gewicht.y
		+ texture(t, p.xy * massstab).rgb * gewicht.z;
}

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	welt_normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 m = texture(maske, (welt_pos.xz - welt_ursprung) / welt_groesse);
	float h = welt_pos.y;
	vec3 n = normalize(welt_normale);
	float steil = 1.0 - n.y;
	vec2 p = welt_pos.xz;
	float gross = rauschen(p * 0.012) * 0.6 + rauschen(p * 0.05) * 0.4;   // großflächige Flecken
	float klein = rauschen(p * 0.4);

	vec3 gewicht = pow(abs(n), vec3(4.0));
	gewicht /= gewicht.x + gewicht.y + gewicht.z;

	// Anteile
	float a_fels = smoothstep(0.24, 0.42, steil + (gross - 0.5) * 0.12);
	// An Steilwänden wird der bemooste Fels zu nacktem grauem Fels
	float a_klippe = mit_klippe ? smoothstep(0.36, 0.55, steil + (gross - 0.5) * 0.16 + (klein - 0.5) * 0.05) : 0.0;
	float a_sand = 1.0 - smoothstep(meeresspiegel + 0.8, meeresspiegel + 2.6, h + klein * 0.8);
	float a_schnee = smoothstep(schneegrenze, schneegrenze + 30.0, h + gross * 20.0) * (1.0 - smoothstep(0.22, 0.42, steil));
	float a_erde = smoothstep(0.62, 0.8, gross + klein * 0.15) * 0.55;   // kahle Stellen im Gras
	float a_weg = m.r;
	float a_sumpf = m.g;
	// In der Stadt sind die Wege gepflastert, zwischen den Häusern liegen Höfe aus festgetretener Erde.
	float in_stadt = gepflastert(p);
	float a_pflaster = in_stadt * smoothstep(0.1, 0.5, m.r) * (1.0 - a_fels);
	// Kais am Hafen (Höhe der Kaimauern) sind gepflastert
	a_pflaster = max(a_pflaster, in_stadt * (1.0 - smoothstep(-17.6, -17.0, h)) * step(meeresspiegel + 0.5, h) * (1.0 - a_fels));
	a_erde = max(a_erde, in_stadt * (1.0 - a_fels) * smoothstep(0.45, 0.75, gross) * 0.6);
	a_weg *= 1.0 - in_stadt;

	vec3 g = zwei(gras_farbe, p, M_GRAS) * mix(gras, gras_trocken, smoothstep(0.35, 0.8, gross));
	vec3 farbe = mix(g, zwei(erde_farbe, p, M_ERDE), a_erde);
	farbe = mix(farbe, zwei(sand_farbe, p, M_SAND) * sand, a_sand);
	farbe = mix(farbe, zwei(sumpf_farbe, p, M_SUMPF) * sumpf, a_sumpf);
	farbe = mix(farbe, zwei(erde_farbe, p, M_ERDE * 0.8) * weg, a_weg);
	// In Städten und Höfen: Kopfsteinpflaster mit ausgetretenen Erdstellen
	vec3 pf = texture(pflaster_farbe, p / M_PFLASTER).rgb * mix(1.0, 0.85, klein);
	pf = mix(pf, zwei(erde_farbe, p, M_ERDE) * 0.9, smoothstep(0.68, 0.85, gross) * 0.7);
	farbe = mix(farbe, pf, a_pflaster);
	vec3 f = mix(dreiseitig(fels_farbe, welt_pos, gewicht, 1.0 / M_FELS), dreiseitig(fels_farbe, welt_pos, gewicht, 1.0 / (M_FELS * 4.0)), 0.4) * fels;
	vec3 k = mix(dreiseitig(klippe_farbe, welt_pos, gewicht, 1.0 / M_KLIPPE), dreiseitig(klippe_farbe, welt_pos, gewicht, 1.0 / (M_KLIPPE * 5.0)), 0.45);
	k *= 0.82 + rauschen(welt_pos.xz * 0.03 + welt_pos.y * 0.05) * 0.3;
	f = mix(f, k, a_klippe);
	farbe = mix(farbe, f, a_fels);
	farbe = mix(farbe, zwei(schnee_farbe, p, M_SCHNEE) * schnee, a_schnee);
	farbe *= 0.85 + gross * 0.3;

	// Normalen ohne Tangenten: die Normalenkarte kippt die Weltnormale
	vec3 nk_boden = texture(gras_normal, p / M_GRAS).rgb * (1.0 - a_weg - a_erde) + texture(erde_normal, p / M_ERDE).rgb * (a_weg + a_erde);
	nk_boden = mix(nk_boden, texture(pflaster_normal, p / M_PFLASTER).rgb, a_pflaster);
	vec3 nk_fels = texture(fels_normal, welt_pos.zy * (1.0 / M_FELS)).rgb * gewicht.x + texture(fels_normal, welt_pos.xz * (1.0 / M_FELS)).rgb * gewicht.y + texture(fels_normal, welt_pos.xy * (1.0 / M_FELS)).rgb * gewicht.z;
	if (mit_klippe) {
		vec3 nk_klippe = texture(klippe_normal, welt_pos.zy * (1.0 / M_KLIPPE)).rgb * gewicht.x + texture(klippe_normal, welt_pos.xz * (1.0 / M_KLIPPE)).rgb * gewicht.y + texture(klippe_normal, welt_pos.xy * (1.0 / M_KLIPPE)).rgb * gewicht.z;
		nk_fels = mix(nk_fels, nk_klippe, a_klippe);
	}
	vec3 nk = mix(nk_boden, nk_fels, a_fels) * 2.0 - 1.0;
	float staerke = mix(mix(0.45, 0.9, a_pflaster), 1.1, a_fels) * (1.0 - a_schnee * 0.6);
	vec3 neu = normalize(n + vec3(nk.x, 0.0, -nk.y) * staerke * (1.0 - gewicht.x - gewicht.z) + vec3(0.0, nk.y, 0.0) * 0.0
		+ (vec3(0.0, nk.y, nk.x) * gewicht.x + vec3(nk.x, nk.y, 0.0) * gewicht.z) * staerke * a_fels);
	NORMAL = normalize((VIEW_MATRIX * vec4(neu, 0.0)).xyz);

	ALBEDO = farbe;
	ROUGHNESS = mix(0.95, 0.75, a_schnee);
}
