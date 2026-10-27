# Circle Master — Spécification fonctionnelle (FSD)

Rédigée pendant la construction du bundle, à partir des FSD des deux plugins d'origine :

- `../sketchup-circle-advanced/FSD.md` (outil Circle, mode modification, re-segmentation des cercles, des cylindres et des coins arrondis) ;
- `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre, redimensionnement, reconstruction native, interfaces, limitations).

Plan prévu : objectif ; entrées (sélections, saisies de l'analyseur unique) ; outil Circle ; redimensionnement des cylindres ; moteur de reconstruction unique ; réglages et reprise des anciens ; interface (menu, barre d'outils, fenêtres) ; limitations ; structure des fichiers ; tests ; historique des versions.

État : version 1.1.0 livrée (1.0.0 : étapes 1 à 7 des directives ; 1.0.1 : correctif des cercles voisins, 2026-10-27 ; 1.1.0 : fenêtre *Resize Cylinders…* avec champ Segments et boutons Step, 2026-10-27). Le mode d'emploi détaillé est dans les manuels `docs/USER_MANUAL_EN.md` et `docs/USER_MANUAL_FR.md` ; ce FSD décrit le fonctionnement et les différences avec les plugins d'origine.

## Outil Circle et fenêtre Settings (EF-01)

Code de Circle Advanced 1.4.0, comportement identique : voir `../sketchup-circle-advanced/FSD.md` § 2 (tracé, verrouillage, saisie, résultat, paramètres, mode modification, segments des cercles, des extrémités de cylindre et des coins arrondis, mode copie, double-clic) ; ce détail sera fusionné ici avec la documentation. Fichiers : `circle_tool.rb`, `resegmenter.rb`, `fillet.rb`, `settings_dialog.rb`, `html/settings.html` ; segments d'une extrémité de cylindre par le moteur unique (`volume.rb`, ci-dessous).

Différences avec Circle Advanced :

| Point | Circle Advanced | Circle Master |
|---|---|---|
| Noms dans *Édition > Annuler* | `Circle`, `Resize Circle`, `Modify Circle`, `Circle Segments` | `Circle Master — Circle`, `Circle Master — Resize Circle`, etc. (décision du 2026-10-26) |
| Rayon d'une saisie, incrément | méthodes privées de `CircleTool` | `VcbParser.radius_from`, `VcbParser.target_radius` (mêmes calculs, même refus d'une taille ≤ 0) |
| Fenêtre Settings | titre « Circle Advanced », position mémorisée sous `CircleAdvanced_Settings` ; taille fixe 360 × 480 imposée à chaque ouverture | titre « Circle Master », `CircleMaster_Settings` ; légende « Value typed without marker (all commands) » ; **redimensionnable**, 360 × 560 à la première ouverture, minimum 320 × 400, défilement si trop petite ; SketchUp mémorise taille et position entre les sessions |
| Réglages | section `CircleAdvanced` | section `CircleMaster`, reprise des anciens (ci-dessous) |
| Messages de refus d'un cylindre | « … : use Circle Re-Segment » | sans renvoi à Circle Re-Segment (plugin que les utilisateurs n'ont pas) : « Cylinder not supported (raison) », « Circle shared with another surface » |
| Coin arrondi **extérieur** passé à plus de segments (ex. rayon 10 mm, 12 → 24) | refusé (« The rounded corner could not be rebuilt ») : les lignes provisoires suivaient les tangentes, si près du nouvel arc près des points de tangence (r × (1 − cos pas) : 0,02 mm) que SketchUp y collait ses premiers sommets (tolérance 0,001″), et la face provisoire était cherchée au 1er segment, où elle finit en pointe | `fillet.rb` : lignes provisoires vers un point de la bissectrice deux fois plus loin du centre que le coin ; face provisoire cherchée au segment du milieu. Vérifié : rayon 10 mm 12 → 24, rayon 2 mm 12 → 48 ; mêmes résultats que Circle Advanced là où il fonctionnait (12 → 6, coin intérieur) |

## Redimensionnement des cylindres (EF-02 à EF-06)

Code de Cylinder Resize 0.3.0, comportement identique : voir `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre ou tronc de cône par sa paroi, rayon cible par cercle, cônes, déplacement des sommets ou reconstruction native des cercles cassés, soudure en secours, faces hôtes, composants, interfaces, limitations) ; ce détail sera fusionné ici avec la documentation. Fichiers : `cylinders/detector.rb`, `cylinders/resizer.rb`, `cylinders/resize_tool.rb` ; fenêtre `resize_dialog.rb` et `html/resize.html`, ouverte par `CircleMaster.resize_selection` (`main.rb`, ci-dessous) ; reconstruction native par le moteur unique (`volume.rb`, ci-dessous).

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

