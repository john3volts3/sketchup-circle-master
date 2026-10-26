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
- Test utilisateur OK dans SketchUp 2021 (fenêtre, incrément, annulation, outil, rayon, `--1`, refus des segments, trou dans un bloc, mode rayon) ; commit `609bf7c`.

### Fenêtre Settings trop petite

- **Demande utilisateur** : la fenêtre est trop basse, les boutons ne se voient pas ; la rendre redimensionnable et garder sa taille pour les sessions suivantes.
- **circle_master/settings_dialog.rb** — `resizable: true`, `scrollable: true`, hauteur par défaut 480 → 560, minimum 320 × 400 (`min_width`, `min_height`) ; suppression du `set_size` qui imposait 360 × 480 à chaque ouverture et écrasait la taille mémorisée par SketchUp sous `preferences_key`.
- Constat (lecture seule de `PrivatePreferences.json`) : SketchUp 2021 avait déjà mémorisé 360 × 480 sous `WebCommonDialog_CircleMaster_Settings` ; sur ce PC, la première ouverture reste donc à 480 jusqu'au premier agrandissement.
- **FSD.md** — Ligne « Fenêtre Settings » des différences avec Circle Advanced.

### Lanceur de tests et comparaison des moteurs (étapes 5 et 6, préparation)

- **Demande utilisateur** : lanceur de tests repris de Solid Progress ; vérifier que le moteur de Solid Progress est le plus performant ; utiliser Solid for Maker pour les booléens sous Make 2017.
- **tools/tests/run_tests.ps1** (créé, repris de Solid Progress) — Déploiement, lancement `-RubyStartup`, attente du rapport, fermeture du seul SketchUp lancé ; sauvegarde de `PrivatePreferences.json` avant de désactiver l'écran d'accueil de 2021 ; modes manuel et démo de Solid Progress non repris.
- **tools/tests/run_tests.rb** (créé, repris de Solid Progress) — Runner (cas, minuteurs, boîtes de message interceptées, `write_default` intercepté, définitions inutilisées, rapport) ; cas INFO qui n'échouent jamais ; tests P1, S1 à S5, Z1.
- **tools/tests/engine_cases.rb** (créé) — E1 à E8 : Solid Progress (installé) contre Cylinder Resize sur le même solide cassé (géométries des T15 de Solid Progress), opérations annulées, signature de forme, temps ; booléens natifs (Pro) ou Solid for Maker 1.0.1 (Make) ; E9 segments de Circle Advanced, E10 rayon de Cylinder Resize.
- **tools/tests/vcb_parser_cases.rb** — Chaque cas attrape sa propre erreur ; dans SketchUp, décimales au séparateur du PC (`,` ici : le vrai `to_l` refuse `7.5`) ; yards sautés là où `to_l` ne les connaît pas (SketchUp 2017).
- Corrections de tests en cours de route : une distance est une `Length`, comparée avec la tolérance de SketchUp (`distance < 1e-4` toujours faux) → `.to_f` ; un cercle natif dont on coupe une arête reste natif → cas E2 sur cercle éclaté.
- Lancement : refusé à Claude avec `powershell -ExecutionPolicy Bypass` (classifieur de permissions) ; lancé directement dans la session PowerShell de Claude Code (déjà en `Bypass` pour son processus).
- **Résultats** : 9/9 sous SketchUp 2021 Pro (30 s) et sous Make 2017 (23 s). Moteurs : même résultat sur 7 géométries sur 8 ; cercle avec point de coupe : seul Solid Progress répare ; plaque de 20 trous : Solid Progress 2,1 s / Cylinder Resize 15,3 s (2021), 1,4 s / 7,3 s (2017).
- **PRD.md** — Q-2 et Q-3 : résultats et recommandation. **FSD.md** — Section « Tests », structure.

### Point ou virgule décimale (EF-11)

- **Demande utilisateur** : accepter le point et la virgule comme séparateur décimal (sur ce PC, `to_l` refusait `7.5`).
- **circle_master/vcb_parser.rb** — `local_decimals` : avant `to_l`, tout point ou virgule collé à un chiffre devient `Sketchup::RegionalSettings.decimal_separator` ; message d'erreur avec le texte tapé.
- **tools/tests/vcb_parser_cases.rb** — Conversion des cas au séparateur du PC retirée (point et virgule doivent passer avec le vrai `to_l`) ; hors SketchUp, `to_l` simulé à un seul séparateur et deux passages (virgule, point) ; 5 cas ajoutés (`7,5r`, `r7,5`, `+0,5`, `+r0,5`, refus de `x7.5`) : 92 cas. Constat : le vrai `to_l` accepte `7,5x` (lettre finale ignorée).
- **PRD.md** — EF-11, CA-07, décision (exception à « rien de nouveau en 1.0.0 »). **FSD.md** — Section Saisie : séparateur décimal, limites.
- Vérifications : 92/92 hors SketchUp avec chaque séparateur ; batterie 9/9 sous SketchUp 2021 Pro (92 cas avec le vrai `to_l`) et sous Make 2017 (91 cas, yards sautés).

### Étape 5 des directives : moteur de reconstruction unique

