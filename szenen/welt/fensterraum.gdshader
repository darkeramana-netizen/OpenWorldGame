shader_type spatial;
// Blick in einen Raum hinter der Fensterscheibe geschlossener Häuser ("Interior Mapping"): Der Blickstrahl wird in
// einen gedachten Raum hinter der Scheibe verlängert und trifft dort Rückwand, Seitenwände, Dielenboden oder
// Balkendecke; davor Möbel (Schrank, Truhe) und Vorhänge je Fenster verschieden. Die Scheibe selbst spiegelt leicht.
// UV: x = Fensternummer + 0..1 (links nach rechts), y = 0..1 (oben nach unten); die ganze Zahl in x macht jedes
// Fenster anders (bei Stadthäusern zusätzlich die Nummer des Hauses).

uniform float tiefe = 1.3;                 // Raumtiefe in Fensterbreiten
uniform float hoehe = 1.6;                 // Raumhöhe in Fensterhöhen (der Raum ist höher als das Fenster)
uniform vec3 putz : source_color = vec3(0.62, 0.55, 0.45);
uniform vec3 dielen : source_color = vec3(0.34, 0.24, 0.15);
uniform vec3 balken : source_color = vec3(0.22, 0.16, 0.11);
uniform float licht = 0.5;

varying float haus;

void vertex() {
	haus = float(INSTANCE_ID);
}

float zufall(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	float id = floor(UV.x) + haus * 17.0;
	vec2 f = vec2(fract(UV.x), UV.y);
	// Blick im Raum der Scheibe: x nach rechts, y nach unten, z aus der Scheibe heraus. TANGENT zeigt zu wachsendem
	// UV.x; BINORMAL zeigt in Godot zu fallendem UV.y (nach oben), daher das Minus.
	vec3 sicht = vec3(dot(VIEW, TANGENT), -dot(VIEW, BINORMAL), dot(VIEW, NORMAL));
	vec3 d = -normalize(sicht);
	d.z = min(d.z, -0.05);
	// Raum: x 0..1, y von -(hoehe-1)/2 bis 1+(hoehe-1)/2, z von -tiefe bis 0
	float rand_y = (hoehe - 1.0) * 0.5;
	vec3 p = vec3(f, 0.0);
	float tx = d.x > 0.0 ? (1.0 - p.x) / d.x : -p.x / min(d.x, -1e-4);
	float ty = d.y > 0.0 ? (1.0 + rand_y - p.y) / d.y : (-rand_y - p.y) / min(d.y, -1e-4);
	float tz = -tiefe / d.z;
	float t = min(tx, min(ty, tz));
	vec3 h = p + d * t;
	vec3 farbe;
	float r1 = zufall(id);
	float r2 = zufall(id + 3.7);
	float r3 = zufall(id + 9.1);
	if (t == tz) {
		// Rückwand: Putz mit Flecken; davor ein Möbel unten (Schrank, Truhe oder Bank)
		farbe = putz * (0.85 + 0.15 * zufall(floor(h.x * 6.0) + floor(h.y * 5.0) * 7.0 + id));
		float links = 0.1 + r1 * 0.45;
		float breit = 0.25 + r2 * 0.3;
		float oben_m = r3 < 0.4 ? 0.15 : 0.62;   // hoher Schrank oder niedrige Truhe
		if (h.x > links && h.x < links + breit && h.y > oben_m && h.y < 1.0 + rand_y) {
			farbe = vec3(0.3, 0.2, 0.12) * (0.8 + 0.2 * step(0.5, fract((h.x - links) / breit * 2.0)));
		}
		// ein Bild oder Wandbehang
		if (r2 > 0.5 && abs(h.x - (0.75 - r1 * 0.3)) < 0.1 && h.y > 0.15 && h.y < 0.38) {
			farbe = mix(vec3(0.5, 0.15, 0.1), vec3(0.2, 0.3, 0.45), r3);
		}
	} else if (t == ty) {
		if (d.y > 0.0) {
			// Dielenboden
			farbe = dielen * (0.8 + 0.2 * step(0.08, fract(h.x * 5.0 + floor(h.z * 2.0) * 0.37)));
		} else {
			// Decke mit Balken
			farbe = balken * (fract(h.z * 2.5) < 0.3 ? 0.6 : 1.1);
		}
	} else {
		farbe = putz * 0.78;
	}
	// je tiefer, desto dunkler
	farbe *= mix(1.0, 0.35, clamp(-h.z / tiefe, 0.0, 1.0));
	// Vorhänge an den Seiten (nicht in jedem Fenster)
	if (r3 > 0.45) {
		float breite_v = 0.12 + r1 * 0.12;
		if (f.x < breite_v || f.x > 1.0 - breite_v) {
			vec3 stoff = mix(vec3(0.55, 0.2, 0.12), vec3(0.75, 0.68, 0.5), r2);
			farbe = stoff * (0.75 + 0.25 * sin(f.x * 80.0));
		}
	}
	// leichte Spiegelung der Scheibe
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// wenig Spiegelung, damit man den Raum auch von unten und im Schatten sieht
	ALBEDO = farbe * licht;
	EMISSION = farbe * 0.22;
	ROUGHNESS = 0.14;
	SPECULAR = 0.25 + fresnel * 0.45;
	METALLIC = 0.0;
}
