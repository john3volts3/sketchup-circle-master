# Circle Master — Spécification fonctionnelle (FSD)

Rédigée pendant la construction du bundle, à partir des FSD des deux plugins d'origine :

- `../sketchup-circle-advanced/FSD.md` (outil Circle, mode modification, re-segmentation des cercles, des cylindres et des coins arrondis) ;
- `../sketchup-cylindrer-resize/FSD.md` (détection d'un cylindre, redimensionnement, reconstruction native, interfaces, limitations).

Plan prévu : objectif ; entrées (sélections, saisies de l'analyseur unique) ; outil Circle ; redimensionnement des cylindres ; moteur de reconstruction unique ; réglages et reprise des anciens ; interface (menu, barre d'outils, fenêtres) ; limitations ; structure des fichiers ; tests ; historique des versions.

État : squelette (étape 1 des directives). Les commandes sont en place mais leur code n'est pas encore porté : chacune affiche « `<commande>: not available yet` » dans la barre d'état et la console.

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
  icons/                    # icônes des deux plugins d'origine, noms inchangés
LICENSE                     # MIT
```
