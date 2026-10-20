# Projektstatus: Main Menu, Upgrades und Ein-Runden-Zeitrennen

## Sitzpose Und Wiederverwendbare Constraints (19.10.2026)

Die fehlgeschlagene Schienbein-Erweiterung der Sitzhoehenmessung ist ersetzt:
Becken/Oberschenkel bestimmen die Auflage, Beine werden bei festen Fusszielen
separat auf Reichweite und Sitz-/Rahmenfreiheit geprueft. Begrenzte Sitztiefen-
und Oberkoerpersuche pruefen die gemeinsame Erreichbarkeit; Konflikte werden
explizit gemeldet, statt den ganzen Fahrer unbemerkt anzuheben.

Motorwechsel verwenden eine gemessene Handhuelle, korrigierte Handflaechen,
deterministische Ellbogenkandidaten und einen geglaetteten 0.4-Sekunden-Pfad.
Die Reichweitenpruefung umfasst Schubphasen und beide Atemextreme. Sitzprofil am
Fahrzeug konfigurierbar; Fahrphysik, Strecke, Kameras und bestehende fremde
Aenderungen bleiben erhalten. Kein Reset, Checkout oder Commit.

Ergebnisse: 52 gezielte Sitzpose-, 31 Smoke-, 79 Renn- und 205 Upgrade-Checks
headless bestanden; 245 grafische Upgrade-Checks bei 1080p auf Intel Iris Xe.
Automatische Runde weiterhin 00:17.235 ohne Wandkontakt. Finale Front-/Seiten-
und Schubaufnahmen angesehen; keine menschliche Probefahrt. Handrim-Abstand
etwa 2.1-2.4 cm, Motor-Handauflage etwa 8 mm: keine exakte Greifsimulation.

Profilfelder, Integrationsschritte, Nachweise und Einschraenkungen:
[SEATING.md](SEATING.md). Die folgenden Berichte sind historische Zwischenstaende.

## Handfreiheit Und Workshop-Orbit (16.10.2026)

Ursache der Handueberschneidung: Die STOCK-Skelettpose platzierte die Handgelenke
bei X=+/-0.558 nahe am Rad und richtete die Finger abwaerts in dessen Volumen.
Die Figur besitzt keine physikalischen Handkollider; die Fahrzeugkollision war
nicht ursaechlich. Die manuelle Handbahn liegt jetzt weiter aussen und hoeher
(X=+/-0.66), mit angepasster Fingerorientierung. Position und Orientierung blenden
in 0.32 Sekunden zwischen Armlehnen- und manueller Pose um, auch bei Gegenwechseln.
Fahrphysik, Radkollisionen, Modelle und Engine-Stats wurden nicht veraendert.

Die vorher feste Workshop-Kamera erlaubt jetzt horizontales Orbit und begrenzte
Hoehenaenderung per linkem Mausziehen ueber dem Modell. Die fokussierbaren Buttons
< / FRONT / > bieten 45-Grad-Schritte und direkte Vorderansicht. Startansicht ist
schraeg von vorn. Motorwechsel erhalten den Blickwinkel. Nur im Workshop und
READY aktiv; beim Rennstart wird der Drag beendet und die UI ausgeblendet.

Pruefung: 31 Smoke-, 79 Renn- und 158 Upgrade-Checks headless bestanden, ebenso
Import und Start. Automatische Runde weiterhin 00:17.235 ohne Wandkontakt.
Grafisch 192 Upgrade-Checks bei 720p, nach ergaenzten Bewegungstests 198 bei 1080p
bestanden (GL Compatibility, Intel Iris Xe). Mausereignisse durchlaufen den
Viewport-GUI-Pfad, Tastaturereignisse Input.parse_input_event. Getestet wurden
beide Motorzustaende, Ansichtserhalt, Front/Seite/Rueckseite, Begrenzung der Hoehe,
deaktivierter Orbit im Rennen und die bestehende Fahrsteuerung.

