# Circle Master — Manuel utilisateur

*[English version](USER_MANUAL_EN.md)*

Version 1.1.0

## 1. Présentation

**Circle Master** est une extension SketchUp gratuite pour celles et ceux qui modélisent des pièces
à **imprimer en 3D**. Elle fait deux choses que SketchUp ne fait pas seul :

- **changer le nombre de segments d'un cylindre déjà extrudé** (moins de facettes visibles à
  l'impression), ce qu'*Infos sur l'entité* ne permet que pour un cercle plat ;
- **remettre un trou ou un tenon à un diamètre exact** (jeu d'impression), même quand une opération
  sur les solides a cassé ses cercles.

Elle compte quatre commandes, dans le menu *Extensions → Circle Master* et la barre d'outils
**Circle Master** :

| Commande | Rôle |
|----------|------|
| **Circle** | Remplace l'outil Cercle natif : saisie en diamètre, 48 segments par défaut et mémorisés ; redimensionne aussi les cercles et arcs existants et change leur nombre de segments, y compris le cercle d'extrémité d'un cylindre et le coin arrondi d'un volume |
| **Resize Cylinders…** | Fenêtre : redimensionne les cylindres dont la paroi est sélectionnée (diamètre, rayon, incrément, nombre de segments, pas en un clic de -0.3 à +0.3) |
| **Cylinder Resize Tool** | La même chose, en interactif : clic sur la paroi d'un cylindre, puis saisie de la nouvelle taille |
| **Settings…** | Nombre de segments par défaut, saisie en diamètre ou en rayon, mode de coordonnées |

Le résultat est toujours fait de **cercles natifs SketchUp** : l'inférence du centre fonctionne, et
*Infos sur l'entité* affiche le rayon et le nombre de segments.

Circle Master réunit deux extensions antérieures du même auteur, **Circle Advanced 1.4.0** et
**Cylinder Resize 0.3.0**, avec un moteur de reconstruction commun (issu de Re-Cercle et de Solid
Progress).

## 2. Installation

1. Si **Circle Advanced** ou **Cylinder Resize** est installé, désinstallez-le d'abord
   (*Extensions → Gestionnaire d'extensions*) : sinon leurs commandes apparaîtraient en double.
   Leurs réglages (nombre de segments, diamètre ou rayon) sont repris par Circle Master.
2. Récupérez le fichier `circle_master.rbz` (releases GitHub).
3. Dans SketchUp : *Extensions → Gestionnaire d'extensions → Installer l'extension…*, choisissez le
   fichier et acceptez l'avertissement.

La barre d'outils **Circle Master** apparaît (sinon : *Affichage → Barres d'outils*).

### Remplacer l'outil Cercle natif (touche C)

1. *Fenêtre → Préférences → Raccourcis*.
2. Tapez `Circle Master` dans le filtre.
3. Sélectionnez `Extensions/Circle Master/Circle`, tapez `C` dans *Ajouter un raccourci*, cliquez
   sur **+**.
4. Confirmez la réaffectation du raccourci de l'outil Cercle natif.

## 3. Tracer un cercle

1. Activez **Circle** (bouton, menu ou touche `C`).
2. **Cliquez** pour placer le centre. Le cercle suit l'orientation de la face survolée, sinon il est
   horizontal (normale sur l'axe bleu).
3. Donnez la taille :
   - par un **second clic**, ou
   - par un **clic-glisser-relâcher** depuis le centre, ou
   - en **tapant** la valeur puis *Entrée*.

La face du cercle est créée automatiquement ; sur une face existante, celle-ci est découpée.
L'outil reste actif pour le cercle suivant. **Échap** annule le cercle en cours. Le cercle est créé
dans le groupe ou le composant en cours d'édition.

### Double-clic : répéter le cercle précédent

Un **double-clic** pose un cercle de la taille et du nombre de segments du cercle précédent, centré
sur le point double-cliqué. Le cercle précédent est le dernier tracé avec l'outil, ou le cercle
sélectionné à l'activation de l'outil ; il est mémorisé pour la session SketchUp.

### Couleur de l'aperçu

| Couleur | Signification |
|---------|---------------|
| Rouge | Cercle perpendiculaire à l'axe rouge |
| Vert | Cercle perpendiculaire à l'axe vert |
| Bleu | Cercle horizontal (perpendiculaire à l'axe bleu) |
| Noir | Orientation quelconque (face inclinée) |

Un trait **épais** signifie que l'orientation est verrouillée. Pendant le glisser, la ligne en
tirets du centre au curseur devient épaisse rouge, verte ou bleue quand le curseur suit un axe.

## 4. Verrouiller l'orientation

| Touche | Effet |
|--------|-------|
| **→** | Verrouille sur l'axe rouge (appuyer à nouveau pour déverrouiller) |
| **←** | Verrouille sur l'axe vert |
| **↑** | Verrouille sur l'axe bleu |
| **↓** | Verrouille l'orientation actuelle (celle de la face survolée) |
| **Maj** maintenue | Fige l'orientation tant que la touche est enfoncée |

Le verrou est relâché après chaque cercle et sur Échap.

## 5. Saisir des valeurs (zone Mesures)

La même syntaxe sert à toutes les commandes. Les longueurs sont dans les unités du modèle ; vous
pouvez aussi taper une unité (`50mm`, `2'`). Le **point et la virgule décimale** fonctionnent tous
les deux, quels que soient les réglages de Windows (`7.5` et `7,5`). Plusieurs valeurs sont séparées
par `;`.

| Saisie | Signification |
|--------|---------------|
| `50` | **Diamètre** 50 (ou rayon, si le réglage le dit, § 9) |
| `25r` ou `r25` | **Rayon** 25 |
| `50d` ou `d50` | Diamètre explicite |
| `48s` ou `s48` | **48 segments** (3 à 999) |
| `50;36s` | Diamètre 50 **et** 36 segments |
| `+5`, `-2,5` | **Incrément** : diamètre + 5, diamètre − 2,5 (cercle ou cylindre existant) |
| `+r1`, `-0,5r` | Incrément du rayon |
| `--5` | Comme `+5` (quand la touche `+` est prise par un raccourci clavier) |

Une saisie invalide émet un bip et affiche un message dans la barre d'état ; rien n'est modifié.

Avec l'outil **Circle**, l'effet dépend du moment de la saisie :

| Moment | Effet |
|--------|-------|
| Avant de placer le centre | Un nombre seul (`36`) fixe le nombre de **côtés**, comme l'outil natif. La zone affiche « Sides ». |
| Centre placé | Le cercle est créé à la taille tapée. |
| Juste après un cercle | La saisie **modifie ce dernier cercle** (taille, incrément et/ou segments). La zone affiche « Diameter; Segments » : `50mm; 48s`. |
| Cercles ou arcs sélectionnés à l'activation de l'outil | La saisie **modifie la sélection** (§ 6). |

Un nombre de segments tapé pendant le tracé (`48s`) devient le nouveau défaut. Modifier le dernier
cercle n'est plus possible après un autre clic, une autre opération ou une annulation.

## 6. Modifier des cercles et arcs existants (outil Circle)

1. Avec l'outil **Sélection**, cliquez sur l'**arête** d'un cercle ou d'un arc (Maj/Ctrl + clic
   pour en sélectionner plusieurs).
2. Activez **Circle**.
3. La zone Mesures affiche « Diameter; Segments » avec la taille et le nombre de segments actuels,
   par exemple `50mm; 48s`.
4. Tapez la nouvelle valeur puis *Entrée* :

| Saisie | Effet |
|--------|-------|
| `60` | Diamètre 60 (toutes les courbes sélectionnées) |
| `30r` | Rayon 30 |
| `+5` / `-2,5` | Chaque courbe grandit de 5 / rétrécit de 2,5, depuis sa propre taille |
| `36s` | **36 segments** (un arc reçoit lui-même 36 segments, comme dans *Infos sur l'entité*) |
| `60;36s` | Diamètre 60 **et** 36 segments |

Le cercle garde son centre et reste un cercle natif ; son disque, ou le trou dans une face, suit
avec ses matériaux. Le nombre de segments par défaut ne change pas.

- **Cylindres** : `36s` sur un cercle d'extrémité d'un cylindre ou d'un tronc de cône (trou, tenon,
  fraisurage) reconstruit le **volume entier** avec 36 segments aux deux extrémités — ce
  qu'*Infos sur l'entité* ne permet pas (champ grisé).
- **Coins arrondis de volumes** : `36s` sur l'un des deux arcs d'un coin arrondi (arête arrondie
  d'une boîte, angle rentrant arrondi d'un L…) reconstruit la paroi courbe et les deux arcs avec 36
  segments ; les faces voisines restent tangentes. Plus ou moins de segments, coin extérieur ou
  intérieur.

L'outil reste dans ce mode : une nouvelle saisie corrige ; **Ctrl+Z** annule une saisie à la fois.
Un **clic** commence un nouveau cercle et **Échap** quitte le mode (la sélection est vidée).

### Poser des copies d'un cercle sélectionné (Ctrl)

1. Sélectionnez un cercle et activez l'outil.
2. Appuyez sur **Ctrl** seul et relâchez (ou tapez `=` puis *Entrée*) : **mode copie** ; la barre
   d'état affiche « Copy: … ».
3. Chaque **clic** pose un cercle de cette taille et de ce nombre de segments. Une saisie (`30`,
   `+2`, `36s`) modifie le cercle qui vient d'être posé et les suivants.
4. **Ctrl** à nouveau ou **Échap** : retour au tracé normal.

### Bon à savoir

- Seule l'**arête** compte : une face de disque sélectionnée seule ne suffit pas.
- Redimensionner avec l'outil Circle le seul cercle d'extrémité d'un cylindre en fait un tronc de
  cône : pour redimensionner un **cylindre entier**, utilisez les commandes de cylindres (§ 7).
- Changer le nombre de segments **recrée** les faces voisines : matériau, balise et orientation
  sont conservés, la position d'une texture et les attributs sont perdus.
- Refusés (message, rien n'est modifié) : polygone, ligne raccordée au milieu du cercle, cône
  pointu, cylindre oblique, tube sans face, cylindres empilés ; coin arrondi à paroi oblique ou
  coupée, ou à deux rayons différents (redimensionnez les deux arcs ensemble).
- Un cercle « cassé » (arêtes éclatées ou soudées) est ignoré par l'outil Circle : les commandes de
  cylindres le reconstruisent (§ 7).
- Dans un composant, toutes les copies sont modifiées.

## 7. Redimensionner des cylindres (Resize Cylinders…, Cylinder Resize Tool)

Un **cylindre**, ici, est un cylindre droit ou un tronc de cône fait par *Pousser/Tirer* sur un
cercle : une paroi lisse entre deux cercles coaxiaux. Les trous dans un bloc, les tenons sur une
pièce, les chevilles et les fraisurages en font partie. Sélectionnez ou cliquez sa **paroi**, pas un
cercle.

### Resize Cylinders… (fenêtre)

1. Sélectionnez la paroi d'un ou de plusieurs cylindres (un clic sur la surface latérale lisse ;
   Maj/Ctrl pour en ajouter).
2. *Extensions → Circle Master → Resize Cylinders…* (ou le 2e bouton de la barre d'outils).
3. La fenêtre affiche le nombre de cylindres (et de cônes), la taille du premier dans le **Mode**
   choisi et son nombre de **Segments** (vide, « mixed », si les cylindres sélectionnés n'ont pas
   tous le même).
4. Au choix :
   - changez **Value** et/ou **Segments**, puis **OK** (*Entrée*) : seuls les champs modifiés sont
     appliqués ; **Value** accepte tout ce qui figure dans « Ce que vous pouvez taper » plus bas ;
   - ou cliquez sur l'un des boutons **Step**, **+0.05 à +0.3** ou **-0.05 à -0.3** : le pas est
     ajouté à chaque cylindre depuis sa propre taille, avec le nouveau nombre de segments si vous
     l'avez changé, et la fenêtre se ferme. Pratique pour les emboîtements des pièces imprimées en
     3D (jeu d'un trou ou d'un tenon) ou pour corriger une taille.

Le **Mode** (**Diameter** ou **Radius**, le réglage commun, § 9) décide à quoi s'appliquent la
valeur et les pas : en mode *Radius*, `+0.2` ajoute 0,2 au rayon, donc 0,4 au diamètre. Les pas
sont en **unités du modèle** : le titre du cadre les indique, par exemple *Step (diameter, mm)*.
Changer de mode fait passer la valeur affichée du diamètre au rayon. Une étape d'annulation par OK
ou par clic ; un tronc de cône reste un cône avec un pas (sans question). Une erreur (taille nulle
ou négative, nombre de segments refusé) s'affiche en rouge dans la fenêtre, qui reste ouverte ;
*Cancel* ou *Échap* la ferme sans rien changer.

### Cylinder Resize Tool (interactif)

1. Activez l'outil (3e bouton de la barre d'outils).
2. Survolez un cylindre (il est surligné), cliquez pour le choisir. **Maj/Ctrl + clic** en ajoute ou
   en retire un ; un clic à côté vide la liste. Les troncs de cône sont affichés d'une autre
   couleur, avec un avertissement.
3. La zone Mesures affiche « Diameter; Segments » avec la taille et le nombre de segments du premier
   cylindre, par exemple `50mm; 24s`. Tapez la nouvelle valeur, puis *Entrée*.

L'outil reste actif : une nouvelle saisie corrige, un clic choisit un autre cylindre. La barre
d'espace revient à l'outil Sélection.

### Ce que vous pouvez taper

| Saisie | Effet |
|--------|-------|
| `15`, `d15` | Diamètre 15 (rayon si le réglage est « Radius » : `r` et `d` marchent toujours) |
| `r7,5` | Rayon 7,5 |
| `+1`, `-0,1` | Incrément du diamètre, pour chaque cylindre depuis sa propre taille |
| `+r0,5` | Incrément du rayon |
| `--1` | Comme `+1` |
| `36s` | **36 segments**, même taille |
| `15;36s` | Diamètre 15 **et** 36 segments |
| `+0,2;48s` | Diamètre + 0,2 **et** 48 segments |

- **Troncs de cône** : un incrément garde le cône (même angle) ; une valeur absolue en fait un
  cylindre, après confirmation (*Non* ne change rien) ; un nombre de segments seul garde le cône.
- **Cercles cassés** (arêtes simples, courbes soudées, cercles coupés par une opération sur les
  solides, points de coupe en plus) : le cylindre est **reconstruit en cercles natifs** à la
  nouvelle taille. Quand c'est impossible (ligne raccordée à un cercle, cylindres empilés…), la
  taille reste exacte et les cercles sont soudés en une courbe (SketchUp 2020.1 et suivants ;
  laissés en arêtes sous SketchUp 2017).
- **Nombre de segments** : chaque cylindre est reconstruit en cercles natifs. Si l'un des cylindres
  sélectionnés ne peut pas l'être, **rien n'est modifié** et la barre d'état en donne la raison.
  Taper le nombre de segments qu'il a déjà ne change rien.
- Trous dans un bloc et tenons sur une pièce : la face hôte et ses matériaux restent intacts.
- Dans un composant, ouvrez-le d'abord ; sa définition est modifiée, donc toutes ses copies.
- Une étape d'annulation par saisie.

## 8. Quelle commande pour quoi ?

| Vous voulez… | Utilisez |
|--------------|----------|
| Tracer des cercles d'un diamètre exact avec beaucoup de segments | **Circle** |
| Changer le diamètre d'un cercle ou d'un arc plat | **Circle**, cercle sélectionné |
| Changer le nombre de segments d'un cylindre, d'un trou ou d'un coin arrondi | **Circle** (cercle d'extrémité ou arc sélectionné) ou les commandes de cylindres (paroi sélectionnée) |
| Remettre un trou ou un tenon entier à un diamètre exact (aux deux bouts) | **Resize Cylinders…** ou **Cylinder Resize Tool** |
| Réparer un trou cassé par une opération sur les solides en le redimensionnant | les commandes de cylindres |

## 9. Réglages

*Extensions → Circle Master → Settings…* (ou le 4e bouton de la barre d'outils). La fenêtre se
redimensionne ; sa taille et sa position sont mémorisées.

| Réglage | Description | Défaut |
|---------|-------------|--------|
| Default segment count | Nombre de segments des nouveaux cercles | 48 |
| Value typed without marker | **Diameter** : `50` = diamètre, `25r` = rayon. **Radius** : `25` = rayon, `50d` = diamètre. Vaut pour **toutes les commandes**, y compris le champ *Mode* de *Resize Cylinders…* | Diameter |

Tant qu'un réglage n'a pas été changé dans Circle Master, il est lu dans Circle Advanced (segments,
mode de saisie, mode de coordonnées) ou dans Cylinder Resize (mode) ; les réglages de ces extensions
ne sont jamais modifiés.

### Avancé — Mode de coordonnées (dans les groupes)

Règle la position des cercles tracés dans un groupe ou un composant ouvert :

- **Auto (recommandé, par défaut)** : suit ce que SketchUp indique pour le groupe ouvert.
- **World** : aucune conversion.
- **Local** : conversion par la transformation du groupe ouvert.

Ne le changez **que** si les cercles tracés dans un groupe ouvert apparaissent au mauvais endroit ou
à la mauvaise taille. Un mauvais réglage décale tous les cercles tracés dans les groupes :
l'avertissement passe en rouge et une confirmation est demandée à l'enregistrement d'un changement.

## 10. Compatibilité

- Testé sous **SketchUp 2021 Pro** et **SketchUp Make 2017**, Windows (batterie de tests
  automatique).
- Devrait fonctionner de SketchUp 2017 à 2027 : vérifié d'après les notes de version de l'API Ruby
  de SketchUp (Ruby 2.2 à 3.4), non testé. Avant 2020.1, un cercle qui ne peut pas être reconstruit
  en cercle natif reste en arêtes séparées au lieu d'être soudé.
- Ne demande pas SketchUp Pro : aucun outil Solides n'est utilisé.
- Interface de l'extension en anglais.

## 11. Limites connues

- Pas de « rapporteur » coloré avant le premier clic : un petit cercle d'aperçu le remplace.
- Survoler une arête n'oriente pas le cercle perpendiculairement à elle.
- Le premier sommet du cercle peut être tourné autrement qu'avec l'outil natif.
- Les boutons de la barre d'outils n'apparaissent enfoncés qu'à partir de SketchUp 2019.
- Les faces recréées perdent la position de leur texture et leurs attributs.
- Un arc dont les segments seraient plus courts que la tolérance de SketchUp (0,001″ ≈ 0,025 mm)
  ne peut pas être tracé, même par les outils natifs (par exemple un quart de cercle de rayon
  0,5 mm en 48 segments).
- Cercles qui se touchent (trous ou tenons tangents) : près du point de contact, leurs arêtes ne
  sont qu'à quelques centièmes de millimètre. Quand un sommet du cercle reconstruit tombe à moins
  de 0,001″ (≈ 0,025 mm) de l'autre cercle, SketchUp les soude, et le changement est refusé
  (« … could not be rebuilt, nothing was changed »). Un écart de 0,1 mm
  entre eux suffit.
- Pas de séparateur de milliers (`1,000` est lu comme 1 sur un PC qui utilise le point décimal).

## 12. Dépannage

| Problème | Solution |
|----------|----------|
| Commandes en double | Désinstallez Circle Advanced et Cylinder Resize (§ 2) |
| Barre d'outils invisible | *Affichage → Barres d'outils → Circle Master* |
| « Cannot modify the circle » | Tracez un nouveau cercle : le précédent ne peut plus être modifié |
| La zone affiche « Sides » alors qu'un cercle est sélectionné | Le cercle est cassé ou seule sa face est sélectionnée : cliquez son arête, ou utilisez les commandes de cylindres |
| « Cylinder not supported (…) » ou « Rounded corner not supported (…) » | Rien n'a été modifié ; la raison indique la condition non remplie |
| « The segment count cannot be changed (…), nothing was changed » | L'un des cylindres sélectionnés ne peut pas être reconstruit (par exemple une ligne raccordée à un cercle) : redimensionnez-le sans segments, ou retirez la ligne |
| « … could not be rebuilt, nothing was changed » | La vérification finale a échoué et tout a été annulé ; signalez le cas avec une capture |
| Erreur au chargement | *Fenêtre → Console Ruby* : copiez le message et signalez-le sur GitHub |
