# Circle Master — Spécification fonctionnelle (FSD)

Rédigée pendant la construction du bundle, à partir des FSD des deux plugins d'origine :

- `../sketchup-circle-advanced/FSD.md` (outil Circle, mode modification, re-segmentation des cercles, des cylindres et des coins arrondis) ;
- `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre, redimensionnement, reconstruction native, interfaces, limitations).

Plan prévu : objectif ; entrées (sélections, saisies de l'analyseur unique) ; outil Circle ; redimensionnement des cylindres ; moteur de reconstruction unique ; réglages et reprise des anciens ; interface (menu, barre d'outils, fenêtres) ; limitations ; structure des fichiers ; tests ; historique des versions.

État : les quatre commandes sont portées et passent par un moteur de reconstruction unique (étapes 1 à 5 des directives). Reste : batterie complète (étape 6), documentation.

## Outil Circle et fenêtre Settings (EF-01)

Code de Circle Advanced 1.4.0, comportement identique : voir `../sketchup-circle-advanced/FSD.md` § 2 (tracé, verrouillage, saisie, résultat, paramètres, mode modification, segments des cercles, des extrémités de cylindre et des coins arrondis, mode copie, double-clic) ; ce détail sera fusionné ici avec la documentation. Fichiers : `circle_tool.rb`, `resegmenter.rb`, `fillet.rb`, `settings_dialog.rb`, `html/settings.html` ; segments d'une extrémité de cylindre par le moteur unique (`volume.rb`, ci-dessous).

Différences avec Circle Advanced :

| Point | Circle Advanced | Circle Master |
|---|---|---|
| Noms dans *Édition > Annuler* | `Circle`, `Resize Circle`, `Modify Circle`, `Circle Segments` | `Circle Master — Circle`, `Circle Master — Resize Circle`, etc. (décision du 2026-10-26) |
| Rayon d'une saisie, incrément | méthodes privées de `CircleTool` | `VcbParser.radius_from`, `VcbParser.target_radius` (mêmes calculs, même refus d'une taille ≤ 0) |
| Fenêtre Settings | titre « Circle Advanced », position mémorisée sous `CircleAdvanced_Settings` ; taille fixe 360 × 480 imposée à chaque ouverture | titre « Circle Master », `CircleMaster_Settings` ; légende « Value typed without marker (all commands) » ; **redimensionnable**, 360 × 560 à la première ouverture, minimum 320 × 400, défilement si trop petite ; SketchUp mémorise taille et position entre les sessions |
| Réglages | section `CircleAdvanced` | section `CircleMaster`, reprise des anciens (ci-dessous) |
| Coin arrondi **extérieur** passé à plus de segments (ex. rayon 10 mm, 12 → 24) | refusé (« The rounded corner could not be rebuilt ») : les lignes provisoires suivaient les tangentes, si près du nouvel arc près des points de tangence (r × (1 − cos pas) : 0,02 mm) que SketchUp y collait ses premiers sommets (tolérance 0,001″), et la face provisoire était cherchée au 1er segment, où elle finit en pointe | `fillet.rb` : lignes provisoires vers un point de la bissectrice deux fois plus loin du centre que le coin ; face provisoire cherchée au segment du milieu. Vérifié : rayon 10 mm 12 → 24, rayon 2 mm 12 → 48 ; mêmes résultats que Circle Advanced là où il fonctionnait (12 → 6, coin intérieur) |

## Redimensionnement des cylindres (EF-02 à EF-06)

Code de Cylinder Resize 0.3.0, comportement identique : voir `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre ou tronc de cône par sa paroi, rayon cible par cercle, cônes, déplacement des sommets ou reconstruction native des cercles cassés, soudure en secours, faces hôtes, composants, interfaces, limitations) ; ce détail sera fusionné ici avec la documentation. Fichiers : `cylinders/detector.rb`, `cylinders/resizer.rb`, `cylinders/resize_tool.rb` ; fenêtre dans `main.rb` (`CircleMaster.resize_selection`) ; reconstruction native par le moteur unique (`volume.rb`, ci-dessous).

