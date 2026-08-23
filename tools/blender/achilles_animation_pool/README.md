# Retarget du pool d'animations Achille

Ce dossier contient le script Blender qui retargete toutes les actions d'un GLB Meshy vers une copie du squelette canonique Achille V1. La source et la V1 sont strictement des entrées en lecture ; la sortie doit être un dossier isolé.

## Entrées validées

- Source : `Meshy_AI_Meshy_Merged_Animations (4).glb`, SHA-256 `21DAD4EE17146F3A1430A684C7EFD14544701100307C233D4E5B27812EF58770`.
- Canonique : `assets/characters/Achilles/3d/achilles_rig_v1.glb`, SHA-256 `CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F`.
- Blender validé : `5.1.2`.

Le script attend un rig Meshy de 24 os et le rig canonique de 52 os. Il transfère 22 os, échantillonne les actions à 30 images par seconde, conserve les 30 os de doigts canoniques en pose de repos et ajoute les 20 actions retargetées aux 4 actions natives.

## Commande

Depuis la racine du projet, en adaptant les chemins Blender et Meshy à la machine :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" `
  --background `
  --factory-startup `
  --disable-autoexec `
  --python "tools/blender/achilles_animation_pool/retarget_all_actions.py" `
  -- `
  --source "C:\Users\paolo\Downloads\Meshy_AI_Meshy_Merged_Animations (4).glb" `
  --canonical "assets\characters\Achilles\3d\achilles_rig_v1.glb" `
  --output-dir "output\achilles_animation_pool_v2_rebuild"
```

Le dossier de sortie ne doit être contenu ni dans le dossier de la source, ni dans celui du canonique. Les chemins placés sur des lecteurs Windows différents sont acceptés.

## Sorties

Le script génère :

- `achilles_rig_animation_pool_v2.blend` : scène de travail retargetée ;
- `achilles_rig_animation_pool_v2.glb` : modèle canonique avec les 24 animations ;
- `retarget_result.json` : mapping, comptages, durées, root deltas et validation des courbes.

Avant de promouvoir un nouvel export dans `assets/characters/Achilles/3d/`, vérifier :

1. 52 joints et la signature squelette `6CC796EE5D708EE1A7F884C028C457CA535A4D7B572A189B36DFE5EBAD62D65D` ;
2. 24 animations : 20 noms préfixés `achilles_v2__` et les 4 natives ;
3. aucune courbe non finie et une erreur de transfert du root inférieure à `1e-5` ;
4. marche, course, idle, impact et les quatre sorts dans Godot ;
5. absence de modification du SHA-256 de `achilles_rig_v1.glb`.

## Passe artistique restante

Ce retarget produit un prototype structurel. Réviser en mouvement les contacts pieds/sol, les bras et mains, les prises d'épée ou d'arc et les coutures de boucle. Les 30 os de doigts ont besoin de poses manuelles. Les clips `Basic_Jump`, `Double_Combo_Attack`, `Simple_Kick`, `Sword_Judgment` et `Triple_Combo_Attack` demandent une attention particulière au root motion. La source ne contient aucune animation de mort.