Handtest: Aus Originalgewichten/Bind-Posen verformte Hand-/Fingervertices werden
gegen konservative Radzylinder geprueft, fuer sechs Wechselablaeufe und je 16
Phasen vorwaerts/rueckwaerts sowie Ruhe/Ausrollen. Dies ist eine diskrete
Geometriepruefung, keine kontinuierliche Kollisionssimulation oder exakte
Greifsimulation. Echte Front-/Seiten-/Renn- und Wechselaufnahmen wurden angesehen;
Gesicht sichtbar, keine Hand-Rad-Durchdringung in den geprueften Ansichten.
Aufnahmen: user://upgrade-menu-51388-1583004-*.png (1080p) und
user://upgrade-menu-32720-1503380-*.png (720p). Keine menschliche Probefahrt.

## Reviewkorrekturen (16.10.2026)

- Fahr- und Renntests verwenden vor dem Szenenstart einen expliziten STOCK-Zustand
  ohne persoenlichen Upgrade-Speicherpfad. Keine Aenderung an echten Spielstaenden.
- Upgrade-Speicherung schreibt eine temporaere Datei und ersetzt das Ziel erst
  nach erfolgreichem Flush. Bei Fehler bleiben Auswahl und `save_pending` im
  Speicher; identische Auswahl versucht erneut zu schreiben. Erst Erfolg loescht
  Fehler und Pending-Status. Fehlgeschlagene Ersetzungen entfernen die Tempdatei.
- Ungesicherte Bestzeiten werden beim naechsten Rennversuch, bei jedem Zieleinlauf
  und bei Rueckkehr zum Hauptmenue erneut gespeichert. Eine langsamere Runde kann
  so den bereits schnelleren, noch ungesicherten Rekord retten. Kein Retry pro Frame.
- ENGINE bietet eine tastaturbedienbare STOCK-Aktion mit Motorabbau, Basisstats,
  sichtbarer Auswahl und persistenter Speicherung. Bestehende drei Motoren bleiben.
- Regressionen pruefen einen simulierten Austauschfehler (alte Datei bleibt
  bytegleich), einen echten FileAccess-Fehler, identische Retry-Auswahl, frisches
  Laden und Bestzeitrettung. Tatsachlicher Austausch vorhandener Dateien auf
  Windows wird durch die erfolgreichen Engine-Wechsel mitgeprueft; ein Stromausfall
  oder Prozessabbruch waehrend des Schreibens wurde nicht provoziert.

Aktuelle Ergebnisse: Import/Headless-Start bestanden; 31 Smoke-, 124 Upgrade-
und 79 Rennpruefungen ohne Grafik. Automatische STOCK-Runde `00:17.235`, kein
Wandkontakt. Je 152 grafische Upgrade-Pruefungen bei 1280x720 und 1920x1080 auf
Intel Iris Xe bestanden. STOCK-Aufnahmen beider Groessen angesehen, Buttons und
Fokusrahmen passen ins Fenster. Tab/Enter durch Hauptmenue, Kategorien, Engine,
STOCK und BACK wird mit InputEventKey geprueft, nicht nur mit Signalaufrufen.
Die Speicherwarnungen dieser Testlaeufe sind erwartet. Keine gemeldeten
Skriptdiagnostikfehler. Die aelteren Testergebnisse unten bleiben historisch.

Bewusst nicht Teil dieses schnellen Durchgangs: frei belegbare Fahraktionen,
Gamepads, Architekturumbau und menschliche Probefahrt. Die Fahrphysik, Strecke
und Darstellung wurden nicht veraendert. Testbefehle und aktueller lokaler
Godot-Pfad stehen in der [README](../README.md).

## Modell- Und Workshopueberarbeitung (16.10.2026)

Umgesetzt im vorhandenen Projekt, ohne Aenderung an Strecke, InputMap,
CharacterBody3D-Kollisionsform, Fahrformeln, Upgrade-Daten oder Rennregeln.
Die folgenden Abschnitte vom 15./13.10. sind historische Nachweise und
beschreiben teilweise die inzwischen ersetzte Primitive-Darstellung.

### Sicherung Und Umfang

Vor Beginn war der Git-Status sauber. Ausgangscommit:
`608973d74180ff02d596691eeb83579358861057`.
Verifizierte externe Sicherung per `git archive`:
`../WheelChairRacer-before-realism-608973d.zip`, 9,593,417 Bytes.
Kein Commit, Branch, Push, destruktiver Git-Befehl oder zweites Projekt.

