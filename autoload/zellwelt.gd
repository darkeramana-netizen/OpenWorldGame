extends Node
## Lädt Zellinhalte nach ihrem Abstand zum Spieler nach und gibt ferne wieder frei (docs/05-phase2-zellen.md).
##
## Ein Zellinhalt ist ein Knoten, der sich mit melde() anmeldet und diese Methoden hat:
##   zell_rechteck() -> Rect2          Grundfläche in Welt-x/z (für den Abstand)
##   zell_abstand() -> float           geladen, solange der Spieler näher ist (entladen erst ab + PUFFER)
##   zell_dateien() -> PackedStringArray  Dateien, die vorher im Hintergrund geladen werden (darf leer sein)
##   zell_bauen()                      Inhalt aufbauen (Hauptthread)
##   zell_leeren()                     Inhalt freigeben
##
## Verfahren (nach Sorrow-Engine): Reihenfolge nach Abstand, nah zuerst; Aufbau mit Zeitbudget je Bild (bei stehendem
## Ladebildschirm größer); Dateien vorher im Hintergrund laden; Entladen erst mit Puffer hinter dem Ladeabstand,
## damit an der Grenze nicht ständig geladen und entladen wird; Prüfung alle PRUEF_S Sekunden.

## Entladen erst so viel weiter weg als geladen (Meter)
const PUFFER := 32.0
## So oft wird geprüft, was geladen sein soll (Sekunden)
const PRUEF_S := 0.2
## Zeit je Bild für den Aufbau (ms); mindestens ein Inhalt je Bild wird gebaut
const BUDGET_MS := 3.0
## Zeit je Bild, solange der Ladebildschirm steht
const BUDGET_VORHANG_MS := 40.0
## Höchstens so viele Dateien gleichzeitig im Hintergrund
const MAX_VORLADEN := 4

## true: alle gemeldeten Inhalte werden sofort gebaut (wie ohne Zellen), z. B. für Werkzeuge
var aus := false
## Feste Position statt der Kamera (für Tests); null: aktive Kamera
var ziel_position: Variant = null
## Zähler für Tests und Messungen
var gebaut := 0
var geleert := 0
## Längster Aufbau eines einzelnen Inhalts und Summe aller Aufbauten (ms), für die Messung
var groesster_bau_ms := 0.0
var bau_ms_summe := 0.0

enum { LEER, VORLADEN, BEREIT, GEBAUT }

var _inhalte: Array = []          # gemeldete Knoten
var _stufe := {}                  # Instanz-ID -> LEER/VORLADEN/BEREIT/GEBAUT
var _laden: Array = []            # nach Abstand sortiert: sollen geladen sein, sind es aber noch nicht
var _seit_pruefung := 0.0
var _neu_pruefen := false


## Meldet einen Zellinhalt an. Er wird gebaut, sobald der Spieler nah genug ist (bei aus sofort).
func melde(n: Node) -> void:
	if n in _inhalte:
		return
	_inhalte.append(n)
	_stufe[n.get_instance_id()] = LEER
	if aus:
		_baue(n)
		return
	_neu_pruefen = true


func abmelde(n: Variant) -> void:
	if not is_instance_valid(n):
		_aufraeumen()
		return
	_inhalte.erase(n)
	_laden.erase(n)
	_stufe.erase((n as Object).get_instance_id())


func ist_gebaut(n: Node) -> bool:
	return _stufe.get(n.get_instance_id(), LEER) == GEBAUT


## Inhalte, die schon gebaut sein sollten, es aber noch nicht sind (für den Ladebildschirm)
func wartend() -> int:
	if _neu_pruefen:
		_pruefe()
	return _laden.size()


## Alles neu bewerten (z. B. nach einem Sprung des Spielers)
func pruefe_sofort() -> void:
	_pruefe()


func _process(delta: float) -> void:
	if _inhalte.is_empty():
		return
	_seit_pruefung += delta
	if _neu_pruefen or _seit_pruefung >= PRUEF_S:
		_pruefe()
	_baue_mit_budget()


## Position, um die geladen wird
func position_() -> Vector3:
	if ziel_position != null:
		return ziel_position
	var vp := get_viewport()
	var kamera := vp.get_camera_3d() if vp != null else null
	return kamera.global_position if kamera != null else Vector3.ZERO


static func abstand_zu(rechteck: Rect2, p: Vector3) -> float:
	var q := Vector2(clampf(p.x, rechteck.position.x, rechteck.end.x), clampf(p.z, rechteck.position.y, rechteck.end.y))
	return q.distance_to(Vector2(p.x, p.z))


