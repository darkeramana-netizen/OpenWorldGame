shader_type spatial;
// Stein, Putz und Böden: triplanar in Weltkoordinaten wie die StandardMaterialien, aber ohne sichtbare
// Wiederholung. Jede Fläche wird zweimal abgetastet (echte Größe und 1,8-mal größer) und nach
// großflächigem Rauschen gemischt; dazu leichte Farbschwankungen von Stein zu Stein und Moos auf Oberseiten.

uniform sampler2D farbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normalen : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rauheit : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meter = 2.5;               // Kantenlänge einer Kachel
uniform vec3 ton : source_color = vec3(1.0);
uniform float schwankung = 0.18;         // Farbschwankung über große Flächen
uniform float moos = 0.35;               // Moos und Flechten auf nach oben weisenden Flächen
uniform float normal_staerke = 1.0;

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

void fragment() {
	vec3 n = normalize(welt_normale);
	vec3 gewicht = pow(abs(n), vec3(4.0));
	gewicht /= gewicht.x + gewicht.y + gewicht.z;
	vec2 uv[3] = { welt_pos.zy / meter, welt_pos.xz / meter, welt_pos.xy / meter };
	float mischung = smoothstep(0.3, 0.7, rauschen3(welt_pos * 0.06));

	vec3 alb = vec3(0.0);
	vec3 nk = vec3(0.0);
	float rau = 0.0;
	for (int i = 0; i < 3; i++) {
		float g = i == 0 ? gewicht.x : (i == 1 ? gewicht.y : gewicht.z);
		if (g < 0.01) continue;
		vec2 a = uv[i];
		// Waagrechte Steinlagen müssen waagrecht bleiben: gedreht wird nur auf Oberseiten
		vec2 b = (i == 1 ? drehe(uv[i]) : uv[i]) * 0.55 + 0.31;
		alb += mix(texture(farbe, a).rgb, texture(farbe, b).rgb, mischung * 0.6) * g;
		nk += mix(texture(normalen, a).rgb, texture(normalen, b).rgb, mischung * 0.6) * g;
		rau += mix(texture(rauheit, a).r, texture(rauheit, b).r, mischung * 0.6) * g;
	}
	// Großflächige Farbschwankung: hellere und dunklere, wärmere und kühlere Partien
	float gross = rauschen3(welt_pos * 0.11);
	alb *= mix(vec3(1.0 - schwankung), vec3(1.0 + schwankung * 0.6, 1.0 + schwankung * 0.5, 1.0 + schwankung * 0.3), gross);
	alb *= ton;
	// Moos und Flechten auf Oberseiten (Zinnen, Gesimse, Mauerkronen)
	float oben = smoothstep(0.45, 0.85, n.y) * moos * smoothstep(0.35, 0.75, rauschen3(welt_pos * 0.9 + 3.0));
	alb = mix(alb, vec3(0.16, 0.19, 0.09), oben);
	ALBEDO = alb;
	ROUGHNESS = clamp(rau + oben * 0.2, 0.0, 1.0);
	// Normalenkarte ohne Tangenten: in die Weltnormale kippen (wie im Geländeshader)
	vec3 t = nk * 2.0 - 1.0;
	vec3 neu = n;
	neu += (vec3(0.0, t.y, t.x) * gewicht.x + vec3(t.x, 0.0, t.y) * gewicht.y + vec3(t.x, t.y, 0.0) * gewicht.z) * normal_staerke * 0.8;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(neu), 0.0)).xyz);
}
