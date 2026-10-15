# Projektstatus: Main Menu, Upgrades und Ein-Runden-Zeitrennen

Aktueller Meilenstein (15.10.2026): Main Menu, persistente Engine-Upgrades,
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