# Circle Master — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* sera dans `FSD.md`. Directives de construction : `DIRECTIVES_BUNDLE.md`.

Dernière mise à jour : 2026-10-27 (livraison 1.1.0).

## 1. Contexte et problème

Pour imprimer en 3D une pièce modélisée dans SketchUp, deux gestes manquent : **changer le nombre de segments d'un cylindre déjà extrudé** (les facettes se voient à l'impression ; *Infos sur l'entité* ne le permet que pour un cercle plat) et **remettre un trou ou un tenon au diamètre exact** (jeu d'impression), surtout quand une opération booléenne a cassé le cercle. Aucun outil gratuit ni payant ne le fait de façon dédiée (`../sketchup-publication/EVALUATION.md`). Circle Advanced 1.4.0 et Cylinder Resize 0.3.0, du même auteur, le font ; Circle Master les réunit pour une publication gratuite.

## 2. Utilisateurs et usages

Personnes qui modélisent dans SketchUp des pièces techniques à imprimer en 3D (trous, tenons, chevilles, chambrages), sous SketchUp Pro ou Make 2017.

## 3. Objectifs et critères de succès

- Un seul plugin, une page SketchUcation, un manuel, sans perte de fonction par rapport aux deux plugins d'origine.
- Batterie automatique verte sous SketchUp 2021 Pro et Make 2017.
- Publication gratuite, sans concurrencer un plugin payant équivalent.

## 4. Périmètre

### Inclus

Toutes les fonctions de Circle Advanced 1.4.0 et de Cylinder Resize 0.3.0 (voir EF ci-dessous).

### Exclu

