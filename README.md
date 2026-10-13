# WheelchairRacer

Spielbarer 3D-Prototyp im vorhandenen Godot-Projekt. Entwickelt und geprueft
mit Godot **4.7.2 stable**, GDScript, GL Compatibility und der vorhandenen
Jolt-Physikkonfiguration. Keine externen Modelle oder Zusatzpakete erforderlich.

## Start

1. Dieses `project.godot` in Godot oeffnen.
2. Den Ressourcenimport abwarten.
3. **F5** druecken. Die Hauptszene `scenes/main.tscn` ist bereits eingestellt.
4. Bei Bedarf ins Spielfenster klicken, damit es Tastatureingaben erhaelt.

Strecke, Rollstuhl und HUD werden beim Start durch GDScript erzeugt.
Der Editor zeigt daher vor dem Start nur den Hauptknoten der Szene.

| Taste | InputMap-Aktion | Funktion |
| --- | --- | --- |
| W | `accelerate` | Beschleunigen |
| S | `brake` | Bis zum Stillstand bremsen |
| A / D | `steer_left` / `steer_right` | Beim Fahren lenken |
| R | `reset` | Position, Ausrichtung, Geschwindigkeit und Kamera zuruecksetzen |

Ohne W rollt das Fahrzeug aus. S hat Vorrang vor W. Vor engen Kurven bremsen;
die Hoechstgeschwindigkeit betraegt 18 m/s (rund 65 km/h). Es gibt keinen
Rueckwaertsgang. Nach dem Festfahren kann R verwendet werden.

## Inhalt

- Geschlossene Stadionstrecke mit zwei Geraden, zwei Halbkreisen, solidem
  Boden, Innen-/Aussenbegrenzungen und Startmarkierung.
- Geometrischer Rollstuhl mit Rahmen, Sitz, Greifreifen, Speichen,
  Vorderraedern und sitzender Figur mit Helm.
- CharacterBody3D-Arcadebewegung mit Kollisionen und rein visueller Raddrehung.
- Automatische Third-Person-Kamera, Sonnenlicht, Umgebungslicht,
  Geschwindigkeitsanzeige und sichtbare Steuerungsleiste.

## Tests Wiederholen

PowerShell im Projektordner. Auf diesem Rechner wurde Godot hier gefunden:

```powershell
$godot = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
& $godot --version
& $godot --headless --path . --editor --import
& $godot --headless --path . --quit-after 180
& $godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
& $godot --path . --rendering-method gl_compatibility --quit-after 180
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --script res://tests/smoke_test.gd
```

Der Verhaltenstest beendet sich bei fehlgeschlagenen Pruefungen mit Exitcode 1.
Er simuliert physische Tasteneingaben und prueft Eingabezuordnung, Bodenkontakt,
Beschleunigen, Geschwindigkeitslimit, Bremsen, Ausrollen, beide Lenkrichtungen,
Kollisionen an Geraden und Kurven sowie Fahrzeug- und Kamerareset.

## Verifizierter Stand

- Godot-Version: `4.7.2.stable.official.ed1daf0bf`.
- Ressourcenimport und Headless-Start erfolgreich, keine verbleibenden
  GDScript- oder Laufzeitfehler in den ausgefuehrten Pruefungen.
- 28 Verhaltens-/Konfigurationspruefungen ohne Grafik bestanden.
- Dieselben Pruefungen mit echter OpenGL-3.3-Compatibility-Ausgabe auf
  Intel Iris Xe bestanden, dazu sechs Screenshot-/Bildpruefungen.
- Startansicht und Ansicht nach einer automatisierten Lenkbewegung als echte
  Renderbilder angesehen: Figur, Strecke, Beleuchtung und HUD sichtbar.
- Bilder: `user://prototype-start.png` und `user://prototype-turn.png`, unter
  `%APPDATA%\Godot\app_userdata\WheelChairRacer\`.

Keine manuelle Probefahrt mit menschlichen Tastatureingaben durchgefuehrt.
Fahrgefuehl und eine vollstaendige manuell gefahrene Runde sind noch zu pruefen.
Die Kamera hat keine eigene Hinderniskollision. Das ist eine einfache
Teststrecke, noch kein fertiges Rennen: keine Gegner, Anpassungsoptionen,
Rundenwertung oder komplexe Radphysik.

## Gestaltungsstand: Stadtpark

Ueberarbeitung vom 13.10.2026, im bestehenden Projekt. Vorher: flache gruene
Flaeche, gelber Torbalken, rot-weisse Waende, weitgehend einheitliche
Materialrauheit, keine Parkdekoration. Der Git-Status wurde vor der Arbeit
geprueft: Dieser Ordner besitzt kein Git-Repository. Kein Reset, Checkout oder
Neuanlegen eines Projekts wurde ausgefuehrt.

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
Das bestehende HUD zeigt weiterhin nur Titel, Strecke, Geschwindigkeit und
Steuerung, mit kleineren Schriftgroessen und kontrastreichen, flachen Baendern.

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

Finaler Durchlauf auf Intel Iris Xe, OpenGL 3.3 Compatibility, Godot 4.7.2:

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
```

Dieser reine Entwickler-Pruefmodus aktualisiert Nachherbilder und Messbericht,
testet 2x und 4x nur fuer seinen eigenen Prozess und beendet sich automatisch.
Die vorhandene Vorheraufnahme nicht mit `--before` ueberschreiben.
Die Hash-Pruefungen bestaetigen unveraenderte Kollisionsformen/-transformationen,
Eingabebelegung und den Steuerungsabschnitt des Fahrzeugskripts. Import,
Headless-Start, grafischer Start und alle 28 Funktionstests wurden nach der
Ueberarbeitung erneut erfolgreich ausgefuehrt, die Funktionstests auch mit Grafik.

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
- `scripts/wheelchair.gd`: Fahrzeug, geometrisches Modell und Arcadebewegung.
- `tests/smoke_test.gd`: Automatisierte Pruefungen ohne und mit Grafik.
- `tests/visual_review.gd`: Reproduzierbarer Bildvergleich und statische MSAA-Messung.
- `AGENTS.md`: Kurze Regeln fuer weitere Projektarbeit.