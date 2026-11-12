Übernimmt freie Modelle (CC0) von Quaternius ins Projekt: Menschen, Kleidung, Haare, Animationen und Tiere.

Quellen (alle CC0 1.0, https://quaternius.com):
  - Universal Base Characters [Standard]     https://quaternius.itch.io/universal-base-characters
  - Modular Character Outfits - Fantasy      https://quaternius.itch.io/modular-character-outfits-fantasy
  - Universal Animation Library [Standard]   https://quaternius.itch.io/universal-animation-library
  - Farm Animals, Animal Pack Vol.2          https://opengameart.org (Nutzer Quaternius)

Die Pakete werden von Hand (oder per Skript) heruntergeladen und entpackt; dieses Skript bekommt die Ordner:
    python3 werkzeuge/modelle_uebernehmen.py <entpackte Figurenpakete> <entpackte Tierpakete>
Es kopiert nur, was das Spiel braucht, nach modelle/figuren und modelle/tiere, verkleinert die 4K-Texturen auf
1024 Pixel (Farbe und ORM als JPEG, Normalen als PNG) und schreibt die Verweise in den glTF-Dateien um.
