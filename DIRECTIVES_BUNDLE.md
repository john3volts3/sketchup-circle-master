# Directives — créer Circle Master

Circle Master réunit **Circle Advanced 1.4.0** (`../sketchup-circle-advanced`) et **Cylinder Resize 0.3.0** (`../sketchup-cylindrer-resize`) en un seul plugin SketchUp gratuit, pour le publier sur GitHub et SketchUcation. Décision et stratégie : `../sketchup-publication/EVALUATION.md` et `STRATEGIE_CIRCLE_MASTER.md`. Liste de contrôle de publication : `../sketchup-publication/CHECKLIST_PUBLICATION.md`.

À lire au début de chaque session de ce projet, avec `PRD.md` et `JOURNAL.md`. Cadre : skill `/sketchup-plugin` ; cercles et cylindres natifs : skill `/sketchup-native-circles`. Workflow habituel : plan, validation de l'utilisateur, modifications chirurgicales, « Teste OK ? » avant tout commit.

## 1. Noms (identiques partout)

| Élément | Valeur |
|---|---|
| Nom affiché (extension, menu, barre d'outils, Annuler, journaux `[Circle Master]`) | **Circle Master** |
| Chargeur / dossier du plugin | `circle_master.rb` / `circle_master/` |
| Module Ruby | `CircleMaster` |
| Section des réglages (`Sketchup.read_default`) | `CircleMaster` |
| Paquet | `circle_master.rbz` |
| Dépôt GitHub | `sketchup-circle-master`, **privé** jusqu'à la publication |
| Identifiant SketchUcation | `Circle_Master` |
| Première version | **1.0.0** |
| Licence | MIT, `Copyright (c) 2026 john3volts3` (comme les deux plugins d'origine) |

## 2. Fonctions (rien de nouveau dans la 1.0.0 : réunir, pas inventer)

Reprendre **toutes** les fonctions des deux plugins, sans régression :

- de Circle Advanced : l'outil **Circle** (EF-01 à EF-22 de son PRD : 48 segments par défaut et mémorisés, diamètre par défaut, saisies `r`, `d`, `48s`, `50;36s`, incréments, mode modification des cercles et arcs sélectionnés, segments des extrémités de cylindre et des coins arrondis, mode copie Ctrl, double-clic), la fenêtre **Settings** ;
- de Cylinder Resize : **Resize Cylinders…** (fenêtre) et l'outil interactif **Cylinder Resize Tool** (diamètre, rayon, incréments `+1`, `--1`, troncs de cône, cercles cassés reconstruits en natif, faces hôtes conservées, une étape d'annulation).

**À ne pas ajouter** : une commande autonome « réparer les cercles cassés ». C'est la fonction de Curvizard (Fredo6) et d'Eneroth Auto Weld, payants ; la règle de l'auteur est de ne pas les concurrencer. La reconstruction native reste une **étape** du redimensionnement ou du changement de segments de l'élément choisi, comme aujourd'hui.

Menu *Extensions > Circle Master* et barre d'outils **Circle Master** : `Circle`, `Resize Cylinders…`, `Cylinder Resize Tool`, `Settings…`. Interface en anglais.

## 3. Structure cible

```
circle_master.rb                 # chargeur (SketchupExtension)
circle_master/
  version.rb                     # VERSION = '1.0.0'
  main.rb                        # menu, barre d'outils, commandes (garde unless @loaded)
  settings.rb                    # réglages communs + reprise des anciens (§ 5)
  settings_dialog.rb, html/settings.html
  vcb_parser.rb                  # UN seul analyseur de saisie (§ 4)
  circle_tool.rb, fillet.rb, resegmenter.rb   # de Circle Advanced
  volume.rb                      # UN seul moteur de reconstruction des cylindres (§ 4)
  cylinders/detector.rb, resizer.rb, resize_tool.rb   # de Cylinder Resize
  icons/                         # icônes 16 et 24 px des deux plugins, renommées si besoin
tools/tests/                     # batterie automatique (§ 6), hors .rbz
docs/                            # USER_MANUAL_EN.md, USER_MANUAL_FR.md, images/, SKETCHUCATION.md
```

Copier le code (pas de dépendance aux anciens dossiers), renommer les modules en `CircleMaster` (sous-modules gardés : `VcbParser`, `Settings`, `Resegmenter`, `Volume`, `Fillet`, `Detector`, `Resizer`…), adapter les chemins des icônes et de la page HTML.

## 4. Doublons à résoudre (avec preuve, pas à l'œil)

1. **Analyseur de saisie** : `vcb_parser.rb` existe dans les deux plugins (93 lignes de différence). En faire un seul qui accepte les deux syntaxes ; reprendre les 26 cas vérifiés hors SketchUp de Circle Advanced et ajouter ceux de Cylinder Resize (`d15`, `r7.5`, `+d1`, `+r0.5`, `--1`, unités).
2. **Moteur de reconstruction** : `volume.rb` (Circle Advanced) et `rebuilder.rb` (Cylinder Resize) sont deux portages de `volume.rb` de Re-Cercle 2.0. Garder un seul moteur, choisi après comparaison des deux sur la même géométrie (faces, arêtes, cercles natifs, volume), comme T15 de Solid Progress. Ne fusionner que si les résultats sont identiques sur tous les cas d'essai.
3. **Accélération de `repair_holes`** (`OPTIMISATION_REPAIR_HOLES.md`, non commité dans les deux dossiers) : à appliquer seulement après validation par comparaison avec l'ancienne méthode (décision de l'auteur) ; peut attendre une 1.1.
4. **Réglage diamètre / rayon** : Circle Advanced (`input_mode`) et Cylinder Resize (`mode`) en ont chacun un : un seul réglage commun.
5. **Recouvrement des rôles** : Circle Advanced redimensionne des cercles et arcs (cylindre entier exclu de son PRD) ; Cylinder Resize redimensionne des cylindres entiers. Garder les deux comportements tels quels en 1.0.0 et l'expliquer clairement dans le manuel ; une unification éventuelle (un seul outil selon la sélection) est une question ouverte du PRD.

