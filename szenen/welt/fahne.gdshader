shader_type spatial;
render_mode cull_disabled;
// Fahnen und Banner aus Tuch (szenen/welt/burgbau.gd, "fahnen"): wehen im Wind und tragen das Wappen von Drachenstein,
// ein goldener Drache als Raute mit Schwingen auf Rot, mit goldenem Saum. UV: x entlang der Fahne (0 am Mast bzw.
// oben), y quer. art 0: Fahne am Mast (weht frei), art 1: Banner an der Wand (hängt, bewegt sich nur leicht).

uniform vec3 grund : source_color = vec3(0.52, 0.06, 0.05);
uniform vec3 zeichen : source_color = vec3(0.85, 0.66, 0.22);
uniform float art = 0.0;

varying float falte;

void vertex() {
	float t = TIME;
	float x = UV.x;
	float welle;
	if (art < 0.5) {
		// frei wehend: Wellen laufen vom Mast nach außen, außen stärker
		welle = sin(x * 9.0 - t * 4.2 + UV.y * 1.5) * 0.18 + sin(x * 17.0 - t * 6.5) * 0.06;
		VERTEX.z += welle * x;
		VERTEX.y -= x * x * 0.15;
	} else {
		// hängendes Banner: leichtes Schwingen, unten mehr
		welle = sin(UV.y * 6.0 + t * 1.3) * 0.05 + sin(t * 0.9 + UV.y * 2.0) * 0.08;
		VERTEX.z += welle * x;
	}
	falte = welle;
}

void fragment() {
	vec2 uv = UV;
	vec3 farbe = grund;
	// Saum
	float rand = step(uv.y, 0.07) + step(0.93, uv.y) + step(0.95, uv.x);
	// Wappen: Raute (Drachenleib) mit zwei Schwingen
	vec2 m = vec2((art < 0.5 ? 0.45 : 0.42), 0.5);
	vec2 d = abs(uv - m) * vec2(art < 0.5 ? 1.0 : 1.6, 1.0);
	float raute = step(d.x + d.y, 0.16);
	float schwinge = step(abs(uv.x - m.x + (abs(uv.y - 0.5) - 0.18) * 0.6), 0.03) * step(0.12, abs(uv.y - 0.5)) * step(abs(uv.y - 0.5), 0.36);
	farbe = mix(farbe, zeichen, clamp(rand + raute + schwinge, 0.0, 1.0));
	// Falten: hell und dunkel mit der Welle
	farbe *= 0.85 + falte * 1.2;
	ALBEDO = farbe;
	ROUGHNESS = 0.9;
	BACKLIGHT = farbe * 0.35;
}