Rollstuhl: Poly Haven Wheelchair 01 mit echten Speichen, Naben, Greifringen,
Rahmen, Bremshebeln und texturiertem Sitz. Sieben getrennte starre Baugruppen,
richtige Rollachsen, gemeinsam schwenkende Rollen/Gabeln, lokale Fussplatten.
Figur: bekleidetes 54-Bone-Skinning mit Sitz-, Fuss- und Handmarkern, dezenter
abschaltbarer Ruhebewegung, manueller Schubgeste ohne Motor und ruhiger
Armlehnenpose mit Motor. Werkstatt: matte Flaechen, Key/Fill/Rim, Schatten und
neutraler Reflexionshimmel. Der direkte Rennstart stellt Tageslicht wieder her.
Workshop und Rennen verwenden dieselbe Presentation am selben Spieler.

Die alte Primitive-Modellgenerierung wurde aus dem Fahrzeugskript entfernt.
Alle Originalquellen und vorbereiteten Ressourcen liegen lokal vor;
[Assetquellen und Lizenzen](ASSET_SOURCES.md) enthalten Downloadlinks,
Pruefsummen, Bearbeitungsschritte und die **KI-Herkunft der Figur**.

### Automatisch Geprueft

Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility. Finale Pruefungen:

| Pruefung | Ergebnis |
| --- | --- |
| Ressourcenimport / Headless-Start (180 Frames) | Bestanden |
| Smoke, Headless | 30 bestanden |
| Upgrades, Headless | 102 bestanden |
| Rennen, Headless | 71 bestanden, 0 fehlgeschlagen |
| Upgrades, echte OpenGL-Ausgabe | 128 bestanden |
| Rennen, echte OpenGL-Ausgabe | 77 bestanden, 0 fehlgeschlagen |
| Native 1920x1080-Bildaufnahme, sechs Ansichten | Bestanden |
| Editor-Diagnostik der betroffenen Skripte | Keine gemeldeten Fehler |

Vollstaendige Runde mit InputMap: `00:17.235`, sechs Kontrollpunkte, kein
Wandkontakt. Ebenfalls geprueft: Pause, Reset, Neustart, Countdown, Ziel,
Speicherung, alle Motoren, Navigation, Bremsen, Rueckwaerts, Ausrollen,
Wrist-/Ankle-Ziele, Radachsen, Gabellenkung und abschaltbares Idle.
Tests verwenden temporaere Speicherpfade; echte Spielstaende bleiben erhalten.
Dies ersetzt keine menschliche Probefahrt.

### Bilder Und Sichtpruefung

Die Bilder sind echte Godot-Renderaufnahmen, keine Mockups oder Anbieterbilder.
Vorher wurde vor dem Modelltausch aufgenommen; diese Serie bleibt unveraendert.
Kameratransformationen und FOV stehen in den JSON-Protokollen. Die Chair-Ansicht
ist eine Detailansicht und schneidet den oberen Kopf bewusst am Bildrand ab.

| Ansicht | Vorher | Nachher |
| --- | --- | --- |
| Workshop mit UI | [Bild](visual-review/presentation/before-workshop.png) | [Bild](visual-review/presentation/after-workshop.png) |
| Rollstuhl-Detail | [Bild](visual-review/presentation/before-chair.png) | [Bild](visual-review/presentation/after-chair.png) |
| Seite | [Bild](visual-review/presentation/before-side.png) | [Bild](visual-review/presentation/after-side.png) |
| Front | [Bild](visual-review/presentation/before-front.png) | [Bild](visual-review/presentation/after-front.png) |
| Rueckseite | [Bild](visual-review/presentation/before-rear.png) | [Bild](visual-review/presentation/after-rear.png) |
| Rennen | [Bild](visual-review/presentation/before-race.png) | [Bild](visual-review/presentation/after-race.png) |

Sichtpruefung: Figur/Rollstuhl, Kleidungsoberflaeche, Sitz-/Fussanordnung,
Handorientierung, Motoranbindung, Schatten, UI-Lesbarkeit und Rennansicht.
Eine vereinfachte 61K-Figur zeigte Kleidungsrisse und wurde verworfen.
Die finale Figur behaelt 244,257 Dreiecke ohne automatische LODs; der Rollstuhl
40,252 mit LODs. Hinzu kommen die vorhandenen Motoren und wenige Fussstuetzen.
Handgelenk-Zielpruefungen sind kein Nachweis kollisionsfreier Finger/Polster.

### Leistung Und Grenzen

