# WheelchairRacer

Spielbarer 3D-Prototyp im vorhandenen Godot-Projekt. Entwickelt und geprueft
mit Godot **4.7.2 stable**, GDScript, GL Compatibility und der vorhandenen
Jolt-Physikkonfiguration. Die verwendeten CC0-Modelle sind lokal enthalten;
keine Zusatzpakete oder Downloads beim Spielstart erforderlich.

Aktueller Meilenstein: Main Menu mit persistenten Engine-Upgrades und
Ein-Runden-Zeitrennen sowie ueberarbeitete Rollstuhl-/Fahrerdarstellung.
Assetquellen, Lizenzen und KI-Herkunft: [docs/ASSET_SOURCES.md](docs/ASSET_SOURCES.md).
Technischer Stand, Testnachweise und manuelle Abnahme:
[docs/STATUS.md](docs/STATUS.md).

## Start

1. Dieses `project.godot` in Godot oeffnen.
2. Den Ressourcenimport abwarten.
3. **F5** druecken. Die Hauptszene `scenes/main.tscn` ist bereits eingestellt.
4. Bei Bedarf ins Spielfenster klicken, damit es Tastatureingaben erhaelt.
5. **PLAY** waehlen. Nach 3, 2, 1 und "Los!" fahren.

Strecke, Rollstuhl und HUD werden beim Start durch GDScript erzeugt.
Der Editor zeigt daher vor dem Start nur den Hauptknoten der Szene.

| Taste | InputMap-Aktion | Funktion |
| --- | --- | --- |
| W | `accelerate` | Beschleunigen |
| S | `brake` | Bremsen; bei Stillstand rueckwaerts fahren |
| A / D | `steer_left` / `steer_right` | Beim Fahren lenken |
| R | `reset` | Zum letzten gueltigen Kontrollpunkt zurueck, Zeit laeuft weiter |
| Escape | `pause` | Pausieren / fortsetzen |
| Enter / Leertaste | `ui_accept` | Fokussierten Menuebutton bestaetigen |
| Tab / Pfeiltasten | Godot-UI-Navigation | Menuebutton auswaehlen |

## Hauptmenue und Upgrades

Das Hauptmenue zeigt den Fahrer im Rollstuhl in einer ruhigen 3D-Ruhepose sowie
Hoechstgeschwindigkeit, Beschleunigung und das eingebaute Engine-Upgrade.
**PLAY** startet das bestehende Zeitrennen, **UPGRADE** oeffnet die Kategorien
und **EXIT** beendet das Spiel.

Unter **ENGINE** kann genau eines von drei Upgrades ausgewaehlt werden:

| Engine | Max Speed | Acceleration |
| --- | ---: | ---: |
| COMET | +10 km/h | +0 km/h/s |
| RALLY | +5 km/h | +10 km/h/s |
| LAUNCH | +0 km/h | +20 km/h/s |

Ohne Upgrade gelten 65 km/h und 35 km/h/s. Die Werte werden aus der gemeinsamen
Upgrade-Datenstruktur berechnet und vom Fahrzeug direkt fuer Hoechstgeschwindigkeit
und Beschleunigung verwendet. **WHEEL** und **AERODYNAMICS** sind klickbare
"Coming Soon"-Platzhalter. Die Engine-Auswahl bleibt unter
`user://player_upgrades_v1.json` erhalten; sie verwendet einen separaten Speicher
von der persoenlichen Bestzeit. Es gibt keine Spielwaehrung oder Bezahlfunktion.

Der Upgrade-Bildschirm wechselt in eine dunkle, selbst erzeugte Garage mit
eigener Kamera und dezentem Showroom-Licht. Der Rollstuhl bleibt als grosses
3D-Zentrum sichtbar; seine drei Engine-Modelle sind unterschiedliche
prozedurale Baugruppen, die unter dem Sitz direkt am Fahrzeug montiert sind.
Beim Wechsel gleitet das alte Modell heraus und das neue an seinen Platz.
Die gewaehlte Engine bleibt auch beim Start des Rennens am selben Fahrzeug.

Die bekleidete, skinned Fahrerfigur besitzt ein 54-Knochen-Skelett. Sitz-, Fuss-
und Handmarker bestimmen die Pose; `idle_enabled=false` schaltet die dezente
Ruhebewegung ab. Ohne Motor begleitet ein einfacher Schubzyklus die aktive
Beschleunigung. Mit Motor bleiben die Haende an den Armlehnen; beim Ausrollen
endet die Schubbewegung. Hinterraeder und Rollen drehen wegabhaengig, die
Vorderradgabeln schwenken separat. Keine zusaetzlichen Physik- oder IK-Plugins.

