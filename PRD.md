# Circle Master — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* sera dans `FSD.md`. Directives de construction : `DIRECTIVES_BUNDLE.md`.

Dernière mise à jour : 2026-10-26 (squelette : Q-2, Q-3 et décisions).

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
- Nouvelles fonctions en 1.0.0.

## 5. Exigences fonctionnelles

Priorité : **I** = indispensable, **Im** = important, **S** = souhaitable.

| ID | Exigence | Priorité | Statut |
|---|---|---|---|
| EF-01 | **Outil Circle** de Circle Advanced, à l'identique : ses exigences EF-01 à EF-22 (outil comme le natif, 48 segments par défaut et mémorisés, diamètre par défaut, `r` / `d`, `48s`, `50;36s`, modification du dernier cercle, verrouillage de la normale, aperçu coloré, contexte actif, fenêtre de réglages, mode de coordonnées, mode modification des cercles et arcs sélectionnés avec valeur absolue ou incrément, segments des cercles et arcs, des extrémités de cylindre et de tronc de cône, des coins arrondis, mode copie Ctrl, double-clic) | I | proposée |
| EF-02 | **Resize Cylinders…** (fenêtre) de Cylinder Resize : paroi d'un ou plusieurs cylindres sélectionnée, diamètre ou rayon, incréments | I | proposée |
| EF-03 | **Cylinder Resize Tool** (outil interactif) : survol, sélection, Shift/Ctrl pour ajouter, saisie `15`, `d15`, `r7.5`, `+1`, `-0.1`, `+r0.5`, `--1` ; l'outil reste actif | I | proposée |
| EF-04 | Troncs de cône : un incrément garde l'angle, une valeur absolue en fait un cylindre après confirmation | I | proposée |
| EF-05 | Cercles cassés (arêtes, courbe soudée, cercle découpé par un booléen) : le cylindre redimensionné est reconstruit en cercles natifs ; soudure en secours (SketchUp 2020.1+) | I | proposée |
| EF-06 | Trous dans un bloc et tenons : face hôte intacte ; dans un composant, la définition est modifiée | I | proposée |
| EF-07 | Menu *Extensions > Circle Master* et barre d'outils **Circle Master** : Circle, Resize Cylinders…, Cylinder Resize Tool, Settings… | I | proposée |
| EF-08 | **Un seul analyseur de saisie** accepté par l'outil Circle et par le redimensionnement des cylindres | Im | proposée |
| EF-09 | **Un seul réglage diamètre / rayon** pour toutes les commandes | Im | proposée |
| EF-10 | Réglages repris de Circle Advanced (`CircleAdvanced`) et de Cylinder Resize (`CylinderResize`) tant qu'ils ne sont pas changés dans Circle Master | Im | proposée |

## 6. Exigences non fonctionnelles

| ID | Exigence |
|---|---|
| NF-01 | Résultats en cercles natifs `ArcCurve` (inférence du centre, *Infos sur l'entité*) ; matériaux, balises et orientation des faces conservés |
| NF-02 | Une seule opération annulable par action ; en cas d'échec, rien n'est modifié et un message clair s'affiche |
| NF-03 | Interface en anglais ; documentation utilisateur en anglais et en français |
| NF-04 | SketchUp 2017 et suivants (Ruby 2.2) ; aucune dépendance ; ne demande pas SketchUp Pro |
| NF-05 | Aucune donnée personnelle dans le dépôt, les fichiers de démonstration et les messages de commit |
| NF-06 | Batterie de tests automatique (SketchUp 2021 Pro, Make 2017) ; versions annoncées = versions testées |

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
| CA-06 | Batterie verte sous 2021 Pro et Make 2017 | NF-04, NF-06 |

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | Unifier le redimensionnement (un seul outil qui choisit selon la sélection : cercle, arc ou paroi de cylindre) ? | Après la 1.0.0 |
| Q-2 | Moteur de reconstruction unique, à partir de trois versions : `volume.rb` de Circle Advanced (change les segments), `rebuilder.rb` de Cylinder Resize (change le rayon), `circle_restore/volume.rb` de Solid Progress ; le moteur unique prend le rayon et le nombre de segments | Comparaison des trois sur la même géométrie (étape 5 des directives) |
| Q-3 | Accélération de `repair_holes` (`OPTIMISATION_REPAIR_HOLES.md`) en 1.0.0 ou 1.1 ? Déjà présente dans la version de Solid Progress | Après validation par comparaison (avec Q-2) |
| Q-4 | Raccourci clavier recommandé (C pour Circle, comme Circle Advanced) | Manuel |

### Décisions

| Date | Sujet | Décision |
|---|---|---|
| 2026-10-26 | Publication | Publier Circle Advanced et Cylinder Resize, réunis (évaluation : `../sketchup-publication/EVALUATION.md`) |
| 2026-10-26 | Nom | **Circle Master** (« Advanced Circles » écarté : trop proche de « Circle Advanced ») ; aucune extension de ce nom trouvée |
| 2026-10-26 | Positionnement | Gratuit (MIT) ; pas de commande autonome de réparation des cercles (plugins payants équivalents) |
| 2026-10-26 | Moteur de reconstruction | Comparer les trois versions (Circle Advanced, Cylinder Resize, Solid Progress) avant d'en garder une seule (Q-2) |
| 2026-10-26 | Anciens plugins pendant la construction | Laissés installés (SketchUp 2017 et 2021) : menus en double acceptés, pas de conflit Ruby (modules distincts) ; les tests ne vérifient que Circle Master |
| 2026-10-26 | Reprise de `input_mode` | Lu dans `CircleMaster`, sinon `CircleAdvanced/input_mode`, sinon `CylinderResize/mode` : Circle Advanced l'emporte si les deux anciens diffèrent |

## 10. Historique des livraisons

| Date | Version / commit | Exigences livrées |
|---|---|---|
| — | — | — |
