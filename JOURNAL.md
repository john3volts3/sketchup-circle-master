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