Ohne W rollt das Fahrzeug aus. S hat Vorrang vor W, bremst bis zum Stillstand
und faehrt bei weiterem Halten langsam rueckwaerts. Vor engen Kurven bremsen;
die Basis-Hoechstgeschwindigkeit betraegt 65 km/h. Mit COMET steigt sie auf
75 km/h. Nach dem Festfahren kann R verwendet werden.

## Zeitrennen

Eine Runde in vorgegebener Richtung absolvieren. Sechs unsichtbare Kontrolllinien
zaehlen nur geordnet und bei Vorwaertsueberfahrt. Der sichtbare Zaehler zeigt den
Fortschritt; nach 6/6 muss die vorhandene Start-/Ziellinie vorwaerts passiert
werden. Die erste Ueberfahrt direkt nach dem Start beendet das Rennen nicht.

Die Zeit beginnt mit "Los!" und erscheint als `MM:SS.mmm`. Escape friert Fahrzeug,
Countdown, Zeit und Fortschritt ein. Das Pausenmenue bleibt mit der Tastatur
bedienbar. R setzt nur Position, Ausrichtung, Geschwindigkeit und Kamera am
letzten gueltigen Kontrollpunkt zurueck, nicht Zeit oder Rennfortschritt. Vor dem
ersten Kontrollpunkt geht es zur Startposition zurueck.

Nach dem Ziel zeigt das Ergebnis Rundenzeit, bisherige Bestzeit und gegebenenfalls
"Neuer Rekord!". Enter startet einen neuen Versuch mit frischem Countdown.
Auch im Pausenmenue ist "Neuer Versuch" verfuegbar. Die Bestzeit bleibt erhalten.
Sie wird nur nach gueltigem Zieleinlauf unter `user://best_time_v1.json`
gespeichert, auf Windows normalerweise in
`%APPDATA%\Godot\app_userdata\WheelChairRacer\`.

## Inhalt

- Hauptmenue mit statischer 3D-Vorschau des wiederverwendeten Rollstuhlfahrers,
  Spielerstats sowie PLAY-, UPGRADE- und EXIT-Navigation.
- Drei persistente Engine-Setups, die Hoechstgeschwindigkeit und Beschleunigung
  direkt in der Fahrzeugsteuerung veraendern.
- Upgrade-Garage mit eigener Beleuchtung/Kamera, grossem Rollstuhl-Showcase und
  drei am Rollstuhl montierten, unterscheidbaren Motorbaugruppen.
- Geschlossene Stadionstrecke mit zwei Geraden, zwei Halbkreisen, solidem
  Boden, Innen-/Aussenbegrenzungen und Startmarkierung.
- Detaillierter CC0-Rollstuhl mit PBR-Texturen, getrennten Rad-/Gabelachsen,
  Fussstuetzen und bekleideter CC0-Figur; gemeinsame Darstellung in Garage/Rennen.
- CharacterBody3D-Arcadebewegung mit Kollisionen und rein visueller Raddrehung.
- Automatische Third-Person-Kamera, Sonnenlicht, Umgebungslicht,
  Geschwindigkeitsanzeige und sichtbare Steuerungsleiste.

## Tests Wiederholen

PowerShell im Projektordner. Hier verifizierter Pfad, bei Bedarf anpassen:

```powershell
$godot = "$env:USERPROFILE\Desktop\game_engeniring\Godot_v4.7.2-stable_win64_console.exe"
& $godot --version
& $godot --headless --path . --editor --import
& $godot --headless --path . --quit-after 180
& $godot --headless --path . --fixed-fps 60 --script res://tests/upgrade_test.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/race_test.gd
& $godot --path . --resolution 1280x720 --fixed-fps 60 --script res://tests/upgrade_test.gd
& $godot --path . --rendering-method gl_compatibility --quit-after 180
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --script res://tests/smoke_test.gd
& $godot --path . --resolution 1920x1080 --fixed-fps 60 --script res://tests/race_test.gd
```

Der Verhaltenstest beendet sich bei fehlgeschlagenen Pruefungen mit Exitcode 1.
Er simuliert physische Tasteneingaben und prueft Eingabezuordnung, Bodenkontakt,
Beschleunigen, Geschwindigkeitslimit, Bremsen, Ausrollen, beide Lenkrichtungen,
Kollisionen an Geraden und Kurven sowie Fahrzeug- und Kamerareset.
Der Upgrade-Test prueft Menue- und Kategorienavigation, alle drei Motoren,
Statistikaktualisierung, Speicherung, Gameplaywerte, Sitzpose aus mehreren
Ansichten, synchronisierte Armbewegung, Vorwaerts-/Rueckwaertsbewegung, Lenken
und die Rueckkehr zur Ruhepose.
Der Renntest prueft zusaetzlich Rennregeln, Tastaturmenues, Countdown, Pause,
Kontrollpunktreset, Neustarts und Bestzeitspeicherung. Speicherpruefungen verwenden
ein separates temporaeres `user://race-tests-*`-Verzeichnis; echte Bestzeiten
werden weder gelesen noch ueberschrieben. Eine komplette Runde wird dabei mit
automatisierten InputMap-Eingaben gefahren, nicht durch Teleportieren abgeschlossen.