Tatsaechlicher Rechner: Dell G15 Special Edition 5521, rund 64 GiB RAM,
RTX 3060 Laptop plus Intel Iris Xe. Der Renderer waehlte **Intel Iris Xe**,
OpenGL 3.3, Treiber 32.0.101.7088. Keine Messung auf ASUS TUF/RTX 4070/16 GB.
Standalone Godot-Editorbinary, kein Release-Export, native 1920x1080, 2x MSAA,
VSync aus. Je statischer Ansicht 60 Warmup-Frames, dann 240 Wallclock-Intervalle;
Spieler-/Rennsimulation eingefroren. Kein GPU-Profiling oder Fahrbenchmark.

| Ansicht | Vorher Mittel ms | Nachher Mittel ms | Nachher p95 ms | Nachher FPS |
| --- | ---: | ---: | ---: | ---: |
| Workshop | 24.045 | 6.364 | 8.501 | 157.14 |
| Chair | 5.843 | 6.441 | 8.228 | 155.25 |
| Seite | 6.119 | 6.102 | 7.813 | 163.89 |
| Front | 4.892 | 5.776 | 7.250 | 173.14 |
| Rueckseite | 10.486 | 6.377 | 8.813 | 156.80 |
| Rennen | 7.427 | 8.965 | 16.153 | 111.54 |

Rohdaten: [vorher](visual-review/presentation/before.json),
[nachher](visual-review/presentation/after.json). Werte schwanken erheblich:
ein frueherer final-topologischer Lauf erreichte im Workshop nur 13.52 FPS
mit p95 538.99 ms, die anderen Ansichten ca. 84-90 FPS. Die Ursache dieses
Ausreissers wurde nicht isoliert. Daher kein belastbarer Speedup oder garantiertes
FPS-Minimum. Die Rennbeleuchtung wurde zusaetzlich korrigiert; der Rennvergleich
isoliert somit nicht die Modellkosten. RAM/VRAM, Exportgroesse und Langzeitverhalten
wurden nicht gemessen. Original und vorbereitete Figur werden gemeinsam geladen.

### Offen / Manuell Abzunehmen

- Die Figur ist glaubwuerdiger und detailliert, aber stilisiert, nicht fotoreal.
  Alter Helm/Brille fehlen. Die Jacke ist warmbraun statt der alten orangen Form.
- Finger greifen die Ringe nicht exakt; Schubzyklus und Rueckwaertsanimation sind
  vereinfacht. Kleine Kontaktueberschneidungen sind nicht ausgeschlossen.
- Keine medizinische/biomechanische Validierung, echte Radphysik, Stoffsimulation
  oder neu konstruierter realer Motor. Bestehende Motoren bleiben Arcade-Modelle.
- Hohe Figurenpolygonzahl: fuer mehrere Fahrer/Low-End braucht es gezielte
  Retopologie und erneut gepruefte LODs; die automatische Reduktion reichte nicht.
- Nicht getestet: menschliche Probefahrt, Release-Export, Zielhardware,
  Langzeitsitzung und mehrere Aufloesungen der finalen Darstellung.
- Keine blockierende Konto-/Lizenz-/Toolabhaengigkeit; der Projektstart ist lokal.

Manuelle Abnahme: F5, UPGRADE/ENGINE, alle drei Motoren und Stats pruefen;
zurueck zu PLAY, W/S/A/D, Ausrollen, Rueckwaerts und R pruefen; mit Escape
pausieren/fortsetzen; Runde beenden, neu starten und nach Neustart gespeicherte
Engine/Bestzeit kontrollieren. Dabei Haende, Fussauflage, Radrotation und
Bildruhe waehrend Kurven und Motorwechseln beobachten. Dies ist noch offen.

## Historischer Stand

Meilenstein (15.10.2026): Main Menu, persistente Engine-Upgrades,
ein fahrzeuggebundener Garagen-Showcase und eine verbesserte Fahrerpose mit
radgekoppelter Schubanimation;
die folgenden frueheren Renn- und Gestaltungstests bleiben als Nachweise erhalten.

Stand der frueheren Rennintegration: 13.10.2026. Implementiert im bestehenden WheelChairRacer-Projekt.
Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility, OpenGL 3.3 auf Intel
Iris Xe. Hauptszene weiterhin `scenes/main.tscn`. Kein zweites Projekt,
keine neuen Abhaengigkeiten, keine neuen Spielmodi.

