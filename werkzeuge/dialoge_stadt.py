"""Schreibt die Alltagsdialoge der Stadtleute nach daten/dialoge/. Aufruf: python3 werkzeuge/dialoge_stadt.py
Texte als Liste: Die Person sagt eine davon, fest je Person und Tag; Einträge mit Bedingung nur, wenn sie gilt."""
import json, pathlib
ZIEL = pathlib.Path(__file__).resolve().parent.parent / "daten" / "dialoge"

def w(t, b=None):
    return {"text": t, "bedingung": b} if b else t

# Gerüchte, die überall in der Stadt erzählt werden, je nach Lage
GERUECHTE = [
    w("Man sagt, in Valdrenn rüstet der junge König. Aber das sagt man seit Jahren."),
    w("Die Fischer sagen, draußen vor den Inseln liegen fremde Boote. Ohne Lotsen. Die Hafenaufsicht hat nichts gesehen, sagt sie."),
    w("Mein Vetter fährt Korn nach Riverlock. Er sagt, dort wird mehr geflüstert als gehandelt."),
    w("Der Bürgermeister war wieder oben in der Burg. Wenn Joris Brandt zur Burg hinaufsteigt, wird hinterher irgendwas teurer."),
    w("Hast du die Signalfeuer gesehen? Die ganze Küste brennt. Meine Mutter hat die Fensterläden vernagelt.", "alarm>=2"),
    w("Die Händler aus Velmund sind abgereist, alle an einem Tag. Das ist nie ein gutes Zeichen.", "alarm>=2"),
    w("Es heißt, in Riverlock hat einer Briefe gefälscht. Für Gold aus Valdrenn. Ein Schreiber, sagen sie.", "kette_abgeschlossen"),
    w("Der Zollherr von Riverlock hat seinen eigenen Schreiber ausgeliefert, hört man. Das hätte ich ihm nicht zugetraut.", "dorn_ausgeliefert"),
    w("Einer aus Riverlock ist über die Brücke nach Osten geflohen, und der Orden hat ihn laufen lassen. So erzählt man es jedenfalls.", "dorn_geflohen"),
    w("Seit dem Winter sieht man mehr Wächter auf der Straße. Wachsamkeit, sagt der Rat. Ich sage: Angst.", "akt2_begonnen"),
]

