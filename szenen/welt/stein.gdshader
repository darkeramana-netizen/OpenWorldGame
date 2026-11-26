shader_type spatial;
// Stein, Putz und Böden: triplanar in Weltkoordinaten wie die StandardMaterialien, aber ohne sichtbare
// Wiederholung. Jede Fläche wird zweimal abgetastet (echte Größe und 1,8-mal größer) und nach
// großflächigem Rauschen gemischt; dazu leichte Farbschwankungen von Stein zu Stein und Moos auf Oberseiten.
//
// Detail und Verwitterung:
//  - Parallax mit der Höhenkarte (texturen/<name>_hoehe.jpg): Fugen und Steinkanten liegen sichtbar zurück,
//    nur in der Nähe der Kamera (weiter weg reicht die Normalenkarte).
//  - Fugenschatten: tiefe Stellen der Höhenkarte werden dunkler (Umgebungsverdeckung im Kleinen).
//  - Regenspuren: senkrechte, dunkle Laufspuren auf Wänden, von oben nach unten auslaufend.
//  - Feuchte und Schmutz am Fuß jeder Wand über dem Gelände (globale Höhenkarte, gesetzt von gelaende.gd):
//    dunkler, grünlich, glatter; darüber ein ausfransender Rand.
//  - Moos und Flechten auf nach oben weisenden Flächen (Zinnen, Gesimse, Mauerkronen).

uniform sampler2D farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normalen : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rauheit : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hoehe : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float meter = 2.5;               // Kantenlänge einer Kachel
uniform vec3 ton : source_color = vec3(1.0);
uniform float schwankung = 0.18;         // Farbschwankung über große Flächen
uniform float moos = 0.35;               // Moos und Flechten auf nach oben weisenden Flächen
uniform vec3 moos_farbe : source_color = vec3(0.16, 0.19, 0.09);
uniform float normal_staerke = 1.0;
uniform float tiefe = 0.0;               // Parallax-Tiefe in Metern (0: aus)
uniform float fugen = 0.45;              // wie dunkel die tiefsten Stellen werden
uniform float regen = 0.38;              // Stärke der Regenspuren auf Wänden
uniform float feuchte = 1.0;             // Stärke der Feuchte am Mauerfuß
uniform float parallax_weite = 28.0;     // bis zu dieser Entfernung (m) wird Parallax gerechnet
// Rüstlöcher (Gerüstlöcher): In jeder Lage des Baugerüsts (etwa 1,3 m) steckten Querhölzer in der Mauer; die Löcher
// blieben offen. 0: keine, 1: in Reihen auf allen geraden Wänden ab 1,6 m über dem Boden.
uniform float ruestloecher = 0.0;
// Flickstellen: spätere Ausbesserungen in etwas anderem Stein (hellere, kühlere Partien mit scharfer Grenze)
uniform float flicken = 0.0;
// Eigene Steine für Oberseiten (z. B. Kaiplatten auf der Krone der Kaimauer statt Bruchstein)
uniform bool mit_deckel = false;
uniform sampler2D deckel_farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deckel_normalen : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deckel_rauheit : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deckel_hoehe : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float deckel_meter = 2.5;

// Geländehöhe der Region (gelaende.gd): R = Höhe in Metern; rahmen = Ursprung x, z und Größe x, z
global uniform sampler2D gelaende_hoehe : filter_linear;
global uniform vec4 gelaende_rahmen;

varying vec3 welt_pos;
varying vec3 welt_normale;

float zufall(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(zufall(i), zufall(i + vec2(1, 0)), u.x), mix(zufall(i + vec2(0, 1)), zufall(i + vec2(1, 1)), u.x), u.y);
}

float rauschen3(vec3 p) {
	return rauschen(p.xz + p.y * 0.37) * 0.5 + rauschen(p.zy * 1.3 + 7.1) * 0.3 + rauschen(p.xy * 0.7 - 3.3) * 0.2;
}