## Upgrade-Garage (15.10.2026)

- **UPGRADE** oeffnet eine dunkle, industriell gestaltete Workshop-Ansicht mit
  eigener Showroom-Kamera, Filmic-Umgebung und warmem Schluessel-/kuehlem Rim-Licht.
- Der bestehende Rollstuhl samt Fahrer bleibt das grosse 3/4-Rueckansicht-Zentrum;
  die Umgebungsgeometrie wird nur in den Upgrade-Seiten eingeblendet.
- `PlayerUpgrades` enthaelt pro Motor die Stats und eine `visual_id`.
  `engine_visuals.gd` baut daraus drei unterschiedliche prozedurale Designs:
  kompakter COMET-Antrieb, mechanischer RALLY-Doppelantrieb und futuristischer
  LAUNCH-Doppelschubkoerper.
- Das jeweils einzige Motormodell ist Kind von `Wheelchair/EngineMount` unter
  dem Sitz. Wechseln laesst es in etwa 0,32 Sekunden herabgleiten und den
  ausgewaehlten Antrieb einrasten. Die persistierte Auswahl und die Gameplay-
  Stats bleiben dieselbe gemeinsame Upgrade-Datenquelle.
- Engine-Wahl, Modellidentitaet, Parent-Hierarchie, Einzelmontage, Navigation,
  Save/Reload und Fahrzeuggestats werden im Upgrade-Regresstest geprueft.

## Fahrerpose Und Schubanimation (15.10.2026)

- Die Figur bleibt prozedural, ist aber unter `Wheelchair/Rider` und
  `UpperBody` gruppiert. Dieses austauschbare Modell-Root benoetigt weder ein
  Skelett noch externe Assets oder Animation-Plugins.
- Becken und Oberschenkel sitzen auf dem Kissen; die Knie beugen nach vorn und
  die Schuhe stehen auf der Fussstuetze. Die Werkstattpose wurde frontal und
  seitlich gerendert, um Sitzkontakt und Beinverlauf zu kontrollieren.
- Ein leichtes Zweisegment-Armsetup positioniert die Haende an den Handringen.
  Waehrend der Fahrt folgt der Schubbogen der tatsaechlichen Radrotation; beim
  Ausrollen kehren Arme und Oberkoerper in etwa 0,22 Sekunden zur Ruhepose
  zurueck. S bremst bis zum Stillstand und faehrt bei weiterem Halten
  rueckwaerts; W schaltet zur Vorwaertsbewegung. Die Engine-Montage bleibt
  unveraendert.
- Der Upgrade-Regresstest prueft Sitz-/Beinposition, Handkontakt, vorwaerts und
  rueckwaerts synchronisierte Rad-/Armbewegung, Lenkung, Stillstand,
  Engine-Anbindung und Werkstattansichten.

## Bestand Und Uebernommene Funktionen

Vor Beginn existierten Fahrzeugbewegung, Startpositionsreset, Folgekamera,
Geschwindigkeitsanzeige, Parkgestaltung und Tests, aber keine Rennverwaltung,
Kontrollpunkte, Zeitnahme, Pause oder Bestzeitspeicherung.

- Bestehende CharacterBody3D-Bewegung inklusive Beschleunigung, Bremsen,
  Lenkung, Hoechstgeschwindigkeit, Kollisionen und visueller Raddrehung beibehalten.
- Reset und das vorhandene `respawned`-Signal fuer Kontrollpunktreset und
  unmittelbares Kameraruecksetzen wiederverwendet.
- Bestehende Streckenpunkte, Start-/Ziellinie, HUD, Renderer, Materialien,
  Beleuchtung und Parkdekoration weiterverwendet.
- Bestehende Smoke- und Grafiktests angepasst, nicht durch Paralleltests ersetzt.

Der Rundkurs ist geschlossen. Alle 88 Abschnitte wurden auf drei Fahrlinien mit
dem Fahrzeugkollisionskoerper geprueft. Zusaetzlich wurde die vollstaendige Runde
mit realer Fahrzeugbewegung ueber InputMap automatisch gefahren. Kein blockierendes
Hindernis und kein Wandkontakt dabei festgestellt; die Strecke wurde nicht umgebaut.
Die Kollisions-Fingerprints entsprechen weiterhin dem Stand vor diesem Meilenstein.

