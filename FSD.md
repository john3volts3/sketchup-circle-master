# Circle Master — Spécification fonctionnelle (FSD)

Rédigée pendant la construction du bundle, à partir des FSD des deux plugins d'origine :

- `../sketchup-circle-advanced/FSD.md` (outil Circle, mode modification, re-segmentation des cercles, des cylindres et des coins arrondis) ;
- `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre, redimensionnement, reconstruction native, interfaces, limitations).

Plan prévu : objectif ; entrées (sélections, saisies de l'analyseur unique) ; outil Circle ; redimensionnement des cylindres ; moteur de reconstruction unique ; réglages et reprise des anciens ; interface (menu, barre d'outils, fenêtres) ; limitations ; structure des fichiers ; tests ; historique des versions.

État : squelette, analyseur unique, outil Circle et réglages (étapes 1 à 3 des directives). `Resize Cylinders…` et `Cylinder Resize Tool` ne sont pas encore portés : elles affichent « `<commande>: not available yet` » dans la barre d'état et la console.

## Outil Circle et fenêtre Settings (EF-01)

Code de Circle Advanced 1.4.0, comportement identique : voir `../sketchup-circle-advanced/FSD.md` § 2 (tracé, verrouillage, saisie, résultat, paramètres, mode modification, segments des cercles, des extrémités de cylindre et des coins arrondis, mode copie, double-clic) ; ce détail sera fusionné ici avec la documentation. Fichiers : `circle_tool.rb`, `resegmenter.rb`, `fillet.rb`, `volume.rb` (moteur provisoire, choix du moteur unique à l'étape 5), `settings_dialog.rb`, `html/settings.html`.

Différences avec Circle Advanced :

| Point | Circle Advanced | Circle Master |
|---|---|---|
| Noms dans *Édition > Annuler* | `Circle`, `Resize Circle`, `Modify Circle`, `Circle Segments` | `Circle Master — Circle`, `Circle Master — Resize Circle`, etc. (décision du 2026-10-26) |
| Rayon d'une saisie, incrément | méthodes privées de `CircleTool` | `VcbParser.radius_from`, `VcbParser.target_radius` (mêmes calculs, même refus d'une taille ≤ 0) |
| Fenêtre Settings | titre « Circle Advanced », position mémorisée sous `CircleAdvanced_Settings` | titre « Circle Master », `CircleMaster_Settings` ; légende « Value typed without marker (all commands) » |
| Réglages | section `CircleAdvanced` | section `CircleMaster`, reprise des anciens (ci-dessous) |

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

Refus (`ArgumentError`, message affiché tel quel) : saisie vide (`Empty input`), valeur illisible (`Invalid value: abc`), valeur nulle (`Value must be positive: 0`), incrément de segments (`The segment count cannot be an increment`).

Fonctions :

- `parse(text)` → `Result(length, kind, segments, bare_integer, sign)`, `delta?` vrai pour un incrément.
- `parse_size(text)` : redimensionnement des cylindres (outil et fenêtre) ; comme `parse`, mais un nombre de segments est refusé : `Changing the segment count is not supported`.
- `radius_from(res)` : rayon en pouces, signe ignoré ; `nil` sans longueur.
- `target_radius(res, current)` : la valeur, ou `current` ± l'incrément ; refus `The resulting size would be zero or negative` si le résultat est ≤ 1e-6 pouce.
- `describe(res)` : texte de la barre d'état, `Ø 15mm`, `Ø +1mm`, `R -0.1mm`.

**Réglage diamètre / rayon unique** (EF-09) : une valeur sans marqueur suit `Settings.input_mode` dans **toutes** les commandes, y compris *Cylinder Resize Tool*, où `15` était toujours un diamètre dans Cylinder Resize 0.3.0 (décision du 2026-10-26).

Différences avec les analyseurs d'origine (pas de perte de fonction) :

- `15;20` donne 20 (la dernière valeur l'emporte, comme dans Circle Advanced) ; Cylinder Resize la refusait.
- `+24s` dans le redimensionnement des cylindres : `The segment count cannot be an increment` au lieu de `Changing the segment count is not supported`.
- Le paramètre `default_kind` de Cylinder Resize disparaît : la fenêtre écrira son choix dans le réglage commun.

Cas : `tools/tests/vcb_parser_cases.rb` (87 cas : saisies des deux plugins, refus, `parse_size`, `radius_from`, `target_radius`, `describe` en mode diamètre et rayon). Hors SketchUp : `ruby tools/tests/vcb_parser_cases.rb` (`Sketchup` et `String#to_l` simulés, modèle en mm). Dans SketchUp : `CircleMasterTests::VcbParserCases.run` avec le vrai `to_l` (modèle en mm) ; le mode de saisie n'est changé qu'en mémoire.

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

| Commande | Icône | Rôle (une fois porté) |
|---|---|---|
| `Circle` | `circle_16/24.png` | Outil Circle de Circle Advanced (EF-01) |
| `Resize Cylinders…` | `resize_dialog_16/24.png` | Fenêtre de Cylinder Resize (EF-02) |
| `Cylinder Resize Tool` | `resize_tool_16/24.png` | Outil interactif de Cylinder Resize (EF-03) |
| *(séparateur)* | | |
| `Settings…` | `settings_16/24.png` | Fenêtre de réglages |

Les curseurs `cursor_circle.png` et `cursor_resize.png` sont déjà copiés pour les outils. La garde `unless @loaded` évite les doublons au rechargement ; `CircleMaster.reload` recharge les fichiers de `FILES` (développement).

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
  volume.rb                 # segments d'un cylindre ou tronc de cône (moteur provisoire)
  settings_dialog.rb        # fenêtre Settings
  html/settings.html
  icons/                    # icônes des deux plugins d'origine, noms inchangés
tools/tests/
  vcb_parser_cases.rb       # cas de l'analyseur (hors SketchUp ou dans SketchUp)
LICENSE                     # MIT
```