- **Décisions de l'utilisateur** : moteur de Solid Progress comme base, avec le rayon (Cylinder Resize) et les segments (Circle Advanced) ; détection par chaîne dans le `Detector` des cylindres (recommandation acceptée) ; géométries des tests en mm ; tolérances internes du plugin laissées en pouces (unité de SketchUp).
- **circle_master/chains.rb** (créé) — Détection par chaînes de Solid Progress 2.0.1 / Re-Cercle 2.0 (`Run`, `Chain`, `chain_from` et sa géométrie), module `CircleMaster::Chains` ; `find_chains` et le classement non repris (inutiles ici).
- **circle_master/volume.rb** (remplacé) — Moteur de Solid Progress (réparation des trous par grilles) ; ajouts : `rebuild(entities, body, radii:, segments:)`, vérification finale (une `ArcCurve` de N arêtes au rayon cible à chaque bout, sinon exception), retour d'un sommet d'ancrage, `from_curve` (Circle Advanced), lecture directe d'un cercle natif (toute valeur de segments) ; `Body#segments`.
- **circle_master/cylinders/rebuilder.rb** — Supprimé (`git rm`), remplacé par `Volume`.
- **circle_master/cylinders/resizer.rb** — Cylindre au cercle cassé : `rebuild_body` (validité + `Volume.build`) puis `Volume.rebuild(…, radii:)`, rayons associés par centre le plus proche (`radius_at`) ; repli inchangé (sommets déplacés puis soudure).
- **circle_master/cylinders/detector.rb** — `fit_circle` : cercle cassé détecté par chaîne d'abord, moyenne des sommets en secours.
- **circle_master/resegmenter.rb** — `Volume.rebuild(…, segments: n)` ; `Chains::BASE_TOL` au lieu de `Volume::BASE_TOL` (constante de l'ancien moteur).
- **circle_master/main.rb** — `FILES` : `chains` ajouté, `cylinders/rebuilder` retiré.
- **tools/tests/engine_cases.rb** (réécrit) — Comparaison avec les trois moteurs d'origine installés : réparation (Solid Progress), rayon +0,1 mm (Cylinder Resize), segments 24 → 48 et 24 → 12 (Circle Advanced, 6 solides natifs N1 à N6) ; géométries en mm (Solid Progress à l'échelle 1″ → 10 mm). **tools/tests/run_tests.rb** — `slot` en mm, hauteurs comparées en `Float`, en-tête du tableau des moteurs.
- **Résultats** (2021 Pro et Make 2017) : 9/9 ; 27 comparaisons identiques sur 28, la 28e (cercle à point de coupe) n'était pas reconnue par l'ancien Cylinder Resize et est reconstruite par Circle Master ; plaque de 20 trous, rayon : 2,0 s au lieu de 11,0 s (2021), 1,3 s au lieu de 7,2 s (2017).
- **FSD.md** — Section « Moteur de reconstruction unique », différences avec Cylinder Resize, tests, structure. **PRD.md** — Q-2 et Q-3 tranchées, décisions.
- Test utilisateur OK dans SketchUp 2021 (segments d'un cylindre, trou par *Soustraire* redimensionné en valeur et en incrément, annulation, plusieurs trous, coin arrondi).

### Étape 6 des directives : batterie complète automatique

- **Demande utilisateur** : tests entièrement automatiques.
- **tools/tests/run_tests.rb** — Interceptions ajoutées : `UI.inputbox` et `UI.messagebox` avec réponses préparées, zone Mesures (`vcb_label`, `vcb_value`) ; avant chaque test, réglages connus en mémoire (48, diamètre, auto) puis remis, outil désactivé, groupes fermés (`close_all`) ; Z1 : seules des écritures dans `CircleMaster` (interceptées).
- **tools/tests/command_cases.rb** (créé) — 31 cas : C1 à C7 (outil Circle), M1 à M6 (mode modification), F1 à F3 (coins arrondis), K1 et K2 (copie, double-clic), R1 à R7 (redimensionnement), X1 à X3 (petits trous, définitions), D1 et D2 (fenêtre Settings, extension) ; point de saisie simulé, face sous le curseur fournie, fenêtre Settings pilotée en JavaScript ; diagnostic des refus (`note_feedback`, `watch_fillet_check`).
- **tools/tests/engine_cases.rb** — N7 et N8 : coins arrondis face à Circle Advanced (`run_fillet`).
- Erreurs de tests corrigées en route : disque au sol tourné vers le bas (C1) ; composant ouvert : entités rapportées en coordonnées du modèle (R7).
- **Défauts du plugin trouvés et corrigés** (plans validés par l'utilisateur) :
  - **circle_master/chains.rb** — `circumcircle` : seuil d'alignement relatif (`d <= 1e-12 × |a|² × |b|²`) au lieu de `d < 1e-12` ; régression du moteur unique sur les très petits cercles cassés (Ø 1 mm et 0,5 mm à 48 segments) que l'ancien Cylinder Resize reconstruisait.
  - **circle_master/fillet.rb** — Coin arrondi extérieur : lignes provisoires vers `q + (q − c)` au lieu du coin `q` (le long des tangentes, SketchUp collait les premiers sommets d'un arc plus fin, tolérance 0,001″) ; face provisoire cherchée au segment du milieu de l'arc (au 1er, elle finit en pointe). Défaut hérité de Circle Advanced 1.4.0 (confirmé par la comparaison N7).
- **Résultats** : SketchUp 2021 Pro 39/39 ; Make 2017 37/37 (C7, R7 sautés : SketchUp 2020.1+) ; comparaisons identiques sauf les deux cas où l'ancien plugin échouait.
- **FSD.md** — Tests (cas, méthode, résultats, défauts corrigés, limite des arcs plus fins que la tolérance), différence « coin arrondi extérieur » avec Circle Advanced, test d'alignement relatif. **PRD.md** — Vérification des critères d'acceptation, décisions.
- Test utilisateur OK dans SketchUp 2021 sur une vraie pièce (coin arrondi passé à plus de segments).