Git war bei der ersten Bestandsaufnahme noch nicht eingerichtet. Bei der
Fortsetzung war ein Repository vorhanden und `git status --short` leer.
Zwischenzeitliche Benutzerarbeit wurde nicht zurueckgesetzt; kein Commit oder Push
wurde fuer diesen Meilenstein durch den Assistenten ausgefuehrt.

## Implementierter Ablauf

`READY -> COUNTDOWN -> RACING -> FINISHED`; Pause ist ein separater SceneTree-Zustand,
damit der vorherige Rennzustand beim Fortsetzen erhalten bleibt.

- Startmenue mit fokussiertem "Rennen starten". Enter oder Leertaste bestaetigen;
  Tab und Pfeiltasten bedienen die Menues ohne Maus.
- Countdown 3, 2, 1, Los! Vor der Freigabe sind Bewegung und Rennzeit gesperrt.
  Freigabe und Start der Zeitnahme erfolgen im selben Physiktakt.
- Genau eine Runde, laufende Zeit `MM:SS.mmm`, Kontrollpunktzaehler 0/6 bis 6/6,
  bestehende Geschwindigkeitsanzeige unveraendert vorhanden.
- Sechs gerichtete Kontrolllinien aus vorhandenen Streckenpunkten: rechte Gerade,
  oberer Scheitelpunkt, linke Gerade und drei Punkte im unteren Bogen.
  Nur die Spielerbewegung zaehlt, ausschliesslich am naechsten erforderlichen Punkt.
- Ueberquerung wird zwischen vorheriger und aktueller Position geprueft, nicht
  durch wiederholten Aufenthalt in einem Trigger. Falsche Richtung, seitliches
  Verfehlen, doppelte und uebersprungene Kontrollpunkte geben keinen Fortschritt.
- Das Ziel an der vorhandenen Startmarkierung zaehlt erst nach 6/6 und nur
  vorwaerts. Die Startposition bzw. erste Zielueberfahrt beendet kein Rennen.
- Rennzeit folgt aktiven Physiktakten; beim Zieleinlauf wird die Ueberquerung
  innerhalb des letzten Takts interpoliert. Pausezeit zaehlt nicht mit.
- Ergebnis mit Rundenzeit, bisheriger Bestzeit, optional "Neuer Rekord!" und
  fokussiertem "Erneut starten". Nach Zieleinlauf stoppen Fahrzeug und Zeit.
- Escape pausiert und setzt fort. Das Pausenmenue verarbeitet weiterhin Eingaben
  und bietet "Fortsetzen" sowie "Neuer Versuch".
- R und das vorhandene Auffangen nach einem Sturz setzen zum letzten gueltigen
  Kontrollpunkt in Fahrtrichtung zurueck. Der Ruecksetzpunkt liegt 1.5 m hinter
  dessen Linie in Fahrtrichtung, innerhalb der Fahrbahn. Ohne Kontrollpunkt wird
  die urspruengliche Startposition verwendet.
- Reset setzt weder Zeit noch Fortschritt zurueck. Der Positionssprung wird von
  der Ueberquerungspruefung ausgeschlossen. Im Countdown und in der Pause ist
  der Spieler nicht ruecksetzbar.
- Neue Versuche setzen Zeit, Fortschritt, Countdown, Position, Geschwindigkeit,
  Ergebnis und Rekordmeldung zurueck; die Bestzeit bleibt erhalten.

## Speicherung

Produktivdatei: `user://best_time_v1.json`, JSON mit Versionsnummer und positiver,
ganzzahliger Bestzeit in Millisekunden. Auf Windows normalerweise unter
`%APPDATA%\Godot\app_userdata\WheelChairRacer\`.

Nur eine gueltig beendete, schnellere Runde schreibt die Datei. Zunaechst wird
eine temporaere Datei geschrieben und anschliessend umbenannt. Fehlende,
unlesbare, uebergrosse, ungueltige oder nicht passende Dateien werden als
"keine Bestzeit" behandelt. Ein Schreibfehler verhindert das Ergebnis nicht;
das Ergebnis zeigt dann einen Speicherhinweis. Keine Cloud-Synchronisation.

Die Tests verwenden ein eigenes `user://race-tests-<Prozess>-<Zeit>/`-Verzeichnis,
das danach bereinigt wird. Smoke- und Grafiktests deaktivieren den Bestzeitpfad.
Echte Bestzeiten werden von diesen Tests weder gelesen noch ueberschrieben.

