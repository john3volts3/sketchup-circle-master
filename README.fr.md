# Circle Master

*[English version](README.md)*

Extension SketchUp gratuite pour l'**impression 3D** : des trous et des tenons au diamètre exact, et
des cylindres lisses même après l'extrusion.

- Outil **Circle** qui remplace l'outil natif : une valeur tapée est un **diamètre** par défaut
  (`25r` pour un rayon), **48 segments par défaut** et le dernier nombre de segments est mémorisé ;
  inférences, flèches pour verrouiller l'axe, clic-clic ou clic-glisser, comme l'outil natif.
- **Changer le nombre de segments d'un cylindre déjà extrudé** (`36s`), d'un trou, d'un tenon ou du
  **coin arrondi** d'un volume — grisé dans *Infos sur l'entité*.
- **Remettre trous et tenons à la taille exacte** : sélectionnez la paroi, tapez `5,2` ou `+0,2` ;
  les deux bouts changent, la face hôte et ses matériaux restent intacts. Taille et segments
  ensemble : `5,2;48s`. Ou, dans la fenêtre **Resize Cylinders…**, un clic sur un bouton de
  **pas** (+0.05 à +0.3, -0.05 à -0.3) pour ajuster un emboîtement.
- Les **cercles cassés** (coupés par une opération sur les solides, éclatés ou soudés) sont
  **reconstruits en cercles natifs** pendant le redimensionnement : l'inférence du centre et *Infos
  sur l'entité* fonctionnent à nouveau.
- Redimensionner et changer les segments de cercles et d'arcs existants, poser des **copies** d'un
  cercle (Ctrl), répéter le cercle précédent par un **double-clic**.
- Point ou virgule décimale, quels que soient les réglages de Windows ; une étape d'annulation par
  action.

Testé sous **SketchUp 2021 Pro** et **SketchUp Make 2017** (Windows). Devrait fonctionner de
SketchUp 2017 à 2027 (vérifié d'après les notes de version de l'API Ruby, non testé). Ne demande pas
SketchUp Pro. L'interface de l'extension est en anglais.

## Installation

1. Désinstallez **Circle Advanced** et **Cylinder Resize** s'ils sont installés (Circle Master les
   remplace et reprend leurs réglages).
2. Téléchargez `circle_master.rbz` depuis les [releases](../../releases/latest).
3. SketchUp → *Extensions → Gestionnaire d'extensions → Installer l'extension…* → choisissez le
   `.rbz`.
4. (Conseillé) *Fenêtre → Préférences → Raccourcis* : affectez la touche **C** à
   `Extensions/Circle Master/Circle`.

## Prise en main

| Objectif | Comment |
|----------|---------|
| Tracer un cercle de Ø 25 | **Circle**, clic sur le centre, tapez `25`, Entrée |
| Lisser un cylindre extrudé | Sélectionnez un cercle d'extrémité, **Circle**, tapez `64s` — ou sélectionnez sa paroi, **Cylinder Resize Tool**, tapez `64s` |
| Trou au jeu d'impression | **Cylinder Resize Tool**, clic sur la paroi du trou, tapez `5,2` (ou `+0,2`) |
| Ajuster un emboîtement en un clic | Sélectionnez la paroi du trou ou du tenon, **Resize Cylinders…**, cliquez sur **+0.2** (ou un autre pas) |
| Taille et segments d'un coup | `5,2;48s` |

| Saisie | Effet |
|--------|-------|
| `50` / `50mm` | Diamètre (ou rayon, voir *Settings*) |
| `25r` / `r25` | Rayon |
| `50d` | Diamètre explicite |
| `48s` | Nombre de segments |
| `50;36s` | Taille et segments |
| `+5` / `-2,5` / `+r1` | Incrément du diamètre / du rayon |
| `--5` | Comme `+5` (quand `+` est pris par un raccourci) |

## Documentation

- Manuel utilisateur : [Français](docs/USER_MANUAL_FR.md) · [English](docs/USER_MANUAL_EN.md)
- Changements : [CHANGELOG.md](CHANGELOG.md)
- Exigences et spécification fonctionnelle : [PRD.md](PRD.md), [FSD.md](FSD.md)

## Origine

Circle Master réunit **Circle Advanced 1.4.0** et **Cylinder Resize 0.3.0**, avec le moteur de
reconstruction en cercles natifs de **Re-Cercle** et de **Solid Progress** (même auteur).

## Développement

- Tests automatiques (SketchUp fermé) : `powershell -File tools\tests\run_tests.ps1` (SketchUp
  2021, puis Make 2017) ; cas de l'analyseur sans SketchUp : `ruby tools/tests/vcb_parser_cases.rb`.
- Recharger sans redémarrer SketchUp (console Ruby) : `CircleMaster.reload`.
- Code compatible Ruby 2.2 (SketchUp 2017) : pas de `&.`, `<<~`, `clamp`, `match?`…
- Construire le `.rbz` : zipper `circle_master.rb` et `circle_master/`, renommer en `.rbz`.

## Licence

MIT — voir [LICENSE](LICENSE).
