shader_type spatial;
// Das Wächtermeer: Wellen aus mehreren Rauschlagen in verschiedenen Richtungen (keine Streifen), dunkles Blaugrün,
// Spiegelung des Himmels zum Rand hin. Dieselbe Oberfläche dient als Fernmeer bis zum Horizont (mit Aussparung).
// Die Wassertiefe kommt aus der Höhenkarte des Geländes (globale Uniform, auch von stein.gdshader genutzt; die
// Tiefenkarte des Bildschirms ist nicht auf jedem Treiber gefüllt): Flaches Wasser ist durchsichtig und grünlich
// (man sieht den Grund), tiefes fast schwarz; am Ufer ein Saum aus Gischt. Im Hafenbecken ist das Wasser trüb und ruhig.

global uniform sampler2D gelaende_hoehe : filter_linear;
global uniform vec4 gelaende_rahmen;
// Himmel für die Spiegelung (tageslicht.gd setzt beide je Bild): Wasser spiegelt flach gesehen fast ganz (Fresnel)
global uniform vec4 himmel_oben : source_color;
global uniform vec4 himmel_horizont : source_color;
uniform float spiegelung = 1.0;
uniform vec3 farbe_tief = vec3(0.012, 0.05, 0.065);  // tiefes Blaugrün wie im Referenzbild
uniform vec3 farbe_hell = vec3(0.025, 0.085, 0.095);
uniform vec3 farbe_flach = vec3(0.06, 0.13, 0.11);   // über hellem Grund
uniform float sichttiefe = 1.4;                      // so tief sieht man ins Wasser (Meter bis fast undurchsichtig)
uniform float gischt = 1.0;
// Hafenbecken (x min, z min, x max, z max): trübes, grünlich-graues Wasser, kaum Kräuselung
uniform vec4 hafen = vec4(0.0);
uniform vec3 farbe_hafen = vec3(0.03, 0.055, 0.045);
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
	float im_hafen = 0.0;
	if (hafen.z > hafen.x) {
		vec2 r = min(welt_pos.xz - hafen.xy, hafen.zw - welt_pos.xz);
		im_hafen = clamp(min(r.x, r.y) / 25.0, 0.0, 1.0);
	}
	float staerke = kraeuseln * (1.0 - smoothstep(kraeuseln_bis * 0.3, kraeuseln_bis, abstand)) * (1.0 - im_hafen * 0.6);
	// Normale aus dem Gefälle der Wellenhöhe (in Weltkoordinaten)
	vec2 p = welt_pos.xz;
	float e = 0.35;
	float h0 = wellen(p, TIME);
	float hx = wellen(p + vec2(e, 0.0), TIME);
	float hz = wellen(p + vec2(0.0, e), TIME);
	vec3 n_welt = normalize(vec3(-(hx - h0) / e * staerke, 1.0, -(hz - h0) / e * staerke));
	// feine Kräuselung nah an der Kamera (bis 60 m): kleine, schnelle Wellen, die das Licht brechen
	float nah = 1.0 - smoothstep(25.0, 60.0, abstand);
	if (nah > 0.0) {
		float ef = 0.08;
		vec2 q = p * 2.2;
		float f0 = rauschen(q + vec2(TIME * 0.9, TIME * 0.6)) + rauschen(q * 1.9 - vec2(TIME * 1.3, -TIME * 0.4)) * 0.5;
		float fx = rauschen(q + vec2(ef * 2.2, 0.0) + vec2(TIME * 0.9, TIME * 0.6)) + rauschen((q + vec2(ef * 2.2, 0.0)) * 1.9 - vec2(TIME * 1.3, -TIME * 0.4)) * 0.5;
		float fz = rauschen(q + vec2(0.0, ef * 2.2) + vec2(TIME * 0.9, TIME * 0.6)) + rauschen((q + vec2(0.0, ef * 2.2)) * 1.9 - vec2(TIME * 1.3, -TIME * 0.4)) * 0.5;
		n_welt = normalize(n_welt + vec3(-(fx - f0), 0.0, -(fz - f0)) * 0.35 * nah * (1.0 - im_hafen * 0.4));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_welt, 0.0)).xyz);

	// großflächige, weiche Farbunterschiede (Strömung, Tiefe) statt regelmäßiger Bänder
	float flecken = rauschen(p * 0.004 + vec2(TIME * 0.002, 0.0)) * 0.5 + rauschen(p * 0.013) * 0.25 + 0.5;
	vec3 farbe = mix(farbe_tief, farbe_hell, clamp(flecken, 0.0, 1.0) * 0.6);
	farbe = mix(farbe, farbe_hafen * (0.85 + flecken * 0.3), im_hafen);

	// Wassertiefe unter diesem Punkt (außerhalb der Höhenkarte: tief); entlang des Blicks ist der Weg zum Grund länger
	float tief = 50.0;
	if (gelaende_rahmen.z > 0.0) {
		vec2 guv = (welt_pos.xz - gelaende_rahmen.xy) / gelaende_rahmen.zw;
		if (guv.x > 0.0 && guv.y > 0.0 && guv.x < 1.0 && guv.y < 1.0) {
			vec2 n = vec2(textureSize(gelaende_hoehe, 0));   // Rasterpunkte liegen auf den Texelmitten
			float grund = textureLod(gelaende_hoehe, guv * (n - 1.0) / n + 0.5 / n, 0.0).r;
			// Liegt das Gelände deutlich über dem Wasser, ist das Wasser in einem Gang oder einer Halle unter dem
			// Fels (Untergrundhafen, Kanal): dort tief, nicht Strand
			tief = grund > welt_pos.y + 0.6 ? 50.0 : max(welt_pos.y - grund, 0.0);
		}
	}
	float durch_blick = tief / max(abs(dot(normalize(CAMERA_POSITION_WORLD - welt_pos), vec3(0.0, 1.0, 0.0))), 0.15);
	float sicht = sichttiefe * (1.0 - im_hafen * 0.65);
	float flach = exp(-tief / max(sicht * 0.5, 0.01));
	farbe = mix(farbe, farbe_flach * (1.0 - im_hafen * 0.4), flach * 0.7);
	ALPHA = clamp(1.0 - exp(-durch_blick / max(sicht, 0.01)), 0.0, 1.0);
	// ab 3 m Tiefe undurchsichtig: Stufen und Platten des Meeresbodens (Geländeerzeuger) schimmern sonst durch
	ALPHA = max(ALPHA, smoothstep(1.5, 3.0, tief));
	ALPHA = max(ALPHA, smoothstep(kraeuseln_bis * 0.5, kraeuseln_bis * 1.5, abstand));

	// Gischt: ein unruhiger Saum, wo das Wasser flach auf den Grund läuft
	float schaum_rauschen = rauschen(p * 1.7 + vec2(TIME * 0.25, -TIME * 0.18)) * 0.5 + rauschen(p * 4.3 - vec2(TIME * 0.4, 0.0)) * 0.3 + 0.5;
	float saum = 1.0 - smoothstep(0.0, 0.55 + 0.35 * sin(TIME * 0.9 + p.x * 0.3 + p.y * 0.2), tief);
	float schaum = saum * smoothstep(0.35, 0.75, schaum_rauschen) * gischt * (1.0 - im_hafen * 0.35)
			* (1.0 - smoothstep(60.0, 160.0, abstand));
	ALBEDO = mix(farbe, vec3(0.75, 0.78, 0.76), schaum);
	ALPHA = max(ALPHA, schaum);
	// Mit der Kräuselung darf die Oberfläche glatter sein: Die Sonne glitzert in vielen kleinen Lichtern statt
	// eines großen weißen Flecks. Gischt ist matt.
	ROUGHNESS = mix(mix(0.2, 0.06, staerke / max(kraeuseln, 0.001)), 0.8, schaum);
	SPECULAR = 0.5;
	// Spiegelung des Himmels nach Fresnel (Wasser: 2 % senkrecht, flach fast ganz), mit den Wellen verzerrt; macht aus
	// der dunklen Fläche erkennbar Wasser (vorher wirkte es wie ein blauer Boden)
	vec3 v = normalize(CAMERA_POSITION_WORLD - welt_pos);
	vec3 r = reflect(-v, n_welt);
	float cos_t = clamp(dot(v, n_welt), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - cos_t, 5.0);
	vec3 himmel = mix(himmel_horizont.rgb, himmel_oben.rgb, smoothstep(0.0, 0.5, r.y));
	EMISSION = himmel * fresnel * (1.0 - schaum) * spiegelung;
	ALPHA = max(ALPHA, fresnel);
}
