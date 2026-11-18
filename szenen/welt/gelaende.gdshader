shader_type spatial;
// Das Gelände aus Texturen (werkzeuge/texturen_erzeugen.py): Gras, Erde, Fels, Sand, Schnee und Sumpf,
// gemischt nach Höhe, Steilheit und Rauschen. Fels liegt triplanar auf Steilhängen, damit er nicht verzerrt.
// Jede Textur wird in zwei Größen gelesen und gemischt, so sieht man keine Kachelmuster.
// Die Maske (daten/<gelaende>/maske.png) malt Wege (Rot), Sumpf (Grün) und gepflasterte Burghöfe (Blau).
#include "res://szenen/welt/gelaende_material.gdshaderinc"

varying vec3 welt_pos;
varying vec3 welt_normale;

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	welt_normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 farbe;
	vec3 normale;
	float rauheit;
	gelaende_material(welt_pos, welt_normale, farbe, normale, rauheit);
	NORMAL = normalize((VIEW_MATRIX * vec4(normale, 0.0)).xyz);
	ALBEDO = farbe;
	ROUGHNESS = rauheit;
}