def datei(name, daten):
    # Die Antworten stehen gleich unter dem Gruß; danach fragt "fragen" mit denselben Antworten nach.
    k = daten["knoten"]
    if "fragen" in k and k.get("start", {}).get("weiter") == "fragen":
        k["start"]["optionen"] = k["fragen"]["optionen"]
        del k["start"]["weiter"]
        k["fragen"]["text"] = [w("Sonst noch etwas?"), w("Noch etwas?"), w("Was noch?")]
    (ZIEL / f"{name}.json").write_text(json.dumps(daten, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")

def schlicht(name, gruss, eigenes_thema, eigenes_text, abschied, extra_optionen=(), extra_knoten=None):
    optionen = [
        {"text": "Was hört man in der Stadt?", "weiter": "geruecht"},
        {"text": eigenes_thema, "weiter": "thema"},
        *extra_optionen,
        {"text": "Gehabt Euch wohl.", "weiter": "ende"},
    ]
    knoten = {
        "start": {"text": gruss, "weiter": "fragen"},
        "fragen": {"text": "", "optionen": optionen},
        "geruecht": {"text": GERUECHTE, "weiter": "fragen"},
        "thema": {"text": eigenes_text, "weiter": "fragen"},
        "ende": {"text": abschied},
    }
    knoten.update(extra_knoten or {})
    datei(name, {"knoten": knoten})

schlicht("stadt_buerger",
    [w("Guten Tag, Wächter."), w("Ah, einer vom Orden. Ist etwas passiert?"), w("Schönes Wetter für den Markt, nicht wahr?"),
     w("Wächter {name}. Man kennt dich inzwischen im Viertel.", "rang>=4"),
     w("Ist es wahr, dass es Krieg gibt? Sag es mir ehrlich.", "alarm>=2"),
     w("Nicht jetzt, ich muss nach Hause, bevor es dunkel wird.", "abschnitt=nachmittag")],
    "Wie lebt es sich in Drachenstein?",
    [w("Eng, laut und teuer. Aber sicher. Solange oben in der Burg die Lichter brennen, schläft man hier gut."),
     w("Die Häuser steigen den Berg hinauf wie Treppenstufen. Wer unten am Kai wohnt, riecht nach Fisch, wer oben wohnt, nach Geld."),
     w("Zwanzigtausend Leute und eine Burg voller Leute, die nicht reden dürfen. Man gewöhnt sich an alles.")],
    [w("Pass auf dich auf."), w("Vigilamus, sagt ihr doch, oder?"), w("Grüß die Burg von mir.")])

schlicht("stadt_haendler",
    [w("Frische Ware, Wächter! Ach, ihr dürft ja nichts kaufen."), w("Schau ruhig, schauen kostet nichts."),
     w("Heute läuft es schlecht. Die Leute halten ihr Geld fest.", "akt2_begonnen"),
     w("Der halbe Markt ist schon zu. Ich bleibe, bis der Orden mich fortschickt.", "alarm>=2")],
    "Wie läuft der Handel?",
    [w("Gut genug. Das Salz kommt über Riverlock, der Fisch aus dem Meer, das Geld von oben."),
     w("Seit Riverlock schwankt, sind die Preise für Salz gestiegen. Die Leute merken es zuerst am Brot."),
     w("Wer handeln will, zahlt Marktgebühr an den Orden und Steuer an die Stadt. Zweimal zahlen für einmal verkaufen.")],
    [w("Komm wieder, wenn du einen Freund hast, der kaufen darf."), w("Gute Wache, Wächter.")])

schlicht("stadt_handwerker",
    [w("Ich hab zu tun, aber frag ruhig."), w("Ein Wächter vor meiner Werkstatt. Hat jemand was gegen mich vorgebracht?"),
     w("Die Burg hat wieder bestellt. Mehr als sonst.", "akt2_begonnen"),
     w("Die Burg nimmt alles, was ich mache. Für den Krieg, heißt es.", "alarm>=2")],
    "Was arbeitet Ihr?",
    [w("Was gebraucht wird. Kessel, Riemen, Fässer, Brot. Der Orden ist der beste Kunde, aber er zahlt spät."),
     w("Meine Lehrlinge sind alle beim Orden gelandet. Ich bilde sie aus, ihr nehmt sie mir weg."),
     w("Seit meinem Großvater stehen wir hier. Die Werkstatt hat drei Brände gesehen und den letzten Krieg.")],
    [w("Und jetzt lass mich arbeiten."), w("Gute Wache.")])

datei("stadt_kind", {"knoten": {
    "start": {"text": [w("Bist du ein echter Wächter? Darf ich deinen Säbel sehen?"),
                       w("Wir spielen Stille-Stunde. Wer redet, verliert! … Oh. Jetzt hab ich verloren."),
                       w("Mama sagt, ich soll nicht mit Wächtern reden. Warum eigentlich?"),
                       w("Ich werde auch Wächter, wenn ich groß bin. Oder Fischer."),
                       w("Hast du die Feuer gesehen? Die sind so hoch wie der Kirchturm!", "alarm>=2")],
              "optionen": [{"text": "Geh nach Hause, wenn es dunkel wird.", "weiter": "heim"},
                           {"text": "Spiel weiter.", "weiter": "ende"}]},
    "heim": {"text": "Jaja. Das sagen alle."},
    "ende": {"text": "Fang mich doch!"}}})

schlicht("streife",
    [w("Wächter {name}. Ruhige Straßen heute.", "rang>=4"), w("Streife. Nichts zu melden, bis jetzt."),
     w("Halt die Augen offen, Geselle.", "rang<4"),
     w("Die Hafenaufsicht hat mehr Leute angefordert. Wir gehen doppelte Runden.", "akt2_begonnen"),
     w("Alarm. Wir räumen die Märkte und schicken die Leute in die Häuser.", "alarm>=2"),
     w("Nachtstreife. Wer jetzt noch draußen ist, hat meist einen Grund.", "abschnitt=nacht")],
    "Worauf achtet die Streife?",
    [w("Auf Fremde ohne Lotsenmarke, auf Feuer, auf Leute, die zu viel fragen. Und darauf, dass die Stadt sieht, dass wir da sind."),
     w("Die Stadt hat keine eigene Wache. Den Markt verwaltet der Rat, aber die Straßen hüten wir."),
     w("Wer etwas sieht, meldet es dem Kammerhüter. Nicht dem Bürgermeister, nicht dem Zoll. Dem Kammerhüter.")],
    [w("Vigilamus."), w("In silentio.")])

schlicht("hafen",
    [w("Pass auf, wo du hintrittst, Wächter. Hier ist alles nass."), w("Die Netze flicken sich nicht von allein."),
     w("Heute kein guter Fang. Das Meer ist unruhig."), w("Das Schiff aus Riverlock ist überfällig. Wieder einmal.", "akt2_begonnen"),
     w("Alle Boote bleiben im Hafen. Befehl des Ordens.", "alarm>=2")],
    "Wie ist die Arbeit am Kai?",
    [w("Hart und früh. Wer bei Morgengrauen nicht draußen ist, fängt nichts."),
     w("Der Orden nimmt den Zehnten vom Fang und gibt uns dafür die Mole und die Lotsen. Ein fairer Handel, sagt mein Vater. Ich weiß nicht."),
     w("Jorin war ein Fischer, weißt du. Der erste Name auf eurer Ordenswand. Daran denken hier alle, wenn sie über den Orden fluchen.")],
    [w("Und jetzt geh mir aus dem Licht."), w("Guten Fang, sagt man bei uns.")])

datei("kaufmann_velmund", {"knoten": {
    "start": {"text": [w("Ein Wächter. Ich habe meine Lotsenmarke, sie liegt beim Hafenwächter."),
                       w("Drachenkai, weiter darf ich nicht. Ich kenne die Regeln, Wächter.")], "weiter": "fragen"},
    "fragen": {"text": "", "optionen": [
        {"text": "Was führt Euch hierher?", "weiter": "handel"},
        {"text": "Wie steht es in Velmund?", "weiter": "velmund"},
        {"text": "Gehabt Euch wohl.", "weiter": "ende"}]},
    "handel": {"text": "Salz und Pelze aus Valdrenn, dafür Fisch und Torf zurück. Keine Waffen, kein Pulver, keine Pferde. Ich weiß, was verboten ist, und meine Ladung wurde zweimal durchsucht.", "weiter": "fragen"},
    "velmund": {"text": [w("Die Handelshäuser verdienen gut, solange Frieden ist. Darum wollen sie Frieden. Der König will etwas anderes, aber der König kauft nichts bei uns."),
                         w("Man spricht in Velmund von Geschützen, die nach Westen gezogen werden. Ich sage nur, was man spricht.", "akt2_begonnen")],
                "weiter": "fragen"},
    "ende": {"text": "Möge die Stille halten. Für uns beide."}}})

datei("hafenaufsicht", {"knoten": {
    "start": {"text": [w("Hafenaufsicht. Kein Schiff legt hier an, ohne dass ich es weiß."),
                       w("Wächter {name}. Ruhiger Tag am Kai.", "rang>=4")], "weiter": "fragen"},
    "fragen": {"text": "", "optionen": [
        {"text": "Wer kommt alles in den Hafen?", "weiter": "wer"},
        {"text": "Der Kaufmann aus Velmund?", "weiter": "velmund"},
        {"text": "Vigilamus.", "weiter": "ende"}]},
    "wer": {"text": "Unsere Fischer, die Kornschiffe aus Riverlock und zweimal im Monat ein Kaufmann aus Velmund mit Lotsen. Fremde bleiben am Kai. Wer weiter will, braucht die Erlaubnis des Landkomturs.", "weiter": "fragen"},
    "velmund": {"text": "Teodor Vass. Kommt seit zwölf Jahren. Ich traue ihm, soweit ich seine Kisten durchsucht habe, und das habe ich gründlich.", "weiter": "fragen"},
    "ende": {"text": "In silentio."}}})

datei("kuester", {"knoten": {
    "start": {"text": [w("Willkommen vor St. Georg. Drinnen wird geschwiegen, wie bei euch in der Burg."),
                       w("Der Orden führt unsere Kirche als Ort der Stille. Wir beten, ihr schweigt. Es verträgt sich."),
                       w("Es kommen mehr Leute als sonst. Wenn die Angst wächst, wird die Kirche voll.", "akt2_begonnen")],
              "weiter": "fragen"},
    "fragen": {"text": "", "optionen": [
        {"text": "Erzählt mir von der Kirche.", "weiter": "kirche"},
        {"text": "Gehabt Euch wohl.", "weiter": "ende"}]},
    "kirche": {"text": "St. Georg, weil er mit dem Drachen kämpfte. Die Stadt hat sich das Wappentier vom Orden geborgt und den Heiligen dazu. Unter der Kirche liegen Gräber aus der Zeit, als hier nur die Burg stand.", "weiter": "fragen"},
    "ende": {"text": "Geh in Frieden. Oder in Stille, wie ihr sagt."}}})

datei("ratsdiener", {"knoten": {
    "start": {"text": "Das Rathaus der Stadt Drachenstein. Der Bürgermeister empfängt heute nicht.", "weiter": "fragen"},
    "fragen": {"text": "", "optionen": [
        {"text": "Was tut der Stadtrat?", "weiter": "rat"},
        {"text": "Gehabt Euch wohl.", "weiter": "ende"}]},
    "rat": {"text": [w("Er verwaltet den Markt, prägt die Münzen und streitet mit eurer Burg über die Hafengebühren. Bürgermeister Brandt sagt, die Stadt gehört den Bürgern und die Mauern dem Orden."),
                     w("Er tagt jeden Tag, seit es um Riverlock unruhig ist. Die Handelsfamilien fürchten den Krieg mehr als den König.", "akt2_begonnen")],
            "weiter": "fragen"},
    "ende": {"text": "Ich richte aus, dass der Orden gefragt hat."}}})

datei("fluechtling", {"knoten": {
    "start": {"text": "Bitte, ich habe nichts getan. Ich habe einen Schein vom Landkomtur, sieh her.", "weiter": "fragen"},
    "fragen": {"text": "", "optionen": [
        {"text": "Woher kommst du?", "weiter": "woher"},
        {"text": "Wie kommst du hier zurecht?", "weiter": "leben"},
        {"text": "Leb wohl.", "weiter": "ende"}]},
    "woher": {"text": "Aus dem Süden von Valdrenn. Die Ernte war schlecht, und der König hat das Korn für seine Soldaten genommen. Wir sind über Riverlock gekommen, mein Bruder und ich. Er ist jetzt Anwärter in der Burg.", "weiter": "fragen"},
    "leben": {"text": [w("Ich wasche für die Leute am Markt. Sie bezahlen schlecht und schauen schief. Weil Valdrenn Spione als Flüchtlinge schickt, sagen sie. Vielleicht stimmt es sogar. Aber ich bin keiner."),
                       w("Seit dem Alarm sehen mich alle an, als hätte ich die Feuer selbst angezündet.", "alarm>=2")],
              "weiter": "fragen"},
    "ende": {"text": "Danke, dass du gefragt hast. Das tun nicht viele."}}})
print("ok")
