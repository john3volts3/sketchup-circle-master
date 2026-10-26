# Journal des modifications — Circle Master

> Circle Master réunit Circle Advanced 1.4.0 (`../sketchup-circle-advanced`) et Cylinder Resize 0.3.0 (`../sketchup-cylindrer-resize`). Leur historique reste dans leurs dépôts.

## Session du 2026-10-26

### Création du dossier (aucun code)

- **Demande utilisateur** (depuis la session Solid Progress) : après l'évaluation des plugins à publier (`../sketchup-publication/EVALUATION.md`), publier Circle Advanced et Cylinder Resize réunis ; créer ce dossier et y placer les directives pour construire le bundle ; nom choisi par l'utilisateur : **Circle Master**.
- **DIRECTIVES_BUNDLE.md** — Noms, fonctions à reprendre (et ce qu'il ne faut pas ajouter), structure cible, doublons à résoudre avec preuve (analyseur, moteur de reconstruction, réglage diamètre/rayon), passage depuis les anciens plugins, tests, documentation, ordre de travail, règles.
- **PRD.md** — Exigences EF-01 à EF-10, NF-01 à NF-06, critères d'acceptation, questions ouvertes Q-1 à Q-4, décisions.
- **FSD.md** — Plan, à rédiger pendant la construction.
- **Dépôt git** initialisé à la demande de l'utilisateur (`.gitignore` repris de Solid Progress : `build/`, `tools/tests/results/`, `*.skb`, `mes tests/`) ; premier commit `14d9836` ; dépôt GitHub **privé** `sketchup-circle-master` créé et poussé. Pas encore de code.

### Étape 1 des directives : squelette du plugin

- **Décisions de l'utilisateur** : étape 1 seule pour cette session ; moteur de reconstruction à choisir parmi **trois** versions (Circle Advanced, Cylinder Resize, Solid Progress) ; anciens plugins laissés installés pendant la construction.
- **circle_master.rb** (créé) — Chargeur `SketchupExtension` « Circle Master », sur le modèle de Circle Advanced ; description réunissant les deux plugins.
- **circle_master/version.rb** (créé) — `VERSION = '1.0.0'`.
- **circle_master/settings.rb** (créé) — Réglages de Circle Advanced (`segments`, `input_mode`, `coord_mode`) dans la section `CircleMaster` ; lecture de secours dans `CircleAdvanced` puis `CylinderResize/mode` (mis en minuscules) ; écriture dans `CircleMaster` seulement. 13 cas vérifiés hors SketchUp (Sketchup simulé) : défauts, reprise, priorités, valeur invalide, anciennes sections jamais écrites.
- **circle_master/main.rb** (créé) — Menu et barre d'outils Circle Master : `Circle`, `Resize Cylinders…`, `Cylinder Resize Tool`, séparateur, `Settings…` ; libellés et icônes repris des deux plugins ; commandes provisoires « not available yet » ; garde `@loaded`, `CircleMaster.reload`.
- **circle_master/icons/** (créé) — 10 PNG copiés sans changement (`circle_*`, `settings_*`, `cursor_circle` de Circle Advanced ; `resize_dialog_*`, `resize_tool_*`, `cursor_resize` de Cylinder Resize).
- **LICENSE** (créé) — MIT, identique à celle des deux plugins.
- **DIRECTIVES_BUNDLE.md** — § 4.2 : correction après lecture du code (les deux moteurs ne sont pas des doublons : segments contre rayon ; troisième version dans Solid Progress) et décision de comparer les trois.
- **PRD.md** — Q-2 et Q-3 précisées ; décisions : comparaison à trois, anciens plugins laissés installés, priorité de reprise de `input_mode`.
- **FSD.md** — Premières sections : réglages et reprise, interface, structure des fichiers.
- Vérifications : `ruby -c` sur les 4 fichiers, pas de syntaxe postérieure à Ruby 2.2 ; plugin déployé dans les dossiers Plugins de SketchUp 2021 et 2017 (test de chargement par l'utilisateur).
- Test utilisateur OK (menu, barre d'outils, icônes) ; commit `d00d809`, poussé.

### Étape 2 des directives : analyseur de saisie unique

- **Décision de l'utilisateur** : *Cylinder Resize Tool* suit le réglage diamètre / rayon commun (dans Cylinder Resize 0.3.0, `15` y était toujours un diamètre).
- **circle_master/vcb_parser.rb** (créé) — Analyseur de Circle Advanced sans changement (`parse`, `split_sign`, `to_length`) ; ajout de `parse_size` (refus des segments, message de Cylinder Resize), `radius?`, `radius_from`, `target_radius` (repris de `circle_tool.rb`, refus d'une taille ≤ 0), `describe` (repris de Cylinder Resize) ; une valeur sans marqueur suit `Settings.input_mode`. Le paramètre `default_kind` de Cylinder Resize disparaît.
- **circle_master/main.rb** — `FILES` charge `vcb_parser`.
- **tools/tests/vcb_parser_cases.rb** (créé) — 87 cas (les « 26 cas » de Circle Advanced n'avaient pas été conservés : reconstitués à partir des deux FSD) ; hors SketchUp avec `Sketchup` et `String#to_l` simulés, ou dans SketchUp avec le vrai `to_l` ; mode de saisie changé en mémoire seulement. 87/87 hors SketchUp ; un analyseur volontairement faussé (copie dans le scratchpad) donne 4 échecs, le fichier de cas les détecte.
- **FSD.md** — Section « Saisie : analyseur unique », différences avec les analyseurs d'origine, structure.
- **PRD.md** — Décision : Cylinder Resize Tool suit le réglage commun.
- **DIRECTIVES_BUNDLE.md** — § 4.1 : cas conservés dans `tools/tests/`.
- Fichiers `vcb_parser.rb` et `main.rb` déployés dans SketchUp 2021 et 2017.
- Rien de visible à tester à cette étape (l'analyseur n'est relié à aucun bouton) : commit reporté, avec l'étape 3.

### Étape 3 des directives : outil Circle et réglages

- **Décision de l'utilisateur** : noms dans *Annuler* préfixés « Circle Master — » (choix A).
- **circle_master/circle_tool.rb** (repris de Circle Advanced 1.4.0) — Module `CircleMaster` ; méthodes privées `radius_from` / `target_radius` supprimées, 7 appels vers `VcbParser` ; constante `EPSILON` retirée (ne servait qu'à elles) ; noms d'opération `"#{PLUGIN_NAME} — …"`.
- **circle_master/resegmenter.rb**, **fillet.rb**, **volume.rb** (repris) — Nom du module seulement ; `volume.rb` provisoire jusqu'au choix du moteur unique (étape 5).
- **circle_master/settings_dialog.rb** (repris) — Module, `preferences_key: 'CircleMaster_Settings'`, `CircleMaster.circle_tool_active?`.
- **circle_master/html/settings.html** (repris) — Titre et en-tête « Circle Master » ; légende « Value typed without marker (all commands) ».
- **circle_master/main.rb** — `FILES` complet de Circle Advanced ; `Circle` active `CircleTool`, `Settings…` ouvre `SettingsDialog` ; `circle_tool_active?` et case cochée du bouton Circle.
- **FSD.md** — Section « Outil Circle et fenêtre Settings » (différences avec Circle Advanced), structure. **PRD.md** — Décision des noms dans *Annuler*.
- Vérifications : `ruby -wc` sur tous les fichiers ; plus aucune référence à `CircleAdvanced` hors reprise des réglages ; `diff` de chaque fichier repris contre l'original = changements listés seulement ; 87/87 cas de l'analyseur ; déployé dans SketchUp 2021 et 2017.
- Test utilisateur OK dans SketchUp 2021 (tracé, saisies, modification, segments d'un cylindre, annulation, Settings) ; étapes 2 et 3 commitées ensemble (`8e96112`).

### Étape 4 des directives : commandes de Cylinder Resize

- **circle_master/cylinders/detector.rb**, **rebuilder.rb** (repris de Cylinder Resize 0.3.0) — Nom du module seulement ; `rebuilder.rb` provisoire jusqu'au choix du moteur unique (étape 5).
- **circle_master/cylinders/resizer.rb** (repris) — Module ; nom d'opération « Circle Master — Resize Cylinders ».
- **circle_master/cylinders/resize_tool.rb** (repris) — Module ; `VcbParser.parse_size` ; zone Mesures « Diameter » / « Radius » et taille selon le réglage commun ; aide de la barre d'état selon le réglage.
- **circle_master/main.rb** — `FILES` + 4 fichiers `cylinders/` ; `resize_selection` (fenêtre de Cylinder Resize : *Mode* lu dans le réglage commun et écrit seulement s'il change, `parse_size`) ; `activate_resize_tool`, `resize_tool_active?`, case cochée ; aide du bouton Cylinder Resize Tool ; `not_available` supprimé (plus utilisé).
- **circle_master/settings_dialog.rb** — *OK* rafraîchit aussi Cylinder Resize Tool s'il est actif.
- **FSD.md** — Section « Redimensionnement des cylindres » (différences avec Cylinder Resize), interface, structure.
- Vérifications : `ruby -wc` sur tous les fichiers ; plus aucune référence à `CylinderResize` hors reprise des réglages ; `diff` de chaque fichier repris et de `resize_selection` contre l'original = changements listés seulement ; 87/87 cas ; déployé dans SketchUp 2021 et 2017.
- Test utilisateur OK dans SketchUp 2021 (fenêtre, incrément, annulation, outil, rayon, `--1`, refus des segments, trou dans un bloc, mode rayon).
