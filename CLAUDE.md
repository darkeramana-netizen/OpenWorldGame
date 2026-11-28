# Arbeitsregeln für dieses Projekt

- **Vision**: `docs/00-vision.md` ist der langfristige Maßstab (realistisch, historisch plausibel, funktional; keine
  Fantasy-Übertreibung, keine Abkürzungen mit technischen Schulden, Optik nicht ohne Not verschlechtern). Vor größeren
  Entscheidungen lesen.
- **Sprache**: Antworten, Kommentare, Bezeichner und Dokumentation auf Deutsch.
- **Ablauf**: Arbeit auf dem Zweig `spiel-ausbau`; alle Testreihen (`tests/test_*.gd`, headless) laufen lassen;
  Fehler untersuchen und beheben; erst wenn alles grün ist, per Fast-forward nach `main` und pushen. Danach visuelle
  Prüfung durch den Entwickler.
- **Bauskripte**: Regionen entstehen aus `werkzeuge/bau/region_*.py` (nicht die `.tscn` von Hand ändern). Nach
  Codeänderungen an Bauten den Baucache füllen (`werkzeuge/baucache_fuellen.gd`).
- **Assets**: nur CC0 oder freie Lizenzen, mit Quelle in der jeweiligen `QUELLEN.md`.
- **C++-Module**: Repository `sorrowland-module` (GDExtension), modular und nicht fest an dieses Spiel gebunden;
  gebaut mit `werkzeuge/bauen.sh <Spielordner>`.
- **Mängel und Stand**: `docs/maengel-drachenstein.md` fortschreiben.
