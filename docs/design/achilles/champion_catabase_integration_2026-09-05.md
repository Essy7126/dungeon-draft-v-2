# Intégration Champion dans la Catabase — 5 septembre 2026

## Périmètre

**DÉCISION VALIDÉE :** appliquer le theorycraft Achille fourni en pièce jointe à la Catabase existante. Les sprites, l’introduction, les cartes et les ennemis continuent d’évoluer dans leurs tâches dédiées. Cette passe ne crée aucune run, séquence de dix combats ou nouveau boss.

**EXPÉRIMENTAL V0 :** les valeurs d’équilibrage sont éditables. Le [tableau complet des statistiques, techniques, maîtrises et objets](champion_catabase_statistics_v0.md) est généré depuis les Resources et le resolver de combat ; sa [version JSON](champion_catabase_statistics_v0.json) permet une exploitation externe.

## Comportement livré

**OBSERVÉ :** Achille gagne de l’XP à la victoire de chaque rencontre, une seule fois. Les techniques n’ont plus d’XP ni de progression par lancement. Les trois rencontres actuelles accordent 100, 120 et 140 XP : niveau 4 sans bonus. La Sagesse est figée au début de la rencontre ; le Serment du Pélion exige une victoire sans consommable après acceptation préalable.

**OBSERVÉ :** les caractéristiques et les 36 maîtrises alimentent le même pipeline que les aperçus du codex. Les quatre techniques, les attaques automatiques, les boucliers séparés, les déplacements optionnels, les collisions et les réactions de reliques sont raccordés au combat réel. Les réactions concurrentes réservent leur fréquence et la rendent si elles ne sont finalement pas choisies ou exécutables.

**OBSERVÉ :** la sélection, le HUD, le codex et le bilan de victoire affichent le modèle Champion. Les points peuvent être gardés ou investis entre les combats. L’étape de Chiron propose équipement, reliques, soin, forge, renouvellement, réorientation et leçons. Les statistiques des équipements sont passives et ne créent pas d’attaque d’arme.

**OBSERVÉ :** le snapshot inventaire/progression V5 conserve le build, les blessures, les objets forgés, l’économie, les propositions du marchand et les priorités de réaction. Un état invalide est refusé après validation isolée, sans altérer le héros vivant. Les sauvegardes Achille antérieures sont refusées explicitement ; ce format n’est pas une sauvegarde intégrale d’un combat en cours. Le trio conserve son système historique d’XP par sort.

## Validation reproductible

Moteur : Godot 4.7.1 ; GUT 9.7.1.

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s res://addons/gut/gut_cmdln.gd '-gconfig=res://artifacts/achilles_theorycraft_integration/final.gut.json' -gexit
```

**OBSERVÉ : 28 scripts, 256 tests réussis, 4 772 assertions, code de sortie 0.** Aucun script ignoré ni erreur de parsing. La suite couvre formules, prérequis/exclusions, effets réactifs et statiques, achats, forge, copies Studio, sauvegardes, sélection, codex, récompenses, transitions et systèmes historiques. Elle inclut un cycle réel dans Battle Map0 : déploiement, Garde orientée, Percée/Bastion, Frappe, tour ennemi, activation suivante.

Le journal `artifacts/achilles_theorycraft_integration/final_suite.log` conserve les preuves. Le message de victoire différée est provoqué par un test de garde-fou historique. Godot signale encore des ressources et instances non libérées à la fermeture du processus de tests ; ce résultat ne constitue donc pas une validation de l’absence de fuite mémoire.

Les captures du codex couvrent 1280 × 720, 1366 × 768 et 1920 × 1080. Le bilan, l’investissement de caractéristiques et le marchand ont été rendus et inspectés à 1280 × 720. Reproduction :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/champion_progression/review_catabase_progression_flow.gd
```

Les hauts niveaux montrés dans certaines captures utilisent des états de revue isolés. Les nombres de ce rapport sont ceux de la passe locale, pas un statut de CI distante.

Les régressions finales couvrent aussi les valeurs par cible de Fléau, Ligne et Volée, les portées effectives, les deux arrondis successifs de la Garde et les aperçus de caractéristiques avec maîtrises. Le codex a été rendu à nouveau avec un chemin légal vers Fléau. Le JSON V2 contient les coefficients et conditions de gameplay en plus des libellés.

Résolution sur les boucliers créés par maîtrise et extinction immédiate de l’aura après consommation complète de la Garde : deux régressions reproduites avant correction, puis validées dans le lot final.