vec2 drehe(vec2 p) {
	const float c = 0.7986;   // cos 37°
	const float s = 0.6018;
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	welt_normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Parallax entlang einer Projektion: p_ab Weltkoordinaten in der Ebene, v_ab und v_n der Blick (zur Kamera)
// in der Ebene und entlang der Flächennormale. Gibt die verschobene Ebenenkoordinate (Meter) zurück.
float hoehe_bei(vec2 uv, bool deckel) {
	return deckel ? textureLod(deckel_hoehe, uv, 0.0).r : textureLod(hoehe, uv, 0.0).r;
}

vec2 parallax(vec2 p_ab, vec2 v_ab, float v_n, float staerke, bool deckel) {
	float m = deckel ? deckel_meter : meter;
	if (tiefe <= 0.0 || staerke <= 0.0) {
		return p_ab;
	}
	float vn = max(v_n, 0.25);
	const int SCHRITTE = 10;
	float schritt = 1.0 / float(SCHRITTE);
	vec2 versatz = -v_ab / vn * tiefe * staerke;   // Weg in der Ebene bis zur vollen Tiefe
	float lage = 0.0;                              // 0 = Oberfläche, 1 = volle Tiefe
	vec2 p = p_ab;
	float h = hoehe_bei(p / m, deckel);
	float vorher_lage = 0.0;
	float vorher_tief = 1.0 - h;
	for (int i = 0; i < SCHRITTE; i++) {
		if (lage >= 1.0 - h) {
			break;
		}
		vorher_lage = lage;
		vorher_tief = 1.0 - h;
		lage += schritt;
		p = p_ab + versatz * lage;
		h = hoehe_bei(p / m, deckel);
	}
	// zwischen den letzten beiden Schritten einpassen
	float a = vorher_tief - vorher_lage;
	float b = (1.0 - h) - lage;
	float t = clamp(a / max(a - b, 0.0001), 0.0, 1.0);
	return p_ab + versatz * mix(vorher_lage, lage, t);
}

void fragment() {
	vec3 n = normalize(welt_normale);
	vec3 gewicht = pow(abs(n), vec3(4.0));
	gewicht /= gewicht.x + gewicht.y + gewicht.z;
	vec3 zur_kamera = CAMERA_POSITION_WORLD - welt_pos;
	float entfernung = length(zur_kamera);
	vec3 v = zur_kamera / max(entfernung, 0.001);
	float px_staerke = 1.0 - smoothstep(parallax_weite * 0.6, parallax_weite, entfernung);

	// Zwei Projektionen (Meter): Wände entlang der Wand selbst (waagrecht entlang der Wand, senkrecht die Höhe),
	// so bleibt der Stein auf schräg stehenden Mauern unverzerrt (vorher entlang der Weltachsen: gestreckt und
	// doppelt überblendet, Mängelliste M19); Oberseiten von oben. Parallax nur für die vorherrschende.
	vec2 entlang = normalize(vec2(-n.z, n.x) + vec2(0.0001, 0.0));
	vec2 nach_aussen = normalize(n.xz + vec2(0.0001, 0.0));
	float g_wand = gewicht.x + gewicht.z;
	vec2 ebene[2] = { vec2(dot(welt_pos.xz, entlang), welt_pos.y), welt_pos.xz };
	vec2 blick[2] = { vec2(dot(v.xz, entlang), v.y), v.xz };
	float blick_n[2] = { dot(v.xz, nach_aussen), v.y * sign(n.y) };
	int haupt = g_wand > gewicht.y ? 0 : 1;
	// Gekrümmte Wände (Rundtürme): Entlang der Wand gemessen ist die Koordinate rund um den Turm überall gleich, die
	// Steine würden zu senkrechten Streifen (Mängelliste M33). Dort deshalb die Projektion entlang der Weltachsen, je
	// nach Richtung der Normale überblendet. Krümmung = Änderung der Normale je Meter.
	float kruemmung = length(fwidth(n.xz)) / max(length(fwidth(welt_pos)), 0.0001);
	float rund = smoothstep(0.02, 0.05, kruemmung);

	float mischung = smoothstep(0.3, 0.7, rauschen3(welt_pos * 0.06));
	vec3 alb = vec3(0.0);
	vec3 nk = vec3(0.0);
	float rau = 0.0;
	float hh = 0.0;
	for (int i = 0; i < 2; i++) {
		float g = i == 0 ? g_wand : gewicht.y;
		if (g < 0.01) continue;
		vec2 e = ebene[i];
		bool deckel = mit_deckel && i == 1 && n.y > 0.0;
		if (i == haupt && !(i == 0 && rund > 0.5)) {
			e = parallax(e, blick[i], blick_n[i], px_staerke, deckel);
		}
		if (deckel) {
			// Platten liegen in Reihen: nicht gedreht und nicht überblendet, sonst verschwimmen die Fugen
			vec2 a = e / deckel_meter;
			alb += texture(deckel_farbe, a).rgb * g;
			nk += texture(deckel_normalen, a).rgb * g;
			rau += texture(deckel_rauheit, a).r * g;
			hh += texture(deckel_hoehe, a).r * g;
			continue;
		}
		vec2 a = e / meter;
		if (i == 0 && rund > 0.0) {
			// um den Turm: zwei Achsenprojektionen; je weiter die Normale zu einer Achse zeigt, desto mehr zählt sie
			vec2 gx = vec2(welt_pos.z * sign(n.x), welt_pos.y) / meter;
			vec2 gz = vec2(-welt_pos.x * sign(n.z), welt_pos.y) / meter;
			float wx = pow(abs(n.x), 4.0);
			float wz = pow(abs(n.z), 4.0);
			wx /= max(wx + wz, 0.0001);
			vec3 alb_r = texture(farbe, gx).rgb * wx + texture(farbe, gz).rgb * (1.0 - wx);
			vec3 nk_r = texture(normalen, gx).rgb * wx + texture(normalen, gz).rgb * (1.0 - wx);
			float rau_r = texture(rauheit, gx).r * wx + texture(rauheit, gz).r * (1.0 - wx);
			float hh_r = texture(hoehe, gx).r * wx + texture(hoehe, gz).r * (1.0 - wx);
			if (rund >= 0.999) {
				alb += alb_r * g;
				nk += nk_r * g;
				rau += rau_r * g;
				hh += hh_r * g;
				continue;
			}
			vec2 b0 = a * 0.55 + 0.31;
			alb += mix(mix(texture(farbe, a).rgb, texture(farbe, b0).rgb, mischung * 0.6), alb_r, rund) * g;
			nk += mix(mix(texture(normalen, a).rgb, texture(normalen, b0).rgb, mischung * 0.6), nk_r, rund) * g;
			rau += mix(mix(texture(rauheit, a).r, texture(rauheit, b0).r, mischung * 0.6), rau_r, rund) * g;
			hh += mix(texture(hoehe, a).r, hh_r, rund) * g;
			continue;
		}
		// Waagrechte Steinlagen müssen waagrecht bleiben: gedreht wird nur auf Oberseiten
		vec2 b = (i == 1 ? drehe(a) : a) * 0.55 + 0.31;
		alb += mix(texture(farbe, a).rgb, texture(farbe, b).rgb, mischung * 0.6) * g;
		nk += mix(texture(normalen, a).rgb, texture(normalen, b).rgb, mischung * 0.6) * g;
		rau += mix(texture(rauheit, a).r, texture(rauheit, b).r, mischung * 0.6) * g;
		hh += texture(hoehe, a).r * g;
	}
	// Großflächige Farbschwankung: hellere und dunklere, wärmere und kühlere Partien
	float gross = rauschen3(welt_pos * 0.11);
	alb *= mix(vec3(1.0 - schwankung), vec3(1.0 + schwankung * 0.6, 1.0 + schwankung * 0.5, 1.0 + schwankung * 0.3), gross);
	alb *= ton;
	// Fugenschatten
	float fuge = mix(1.0 - fugen, 1.0, smoothstep(0.05, 0.6, hh));
	alb *= mix(1.0, fuge, 0.7);

	float senkrecht = 1.0 - smoothstep(0.35, 0.7, abs(n.y));
	// Regenspuren: in der Waagrechten fein, in der Senkrechten lang gezogen, nach unten auslaufend
	float quer = dot(welt_pos.xz, normalize(vec2(-n.z, n.x) + vec2(0.0001)));
	float spur = rauschen(vec2(quer * 3.1, welt_pos.y * 0.22)) * rauschen(vec2(quer * 0.9 + 4.0, welt_pos.y * 0.08));
	spur = smoothstep(0.25, 0.65, spur) * senkrecht * regen;
	alb *= 1.0 - spur * 0.55;
	alb = mix(alb, alb * vec3(0.92, 0.94, 0.9), spur);

	// Feuchte und Schmutz am Fuß der Wand
	float feucht = 0.0;
	if (gelaende_rahmen.z > 0.0) {
		vec2 guv = (welt_pos.xz - gelaende_rahmen.xy) / gelaende_rahmen.zw;
		float boden = textureLod(gelaende_hoehe, guv, 0.0).r;
		float ueber = welt_pos.y - boden;
		float rand = 0.9 + 1.2 * rauschen(vec2(quer * 0.8, welt_pos.y * 0.1) + welt_pos.xz * 0.05);
		feucht = (1.0 - smoothstep(rand * 0.45, rand * 1.3, ueber)) * step(-0.5, ueber) * feuchte;
		feucht *= senkrecht;   // nur Wände, nicht die Böden der Höfe
		alb = mix(alb, alb * vec3(0.48, 0.52, 0.42), feucht);
		// grünliche Algen in den Fugen ganz unten
		float algen = feucht * (1.0 - smoothstep(0.0, 0.5, ueber)) * (1.0 - smoothstep(0.2, 0.55, hh));
		alb = mix(alb, vec3(0.12, 0.15, 0.07), algen * 0.6);
	}

	// Flickstellen: spätere Ausbesserungen, heller und kühler, mit unregelmäßiger, aber klarer Grenze
	if (flicken > 0.0) {
		float fl = smoothstep(0.66, 0.69, rauschen3(welt_pos * vec3(0.05, 0.09, 0.05) + 11.0) + (hh - 0.5) * 0.06);
		alb = mix(alb, alb * vec3(1.12, 1.1, 1.08), fl * flicken * senkrecht);
	}
	// Rüstlöcher: dunkle Löcher in Reihen (Gerüstlagen), nicht an jeder Stelle; nicht auf Rundtürmen (dort verzieht
	// die Koordinate entlang der Wand) und nicht in der Feuchte am Fuß
	float loch = 0.0;
	if (ruestloecher > 0.0 && senkrecht > 0.5 && rund < 0.5 && gelaende_rahmen.z > 0.0) {
		vec2 guv2 = (welt_pos.xz - gelaende_rahmen.xy) / gelaende_rahmen.zw;
		float ueber2 = welt_pos.y - textureLod(gelaende_hoehe, guv2, 0.0).r;
		const float LAGE = 1.32;
		const float ABSTAND = 1.75;
		float reihe = floor(welt_pos.y / LAGE);
		float ver = zufall(vec2(reihe, 3.7)) * ABSTAND;          // jede Lage etwas versetzt
		float spalte = floor((quer + ver) / ABSTAND);
		vec2 in_zelle = vec2(fract((quer + ver) / ABSTAND) * ABSTAND, fract(welt_pos.y / LAGE) * LAGE);
		// etwa jede dritte Stelle, und ganze Lagen bleiben ohne Löcher (dort wurde das Gerüst anders gesetzt)
		float da = step(0.66, zufall(vec2(spalte, reihe) + floor(welt_pos.xz * 0.02) * 7.0)) * step(1.6, ueber2)
			* step(0.3, zufall(vec2(reihe, 17.0) + floor(welt_pos.xz * 0.02)));
		vec2 d = abs(in_zelle - vec2(ABSTAND * 0.5, LAGE * 0.5));
		float r = 0.075 + 0.02 * zufall(vec2(spalte, reihe + 9.0));
		loch = da * (1.0 - smoothstep(r - 0.012, r + 0.004, max(d.x, d.y))) * ruestloecher;
		// unter dem Loch eine helle Laufspur (Kalk und Schmutz, vom Regen herausgewaschen)
		float lauf = da * ruestloecher * (1.0 - smoothstep(0.02, r * 0.8, d.x))
			* step(in_zelle.y, LAGE * 0.5 - r) * (1.0 - smoothstep(0.0, 0.55, LAGE * 0.5 - r - in_zelle.y));
		alb = mix(alb, alb * vec3(0.7, 0.72, 0.7), lauf * 0.6);
		alb = mix(alb, alb * 0.12, loch);
	}

	// Moos und Flechten auf Oberseiten (Zinnen, Gesimse, Mauerkronen), bevorzugt in Vertiefungen
	float oben = smoothstep(0.45, 0.85, n.y) * moos * smoothstep(0.35, 0.75, rauschen3(welt_pos * 0.9 + 3.0) + (0.5 - hh) * 0.3);
	alb = mix(alb, moos_farbe, oben);
	ALBEDO = alb;
	ROUGHNESS = clamp(rau + oben * 0.2 - feucht * 0.25, 0.0, 1.0);
	AO = mix(fuge, 1.0, 0.25) * (1.0 - loch * 0.9);
	AO_LIGHT_AFFECT = 0.25;
	// Normalenkarte ohne Tangenten: in die Weltnormale kippen (wie im Geländeshader)
	vec3 t = nk * 2.0 - 1.0;
	vec3 neu = n;
	neu += ((vec3(entlang.x, 0.0, entlang.y) * t.x + vec3(0.0, t.y, 0.0)) * g_wand + vec3(t.x, 0.0, t.y) * gewicht.y) * normal_staerke * 0.8;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(neu), 0.0)).xyz);
}