func _pruefe() -> void:
	_seit_pruefung = 0.0
	_neu_pruefen = false
	_aufraeumen()
	var p := position_()
	var soll: Array = []
	for n: Node in _inhalte:
		var d := abstand_zu(n.zell_rechteck(), p)
		var grenze: float = n.zell_abstand()
		var stufe: int = _stufe[n.get_instance_id()]
		if stufe == GEBAUT:
			if d > grenze + PUFFER:
				_leere(n)
		elif d <= grenze:
			soll.append([d, n])
		elif stufe != LEER:
			_verwerfe_vorrat(n)          # war vorgeladen, ist wieder zu weit weg
	soll.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_laden = soll.map(func(e: Array) -> Node: return e[1])
	var laufend := 0
	for n: Node in _laden:
		if _stufe[n.get_instance_id()] == VORLADEN:
			laufend += 1
	for n: Node in _laden:
		if laufend >= MAX_VORLADEN:
			break
		if _stufe[n.get_instance_id()] == LEER:
			_vorladen(n)
			laufend += 1


func _vorladen(n: Node) -> void:
	var dateien: PackedStringArray = n.zell_dateien()
	var angefragt := false
	for d in dateien:
		if ResourceLoader.exists(d) and ResourceLoader.load_threaded_get_status(d) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(d, "", false, ResourceLoader.CACHE_MODE_IGNORE)
			angefragt = true
	_stufe[n.get_instance_id()] = VORLADEN if angefragt else BEREIT


func _vorrat_fertig(n: Node) -> bool:
	for d in n.zell_dateien():
		var s := ResourceLoader.load_threaded_get_status(d)
		if s == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


func _verwerfe_vorrat(n: Node) -> void:
	for d in n.zell_dateien():
		if ResourceLoader.load_threaded_get_status(d) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(d)
	_stufe[n.get_instance_id()] = LEER


func _baue_mit_budget() -> void:
	if _laden.is_empty():
		return
	var budget := BUDGET_VORHANG_MS if Ladevorhang.sichtbar else BUDGET_MS
	var start := Time.get_ticks_usec()
	var laufend := 0
	for n: Variant in _laden:
		if is_instance_valid(n) and _stufe.get((n as Node).get_instance_id(), LEER) == VORLADEN:
			laufend += 1
	var i := 0
	while i < _laden.size():
		var n: Variant = _laden[i]
		if not is_instance_valid(n):
			_laden.remove_at(i)
			continue
		var id := (n as Node).get_instance_id()
		var stufe: int = _stufe.get(id, LEER)
		if stufe == VORLADEN and _vorrat_fertig(n):
			stufe = BEREIT
			_stufe[id] = BEREIT
			laufend -= 1
		if stufe == LEER and laufend < MAX_VORLADEN:
			_vorladen(n)
			stufe = _stufe[id]
			if stufe == VORLADEN:
				laufend += 1
		if stufe != BEREIT:
			i += 1
			continue
		_laden.remove_at(i)
		_baue(n)
		if (Time.get_ticks_usec() - start) / 1000.0 >= budget:
			break


func _baue(n: Node) -> void:
	var t := Time.get_ticks_usec()
	n.zell_bauen()
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	groesster_bau_ms = maxf(groesster_bau_ms, ms)
	bau_ms_summe += ms
	_stufe[n.get_instance_id()] = GEBAUT
	gebaut += 1


## Zahlen für die Messung
func zahlen() -> Dictionary:
	return {"gemeldet": _inhalte.size(), "gebaut": gebaut, "geleert": geleert,
		"groesster_bau_ms": snappedf(groesster_bau_ms, 0.1), "bau_ms_summe": snappedf(bau_ms_summe, 0.1)}


func _leere(n: Node) -> void:
	n.zell_leeren()
	_stufe[n.get_instance_id()] = LEER
	geleert += 1


func _aufraeumen() -> void:
	var gueltig: Array = []
	for n: Variant in _inhalte:
		if is_instance_valid(n) and (n as Node).is_inside_tree():
			gueltig.append(n)
	if gueltig.size() == _inhalte.size():
		return
	_inhalte = gueltig
	var ids := {}
	for n: Node in _inhalte:
		ids[n.get_instance_id()] = true
	for id: int in _stufe.keys():
		if not ids.has(id):
			_stufe.erase(id)
	_laden = _laden.filter(func(n: Variant) -> bool: return is_instance_valid(n) and ids.has((n as Node).get_instance_id()))