## Aktueller Nachweis (16.10.2026)

Import und Headless-Start bestanden. Headless: 30 Fahr-, 102 Upgrade-, 71
Rennpruefungen. Echte GL-Compatibility-Ausgabe auf Intel Iris Xe: 128 Upgrade-
und 77 Rennpruefungen. Vollstaendige automatisierte Runde: `00:17.235`, ohne
Wandkontakt. Keine manuelle Probefahrt, kein Export- oder Zielhardware-Benchmark.

Echte native 1080p-Vergleiche: [vorher](docs/visual-review/presentation/before-side.png),
[nachher](docs/visual-review/presentation/after-side.png),
[Workshop](docs/visual-review/presentation/after-workshop.png),
[Rennen](docs/visual-review/presentation/after-race.png).
Messmethodik, Einschraenkungen und manuelle Checkliste: [STATUS](docs/STATUS.md).

Neue Bilder erzeugen, ohne die echte Vorher-Serie zu ueberschreiben:

```powershell
& $godot --path . --rendering-method gl_compatibility --resolution 1920x1080 --script res://tests/visual_review.gd -- --presentation-after
```

## Historischer Nachweis Vor Der Modellueberarbeitung

- Godot-Version: `4.7.2.stable.official.ed1daf0bf`.
- Ressourcenimport und Headless-Start erfolgreich, keine verbleibenden
  GDScript- oder Laufzeitfehler in den ausgefuehrten Pruefungen.
- 30 Fahr-/Konfigurationspruefungen ohne Grafik bestanden, inklusive einer
  Kollisionspruefung der gesamten Strecke auf drei Fahrlinien.
- Dieselben Pruefungen mit echter OpenGL-3.3-Compatibility-Ausgabe auf
  NVIDIA GeForce RTX 3070 Laptop GPU bestanden, dazu sechs Screenshot-/Bildpruefungen.
- Startansicht und Ansicht nach einer automatisierten Lenkbewegung als echte
  Renderbilder angesehen: Figur, Strecke, Beleuchtung und HUD sichtbar.
- Bilder: `user://prototype-start.png` und `user://prototype-turn.png`, unter
  `%APPDATA%\Godot\app_userdata\WheelChairRacer\`.
- Renntest: 71 Pruefungen ohne Grafik, 77 mit Grafik inklusive sechs Aufnahmen.
- Upgrade-/Showcase-Test: 90 Headless-Pruefungen und 114 mit GL Compatibility;
  Sitzpose, Front-/Seitenansicht, Schubphase sowie Garage und alle Motoren als
  echte Renderbilder geprueft.
- Engineselektion: alle drei Stats, UI-Anzeige, Dateispeicherung und Bewegung
  mit der ausgewaehlten Beschleunigung automatisch verifiziert.
- Automatisierte vollstaendige Runde: `00:17.365`, alle sechs Kontrollpunkte,
  kein Wandkontakt. Dies ist ein Funktionstest, keine Leistungsmessung.
- Start-, Renn-, Pause- und Ergebnisansichten als echte 1080p-Renderbilder angesehen.

Keine manuelle Probefahrt mit menschlichen Tastatureingaben durchgefuehrt.
Fahrgefuehl und eine vollstaendige manuell gefahrene Runde sind noch zu pruefen.
Die Kamera hat keine eigene Hinderniskollision. Das Zeitrennen umfasst genau
eine Runde, keine Gegner, Anpassungsoptionen oder komplexe Radphysik.
Fuer diesen Rennmeilenstein wurde keine neue Bildratenmessung durchgefuehrt.

## Gestaltungsstand: Stadtpark

Ueberarbeitung vom 13.10.2026, im bestehenden Projekt. Vorher: flache gruene
Flaeche, gelber Torbalken, rot-weisse Waende, weitgehend einheitliche
Materialrauheit, keine Parkdekoration. Der Git-Status wurde vor der Arbeit
geprueft: Zu diesem Zeitpunkt besass der Ordner kein Git-Repository. Inzwischen
wurde Git eingerichtet. Kein Reset, Checkout oder Neuanlegen eines Projekts wurde
fuer die Gestaltung ausgefuehrt.

Die neue Gestaltung konzentriert sich auf Startgerade und ersten Kurvenbogen:
neun geometrische Baeume, fuenf niedrige Buschgruppen, eine Promenade mit zwei
Baenken, drei Rennbanner, ein Wegweiser und drei Kurvenpfeiltafeln. Eine kleine,
zurueckgenommene Stadtsilhouette bildet den Hintergrund. Alle neuen Elemente
liegen unter `ParkDecoration`, ohne CollisionObjects oder neue Fahrphysik.

| Palette | Albedo-Farbe | Verwendung |
| --- | --- | --- |
| Parkgruen | `#4f6948` | Ruhige Rasenflaeche mit dezenter Tonvariation |
| Asphalt | `#303b40` | Dunkler, feinkoerniger Belag |
| Warmweiss | `#d9dfd5` | Markierungen, Torbeschriftung, HUD |
| Petrol | `#205654` | Starttor, Banner, Wegweiser |
| Koralle | `#b95343` | Sparsame Rennakzente an Waenden und Tor |