### Fenêtre *Resize Cylinders…* (EF-02, EF-13, 1.1.0)

`circle_master/resize_dialog.rb` (`CircleMaster::ResizeDialog`) et `circle_master/html/resize.html` ; remplacent en 1.1.0 l'`UI.inputbox` de Cylinder Resize (champs *Mode* et *Value*), qui n'accepte pas de boutons.

- **Ouverture** : `CircleMaster.resize_selection` détecte les cylindres de la sélection (`Detector.from_faces`, inchangé ; aucun → message) puis `ResizeDialog.show` (`UI::HtmlDialog`, `show_modal` ; 420 × 430 à la première ouverture, minimum 380 × 360, taille et position mémorisées sous `CircleMaster_Resize`).
- **Valeurs affichées** : nombre de cylindres et de cônes ; *Mode* = réglage commun ; *Value* = taille du premier cylindre dans ce mode (`Sketchup.format_length` ; diamètre et rayon envoyés tous deux : la valeur suit le mode tant qu'elle n'est pas modifiée) ; *Segments* = nombre commun (`Detector::Cylinder#segments`), vide avec « mixed » s'ils diffèrent ; titre du cadre *Step (diameter|radius, unité)*, unité tirée de `UnitsOptions['LengthUnit']` (`in ft mm cm m yd`).
- **Saisie envoyée** (`sketchup.apply(mode, value, segments)`) : *Value* seulement si elle diffère de la taille affichée pour le mode choisi ; *Segments* seulement s'il diffère de la valeur initiale (entier de 3 à 999 vérifié dans la page, sinon message) ; un bouton **Step** envoie sa valeur (`+0.05` à `+0.3`, `-0.05` à `-0.3`) à la place de *Value*. Ruby assemble la saisie dans la syntaxe de la zone Mesures (`ResizeDialog.input_text` : `+0.2;36s`) et l'applique par `CircleMaster.resize_cylinders` (l'ancienne fin de `resize_selection`, sans changement : mode écrit s'il change, `VcbParser.parse`, question sur les cônes, `Resizer.resize`, barre d'état). Rien de modifié : seul le mode est enregistré, s'il a changé.
- **Pas** : en unités du modèle (`to_l`, choix de l'utilisateur), sur le diamètre ou le rayon selon le mode (`VcbParser.target_radius`), depuis la taille de chaque cylindre ; un incrément garde les troncs de cône sans question (EF-04) ; une étape d'annulation par clic. Nommés *Step* et non *Clearance* : jeux d'impression, mais aussi corrections de taille.
- **Fin** : opération faite → fenêtre fermée ; `ArgumentError` (saisie invalide, taille ≤ 0, segments refusés : levés avant toute modification) → message en rouge dans la fenêtre, qui reste ouverte ; cônes gardés à la question → fenêtre ouverte ; autre erreur (pendant l'opération, annulée) → fenêtre fermée, boîte de message et console comme avant. Un seul envoi à la fois (page : `busy` ; Ruby : plus rien après une opération faite). *Cancel*, *Échap* : fermée sans rien changer.
- **Différences avec l'ancienne fenêtre** : valider la valeur affichée (arrondie, ex. `~ 5,2mm`) la réappliquait et pouvait décaler légèrement la taille ; changer le mode sans retaper la valeur appliquait le diamètre affiché comme un rayon. Les deux sont évités.
- `HtmlDialog#show_modal` ne rend la main à Ruby qu'à la fermeture de la fenêtre (Windows, SketchUp 2021, constaté le 2026-10-27) ; sans conséquence : les rappels de la page sont traités pendant l'attente. Les tests l'affichent avec `show`.

## Moteur de reconstruction unique (Q-2, Q-3)

`circle_master/volume.rb` (`CircleMaster::Volume`) et `circle_master/chains.rb` (`CircleMaster::Chains`) : moteur de Solid Progress 2.0.1 (issu de Re-Cercle 2.0, réparation des trous par grilles de Solid for Maker), choisi après comparaison des trois moteurs d'origine (2026-10-26).

- `Volume.build(faces)` → `[body, nil]` ou `[nil, raison]` : paroi = faces reliées par arêtes adoucies, bordée par 2 boucles ; chaque boucle est un cercle natif (lu sur son `ArcCurve`, quel que soit son nombre de segments, comme Circle Advanced) ou une chaîne (`Chains.chain_from` : points de coupe acceptés, 6 segments au moins ; test d'alignement des sommets relatif à la taille, pour les très petits cercles) ; même nombre de segments, coaxiales, aucune ligne raccordée, faces voisines dans le plan, une face à un bout au moins.
- `Volume.from_curve(curve)` : corps dont `curve` (cercle natif sélectionné) est une extrémité ; `ArgumentError` avec la raison sinon (outil Circle).
- `Volume.rebuild(entities, body, radii: nil, segments: nil)` : par défaut même taille et mêmes segments (réparation) ; `radii:` (un rayon par boucle, Cylinder Resize) et `segments:` (Circle Advanced). Phase : premier coin de la boucle 0. Vérification finale : chaque bout est une seule `ArcCurve` de N arêtes au rayon cible, sinon exception (l'opération de l'appelant est annulée). Renvoie un sommet du cercle de départ (outil Cylinder Resize).
- Arêtes des nouveaux cercles retrouvées par la géométrie (`Volume.ring_edge?`, et `Fillet.ring_edges` pour l'arc d'en face d'un coin arrondi) : les deux extrémités sur le cercle à la tolérance près (`max(0,001″, 0,5 % du rayon)`) **et**, depuis la 1.0.1, l'arête appartient à une `ArcCurve` centrée sur ce cercle. En 1.0.0, une arête d'un autre cercle qui touchait le cercle reconstruit (deux trous tangents, ou un trou tangent au prolongement du cercle d'un coin arrondi), ou qui en passait à moins de la tolérance, était comptée avec lui : la vérification finale refusait et tout était annulé. Un test sur les seuls angles des sommets ne suffit pas : deux trous de même rayon et même nombre de segments ont, au point de contact, des arêtes presque parallèles, décalées de 0,03 mm vers l'extérieur, aux angles de deux sommets consécutifs.
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
| `Resize Cylinders…` | `resize_dialog_16/24.png` | Fenêtre de redimensionnement (EF-02), avec champ Segments et boutons Step en 1.1.0 (EF-13) |
| `Cylinder Resize Tool` | `resize_tool_16/24.png` | Outil interactif de Cylinder Resize (EF-03) |
| *(séparateur)* | | |
| `Settings…` | `settings_16/24.png` | Fenêtre de réglages |

Curseurs des outils : `cursor_circle.png`, `cursor_resize.png`. Les boutons `Circle` et `Cylinder Resize Tool` sont cochés quand leur outil est actif. La garde `unless @loaded` évite les doublons au rechargement ; `CircleMaster.reload` recharge les fichiers de `FILES` (développement).

## Tests (NF-06)

Batterie automatique sur le modèle de Solid Progress, hors `.rbz` :

- `tools/tests/run_tests.ps1` (ASCII) : SketchUp fermé, il déploie le plugin (`circle_master.rb` + miroir `robocopy` de `circle_master/`), lance SketchUp avec `-RubyStartup tools/tests/run_tests.rb`, attend le rapport, ferme le seul SketchUp lancé et affiche le rapport. Options `-Versions 2021,2017`, `-Timeout`, `-NoDeploy`. SketchUp 2021 : écran d'accueil désactivé le temps du test (`PrivatePreferences.json` sauvegardé d'abord dans `%USERPROFILE%\claude-backups\…`, 5 copies gardées, fichier de plus de 20 Mo jamais touché) ; Make 2017 : cliquer sur le bouton de l'écran d'accueil.
- `tools/tests/run_tests.rb` : nouveau modèle vide en millimètres, étapes chaînées par minuteur, boîtes de message et `write_default` interceptés (aucune préférence écrite), définitions inutilisées signalées, rapport `tools/tests/results/latest-<21|17>.txt` (ignoré par git).
- Cas : P1 analyseur (`vcb_parser_cases.rb`, vrai `to_l` ; les yards sont sautés là où `to_l` ne les connaît pas, SketchUp 2017) ; S1 à S5 commandes (création d'un cercle, cercle sélectionné `+10` puis `36s`, segments d'un cylindre, Cylinder Resize Tool `52` / `--1` / annulation, `36s` change les segments) ; E1 à E8 et N1 à N6 comparaison du moteur unique avec les moteurs d'origine installés (INFO, n'échouent jamais : même solide, chaque moteur dans une opération annulée, signature de forme et temps ; réparation face à Solid Progress et rayon +0,1 mm face à Cylinder Resize sur 8 solides cassés, booléens natifs en Pro, Solid for Maker en Make ; segments 24 → 48 et 24 → 12 face à Circle Advanced sur 6 solides natifs) ; E9 segments par le moteur unique ; E10 rayon par `Resizer` ; Z1 seules des écritures dans `CircleMaster` (interceptées). Géométries en mm (celles de Solid Progress à l'échelle 1″ → 10 mm).
- `tools/tests/command_cases.rb` : commandes pilotées comme par l'utilisateur, sans clic. Souris : point de saisie simulé (`FakeInputPoint`) à une position 3D exacte, puis les événements de l'outil (`onMouseMove`, `onLButtonDown`/`Up`, `onLButtonDoubleClick`) ; clavier : `onKeyDown`/`onKeyUp`/`onCancel` ; Cylinder Resize Tool : face « sous le curseur » donnée par le test ; `UI.messagebox` reçoit des réponses préparées ; fenêtres Settings et Resize Cylinders ouvertes pour de bon et remplies en JavaScript (`execute_script` ; `show_modal` remplacé par `show` le temps des tests, sinon Ruby attendrait la fermeture ; fonction de rappel de lecture `cm_tests_values` ajoutée avant le chargement de la page) ; zone Mesures enregistrée (`vcb_label`, `vcb_value`). Avant chaque test, réglages connus en mémoire (48 segments, diamètre, coordonnées auto), remis ensuite.
  - C1 à C7 outil Circle (clic-clic, clic-glisser, Échap, saisies `50` `25r` `d50` `50;36s`, entier seul = côtés, modification du dernier cercle, normale de la face survolée, flèches, Shift, couleurs de l'aperçu, groupe ouvert) ; M1 à M6 mode modification (zone Mesures, valeurs, incréments, plusieurs cercles, Échap, segments d'un cercle et d'un arc, `60;36s`, deux extrémités d'un cylindre) ; F1 à F3 coins arrondis (extérieur et intérieur, rayon 10 mm 12 → 24, petit coin rayon 2 mm 12 → 48) ; F4 coin arrondi r 8 avec un trou Ø 14 à 64 segments tangent au prolongement de son cercle, 6 → 16 (1.0.1) ; K1 et K2 mode copie et double-clic ; R1 à R7 redimensionnement (fenêtre et mode Radius, outil avec survol / clic / Shift+clic, tronc de cône Oui / Non / incrément, trou traversant / tenon / trou borgne avec matériaux, trou fait par booléen, cercle non reconstructible soudé, composant ouvert) ; R8 à R10 segments dans les commandes de cylindres (EF-12 : zone Mesures `50mm; 24s`, `15;36s`, `+0,2;48s`, plusieurs cylindres, tronc de cône, refus motivé sans rien modifier, fenêtre : champ Segments 36 puis `12;36s` dans *Value*, une étape d'annulation) ; R11 deux trous Ø 40 tangents (24 et 48 segments), `48s` sur le premier par l'outil Circle puis `36s` par Cylinder Resize Tool, le second intact (1.0.1 ; Ø 40 : arêtes en vis-à-vis à 0,086 mm, dans la tolérance de Circle Master mais loin de la soudure de SketchUp) ; R12 boutons Step (1.1.0, EF-13 : valeurs affichées, +0.2, -0.05, mode Radius et valeur qui suit, +0.1 sur le rayon, Segments 36 + bouton, taille négative → message dans la fenêtre restée ouverte, Cancel, tronc de cône gardé sans question) ; X1 et X2 très petits trous (Ø 1 et 0,5 mm, 48 segments, cassés puis redimensionnés) ; X3 aucune définition créée ; D1 fenêtre Settings (valeurs, OK, Cancel) ; D2 extension, barre d'outils, version.
  - N7 et N8 (dans `engine_cases.rb`) : coins arrondis extérieur et intérieur, 12 → 24 et 12 → 6, face à Circle Advanced.
  - Ne sont pas testés : le moteur d'inférence de SketchUp (accrochages) et ce qui est dessiné à l'écran (seul le calcul des couleurs l'est).

Résultat du 2026-10-26 : SketchUp 2021 Pro 43/43 ; Make 2017 41/41, C7 et R7 sautés (ouvrir un groupe ou un composant par programme demande SketchUp 2020.1). Comparaisons : identiques, sauf le cercle à point de coupe (non reconnu par l'ancien Cylinder Resize) et le coin arrondi extérieur 12 → 24 (refusé par l'ancien Circle Advanced), reconstruits par Circle Master.

Résultat du 2026-10-27 (1.0.1) : SketchUp 2021 Pro 45/45 ; Make 2017 43/43, C7 et R7 sautés ; F4 et R11 échouaient sur la 1.0.0 (« could not be rebuilt ») ; comparaisons inchangées.

Résultat du 2026-10-27 (1.1.0) : SketchUp 2021 Pro 46/46 ; Make 2017 44/44, C7 et R7 sautés ; N1 à N8 sautés (Circle Advanced désinstallé le même jour : plus de comparaison des segments).

**Défauts trouvés par la batterie et corrigés** (2026-10-26) : très petits cercles cassés à beaucoup de segments non reconstruits (régression du moteur unique : seuil d'alignement absolu de `Chains.circumcircle`, rendu relatif) ; coin arrondi extérieur passé à plus de segments refusé (défaut de Circle Advanced 1.4.0, corrigé dans `fillet.rb`, voir le tableau de l'outil Circle).

**Défaut trouvé en préparant la publication et corrigé en 1.0.1** (2026-10-27) : cercle voisin compté avec le cercle reconstruit (moteur unique ci-dessus).

**Limite (cercles tangents)** : deux cercles qui se touchent se trouvent, près du point de contact, à quelques centièmes de mm (r × pas², environ 0,03 mm pour deux trous Ø 14 à 48 segments). Quand un sommet du cercle reconstruit tombe à moins de 0,001″ (0,025 mm) de l'autre, SketchUp coupe l'arête voisine et soude les deux cercles : le cercle reconstruit est alors en deux courbes, la vérification finale refuse et rien n'est modifié. Selon la position exacte (arrondis), le même changement passe ou non. Aucun outil ne peut l'éviter sans déplacer la géométrie ; un écart de 0,1 mm suffit (des polygones inscrits ne sont jamais plus proches que leurs cercles) (observé le 2026-10-27, test manuel de l'utilisateur et diagnostic).

**Limite** : un arc dont les segments mesureraient moins de la tolérance de SketchUp (0,001″ = 0,025 mm) ne peut pas être tracé, même par les outils natifs (ex. quart de cercle de rayon 0,5 mm en 48 segments).

## Compatibilité des versions de SketchUp (NF-04, NF-06)

Testées : Make 2017 (17.2.2555) et Pro 2021 (21.0.391), Windows. Annoncées sur SketchUcation (cases cochées par l'auteur le 2026-10-27) : **SU 2017 à SU 2027**, d'après une vérification théorique du 2026-10-27 (seules 2017 et 2021 sont utilisables sur le PC de développement : la licence de SketchUp 2023 installée a expiré).

| SketchUp | Ruby | Points vérifiés |
|---|---|---|
| 2017, 2018 | 2.2.4 | Testé en 2017 ; 2018 : même Ruby. `Entities#weld` (2020.1+) avec repli : un cercle non reconstructible reste en arêtes |
| 2019, 2020 | 2.5 | Rien de concerné (unités affichées avec une espace depuis 2019 : déjà le cas en 2021, testé) |
| 2021/22, 2023 | 2.7 | Testé en 2021 ; 2023 : `erase_entities` refuse d'effacer une entité du chemin d'édition ouvert (le plugin n'efface que des arêtes et faces du contexte actif) |
| 2024 à 2026 | 3.2.2 | Aucune méthode retirée par Ruby 3 (`File.exists?`, `Fixnum`, `URI.escape`…) ; arguments nommés appelés par leur nom ; aucun `Struct` construit avec des mots-clés. 2025 : coordonnées d'écran en pixels logiques (seule la taille du petit cercle d'aperçu, `pixels_to_model`, peut changer sur un écran à haute résolution). 2026 : `line_width` (1 ou 3), transformations inversibles : valeurs déjà valides |
| 2027 | 3.4.9 | Aucune bibliothèque sortie de Ruby 3.4 utilisée (seulement `json`) ; pas de `it` ; `add_circle` / `add_arc` à rayon nul renvoient une liste vide (taille 0 refusée par l'analyseur) |

Contrôles faits : `ruby -wc` (Ruby 3.3) sur tous les fichiers sans avertissement ; `tools/tests/vcb_parser_cases.rb` hors SketchUp sous Ruby 3.3 avec les avertissements de dépréciation : 88/88. Sources : notes de version de l'API Ruby (ruby.sketchup.com), notes de SketchUp 2025 et 2026 (help.sketchup.com). macOS non testé.

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
  resize_dialog.rb          # fenêtre Resize Cylinders (champ Segments, boutons Step)
  html/settings.html
  html/resize.html
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

## Historique des versions

| Version | Date | Contenu |
|---|---|---|
| 1.0.0 | 2026-10-26 | Réunion de Circle Advanced 1.4.0 et Cylinder Resize 0.3.0 ; analyseur et réglage diamètre / rayon uniques ; moteur de reconstruction unique ; point ou virgule décimale (EF-11) ; segments dans les commandes de cylindres (EF-12) ; coins arrondis extérieurs et très petits cercles corrigés ; fenêtre Settings redimensionnable ; batterie automatique 2021 Pro et Make 2017 |
| 1.0.1 | 2026-10-27 | Correctif : segments d'un coin arrondi ou d'un cylindre refusés quand un autre cercle touchait le cercle reconstruit (trous tangents, trou tangent au prolongement d'un coin arrondi) ; tests F4 et R11 |
| 1.1.0 | 2026-10-27 | Fenêtre *Resize Cylinders…* en `HtmlDialog` : champ Segments, boutons Step de -0.3 à +0.3 en un clic (EF-13), seuls les champs modifiés appliqués, erreurs dans la fenêtre ; tests R1, R10 refaits, R12 |