- Commande autonome de réparation des cercles cassés (Curvizard, Eneroth Auto Weld : payants).
- Cônes pointus, cylindres obliques, tubes et cylindres empilés au-delà de ce que font déjà les deux plugins.
- Nouvelles fonctions en 1.0.0, sauf EF-11 et EF-12 (demandées par l'utilisateur le 2026-10-26).

## 5. Exigences fonctionnelles

Priorité : **I** = indispensable, **Im** = important, **S** = souhaitable.

| ID | Exigence | Priorité | Statut |
|---|---|---|---|
| EF-01 | **Outil Circle** de Circle Advanced, à l'identique : ses exigences EF-01 à EF-22 (outil comme le natif, 48 segments par défaut et mémorisés, diamètre par défaut, `r` / `d`, `48s`, `50;36s`, modification du dernier cercle, verrouillage de la normale, aperçu coloré, contexte actif, fenêtre de réglages, mode de coordonnées, mode modification des cercles et arcs sélectionnés avec valeur absolue ou incrément, segments des cercles et arcs, des extrémités de cylindre et de tronc de cône, des coins arrondis, mode copie Ctrl, double-clic) | I | livrée en v1.0.0 |
| EF-02 | **Resize Cylinders…** (fenêtre) de Cylinder Resize : paroi d'un ou plusieurs cylindres sélectionnée, diamètre ou rayon, incréments | I | livrée en v1.0.0 |
| EF-03 | **Cylinder Resize Tool** (outil interactif) : survol, sélection, Shift/Ctrl pour ajouter, saisie `15`, `d15`, `r7.5`, `+1`, `-0.1`, `+r0.5`, `--1` ; l'outil reste actif | I | livrée en v1.0.0 |
| EF-04 | Troncs de cône : un incrément garde l'angle, une valeur absolue en fait un cylindre après confirmation | I | livrée en v1.0.0 |
| EF-05 | Cercles cassés (arêtes, courbe soudée, cercle découpé par un booléen) : le cylindre redimensionné est reconstruit en cercles natifs ; soudure en secours (SketchUp 2020.1+) | I | livrée en v1.0.0 |
| EF-06 | Trous dans un bloc et tenons : face hôte intacte ; dans un composant, la définition est modifiée | I | livrée en v1.0.0 |
| EF-07 | Menu *Extensions > Circle Master* et barre d'outils **Circle Master** : Circle, Resize Cylinders…, Cylinder Resize Tool, Settings… | I | livrée en v1.0.0 |
| EF-08 | **Un seul analyseur de saisie** accepté par l'outil Circle et par le redimensionnement des cylindres | Im | livrée en v1.0.0 |
| EF-09 | **Un seul réglage diamètre / rayon** pour toutes les commandes | Im | livrée en v1.0.0 |
| EF-10 | Réglages repris de Circle Advanced (`CircleAdvanced`) et de Cylinder Resize (`CylinderResize`) tant qu'ils ne sont pas changés dans Circle Master | Im | livrée en v1.0.0 |
| EF-12 | **Nombre de segments dans les commandes de cylindres** (*Cylinder Resize Tool*, *Resize Cylinders…*) : `36s`, `15;36s`, `+0,2;48s` ; cylindre natif ou cassé reconstruit en natif, une étape d'annulation ; refus motivé sans rien modifier si un cylindre ne peut pas être reconstruit | Im | livrée en v1.0.0 |
| EF-11 | **Point ou virgule décimale** dans toutes les saisies (zone Mesures, fenêtre *Resize Cylinders…*), quel que soit le séparateur décimal du PC (`7.5` et `7,5`) | Im | livrée en v1.0.0 |
| EF-13 | **Fenêtre *Resize Cylinders…* : champ Segments et boutons Step** (demande du 2026-10-27, pour ajuster les emboîtements en impression 3D, ou corriger une taille) : champ du nombre de segments pré-rempli ; 12 boutons +0.05, +0.1, +0.15, +0.2, +0.25, +0.3 et -0.05 à -0.3 ; un clic applique le pas à chaque cylindre depuis sa propre taille (avec les segments s'ils ont été changés) et ferme la fenêtre ; pas sur le diamètre ou le rayon selon le *Mode* ; pas en unités du modèle ; seuls les champs modifiés sont appliqués ; erreurs affichées dans la fenêtre | Im | livrée en v1.1.0 |

## 6. Exigences non fonctionnelles

| ID | Exigence |
|---|---|
| NF-01 | Résultats en cercles natifs `ArcCurve` (inférence du centre, *Infos sur l'entité*) ; matériaux, balises et orientation des faces conservés |
| NF-02 | Une seule opération annulable par action ; en cas d'échec, rien n'est modifié et un message clair s'affiche |
| NF-03 | Interface en anglais ; documentation utilisateur en anglais et en français |
| NF-04 | SketchUp 2017 et suivants (Ruby 2.2) ; aucune dépendance ; ne demande pas SketchUp Pro |
| NF-05 | Aucune donnée personnelle dans le dépôt, les fichiers de démonstration et les messages de commit |
| NF-06 | Batterie de tests automatique (SketchUp 2021 Pro, Make 2017). Versions annoncées : celles testées, plus celles vérifiées en théorie et dites « non testées » (décision du 2026-10-27 : 2017 à 2027) |

## 7. Contraintes et dépendances

- Code repris de `../sketchup-circle-advanced` (1.4.0) et `../sketchup-cylindrer-resize` (0.3.0), dont le moteur de reconstruction porté de Re-Cercle 2.0.
- `Entities#weld` : SketchUp 2020.1+ ; sous Make 2017, un cercle non reconstructible en natif reste en segments.

## 8. Critères d'acceptation

| ID | Critère | Exigences |
|---|---|---|
| CA-01 | Toutes les exigences de Circle Advanced passent dans Circle Master (batterie) | EF-01 |
| CA-02 | Cylindre Ø 5 → `5.2` : diamètre exact, cercles natifs, face hôte intacte, une étape d'annulation ; idem en incrément `+0.2` | EF-02, EF-03, EF-06 |
| CA-03 | Cylindre découpé par un booléen → redimensionné et reconstruit en cercles natifs | EF-05 |
| CA-04 | Tous les cas de saisie des deux plugins d'origine acceptés par l'analyseur unique | EF-08 |
| CA-05 | Réglages des anciens plugins repris au premier lancement | EF-10 |
| CA-07 | `7.5` et `7,5` acceptés et égaux, sur un PC à virgule et sur un PC à point (cas de l'analyseur avec le vrai `to_l`) | EF-11 |
| CA-08 | Cylindre Ø 50 à 24 segments → `15;36s` : Ø 15 et 36 segments, cercles natifs ; un cylindre non reconstructible dans la sélection → rien n'est modifié, message avec la raison | EF-12 |
| CA-09 | Cylindre Ø 10 : bouton +0.2 → Ø 10,2 en un clic, fenêtre fermée ; -0.05 → Ø 10,15 ; mode *Radius* + bouton +0.1 → rayon + 0,1 ; Segments 36 + bouton → taille et 36 segments ; tronc de cône + bouton → reste un cône sans question ; taille négative → message dans la fenêtre, rien de modifié | EF-13 |
| CA-06 | Batterie verte sous 2021 Pro et Make 2017 | NF-04, NF-06 |

Vérification du 2026-10-26 (batterie automatique, `tools/tests/`) : CA-01 (C1 à C7, M1 à M6, F1 à F3, K1, K2, D1), CA-02 (R1), CA-03 (R5, E1 à E8), CA-04 et CA-07 (P1, 92 cas avec le vrai `to_l`), CA-06 (2021 Pro 42/42, Make 2017 40/40 avec C7 et R7 sautés : SketchUp 2020.1+), CA-08 (S5, R5, R8 à R10). CA-05 (D3, 6 contrôles : anciennes sections lues, priorités, écriture dans CircleMaster seulement). Batterie de livraison : 2021 Pro 43/43, Make 2017 41/41 (C7 et R7 sautés).

Vérification du 2026-10-27 (1.0.1) : F4 (coin arrondi à côté d'un trou tangent au prolongement de son cercle) et R11 (deux trous tangents) pour EF-01 et EF-12 ; batterie 2021 Pro 45/45, Make 2017 43/43 (C7 et R7 sautés).

Vérification du 2026-10-27 (1.1.0) : CA-09 par R12 (14 contrôles, vraie fenêtre pilotée en JavaScript) ; R1 et R10 refaits sur la nouvelle fenêtre (CA-02, CA-08) ; batterie 2021 Pro 46/46, Make 2017 44/44 (C7 et R7 sautés ; N1 à N8 sautés : Circle Advanced désinstallé) ; test de l'utilisateur dans SketchUp 2021 : OK.

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | Unifier le redimensionnement (un seul outil qui choisit selon la sélection : cercle, arc ou paroi de cylindre) ? | Après la 1.0.0 |
| Q-2 | Moteur de reconstruction unique, à partir de trois versions : `volume.rb` de Circle Advanced (change les segments), `rebuilder.rb` de Cylinder Resize (change le rayon), `circle_restore/volume.rb` de Solid Progress ; le moteur unique prend le rayon et le nombre de segments. **Comparaison faite le 2026-10-26** (`tools/tests/engine_cases.rb`, 2021 Pro et Make 2017) : Solid Progress et Cylinder Resize donnent le même résultat sur 7 géométries sur 8 ; sur un cercle cassé avec un point de coupe en plus, seul Solid Progress répare (Cylinder Resize ne reconnaît pas le cylindre) ; plaque de 20 trous : Solid Progress 5 à 7 fois plus rapide (2,1 s / 15,3 s en 2021, 1,4 s / 7,3 s en 2017). Recommandation : base Solid Progress + rayon (Cylinder Resize) + segments (Circle Advanced) | **Tranchée** le 2026-10-26 (décisions) |
| Q-3 | Accélération de `repair_holes` (`OPTIMISATION_REPAIR_HOLES.md`) en 1.0.0 ou 1.1 ? Déjà présente dans la version de Solid Progress, mesurée avec Q-2 (mêmes résultats, 5 à 7 fois plus rapide sur 20 trous) | **Tranchée** : en 1.0.0, avec le moteur unique |
| Q-4 | Raccourci clavier recommandé (C pour Circle, comme Circle Advanced) | Manuel |

### Décisions

| Date | Sujet | Décision |
|---|---|---|
| 2026-10-26 | Publication | Publier Circle Advanced et Cylinder Resize, réunis (évaluation : `../sketchup-publication/EVALUATION.md`) |
| 2026-10-26 | Nom | **Circle Master** (« Advanced Circles » écarté : trop proche de « Circle Advanced ») ; aucune extension de ce nom trouvée |
| 2026-10-26 | Positionnement | Gratuit (MIT) ; pas de commande autonome de réparation des cercles (plugins payants équivalents) |
| 2026-10-26 | Moteur de reconstruction | Comparer les trois versions (Circle Advanced, Cylinder Resize, Solid Progress) avant d'en garder une seule (Q-2) |
| 2026-10-26 | Moteur unique (Q-2, Q-3) | Moteur de Solid Progress (`volume.rb` + détection par chaînes `chains.rb`, réparation des trous par grilles) avec `radii:` et `segments:` ; `cylinders/rebuilder.rb` et l'ancien `volume.rb` retirés. Vérifié face aux trois moteurs d'origine installés (2021 Pro, Make 2017) : 27 comparaisons sur 28 identiques, la 28e est un cercle à point de coupe que l'ancien Cylinder Resize ne reconnaissait pas |
| 2026-10-26 | Batterie complète (étape 6) | Entièrement automatique (demande de l'utilisateur) : souris et clavier simulés, fenêtres pilotées, préférences interceptées ; seul geste : le clic sur l'écran d'accueil de Make 2017 |
| 2026-10-26 | Défauts trouvés par la batterie | Corrigés en 1.0.0 : seuil d'alignement de `Chains` rendu relatif (très petits cercles cassés) ; coin arrondi extérieur à plus de segments (`fillet.rb` : lignes provisoires vers un point de la bissectrice, face cherchée au segment du milieu), défaut hérité de Circle Advanced 1.4.0 |
| 2026-10-26 | Segments dans les commandes de cylindres (EF-12) | Ajoutés en 1.0.0 (choix A de l'utilisateur), exception à « rien de nouveau en 1.0.0 » ; refusés par Cylinder Resize 0.3.0 (« phase 2 » jamais faite) ; un nombre égal à l'actuel ne reconstruit pas |
| 2026-10-26 | Détecteur des cylindres | Cercle cassé : détection par chaîne d'abord, moyenne des sommets en secours (aucun cylindre reconnu avant n'est perdu) |
| 2026-10-26 | Anciens plugins pendant la construction | Laissés installés (SketchUp 2017 et 2021) : menus en double acceptés, pas de conflit Ruby (modules distincts) ; les tests ne vérifient que Circle Master |
| 2026-10-27 | Anciens plugins après la publication | Circle Advanced 1.4.0, Cylinder Resize 0.3.0 et Circle Re-Segment **désinstallés** de SketchUp 2017 et 2021 (et Circle Advanced de 2023) à la demande de l'utilisateur : fichiers déplacés dans un dossier de sauvegarde local, pas effacés ; leurs réglages restent lus par Circle Master (EF-10) ; dépôts archivés le même jour |
| 2026-10-26 | Noms dans *Annuler* | Préfixe du nom affiché (directive § 1, comme Solid Progress) : *Circle Master — Circle*, *Circle Master — Resize Circle*… |
| 2026-10-26 | Cylinder Resize Tool et le réglage diamètre / rayon | L'outil suit le réglage commun (EF-09) : `15` est un rayon si `input_mode = radius` (dans Cylinder Resize 0.3.0, toujours un diamètre) |
| 2026-10-26 | Séparateur décimal | Point et virgule acceptés (EF-11), exception à « rien de nouveau en 1.0.0 » ; `;` reste le seul séparateur de valeurs ; pas de séparateur de milliers |
| 2026-10-26 | Champ *Mode* de la fenêtre Resize Cylinders | Lu dans le réglage commun et écrit s'il change : l'outil Circle suit le choix fait dans la fenêtre |
| 2026-10-26 | Reprise de `input_mode` | Lu dans `CircleMaster`, sinon `CircleAdvanced/input_mode`, sinon `CylinderResize/mode` : Circle Advanced l'emporte si les deux anciens diffèrent |
| 2026-10-27 | Cercle voisin compté avec le cercle reconstruit (trouvé en faisant les images de publication) | Corrigé en 1.0.1 **avant la publication sur SketchUcation**, pour les coins arrondis et les cylindres (demande de l'utilisateur) : une arête n'est retenue que si elle appartient à une `ArcCurve` centrée sur le cercle. Pas de décalage automatique de la géométrie (proposé puis écarté : il changerait les cotes, et 0,001 mm resterait dans la tolérance de 0,5 % du rayon) |
| 2026-10-27 | Fenêtre *Resize Cylinders…* (EF-13) | `UI.inputbox` remplacée par une `UI::HtmlDialog` (seule façon d'avoir des boutons). Choix de l'utilisateur : un clic sur un bouton applique et ferme ; le pas suit le *Mode* (diamètre ou rayon) ; pas en **unités du modèle** (pas forcés en mm) ; cadre nommé **Step** (« Clearance » écarté : pas seulement pour les jeux, aussi pour corriger des problèmes de SketchUp). Ajouté sans demande : seuls les champs modifiés sont appliqués, la valeur affichée suit le mode |
| 2026-10-27 | Versions annoncées | **SU 2017 à SU 2027** cochées sur SketchUcation par l'auteur, après une vérification théorique (versions de Ruby, notes de version de l'API, code passé sous Ruby 3.3 ; détail dans le FSD) ; testées : Make 2017 et Pro 2021 seulement (SketchUp 2023 du PC : licence expirée). NF-06 reformulée |

## 10. Historique des livraisons

| Date | Version / commit | Exigences livrées |
|---|---|---|
| 2026-10-26 | 1.0.0 (tag `v1.0.0`, dépôt privé) | EF-01 à EF-12, NF-01 à NF-06 ; batterie 2021 Pro et Make 2017 |
| 2026-10-27 | 1.0.1 (tag `v1.0.1`, dépôt public) | Correctif d'EF-01 (segments d'un coin arrondi) et d'EF-12 / segments d'une extrémité de cylindre : cercle voisin tangent ; batterie 2021 Pro 45/45, Make 2017 43/43 |
| 2026-10-27 | 1.1.0 (tag `v1.1.0`) | EF-13 (fenêtre *Resize Cylinders…* : champ Segments, boutons Step) ; batterie 2021 Pro 46/46, Make 2017 44/44 |