Différences avec Cylinder Resize :

| Point | Cylinder Resize | Circle Master |
|---|---|---|
| Valeur sans marqueur dans *Cylinder Resize Tool* | toujours un diamètre | suit le réglage commun `input_mode` |
| Zone Mesures de l'outil | toujours « Diameter » et le diamètre | « Diameter; Segments » ou « Radius; Segments » et `50mm; 24s` (taille et segments du 1er cylindre, dans la syntaxe de saisie : revalider la valeur affichée ne change rien) |
| Aide de la barre d'état de l'outil | « Type 15 or d15 = diameter, r7.5 = radius… » | idem en mode diamètre ; « Type 7.5 or r7.5 = radius, d15 = diameter… » en mode rayon ; « 36s = segments, 15;36s » |
| Champ *Mode* de la fenêtre | réglage propre `CylinderResize/mode`, écrit à chaque validation | réglage commun `input_mode`, écrit seulement s'il change : l'outil Circle le suit aussi |
| Analyse de la saisie | `VcbParser.parse(text, default_kind)` | `VcbParser.parse(text)`, comme l'outil Circle |
| **Nombre de segments** (EF-12) | `24s` refusé (« Changing the segment count is not supported ») | `36s`, `15;36s`, `+0,2;48s` dans l'outil et la fenêtre (`+36s` refusé) : chaque cylindre dont le nombre de segments change est reconstruit en natif (`Volume.rebuild(…, radii:, segments:)`), natif ou cassé, en une étape d'annulation ; tous sont vérifiés avant la moindre modification : un cylindre non reconstructible (ligne raccordée…) annule toute la saisie avec la raison (« The segment count cannot be changed (…), nothing was changed ») ; un nombre égal à l'actuel ne reconstruit pas (la taille seule se comporte comme avant) ; un tronc de cône reste un cône sans question (`Detector::Cylinder#segments` : nombre de coins, points de coupe exclus) |
| Nom dans *Annuler* | `Resize Cylinders` | `Circle Master — Resize Cylinders` |
| Fenêtre Settings ouverte avec l'outil actif | — | *OK* rafraîchit la zone Mesures et l'aide de l'outil |
| Cercle cassé avec un point de coupe en plus (laissé par un booléen) | centre par moyenne des sommets : cylindre non reconnu | détection par chaîne d'abord (`Chains`), moyenne en secours : reconnu et reconstruit |
| Reconstruction native | `rebuilder.rb` | moteur unique `Volume.rebuild(…, radii:)` : même résultat, 5 à 6 fois plus rapide sur une plaque de 20 trous |

## Moteur de reconstruction unique (Q-2, Q-3)

`circle_master/volume.rb` (`CircleMaster::Volume`) et `circle_master/chains.rb` (`CircleMaster::Chains`) : moteur de Solid Progress 2.0.1 (issu de Re-Cercle 2.0, réparation des trous par grilles de Solid for Maker), choisi après comparaison des trois moteurs d'origine (2026-10-26).