Asphalt und Gras verwenden unterschiedlich skalierte, nahtlose Noise-Texturen.
Gummi ist dunkel und rau, Metall hat gerichtete Lichtreflexe, Sitzpolster
eine matte Stoffstruktur. Himmel, Sonne und Umgebungslicht nutzen ausschliesslich
Compatibility-faehige Standardfunktionen. Keine neuen Postprocessing-Effekte.
Das HUD erhielt kleinere Schriftgroessen und kontrastreiche, flache Baender.
Der spaetere Rennmeilenstein ergaenzt darin Zeit und Kontrollpunktfortschritt.

Es wurden **keine Fremdassets heruntergeladen oder eingebunden**. Geometrie und
Oberflaechen entstehen aus Godot-Primitiven und FastNoiseLite im Projektcode.
Die UI fordert die lokal installierte Schrift Bahnschrift an und nutzt ansonsten
eine System-Sans-Serif. Keine Schriftdatei wird kopiert oder weiterverteilt;
auf anderen Betriebssystemen kann die Typografie abweichen.

### Echte Vergleichsaufnahmen

Beide Staende wurden mit demselben Testskript, denselben Kameratransformationen,
gleichem Sichtfeld und tatsaechlich gerenderten 1920x1080 Pixeln aufgenommen.
Die Kameraansichten sind der Start und die Mitte des ersten Viertelbogens.
Der Vorher-Stand wurde ebenfalls mit 2x/4x MSAA aufgenommen, damit der reine
Gestaltungsvergleich nicht durch eine andere Kantenglaettung verfaelscht wird.

| Ansicht | Vorher (2x) | Nachher (2x, Standard) | Nachher (4x) |
| --- | --- | --- | --- |
| Start | [Bild](docs/visual-review/before-start-2x.png) | [Bild](docs/visual-review/after-start-2x.png) | [Bild](docs/visual-review/after-start-4x.png) |
| Erste Kurve | [Bild](docs/visual-review/before-curve-2x.png) | [Bild](docs/visual-review/after-curve-2x.png) | [Bild](docs/visual-review/after-curve-4x.png) |

### Messung Und MSAA

**2x MSAA ist die Voreinstellung.** 4x verbessert feine Kanten geringfuegig,
hatte in den gemessenen Ansichten aber hoehere Framezeiten. Die Rohdaten liegen
in [before.json](docs/visual-review/before.json) und
[after.json](docs/visual-review/after.json).

Historischer Durchlauf des Gestaltungsmeilensteins, vor der Rennintegration,
auf Intel Iris Xe, OpenGL 3.3 Compatibility, Godot 4.7.2:

| Ansicht | MSAA | Mittlere FPS | Mittlere Framezeit | 95%-Framezeit |
| --- | --- | --- | --- | --- |
| Start | 2x | 133.4 | 7.50 ms | 14.45 ms |
| Erste Kurve | 2x | 154.2 | 6.49 ms | 18.38 ms |
| Start | 4x | 121.9 | 8.21 ms | 20.99 ms |
| Erste Kurve | 4x | 125.2 | 7.99 ms | 22.12 ms |

