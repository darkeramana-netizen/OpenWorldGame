"""Baut den Vorrat realistischer Menschen (modelle/figuren/menschen/<name>) mit werkzeuge/mensch_bauen.py.

figur.gd wählt daraus nach Geschlecht und Beruf (MENSCHEN_MAENNER, MENSCHEN_FRAUEN, MENSCHEN_BERUF); jeder Name
ergibt feste Hautmerkmale (Bräune, Röte, Sommersprossen, Schmutz), die Tracht färbt Kittel und Kleid im Spiel.

Aufruf aus dem Projektordner:  python3 werkzeuge/menschen_vorrat.py MH_DATA SYSTEM_ASSETS [name …]
"""
import subprocess, sys
from pathlib import Path

VORRAT = {
    # Männer im Kittel
    "mann_1": "alter=22 muskeln=0.55 haare=short02 bart_art=keiner kittelfarbe=0.42,0.34,0.24 flicken=1",
    "mann_2": "alter=34 muskeln=0.6 gewicht=0.55 haare=short01 bart_art=voll kittelfarbe=0.28,0.3,0.22 haut=middleage_caucasian_male",
    "mann_3": "alter=45 gewicht=0.75 groesse=0.4 haare=short03 bart_art=kurz kittelfarbe=0.35,0.22,0.15 haut=middleage_caucasian_male flicken=2",
    "mann_4": "alter=63 gewicht=0.6 muskeln=0.45 haare=short04 bart_art=voll kittelfarbe=0.3,0.3,0.32 haut=old_caucasian_male flicken=2",
    "mann_5": "alter=27 muskeln=0.7 groesse=0.65 haare=short04 bart_art=kurz kittelfarbe=0.22,0.26,0.36",
    "mann_6": "alter=52 gewicht=0.4 muskeln=0.4 groesse=0.55 haare=short02 bart_art=voll kittelfarbe=0.4,0.37,0.3 haut=middleage_caucasian_male flicken=3",
    # Frauen im Kleid
    "frau_1": "geschlecht=0 alter=20 kleidung=kleid haare=braid01 kittelfarbe=0.35,0.16,0.12 flicken=0",
    "frau_2": "geschlecht=0 alter=33 kleidung=kleid haare=ponytail01 gewicht=0.6 kittelfarbe=0.25,0.3,0.2 haut=middleage_caucasian_female flicken=1",
    "frau_3": "geschlecht=0 alter=46 kleidung=kleid haare=bob01 gewicht=0.7 groesse=0.4 kittelfarbe=0.3,0.25,0.35 haut=middleage_caucasian_female flicken=2",
    "frau_4": "geschlecht=0 alter=66 kleidung=kleid haare=bob02 gewicht=0.55 kittelfarbe=0.28,0.27,0.24 haut=old_caucasian_female flicken=2",
    "frau_5": "geschlecht=0 alter=26 kleidung=kleid haare=long01 groesse=0.6 kittelfarbe=0.18,0.24,0.38",
    # Berufe
    "schmied": "ueber=lederschuerze alter=38 muskeln=0.8 gewicht=0.6 kittelfarbe=0.3,0.3,0.32 haare=short01 bart_art=voll haut=middleage_caucasian_male flicken=0",
    "koch": "ueber=schuerze alter=44 gewicht=0.8 kittelfarbe=0.4,0.38,0.32 haare=short03 bart_art=kurz haut=middleage_caucasian_male",
    "magd": "geschlecht=0 alter=30 kleidung=kleid ueber=schuerze haare=ponytail01 kittelfarbe=0.22,0.28,0.38 flicken=1",
    "wache_1": "ueber=wappenrock panzer=kettenhemd alter=30 muskeln=0.75 haare=short03 kittelfarbe=0.3,0.28,0.25 bart_art=kurz",
    "wache_2": "ueber=wappenrock panzer=kettenhemd alter=41 muskeln=0.7 gewicht=0.6 haare=short01 kittelfarbe=0.3,0.28,0.25 bart_art=voll haut=middleage_caucasian_male",
    "moench": "alter=48 kleidung=kleid haare=short04 kittelfarbe=0.3,0.22,0.14 gewicht=0.6 bart_art=kurz flicken=1 haut=middleage_caucasian_male",
}

if __name__ == "__main__":
    mh, sysa = sys.argv[1], sys.argv[2]
    namen = sys.argv[3:] or list(VORRAT)
    for name in namen:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("mensch_bauen.py")), mh, sysa, name] +
                           VORRAT[name].split(), capture_output=True, text=True)
        print(name, "ok" if r.returncode == 0 else "FEHLER\n" + r.stderr[-800:])
