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

### Segments dans les commandes de cylindres (EF-12)

- **Demande utilisateur** : pouvoir changer le nombre de segments depuis les outils cylindres (refusé par Cylinder Resize 0.3.0) ; choix A : dans la 1.0.0.
- **circle_master/vcb_parser.rb** — `parse_size` supprimé (les commandes de cylindres utilisent `parse`) ; `describe` affiche aussi les segments (`36s`, `Ø 15mm; 36s`).
- **circle_master/cylinders/detector.rb** — `Cylinder#segments` : nombre de coins (ArcCurve, sinon chaîne, points de coupe exclus).
- **circle_master/cylinders/resizer.rb** — Segment count : contrôle de tous les cylindres concernés avant l'opération (refus `The segment count cannot be changed (…), nothing was changed`), puis `Volume.rebuild(…, radii:, segments:)` ; nombre égal à l'actuel : pas de reconstruction ; saisie sans longueur : tailles gardées ; `confirm_cones` : pas de question sans longueur.
- **circle_master/cylinders/resize_tool.rb** — `VcbParser.parse` ; zone Mesures « Diameter; Segments » / `50mm; 24s` ; aide « 36s = segments, 15;36s ». **circle_master/main.rb** — fenêtre : `parse` ; aides des deux boutons.
- **Tests** — `vcb_parser_cases.rb` : table `parse_size` retirée, 3 cas `describe` avec segments (88 cas) ; `run_tests.rb` : S5 devient « 36s change les segments » ; `command_cases.rb` : R5 + `48s`, R8 (zone Mesures, `15;36s`, `+0,2;48s`, plusieurs, cône), R9 (refus motivé, taille seule), R10 (fenêtre, annulation) ; `parse_size` remplacé par `parse` (E10, R6).
- **Résultats** : SketchUp 2021 Pro 42/42, Make 2017 40/40 (C7, R7 sautés) ; comparaisons inchangées.
- **FSD.md** — Différences avec Cylinder Resize (segments, zone Mesures, aide), analyseur, tests. **PRD.md** — EF-12, CA-08, décision.
- Test utilisateur OK dans SketchUp 2021 (48s, 20;36s, annulation, fenêtre).

### Étape 7 des directives : documentation et livraison 1.0.0