## Tatsaechlich Ausgefuehrte Pruefungen

Alle folgenden finalen Durchlaeufe endeten erfolgreich:

| Pruefung | Ergebnis |
| --- | --- |
| Godot-Version | 4.7.2 stable bestaetigt |
| `--headless --path . --editor --import` | Keine Import-/Skriptfehler |
| `--headless --path . --quit-after 180` | Hauptszene startet |
| `--path . --quit-after 180` | Grafischer Start mit Compatibility |
| `tests/smoke_test.gd`, headless, fixed-fps 60 | 30 Pruefungen bestanden |
| Derselbe Smoke-Test mit Grafik bei 1920x1080 | 36 inklusive Bildpruefungen bestanden |
| `tests/race_test.gd`, headless, fixed-fps 60 | 71 Pruefungen bestanden |
| Derselbe Renntest mit Grafik bei 1920x1080 | 77 inklusive sechs Aufnahmen bestanden |
| `tests/visual_review.gd -- --capture-only` | Unveraenderte Kollisionen/Fahrbelegung, vier echte 1080p-Bilder |
| `tests/upgrade_test.gd`, headless, fixed-fps 60 | 90 Pruefungen bestanden |
| Derselbe Upgrade-Test mit GL Compatibility bei 1280x720 | 114 Pruefungen bestanden; Sitzpose, Front-/Seitenansicht, Vorwaerts-/Rueckwaertsschub, Garage und alle drei Motoren gerendert/geprueft |

Der Renntest prueft geordnete, uebersprungene, doppelte und falschrichtig
ueberfahrene Kontrollpunkte, Fremdkoerper, verfruehten/falschrichtigen Zieleinlauf,
Tastaturstart, Startsperre, Countdown, Pause/Fortsetzung, Reset ohne Zeit- oder
Fortschrittsgewinn, mehrere Neustarts, schnellere/langsamere Bestzeiten, Laden,
beschaedigte Dateien und einen nicht beschreibbaren Speicherpfad.

Die integrierte automatisierte Runde nutzt die bestehende Fahrzeugphysik und
InputMap statt Teleports: alle sechs Kontrollpunkte und ein gueltiger Zieleinlauf
in `00:17.365`, ohne Wandkontakt. Separate Regeltests verwenden gezielte
Ueberquerungssegmente, um einzelne Grenzfaelle reproduzierbar zu testen.

Echte Renderbilder von Startmenue, aktivem Rennen, Pause und Ergebnis wurden
angesehen. Die sechs Menue-/Rennaufnahmen liegen unter `user://race-*.png`.
Statische Streckenaufnahmen liegen unter `docs/visual-review/race-*.png`.
Historische Gestaltungsaufnahmen wurden nicht ersetzt.

Keine manuelle Probefahrt durchgefuehrt. Keine neue FPS-Messung fuer diesen
Meilenstein; der feste Test-Zeitschritt ist kein Nachweis realer Bildrate.
Die aelteren MSAA-Messwerte in der README beziehen sich auf den Gestaltungsstand
vor der Rennintegration, nicht auf den jetzigen Rennablauf.

## Manuelle Abnahme

1. F5, dann Enter. W bereits im Menue/Countdown halten: Bewegung erst bei Los.
2. Runde in vorgesehener Richtung fahren und Zaehler, laufende Millisekundenzeit
   sowie unveraenderte Geschwindigkeitsanzeige beobachten.
3. Escape waehrend Countdown und Fahrt: alles bleibt stehen. Per Enter oder
   Escape fortsetzen; im Pausenmenue per Pfeiltaste "Neuer Versuch" pruefen.
4. Nach einem Kontrollpunkt R druecken: sichere Rueckkehr, richtige Richtung,
   gleicher Fortschritt, weiterlaufende Zeit. R startet kein neues Rennen.
5. Ziel erreichen: eingefrorene Zeit, Bestzeit und Rekordmeldung pruefen. Mit
   Enter mehrere neue Versuche starten, ohne die Maus zu verwenden.