Methode: je Ansicht 60 Aufwaermframes, danach 240 Wall-Clock-Abstaende zwischen
gerenderten Frames, VSync aus, kein FPS-Limit. Screenshots entstehen ausserhalb
des Messfensters. Keine parallele Testlast waehrend dieser Messung.
**Kurze statische Szenenpruefung mit pausierter Fahrlogik, kein Fahrbenchmark,
keine GPU-Zeitmessung und keine Garantie fuer stabile 60 FPS.** Framezeitspitzen
ueber 16.7 ms traten auf; Langzeittest und Frame-Pacing bleiben lokal zu pruefen.
Der normale Spielstart behaelt seine bisherige VSync-Konfiguration.

### Pruefung Wiederholen

Zusaetzlich zu den obigen Import-, Start- und Funktionstests:

```powershell
& $godot --path . --resolution 1920x1080 --script res://tests/visual_review.gd
& $godot --path . --resolution 1920x1080 --script res://tests/visual_review.gd -- --capture-only
```

Dieser reine Entwickler-Pruefmodus erzeugt jetzt separate `race-*`-Bilder und
`race.json`, testet 2x und 4x nur fuer seinen eigenen Prozess und beendet sich
automatisch. `--capture-only` nimmt Bilder ohne Leistungsmessung auf; dieser
Modus wurde fuer den Rennmeilenstein ausgefuehrt. Das Startmenue wird fuer die
festen Kameraansichten ausgeblendet, die Rennlogik bleibt dabei angehalten.
Die vorhandene Vorheraufnahme nicht mit `--before` ueberschreiben.
Die Hash-Pruefungen bestaetigen unveraenderte Kollisionsformen/-transformationen,
und die bisherige Fahrbelegung. Der Controller-Hash wird weiterhin aufgezeichnet,
aber wegen der absichtlich ergaenzten Startsperre und Kontrollpunktruecksetzung
nicht mehr gegen den Stand vor dem Zeitrennen verglichen. Diese Funktionen
sichern die Fahr- und Renntests ab. Historische `before-*`/`after-*`-Aufnahmen
und Messberichte bleiben unveraendert.

### Manuelle Abnahme

1. F5 starten; fuer exakte 1080p alternativ im Projektterminal
  `& $godot --path . --resolution 1920x1080` verwenden.
2. Am Start Materialunterschiede, Torbeschriftung und HUD-Kontrast beurteilen.
3. Die erste Kurve langsam innen und aussen durchfahren: Pfeile, Sichtweite,
  Dekorationsabstand und Kamera auf Ueberschneidungen pruefen.
4. Eine Runde fahren, W/S/A/D und R pruefen; auf Schattenflimmern,
  Kantenunruhe und anhaltende Framezeitspitzen achten.
5. Bei Bedarf in den Projekteinstellungen unter Rendering > Anti Aliasing >
  Quality > MSAA 3D zwischen 2x und 4x vergleichen; anschliessend 2x wiederherstellen.

Keine manuelle Probefahrt wurde behauptet oder durchgefuehrt. Die Kamera besitzt
weiterhin keine eigene Hinderniskollision; die Freiraeume wurden gestalterisch
eingeplant und in den festen Ansichten geprueft. Feine Schattenkanten koennen mit
Compatibility noch unruhig erscheinen. Der weitere Streckenverlauf ist bewusst
nicht vollstaendig als Park ausgestaltet. Hier endet dieser Gestaltungsmeilenstein.

## Dateien

- `scripts/main.gd`: Strecke, Beleuchtung, Kamera und HUD.
- `scripts/wheelchair.gd`: Fahrzeug, austauschbare Fahrerhierarchie,
  geometrisches Modell, Arcadebewegung und radgekoppelte Schubpose.
- `scripts/engine_visuals.gd`: Datengetriebene, prozedurale Motormodelle fuer die Garage.
- `scripts/race.gd`: Einzige Rennzustandsverwaltung, Linienpruefungen und Bestzeiten.
- `scripts/player_upgrades.gd`: Basestats, Engine-Katalog und gespeicherte Auswahl.
- `tests/smoke_test.gd`: Automatisierte Pruefungen ohne und mit Grafik.
- `tests/race_test.gd`: Rennregeln, isolierte Speichertests und automatisierte Runde.
- `tests/upgrade_test.gd`: Menues, Upgrades, Sitzpose und Schubanimation.
- `tests/visual_review.gd`: Reproduzierbarer Bildvergleich und statische MSAA-Messung.
- `docs/STATUS.md`: Aktueller Meilenstein, Nachweise und manuelle Abnahme.
- `AGENTS.md`: Kurze Regeln fuer weitere Projektarbeit.