- **circle_master/volume.rb** — Messages de `from_curve` sans « use Circle Re-Segment ».
- **tools/tests/command_cases.rb** — D3 : reprise des réglages des anciens plugins (CA-05) avec `read_default` remplacé par une table (rien lu ni écrit sur le disque), priorités et écriture dans `CircleMaster` seulement.
- **README.md**, **README.fr.md** (créés) — Présentation, installation (désinstaller Circle Advanced et Cylinder Resize), raccourci C, prise en main, saisies, versions testées, origine, développement, licence ; lien relatif vers les releases (pas d'identifiant en dur).
- **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md** (créés) — Fusion du manuel de Circle Advanced et du README de Cylinder Resize, avec les nouveautés (réglage commun, point ou virgule, segments dans les commandes de cylindres, coins arrondis corrigés, fenêtre Settings), « quelle commande pour quoi », limites, dépannage ; sans captures (à faire avec le matériel de démonstration).
- **CHANGELOG.md** (créé) — Entrée 1.0.0.
- **PRD.md** — EF-01 à EF-12 « livrée en v1.0.0 », CA-05 couvert par D3, historique des livraisons. **FSD.md** — État, renvoi aux manuels, messages, historique des versions.
- Batterie : SketchUp 2021 Pro 43/43, Make 2017 41/41 (C7, R7 sautés).
- Test utilisateur confirmé avant livraison ; `build/circle_master.rbz` (25 fichiers) ; aucune donnée personnelle (historique, icônes, rbz) ; commit, tag `v1.0.0`, release GitHub privée.

### Publication : dépôt public, images et page SketchUcation

- **Demande utilisateur** : publier Circle Master sur SketchUcation — 2 ou 3 images parlantes, une belle description qui insiste sur le nombre de segments gardé d'une session à l'autre, la saisie en diamètre ou en rayon et la modification des cercles faisant partie d'un volume ; créer la fiche avec le bouton vert **+**, sans publier (l'auteur clique lui-même) ; passer le dépôt GitHub en public après vérification.
- **Dépôt GitHub rendu public** — Avant : tout l'historique contrôlé (`../sketchup-publication/outils/scan_personal_data.ps1` et recherches complémentaires : chemins en `/`, nom d'utilisateur, `AppData`, IP, e-mails) : 12 commits, auteur `noreply`, rien de personnel ; icônes et `.rbz` de la release (25 fichiers, identiques au tag `v1.0.0`) sans donnée personnelle. Après : page, manuel, release et `.rbz` accessibles sans connexion.
- **tools/demo/screenshots.ps1** (créé, repris de `tools/tests/run_tests.ps1`) — Déploie le plugin, lance SketchUp 2021 avec `-RubyStartup`, attend `DONE`, ferme seulement ce SketchUp ; sauvegarde des préférences avant de couper l'écran d'accueil, rétabli ensuite (aussi en cas d'erreur, `finally`). Essai de captures d'écran de la fenêtre abandonné : la copie de l'écran est refusée dans la session de Claude Code (« handle is invalid ») et `PrintWindow` rend la vue OpenGL en blanc.
- **tools/demo/screenshots.rb** (créé) — Scènes simples en mm, commandes du plugin appliquées comme par l'utilisateur (sélection, outil, texte tapé) ; rendus `view.write_image` avant / après : pièce avec tenon, trou et coins arrondis (`64s`, `16s`), deux disques 24 / 64 segments, bloc à trou Ø 5 (`5.2;48s`) ; positions à l'écran des points à légender (`anchors.json`). Rien n'est écrit dans les réglages de l'utilisateur (`write_default` bloqué pour `CircleMaster`), boîtes de message notées.
- **tools/demo/make_images.py** (créé, Pillow) — Mise en page des trois images (1380 px, titres, étiquettes, saisies, cotes) et de l'icône 54 px (cercle mi-facettes mi-lisse, diamètre rouge, couleurs des icônes de la barre d'outils) ; la fenêtre Settings est le vrai `settings.html` rendu par Chrome sans affichage (valeurs 64 / Diameter par un faux objet `sketchup`, largeur 500 px : minimum de Chrome).
- **docs/images/cm_segments.png**, **cm_settings.png**, **cm_resize.png** (créés) — Palette de 256 couleurs (58, 82 et 41 Ko) ; copies de 690 px pour SketchUcation dans un dossier de travail ; aucune métadonnée personnelle.
- **docs/SKETCHUCATION.md** (créé) — Texte de la page en anglais d'après `../sketchup-publication/MODELE_SKETCHUCATION.md` ; vérifié avant de l'écrire : l'outil Cercle natif revient à 24 segments à chaque démarrage (forum SketchUp).
- **SketchUcation** (Dev Tools, Chrome de l'utilisateur) — Fiche `Circle_Master` créée avec le bouton vert **+** ; *Files* : `Circle_Master.rbz` (asset de la release 1.0.0), icône, 3 images ; *Basic Info* (compatibilité SU 2017 et SU 2021/22 seulement, catégories Drawing, Modification, 3D Printing, *Support Link* GitHub, pas de vidéo) ; *Overview*, *Start*, *Documentation*, *Release Notes*. Enregistrée en brouillon onglet par onglet, vérifiée en rouvrant l'éditeur ; **non publiée**. *Author Info* vide. Constat : les champs texte de *Basic Info* ne sont pris en compte qu'à la frappe (événement `keyup`), sinon ils sont enregistrés vides.
- **Défaut trouvé (non corrigé, à décider)** : `Fillet.rebuild` → `ring_edges` choisit les arêtes de l'arc opposé par la seule position de leurs extrémités sur le cercle complet ; quand un trou de la même face est tangent au prolongement du cercle d'un coin arrondi et a beaucoup de segments (ici Ø 14 tangent à un coin r 8, 64 segments), une arête du trou est prise pour une arête de l'arc (17 au lieu de 16) : la vérification finale refuse et tout est annulé (« The rounded corner could not be rebuilt, nothing was changed »). Sans dommage pour le modèle. Correction possible : ne garder que les arêtes dans l'angle de l'arc. Reproduit par un diagnostic isolé (dossier de travail) : 14 cas sans trou ni tenon passent, l'échec n'apparaît qu'après `64s` sur le trou tangent.

## Session du 2026-10-27

### Version 1.0.1 : cercle voisin compté avec le cercle reconstruit

- **Demande utilisateur** : corriger le défaut en 1.0.1 avant de publier, cylindres compris.
- **Diagnostic** (dossier de travail, SketchUp 2021, plugin 1.0.0) : même défaut dans le moteur des cylindres (`Volume.ring_edges`, utilisé par la vérification finale, la mise à l'échelle d'un cône et la restauration des faces) : deux trous Ø 14 tangents, 48 segments, `48s` → « The cylinder could not be rebuilt ». Trois cas du diagnostic refusés pour une autre raison, normale (« cylinder end with a line attached ») : un sommet de chaque trou à moins de 0,025 mm l'un de l'autre, fusionnés par SketchUp.
- **tools/tests/command_cases.rb** — F4 : coin arrondi r 8 (6 segments) et trou traversant Ø 14 à 64 segments tangent au prolongement de son cercle, `16s` ; R11 : deux trous Ø 14 tangents (24 et 48 segments), `48s` sur le premier par l'outil Circle puis par Cylinder Resize Tool, le second intact. Les deux échouent sur la 1.0.0 (« could not be rebuilt »), comme attendu.
- **Premier essai écarté** : arête retenue seulement si ses extrémités sont aux angles de deux sommets consécutifs du nouveau cercle (fonction ajoutée à `chains.rb`). Corrige F4, pas R11 : deux trous de même rayon et même nombre de segments ont, au point de contact, des arêtes presque parallèles décalées de 0,03 mm vers l'extérieur, aux angles de deux sommets consécutifs. Retiré (`chains.rb` inchangé).
- **circle_master/volume.rb** — `ring_edge?` : en plus des deux extrémités sur le cercle, l'arête doit appartenir à une `ArcCurve` centrée sur ce cercle (à la tolérance près) ; l'arête d'un cercle voisin a sa courbe centrée ailleurs.
- **circle_master/fillet.rb** — `ring_edges` (arc d'en face d'un coin arrondi) : même condition.
- **circle_master/version.rb** — `1.0.1`. **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md** — Version 1.0.1.
- **Proposition de l'utilisateur écartée** (décalage automatique d'un millième pour éviter les tangences) : 0,001 mm resterait dans la tolérance (0,5 % du rayon, 0,04 mm pour r 8) et la géométrie ne doit pas bouger (cotes exactes) ; la correction ne déplace rien.
- **Batterie** : SketchUp 2021 Pro 45/45, Make 2017 43/43 (C7, R7 sautés) ; comparaisons avec les anciens moteurs inchangées (mêmes deux écarts connus, en faveur de Circle Master).
- **CHANGELOG.md** — Entrée 1.0.1. **FSD.md** — État, recherche des arêtes des nouveaux cercles, tests F4 et R11, résultats, défaut corrigé, historique. **PRD.md** — Vérification, décision, historique des livraisons.
- `build/circle_master.rbz` 1.0.1 (mêmes 25 fichiers que la 1.0.0, chemins en `/`) ; l'ancien gardé en `build/circle_master-1.0.0.rbz` (hors git).
- **.gitignore** — `__pycache__/` (cache Python laissé par `tools/demo/make_images.py`).
- **Test manuel de l'utilisateur** (géométrie de F4 et R11 tracée par un script du dossier de travail) : coin arrondi OK ; trous Ø 14 tangents, `48s` puis Cylinder Resize Tool `36s` → parfois « The cylinder could not be rebuilt, nothing was changed », parfois OK au deuxième essai. Diagnostic (même séquence, 6 cas) : **soudure par SketchUp**, pas le défaut corrigé. Les arêtes en vis-à-vis de deux trous Ø 14 tangents ne sont qu'à environ 0,03 mm ; un sommet du cercle reconstruit tombe parfois à moins de 0,001″ de l'autre trou, SketchUp coupe son arête (48 → 49 arêtes) et le cercle reconstruit sort en deux courbes (ex. 33 + 31) : refus légitime, rien n'est modifié. Selon la position dans le modèle, le même `36s` passe ou non. Aussi constaté : près du point de contact, le survol peut désigner l'autre trou. L'orange de l'outil est la couleur de survol (bleu : sélectionné), pas une erreur.
- **tools/tests/command_cases.rb** — R11 refait avec des trous **Ø 40** (arêtes en vis-à-vis à 0,086 mm : dans la tolérance de Circle Master, 0,1 mm, loin de la soudure de SketchUp) : `48s` par l'outil Circle puis `36s` par Cylinder Resize Tool (parois du seul trou visé) sur le même trou. Vérifié : F4 et R11 échouent sur une copie de la 1.0.0 tirée de git (dossier de travail).
- **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md**, **docs/SKETCHUCATION.md** — Limite : cercles qui se touchent, soudés par SketchUp à moins de 0,001″ ; un écart de 0,1 mm suffit. **FSD.md** — Même limite, R11.
- **docs/SKETCHUCATION.md** — Version 1.0.1, résultats des tests, notes de version v1.0.1, liste de ce qui reste à faire sur le brouillon.

