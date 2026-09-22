# Donner du poids aux cartes fortes

## Références consultées

- [WAVEN — note 18 : icônes et FX de sorts, ToT, 2018](https://totaime.wordpress.com/2018/09/13/waven-note-18-les-icones-et-fx-de-sorts/) : le créateur décrit la cohérence recherchée entre nom, icône et FX. Le GIF du Poing du Dragon a été observé dans le navigateur : une masse verte projetée, un contour très clair, puis des pointes d'impact. Il s'agit d'une référence historique de développement.
- [DOFUS × Deeamo : portfolio de l'animateur FX](https://deeamo.fr/dofus-x-deeamo-lanimation-de-fx-dans-le-jeu-dankama/) : l'artiste décrit son passage chez Ankama et montre ses productions par classe. La planche Iop observée montre notamment une lame monumentale, des masses pleines, des éclats et des volutes secondaires. Cela ne documente pas une pipeline interne actuelle de DOFUS 3.

Notre interprétation : la puissance se lit dans une silhouette principale ample, une matière plus dense, un contact contrasté et une dissipation hiérarchisée. Augmenter uniquement la luminosité des filaments existants ne suffit pas. Aucun asset de ces jeux n'est copié ou importé.

## Hiérarchie appliquée

Les cartes courantes et les initiations gardent leur budget visuel. Dix attaques à 3 PA ont un corps plus plein, une rémanence d'au moins 1,05 s et des fragments brefs : Coup de grâce, Lames croisées, Tenir le passage, Balayage de hampe, Choc de masse, Tir de longuevue, Volée croisée, Orage concentré, Éclat de braise et Éclats gelés. Orage reçoit une colonne dentelée propre.

Les quatre terrains à 3 PA — Faille ardente, Flèche incendiaire, Bûcher des ombres et Jardin de givre — gagnent une naissance lumineuse qui s'apaise en 0,90 s. La forme au sol reste découpée par les cases réellement actives. Le piège à 2 PA conserve son intensité inférieure.

Les huit cartes réellement classées épiques dans le catalogue ont chacune une forme principale. Leur nappe mesure entre 2,75 et 3,10 largeurs de case ; cela décrit un volume aérien de présentation, jamais la surface affectée par les règles.

| Carte | Silhouette et matière | Rémanence |
|---|---|---:|
| Moisson des condamnés | Deux faux pourpres, bord ivoire et fragments ascendants | 1,55 s |
| Bastion vivant | Trois remparts ambrés à créneaux, montée échelonnée et centre dégagé | 1,65 s |
| Sentence du rempart | Pilon de bronze spectral, facettes et éclat au contact | 1,45 s |
| Volée du crépuscule | Cinq pointes larges et sillages en éventail | 1,40 s |
| Prime de la traque | Grand fer de chasse, trois barbes et sillage jade | 1,45 s |
| Sablier brisé | Verre spectral, deux plateaux et sable suspendu | 1,70 s |
| Sommeil de l'oubli | Deux ailes nocturnes, croissant pâle et voile creux | 1,60 s |
| Couronne de cendres | Cinq grandes flammes courbes, cercle incandescent et cendres | 1,75 s |

Le contact est montré dès l'événement confirmé. La silhouette se déploie durant les premiers 15 % de la rémanence ; le corps se dissipe avant les derniers fragments. Les valeurs ci-dessus ne sont ni un délai avant dégâts ni une durée de contrôle. Aucun second flash ne prétend qu'un deuxième coup a été porté.

Les silhouettes épiques sont exclues du maintien, des ticks et des expirations. La garde ambiante suit le bouclier réel ; les signes de stase suivent ses activations. Sur Paris, le lancer de stase utilise des fragments de désorientation et conserve le signe PA réel, sans sablier ou sommeil trompeur. La Sentence ne promet pas de déplacement. Les exécutions n'affirment pas un bonus que le rapport ne confirme pas séparément.

## Reproduction

Brief par carte → silhouette procédurale → matière et mouvement → événement confirmé → comparaison de puissance → vrais lancers → contrôles de durée et nettoyage.

Les matériaux sont des shaders CanvasItem Godot, avec deux couches autour de l'acteur et la texture de bruit partagée. La même horloge explicite pilote le lecteur en combat et en galerie. Blender n'est pas nécessaire pour ces silhouettes ; aucun service externe n'est requis pour les reproduire.

```powershell
./tools/class_card_vfx/preview.ps1 -Capture
node tools/class_card_vfx/encode.cjs
./tools/class_card_vfx/capture_combat.ps1 -Power
node tools/class_card_vfx/encode_semantics.cjs --power
./dev.ps1 test cards
```

La galerie propose une comparaison courant/épique à échelle identique et la lecture des huit épiques. La sonde `power/` lance les huit sorts par le vrai SpellCaster dans l'arène de production, prend des vues à caméra normale, puis contrôle les expirations réelles. Les captures échantillonnent l'horloge VFX avec IA suspendue ; elles ne constituent pas une mesure de performances GPU ni une partie manuelle complète.

Les résultats de validation de cette passe sont consignés dans [la fiche de suivi](../../ai/CARDS_VFX_POWER_2026-09-21.md). Les rapports des passes antérieures restent historiques.