- `Volume.build(faces)` → `[body, nil]` ou `[nil, raison]` : paroi = faces reliées par arêtes adoucies, bordée par 2 boucles ; chaque boucle est un cercle natif (lu sur son `ArcCurve`, quel que soit son nombre de segments, comme Circle Advanced) ou une chaîne (`Chains.chain_from` : points de coupe acceptés, 6 segments au moins ; test d'alignement des sommets relatif à la taille, pour les très petits cercles) ; même nombre de segments, coaxiales, aucune ligne raccordée, faces voisines dans le plan, une face à un bout au moins.
- `Volume.from_curve(curve)` : corps dont `curve` (cercle natif sélectionné) est une extrémité ; `ArgumentError` avec la raison sinon (outil Circle).
- `Volume.rebuild(entities, body, radii: nil, segments: nil)` : par défaut même taille et mêmes segments (réparation) ; `radii:` (un rayon par boucle, Cylinder Resize) et `segments:` (Circle Advanced). Phase : premier coin de la boucle 0. Vérification finale : chaque bout est une seule `ArcCurve` de N arêtes au rayon cible, sinon exception (l'opération de l'appelant est annulée). Renvoie un sommet du cercle de départ (outil Cylinder Resize).
- Appelants : `Resegmenter` (segments d'une extrémité de cylindre), `Resizer` (cylindre au cercle cassé : `Resizer.rebuild_body` = contrôle de validité + `Volume.build`, rayons cibles associés par centre le plus proche) ; `Fillet` utilise `Volume.tolerance`, `outward?`, `repair_holes`.

Comparaison avec les moteurs d'origine installés (`tools/tests/engine_cases.rb`, SketchUp 2021 Pro et Make 2017) : réparation identique à Solid Progress (8/8), rayon +0,1 mm identique à Cylinder Resize (7/8 ; le 8e est le cercle à point de coupe, non reconnu par Cylinder Resize, reconstruit par Circle Master), segments 24 → 48 et 24 → 12 identiques à Circle Advanced (12/12). Plaque de 20 trous, rayon : Circle Master 2,0 s / Cylinder Resize 11,0 s (2021), 1,3 s / 7,2 s (2017).

## Saisie : analyseur unique (EF-08)

Module `CircleMaster::VcbParser` (`circle_master/vcb_parser.rb`) : l'analyseur de Circle Advanced, sans changement, plus les fonctions de taille de Cylinder Resize. Il sert à la zone Mesures des deux outils et à la valeur de la fenêtre *Resize Cylinders…*.

| Saisie | Résultat |
|---|---|
| `50`, `50mm`, `2'6"`, `3yd` | Valeur sans marqueur (`kind = :default`) : diamètre, ou rayon si `input_mode = radius` |
| `25r`, `r25`, `R25`, `25mm r` | Rayon |
| `50d`, `d50` | Diamètre explicite (`yd` est une unité, pas un marqueur) |
| `48s`, `s48`, `48 S` | Nombre de segments |
| `50;36s`, `50mm; 48s` | Plusieurs valeurs séparées par `;` |
| `+5`, `-2,5`, `- 3`, `+d5`, `+r1`, `-0.5r` | Incrément (`sign` = +1 ou -1) |
| `--5`, `--r1` | `+5`, `+r1` (quand la touche `+` est prise par un raccourci) |
| `~ 50mm` | `~ ` en tête ignoré (valeur approchée de `Sketchup.format_length`) |
| `48` seul | `bare_integer = 48` (nombre de côtés avant le 1er clic, outil Circle) |

**Séparateur décimal** (EF-11) : point ou virgule, quel que soit celui du PC. Avant `String#to_l`, qui n'accepte que le séparateur de Windows, `VcbParser.local_decimals` remplace tout point ou toute virgule collé à un chiffre par `Sketchup::RegionalSettings.decimal_separator` (présent sous Make 2017). Pas d'ambiguïté : les valeurs sont séparées par `;`. Limites : pas de séparateur de milliers (`1,000` = 1 sur un PC à point) ; le vrai `to_l` ignore une lettre finale après une décimale (`7,5x` est lu comme 7,5) ; les yards ne sont connus de `to_l` que depuis SketchUp 2020.

Refus (`ArgumentError`, message affiché tel quel, avec le texte tapé) : saisie vide (`Empty input`), valeur illisible (`Invalid value: abc`), valeur nulle (`Value must be positive: 0`), incrément de segments (`The segment count cannot be an increment`).

Fonctions :

- `parse(text)` → `Result(length, kind, segments, bare_integer, sign)`, `delta?` vrai pour un incrément.
- `radius_from(res)` : rayon en pouces, signe ignoré ; `nil` sans longueur.
- `target_radius(res, current)` : la valeur, ou `current` ± l'incrément ; refus `The resulting size would be zero or negative` si le résultat est ≤ 1e-6 pouce.
- `describe(res)` : texte de la barre d'état, `Ø 15mm`, `Ø +1mm`, `R -0.1mm`, `36s`, `Ø 15mm; 36s`.
- Les commandes de cylindres utilisent `parse`, comme l'outil Circle (`parse_size`, qui refusait les segments, a disparu avec EF-12).

**Réglage diamètre / rayon unique** (EF-09) : une valeur sans marqueur suit `Settings.input_mode` dans **toutes** les commandes, y compris *Cylinder Resize Tool*, où `15` était toujours un diamètre dans Cylinder Resize 0.3.0 (décision du 2026-10-26).

Différences avec les analyseurs d'origine (pas de perte de fonction) :

- `15;20` donne 20 (la dernière valeur l'emporte, comme dans Circle Advanced) ; Cylinder Resize la refusait.
- Point et virgule décimale acceptés partout (les deux plugins n'acceptaient que le séparateur du PC).
- Segments acceptés dans le redimensionnement des cylindres (EF-12) ; `+24s` y est refusé comme dans l'outil Circle (`The segment count cannot be an increment`).
- Le paramètre `default_kind` de Cylinder Resize disparaît : la fenêtre écrira son choix dans le réglage commun.

Cas : `tools/tests/vcb_parser_cases.rb` (88 cas : saisies des deux plugins, refus, `radius_from`, `target_radius`, `describe` en mode diamètre et rayon, avec segments). Hors SketchUp : `ruby tools/tests/vcb_parser_cases.rb` (`Sketchup` et `String#to_l` simulés, modèle en mm ; `to_l` n'accepte que le séparateur simulé ; deux passages : PC à virgule, puis PC à point). Dans SketchUp : `CircleMasterTests::VcbParserCases.run` avec le vrai `to_l` (modèle en mm) ; le mode de saisie n'est changé qu'en mémoire.

## Réglages et reprise des anciens (EF-09, EF-10)

Module `CircleMaster::Settings` (`circle_master/settings.rb`), section `CircleMaster` de `Sketchup.read_default` / `write_default`.

| Clé | Valeurs | Défaut | Reprise, dans l'ordre |
|---|---|---|---|
| `segments` | entier de 3 à 999 | 48 | `CircleMaster/segments`, `CircleAdvanced/segments` |
| `input_mode` | `diameter`, `radius` | `diameter` | `CircleMaster/input_mode`, `CircleAdvanced/input_mode`, `CylinderResize/mode` (`Diameter` / `Radius`, mis en minuscules) |
| `coord_mode` | `auto`, `world`, `local` | `auto` | `CircleMaster/coord_mode`, `CircleAdvanced/coord_mode` |

- La première section qui a une valeur l'emporte ; une valeur invalide donne le défaut.
- `input_mode` est le réglage diamètre / rayon unique de toutes les commandes (EF-09).
- Les valeurs sont mémorisées à la première lecture ; une écriture va **uniquement** dans `CircleMaster`. Les sections des anciens plugins ne sont jamais écrites : tant qu'un réglage n'est pas changé dans Circle Master, il suit celui de l'ancien plugin.

## Interface

Menu *Extensions > Circle Master* et barre d'outils **Circle Master**, dans cet ordre :

| Commande | Icône | Rôle |
|---|---|---|
| `Circle` | `circle_16/24.png` | Outil Circle de Circle Advanced (EF-01) |
| `Resize Cylinders…` | `resize_dialog_16/24.png` | Fenêtre de Cylinder Resize (EF-02) |
| `Cylinder Resize Tool` | `resize_tool_16/24.png` | Outil interactif de Cylinder Resize (EF-03) |
| *(séparateur)* | | |
| `Settings…` | `settings_16/24.png` | Fenêtre de réglages |

Curseurs des outils : `cursor_circle.png`, `cursor_resize.png`. Les boutons `Circle` et `Cylinder Resize Tool` sont cochés quand leur outil est actif. La garde `unless @loaded` évite les doublons au rechargement ; `CircleMaster.reload` recharge les fichiers de `FILES` (développement).

## Tests (NF-06)

Batterie automatique sur le modèle de Solid Progress, hors `.rbz` :

- `tools/tests/run_tests.ps1` (ASCII) : SketchUp fermé, il déploie le plugin (`circle_master.rb` + miroir `robocopy` de `circle_master/`), lance SketchUp avec `-RubyStartup tools/tests/run_tests.rb`, attend le rapport, ferme le seul SketchUp lancé et affiche le rapport. Options `-Versions 2021,2017`, `-Timeout`, `-NoDeploy`. SketchUp 2021 : écran d'accueil désactivé le temps du test (`PrivatePreferences.json` sauvegardé d'abord dans `%USERPROFILE%\claude-backups\…`, 5 copies gardées, fichier de plus de 20 Mo jamais touché) ; Make 2017 : cliquer sur le bouton de l'écran d'accueil.
- `tools/tests/run_tests.rb` : nouveau modèle vide en millimètres, étapes chaînées par minuteur, boîtes de message et `write_default` interceptés (aucune préférence écrite), définitions inutilisées signalées, rapport `tools/tests/results/latest-<21|17>.txt` (ignoré par git).
- Cas : P1 analyseur (`vcb_parser_cases.rb`, vrai `to_l` ; les yards sont sautés là où `to_l` ne les connaît pas, SketchUp 2017) ; S1 à S5 commandes (création d'un cercle, cercle sélectionné `+10` puis `36s`, segments d'un cylindre, Cylinder Resize Tool `52` / `--1` / annulation, `36s` change les segments) ; E1 à E8 et N1 à N6 comparaison du moteur unique avec les moteurs d'origine installés (INFO, n'échouent jamais : même solide, chaque moteur dans une opération annulée, signature de forme et temps ; réparation face à Solid Progress et rayon +0,1 mm face à Cylinder Resize sur 8 solides cassés, booléens natifs en Pro, Solid for Maker en Make ; segments 24 → 48 et 24 → 12 face à Circle Advanced sur 6 solides natifs) ; E9 segments par le moteur unique ; E10 rayon par `Resizer` ; Z1 seules des écritures dans `CircleMaster` (interceptées). Géométries en mm (celles de Solid Progress à l'échelle 1″ → 10 mm).
- `tools/tests/command_cases.rb` : commandes pilotées comme par l'utilisateur, sans clic. Souris : point de saisie simulé (`FakeInputPoint`) à une position 3D exacte, puis les événements de l'outil (`onMouseMove`, `onLButtonDown`/`Up`, `onLButtonDoubleClick`) ; clavier : `onKeyDown`/`onKeyUp`/`onCancel` ; Cylinder Resize Tool : face « sous le curseur » donnée par le test ; `UI.inputbox` et `UI.messagebox` reçoivent des réponses préparées ; fenêtre Settings ouverte pour de bon et remplie en JavaScript (`execute_script`) ; zone Mesures enregistrée (`vcb_label`, `vcb_value`). Avant chaque test, réglages connus en mémoire (48 segments, diamètre, coordonnées auto), remis ensuite.
  - C1 à C7 outil Circle (clic-clic, clic-glisser, Échap, saisies `50` `25r` `d50` `50;36s`, entier seul = côtés, modification du dernier cercle, normale de la face survolée, flèches, Shift, couleurs de l'aperçu, groupe ouvert) ; M1 à M6 mode modification (zone Mesures, valeurs, incréments, plusieurs cercles, Échap, segments d'un cercle et d'un arc, `60;36s`, deux extrémités d'un cylindre) ; F1 à F3 coins arrondis (extérieur et intérieur, rayon 10 mm 12 → 24, petit coin rayon 2 mm 12 → 48) ; K1 et K2 mode copie et double-clic ; R1 à R7 redimensionnement (fenêtre et mode Radius, outil avec survol / clic / Shift+clic, tronc de cône Oui / Non / incrément, trou traversant / tenon / trou borgne avec matériaux, trou fait par booléen, cercle non reconstructible soudé, composant ouvert) ; R8 à R10 segments dans les commandes de cylindres (EF-12 : zone Mesures `50mm; 24s`, `15;36s`, `+0,2;48s`, plusieurs cylindres, tronc de cône, refus motivé sans rien modifier, fenêtre `36s` et `12;36s` avec une étape d'annulation) ; X1 et X2 très petits trous (Ø 1 et 0,5 mm, 48 segments, cassés puis redimensionnés) ; X3 aucune définition créée ; D1 fenêtre Settings (valeurs, OK, Cancel) ; D2 extension, barre d'outils, version.
  - N7 et N8 (dans `engine_cases.rb`) : coins arrondis extérieur et intérieur, 12 → 24 et 12 → 6, face à Circle Advanced.
  - Ne sont pas testés : le moteur d'inférence de SketchUp (accrochages) et ce qui est dessiné à l'écran (seul le calcul des couleurs l'est).

Résultat du 2026-10-26 : SketchUp 2021 Pro 42/42 ; Make 2017 40/40, C7 et R7 sautés (ouvrir un groupe ou un composant par programme demande SketchUp 2020.1). Comparaisons : identiques, sauf le cercle à point de coupe (non reconnu par l'ancien Cylinder Resize) et le coin arrondi extérieur 12 → 24 (refusé par l'ancien Circle Advanced), reconstruits par Circle Master.

**Défauts trouvés par la batterie et corrigés** (2026-10-26) : très petits cercles cassés à beaucoup de segments non reconstruits (régression du moteur unique : seuil d'alignement absolu de `Chains.circumcircle`, rendu relatif) ; coin arrondi extérieur passé à plus de segments refusé (défaut de Circle Advanced 1.4.0, corrigé dans `fillet.rb`, voir le tableau de l'outil Circle).

**Limite** : un arc dont les segments mesureraient moins de la tolérance de SketchUp (0,001″ = 0,025 mm) ne peut pas être tracé, même par les outils natifs (ex. quart de cercle de rayon 0,5 mm en 48 segments).

## Structure des fichiers

```
circle_master.rb            # chargeur (SketchupExtension « Circle Master »)
circle_master/
  version.rb                # CircleMaster::VERSION
  main.rb                   # menu, barre d'outils, commandes
  settings.rb               # réglages communs et reprise des anciens
  vcb_parser.rb             # analyseur de saisie unique
  circle_tool.rb            # outil Circle (Circle Advanced)
  resegmenter.rb            # segments des cercles et arcs existants
  fillet.rb                 # segments des coins arrondis
  chains.rb                 # détection des cercles par chaînes (Re-Cercle)
  volume.rb                 # moteur unique : cylindres et troncs de cône natifs
  settings_dialog.rb        # fenêtre Settings
  html/settings.html
  cylinders/                # Cylinder Resize
    detector.rb             # détection d'un cylindre ou tronc de cône par sa paroi
    resizer.rb              # redimensionnement, une opération annulable
    resize_tool.rb          # outil interactif
  icons/                    # icônes des deux plugins d'origine, noms inchangés
tools/tests/
  run_tests.ps1             # lanceur (SketchUp 2021, Make 2017)
  run_tests.rb              # batterie dans SketchUp
  vcb_parser_cases.rb       # cas de l'analyseur (hors SketchUp ou dans SketchUp)
  engine_cases.rb           # comparaison des moteurs de reconstruction
  command_cases.rb          # commandes pilotées comme par l'utilisateur
LICENSE                     # MIT
```
