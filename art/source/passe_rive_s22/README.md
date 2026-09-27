# Passe-Rive — intégration S22, 26 septembre 2026

La marche et le repos du combat reprennent les sprites natifs utilisés dans les espaces libres. Les PNG d’attaque S19/S20 approuvés sont conservés.

## Fonctionnement

- `passe_rive_s19_backend.gd` sélectionne le rendu natif pour repos, marche, course, réactions, mort et ruée. Le painter S19 est visible uniquement pendant les attaques peintes.
- Les pas dépendent de la distance réelle parcourue, dans le plan du sol et à l’échelle du personnage. La durée d’une case respecte les cycles de l’exploration : 0,72 s en marche, 0,60 s en course. Le virage conserve la phase des pieds. Les longs trajets utilisent la course native.
- La référence de taille est celle de l’exploration : 214 pixels source × `display_scale` (94,16 unités pour le profil actuel). Les corrections constantes de posture sont dans `passe_rive_s22_registration.gd`. Aucun changement d’échelle par frame ; armes et effets ne servent pas de mesure du corps.
- Les fragments du sceau qui débordaient dans la ligne précédente de l’atlas restent attachés à la pose de main correspondante. Les pieds SE des deux premières poses sont recalés. Les autres exclusions de flèche et de dague restent conservées.
- L’effet de carte `move` utilise la ruée native : préparation 0–1, trajet 2–13, réception 14–24 à l’arrivée pendant 0,30 s, puis repos. Un seul déclenchement du sort. Le blink reste distinct ; les règles de portée et les axes autorisés ne changent pas.

## Essayer

Depuis le projet :

```powershell
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Locomotion
```

Le bouton **Essayer marche → sorts → ruée** lance le parcours. **Ruée / Percée** teste directement une charge vers SE, SW, NW ou NE (les axes de la grille isométrique). Les sept attaques et huit orientations restent disponibles dans le panneau.

Ajouter `-Capture` produit un dossier neuf dans `artifacts/dev/` avec rapport, captures et échantillons runtime. `tools/class_card_vfx/build_s22_review.py <dossier>` crée un lecteur HTML et des GIF des captures natives.

## Limites et audit

La taille et les appuis sont des réglages d’intégration. Les silhouettes peintes ont encore un modelé et des proportions de vêtements différents des sprites natifs ; cette passe ne prétend pas les avoir redessinées ni uniformisées. Les poses amples restent volontairement plus basses ou plus larges pendant l’action.

Les chiffres de validation et chemins des preuves fraîches sont dans `VALIDATION.md`. Aucun ancien rapport S21 n’est repris comme preuve. Le banc Studio connecte le même gestionnaire de déplacement que le démarrage normal de Battle, respecte les directions légales de Percée et commence une nouvelle activation entre ses essais.