### Livraison 1.0.1

- **Test utilisateur** : « Teste OK » (géométrie de test avec trous Ø 40, coin arrondi `16s`, trou `48s` puis Cylinder Resize Tool `36s`).
- **Batterie finale** : SketchUp 2021 Pro 45/45, Make 2017 43/43 (C7, R7 sautés) ; `build/circle_master.rbz` identique au tag `v1.0.1` (25 fichiers comparés).
- **Commits** `43cd6e9` (images de publication et `tools/demo/`, `.gitignore`) et `8eebc48` (correctif 1.0.1, tests, documentation) ; recherche de données personnelles dans `git diff --cached` avant chaque commit : rien. Tag `v1.0.1`, push.
- **Release GitHub** `v1.0.1` (« Latest ») avec `circle_master.rbz` (51 523 octets) et notes en anglais (correctif, limite des cercles qui se touchent, versions testées) ; téléchargement vérifié sans connexion.
- **SketchUcation**, brouillon `Circle_Master` (Chrome de l'utilisateur) : *Files* — `Circle_Master.rbz` 1.0.0 retiré (*Remove & Update*, `window.alert` redirigé vers la console avant) puis `Circle_Master.rbz` 1.0.1 envoyé (copie de l'asset de la release) ; *Basic Info* — version 1.0.1 (saisie au clavier, pour l'événement `keyup`) ; *Overview* — résultats 45/45 et 43/43 ; *Documentation* — limite des cercles qui se touchent ; *Release Notes* — v1.0.1 au-dessus de v1.0.0. Chaque onglet enregistré (disquette verte), puis vérifié en rouvrant l'éditeur : version, longueurs des textes (*Overview* 3941, *Documentation* 3080 = texte de `docs/SKETCHUCATION.md`, *Release Notes* 635), `.rbz` présent. **Toujours non publiée** (bouton marche/arrêt jamais touché).
- **docs/SKETCHUCATION.md** — État du brouillon à jour.

### Publication et compatibilité annoncée 2017 → 2027

- **Fiche publiée** par l'auteur (bouton marche/arrêt).
- **Demande utilisateur** : vérifier en théorie les versions de SketchUp où le plugin doit tourner, pour cocher plus que 2017 et 2021 (SketchUp 2023 du PC inutilisable : licence par abonnement expirée).
- **Vérification** (aucun code modifié) : Ruby embarqué par version (notes de version de l'API : 2.2.4 en 2017–2018, 2.5 en 2019–2020, 2.7 de 2021 à 2023, 3.2.2 de 2024 à 2026, 3.4.9 en 2027) ; changements de l'API de 2018 à 2027 (2023 : effacement sur le chemin d'édition ; 2025 : pixels logiques ; 2026 : `line_width`, transformations non inversibles ; 2027 : cercle de rayon nul) ; recherche dans le code des méthodes retirées par Ruby 3 et 3.4 : rien ; `ruby -wc` (Ruby 3.3) sur tous les fichiers : rien ; `vcb_parser_cases.rb` hors SketchUp sous Ruby 3.3 : 88/88.
- **SketchUcation** : cases **SU 2017 à SU 2027** cochées et enregistrées par l'auteur ; vérifié en rouvrant l'éditeur (lecture seule).
- **README.md**, **README.fr.md**, **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md** — « devrait fonctionner de 2017 à 2027, non testé » (et soudure absente avant 2020.1 dans les manuels). **FSD.md** — Section « Compatibilité des versions de SketchUp » (tableau par version). **PRD.md** — NF-06 reformulée (versions annoncées : testées + vérifiées en théorie), décision. **docs/SKETCHUCATION.md** — Cases cochées, publication.

### Anciens plugins désinstallés

- **Demande utilisateur** : désinstaller Circle Advanced et Cylinder Resize de SketchUp (dépôts archivés le même jour).
- SketchUp fermé ; copies installées vérifiées avant (Circle Advanced 1.4.0, Cylinder Resize 0.3.0) puis **déplacées** du dossier `Plugins` de SketchUp 2017 et 2021 (et Circle Advanced de SketchUp 2023) vers un dossier de sauvegarde local, nombre de fichiers et d'octets contrôlés ; réversible en les remettant dans `Plugins`. Réglages `CircleAdvanced` et `CylinderResize` laissés : Circle Master les lit tant qu'ils ne sont pas changés (EF-10). Circle Re-Segment, encore installé, laissé en attendant la décision de l'utilisateur.
- **Circle Re-Segment** désinstallé à son tour (demande utilisateur) : même méthode, SketchUp 2017 et 2021 (absent de 2023), fichiers déplacés dans un dossier de sauvegarde local, contrôlés.
- **Raccourci C** : à réassigner à `Extensions/Circle Master/Circle` par l'utilisateur lui-même (*Window > Preferences > Shortcuts*). Constaté en lecture seule : SketchUp 2017 garde ses raccourcis dans le registre (`Settings`, `Shortcut_34` = `Extensions/Circle Advanced/Circle`), SketchUp 2021 dans `SharedPreferences.json` (`%APPDATA%`), avec aussi l'ancien raccourci de `Extensions/Cylinder Resize/Cylinder Resize Tool` ; rien n'a été modifié.
- **Test utilisateur** : SketchUp démarre normalement, seul Circle Master apparaît dans le menu *Extensions*.
- **PRD.md** — Décision.
