# Was aus Sorrow-Engine für Sorrowland nutzbar ist

Sorrow-Engine (eigenes Projekt, Godot 4.6, Voxel-Welt im Stil von Minecraft) wurde am 18.11.2026 gelesen, nicht
verändert. Die Welt-Pipeline dort ist **C# (.NET 8)**, Steuerung, Menüs, Himmel und Wetter sind GDScript.

Sorrowland ist reines GDScript auf dem normalen Godot 4.7.2. C#-Code lässt sich nicht übernehmen, ohne auf die
.NET-Ausgabe von Godot zu wechseln; davon wird abgeraten. Übernommen werden also **Verfahren**, in GDScript nachgebaut,
und nur bei den GDScript-Teilen auch Code.

## 1. Gut nutzbar: Nachladen um den Spieler (`ChunkController.cs`)

Für das spätere Streaming der Welt (Zellen statt ganzer Regionen) ist das die wertvollste Vorlage:

| Verfahren in Sorrow-Engine | Für Sorrowland |
|---|---|
| Ladeliste aller Zellen im Radius, nach Abstand sortiert, **nur neu gebaut, wenn der Spieler die Zelle wechselt** | genauso; die Zellen wären z. B. 64 × 64 m |
| **Budgets je Bild**: höchstens 3 neue Ladeaufträge, höchstens 10 fertige Meshes einhängen, getrennte Budgets je Art (Wasser extra) | übernehmen, aber als **Zeitbudget** (ms je Bild) wie die Figuren-Warteschlange (`figur.gd`, 4 ms): das hält das Bild auch bei unterschiedlich teuren Zellen gleichmäßig |
| **Entladen mit Abstand-Puffer** (Sichtweite + 3 Zellen), geprüft alle 0,2 s statt in jedem Bild | übernehmen: verhindert Laden/Entladen im Wechsel an der Grenze |
| **Kollision erst ein paar Bilder nach dem Mesh** einhängen | übernehmen: verteilt die Physik-Kosten |
| Aufträge mit **Vorrang** (nah zuerst, Spieleraktion vor allem) und **Entdoppeln** (ein neuerer Auftrag für dieselbe Zelle ersetzt den alten) | übernehmen |
| „Welt bereit“, wenn die nahen Zellen einmal gebaut sind | haben wir schon: der Ladebildschirm (`autoload/ladevorhang.gd`) |

## 2. Gut nutzbar: Regeln für Hintergrund-Threads

Sorrow-Engine hält diese Regeln sauber ein; sie gelten in GDScript genauso (`WorkerThreadPool`, `Mutex`):

- Im Thread nur **Daten** rechnen (Höhen, Mesh-Arrays), nie Knoten anlegen oder in den Szenenbaum hängen.
- **Dateien auf dem Hauptthread** öffnen, dann die Daten an den Thread geben.
- Vor dem Start eine **Kopie (Schnappschuss)** der Daten machen, auf der der Thread arbeitet; das Original darf
  derweil geändert werden.
- Ergebnisse über eine **gesperrte Warteschlange** zurück; der Hauptthread hängt sie mit Budget ein (siehe 1).
- Fehler im Thread nicht über Godot-Funktionen melden, sondern sammeln und auf dem Hauptthread ausgeben.

Bei uns passt das auf: Baucache-Teile im Hintergrund laden (`ResourceLoader.load_threaded_request`), Felsen und
Bewuchs-Lagen im Thread berechnen, später Gelände-Zellen.

## 3. Gut nutzbar: Speichern nur der Änderungen (`ChunkPersistence.cs`)

- Die Welt entsteht immer gleich aus Daten und Startwert; gespeichert werden **nur Zellen, die der Spieler verändert
  hat**. Das Laden selbst zählt ausdrücklich nicht als Änderung.
- Gespeichert wird **beim Entladen** der Zelle und beim Beenden.
- Jede Datei hat eine **Versionsnummer** (alte Stände werden erkannt und umgezogen) und ist komprimiert.

Für Sorrowland: Wenn die Welt in Zellen nachgeladen wird, müssen Zustände wie offene Türen, aufgehobene Dinge, tote
Gegner je Zelle mitwandern. Der Spielstand speichert dann nur die Abweichungen von den Grunddaten, je Zelle.

## 4. Mit Anpassung nutzbar: Wetter (`weather_system.gd`, GDScript)

Sorrowland hat noch kein Wetter. Brauchbar als Grundlage:

- Regen und Schnee als `GPUParticles3D`, die **der Kamera folgen** (kleiner Kasten über dem Spieler statt Partikel
  über der ganzen Welt), 2.000 bzw. 1.400 Teilchen.
- **Weiche Übergänge** über `amount_ratio`, Sturm mit Blitzlicht, Schnee statt Regen in kalten Gebieten (bei uns:
  Gravecrest, oberhalb der Schneegrenze aus dem Geländematerial).

Anzupassen: Aussehen (dort Minecraft-Streifen), Abhängigkeit von Biomen statt Regionen, automatischer Wechsel alle
210 s (bei uns an Spielzeit und Jahreszeit koppeln), kein Regen unter Dächern und in Innenräumen.

## 5. Zum Vergleichen: Himmel und Jahreszeiten (`physical_sky.gd`)

Dort `PhysicalSkyMaterial` mit Jahreszeiten-Steuerung und eigener Wolkenschicht; bei uns `ProceduralSkyMaterial` in
`szenen/welt/tageslicht.gd`. Lohnt einen Vergleich mit Fotos, wenn Himmel und Jahreszeiten drankommen. Der
Wolken-Shader dort (`volumetric_cloud_sky.gdshader`) ist eine einfache 2D-Näherung, keine echten Volumenwolken.

## 6. Nicht nutzbar

- **Grafiken**: `assets/Texturen` sind die Texturen von Minecraft (Rechte bei Mojang). Das **Photon**-Shaderpaket steht
  unter „All rights reserved“; `water.gdshader` liest dessen Rauschtextur. Das **UI Pack** darf laut seiner
  INFO.txt nicht weitergegeben werden. Nichts davon darf ins Spiel.
- Voxel-Meshing, Wassersimulation, Erze, Blöcke, Inventar, Handwerk: an Würfelwelten gebunden.
- Weltgenerierung (Kontinente, tektonische Kurven, Biome): Sorrowland baut nach Grundrissen. Höchstens später für
  Wildnis zwischen den Regionen interessant.
- **Genauigkeit bei großen Entfernungen**: Die README nennt sie als erledigt, im Code findet sich aber kein
  Verschieben des Weltursprungs (Floating Origin). Sorrowland braucht das erst, wenn die Welt deutlich größer als
  einige Kilometer wird (heute ist Drachenstein 2,2 × 1,45 km); dann eigene Lösung.

## Vorschlag

1. Die Verfahren aus 1 bis 3 als Grundlage für den Punkt „Welt in Zellen nachladen“ im Plan (nach dem Gelände).
2. Das Wetter aus 4 als eigenen späteren Punkt, angepasst an Aussehen und Regionen von Sorrowland.
3. Den Himmel aus 5 bei der Arbeit an Himmel und Jahreszeiten mit Fotos vergleichen.