## 5. Passage depuis les anciens plugins

- Réglages : lire `CircleMaster`, puis à défaut les anciennes sections `CircleAdvanced` (`segments`, `input_mode`, `coord_mode`) et `CylinderResize` (`mode`), comme Solid Progress lit `SolidBatch`. Ne jamais écrire dans les anciennes sections.
- Les deux anciens plugins installés en même temps que Circle Master donneraient des commandes en double : le README demande de les désinstaller d'abord. Pas de détection automatique (fonction optionnelle à risque, inutile).
- Les dépôts d'origine sont privés et sans utilisateurs extérieurs : après la publication, un README qui renvoie à Circle Master, puis archivage.
- Dépôt **neuf**, historique neuf (les anciens historiques ne sont pas repris) ; le JOURNAL et le README citent l'origine (Circle Advanced 1.4.0, Cylinder Resize 0.3.0, moteur de Re-Cercle).

## 6. Tests

- Batterie automatique sur le modèle de `../sketchup-solid-progress/tools/tests/` : `run_tests.ps1` (déploiement, `-RubyStartup`, attente du rapport, fermeture du seul SketchUp lancé ; sauvegarde de `PrivatePreferences.json` ; fichier `.ps1` en ASCII) et `run_tests.rb` (cas, étapes chaînées par minuteur, boîtes de message interceptées, rapport `results/latest-<version>.txt`).
- Cas minimum : chaque exigence EF de Circle Advanced (création, saisies, modification, segments des cylindres et des coins arrondis, copie, double-clic) ; Cylinder Resize (diamètre, rayon, incréments, tronc de cône, trou dans un bloc, tenon, cercles cassés par un booléen, dans un composant) ; une seule étape d'annulation par action ; aucune définition inutilisée laissée ; analyseur (tous les cas).
- Reprendre les essais existants : `tools/spike/` des deux projets.
- Versions : SketchUp 2021 Pro et **Make 2017** (Ruby 2.2 : pas de `&.`, `<<~`, `clamp`, `match?`, `sum`) ; `Entities#weld` (2020.1+) gardé par `respond_to?`. N'annoncer que ce qui passe.
- Le plugin n'utilise pas les booléens natifs : il ne demande pas SketchUp Pro.

## 7. Documentation

- `README.md` (anglais) et `README.fr.md`, lien croisé ; section « Demo » avec la vidéo YouTube une fois faite ; installation (désinstaller Circle Advanced et Cylinder Resize d'abord) ; versions testées ; licence.
- `docs/USER_MANUAL_EN.md`, `docs/USER_MANUAL_FR.md` : fusion des manuels de Circle Advanced et du README de Cylinder Resize (qui n'a pas de manuel).
- `PRD.md` (créé), `FSD.md` (à rédiger à partir des deux FSD), `JOURNAL.md`, `CHANGELOG` facultatif.

## 8. Ordre de travail proposé

1. Dépôt git local et squelette (chargeur, `version.rb`, `main.rb`, réglages avec reprise des anciens) ; le plugin se charge dans SketchUp.
2. Analyseur unique et ses cas.
3. Outil Circle et réglages (code de Circle Advanced).
4. Commandes de Cylinder Resize.
5. Moteur unique (comparaison, puis fusion).
6. Batterie complète sous 2021 et Make 2017.
7. Documentation, livraison 1.0.0 (dépôt privé), puis publication selon `../sketchup-publication/STRATEGIE_CIRCLE_MASTER.md`.

## 9. Règles à rappeler

- Aucune donnée personnelle (chemin absolu personnel, nom d'utilisateur, adresse IP, e-mail) dans un fichier suivi ou un message de commit ; chemins relatifs (`../sketchup-circle-advanced`).
- Avant de modifier un fichier hors git (préférences de SketchUp…), le sauvegarder.
- Git sur le NAS : supprimer `index.lock` puis enchaîner `add` et `commit` dans un même appel PowerShell.