6. Spiel schliessen und neu oeffnen: persoenliche Bestzeit muss erhalten bleiben.
7. Bei der eigenen Fenstergroesse Menuekontrast, Fokusrahmen, Lesbarkeit,
   Kameraverhalten und subjektives Fahrgefuehl beurteilen.

## Bekannte Grenzen

Keine verbleibenden Skript-/Startfehler in den ausgefuehrten Pruefungen.
Die Kamera besitzt wie bisher keine eigene Hinderniskollision. Kontrolllinien
sind unsichtbar; der HUD-Zaehler zeigt den Fortschritt. Die Strecke und der
Rennablauf sind lokal, ohne Manipulationsschutz oder Mehrspielerwertung.
Andere Aufloesungen und eine laengere menschliche Probefahrt bleiben manuell
abzunehmen. Keine Gegner, zusaetzlichen Strecken oder Erweiterungen der Fahrphysik.

## Main Menu Und Engine-Upgrades

Im bestehenden `scenes/main.tscn`-Ablauf wurde die READY-Ansicht durch ein
Hauptmenue mit **PLAY**, **UPGRADE** und **EXIT** erweitert. Dasselbe
Wheelchair-CharacterBody3D wird waehrend der Menues auf einer statischen
Showcase-Buehne praesentiert; beim Start wird es an den Streckenstart versetzt
und die vorhandene Gameplaykamera aktiviert. Pause, Rennende und Bestzeit bleiben
Bestandteil des bestehenden Zeitrennens.

`scripts/player_upgrades.gd` ist als `PlayerUpgrades`-Autoload die gemeinsame
Quelle fuer Basestats und Upgrade-Katalog. Standardwerte sind 65 km/h und
35 km/h/s. COMET gibt +10 km/h, RALLY +5 km/h und +10 km/h/s, LAUNCH +20 km/h/s.
Die Auswahl wird in `user://player_upgrades_v1.json` gespeichert. Die
Fahrzeugsteuerung liest dieselben Werte und rechnet sie fuer ihre bestehende
Meter-pro-Sekunde-Bewegung um. WHEEL und AERODYNAMICS sind reine Coming-Soon-
Platzhalter; es gibt keine Waehrung oder Bezahlfunktion.

Das Upgrade-Menue, die drei Wahlkarten und die Statistik werden in derselben
Menue-Navigation gehalten. Die Vorschau nutzt denselben Spieler statt eines
zweiten Modells. PLAY aktiviert die bisherige Rennstrecke und verwendet den
ausgewaehlten Antrieb; Pausen- und Ergebnismenues koennen zum Hauptmenue
zurueckkehren. Die Main-Menu- und Engine-Ansichten wurden bei 1280x720 mit
OpenGL 3.3 GL Compatibility gerendert und visuell geprueft.

### Verifikation Des Upgrade-Meilensteins

| Pruefung | Ergebnis |
| --- | --- |
| Godot 4.7.2 Import und Headless-Start | Erfolgreich |
| `tests/upgrade_test.gd`, Headless | 54 Pruefungen bestanden |
| `tests/upgrade_test.gd`, GL Compatibility | 58 Pruefungen bestanden, Screenshots geprueft |
| `tests/smoke_test.gd`, Headless | 29 Pruefungen bestanden |
| `tests/race_test.gd`, Headless | 71 Pruefungen bestanden |

Der isolierte Upgrade-Test prueft PLAY, EXIT-Verknuepfung, Kategorien und
Coming-Soon-Zustaende, genau drei Enginekarten, Aktualisierung der Stats, die
persistierte Auswahl nach Reload, Werte an den Fahrzeug-Properties und die
tatsaechliche Beschleunigung nach dem Countdown. Er verwendet eine temporaere
Speicherdatei und stellt den zuvor konfigurierten Upgrade-Speicher anschliessend
wieder her. Die Tests unter `--script` erstellen den Autoload bei Bedarf fuer den
isolierten Runner; normale Projektstarts verwenden weiterhin den konfigurierten
Autoload.

Keine manuelle Maus-/Tastatur-Probefahrt nach dieser Aenderung durchgefuehrt.
Bitte Hauptmenue, Maus-Hover/Fokus und persoenliche Engineauswahl im Editorfenster
bei der gewuenschten Aufloesung manuell abnehmen. Die frueheren manuellen
Renn-Abnahmepunkte gelten weiterhin.