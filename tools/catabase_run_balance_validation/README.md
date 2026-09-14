# Validation continue de la run Catabase

Ce harnais headless traverse la route de production avec le même Achille entre
les salles. Il utilise les six préparations publiques, les salles et formations
réelles, `EnemyAI`, `SpellCaster`, l'équipement, les reliques/fournitures, l'XP,
les attributs, l'arbre, les récompenses, les refuges et des sauvegardes/reprises.

Il mesure un bot borné et déterministe, pas une personne. Un résultat ne doit
donc jamais être présenté comme un taux de victoire humain ni comme une preuve
qu'une difficulté est juste. Le chemin dépend uniquement de la graine et de la
profondeur ; les ennemis ne lisent jamais l'arme, les PV ou les décisions du bot.

Exécution prioritaire, une graine et les six armes :

```powershell
./tools/catabase_run_balance_validation/run_validation.ps1 -Label stage1_seed2401 -Seeds 2401
```

Extension à trois graines :

```powershell
./tools/catabase_run_balance_validation/run_validation.ps1 -Label stage2_three_seeds -Seeds 2401,7126,19073
```

Les deux commandes exécutent Normal et Facile avec la politique `balanced`.
Un balayage exploratoire des trois politiques est possible avec
`-Policies balanced,survival,pressure`; il multiplie le coût d'exécution et ne
constitue pas une recherche d'optimalité.

Le rapport JSON est écrit dans
`artifacts/catabase_run_balance_validation/<label>/report.json`. Chaque combat
contient les PV d'entrée et de sortie, les étapes de récupération, le niveau,
les dégâts connus avant défense, les dégâts résolus avant bouclier, la perte de
PV, les tours, le temps, les sorts, le roster et la cause de fin. Le champ
`raw_damage_coverage` rappelle que les effets automatiques ou périodiques n'ont
pas toujours un `DamageResult.raw` exposé au harnais ; les faits résolus restent
alors couverts par l'EventBus.

Limites : le bot pilote la logique de combat sans animation ni clics et réutilise
la boucle headless du probe des six premières salles. Il ne valide ni HUD, ni
timing visuel, ni compréhension des télégraphes. Les drapeaux de matchup servent
à choisir une revue humaine ciblée, pas à demander un nerf automatique.

La politique V2 reste volontairement bornée : elle conserve un objectif pendant
les détours autour des obstacles, utilise légalement les secours disponibles,
remplit les nouveaux emplacements avec des sorts réellement connus, privilégie
la branche liée à l'arme et prend les choix de mémoire selon le profil. Elle
écoute les haltes de lore, mais ignore volontairement marchands et paris. Ses
achats ne constituent ni un build optimal ni une simulation complète de
l'économie ; les échecs du bot ne justifient donc jamais à eux seuls un nerf.

## Contrôle visuel complémentaire

```powershell
./tools/catabase_run_balance_validation/ui_probe.ps1 -Label r6_ui_review
```

Le contrôle utilise le moteur graphique Windows avec une fenêtre masquée et
un dossier de sauvegarde isolé. Il partage le verrou moteur des autres outils :
ne pas le lancer en même temps qu'une suite Godot. Le chemin Godot vient du
diagnostic local ; `-GodotPath` permet de le préciser explicitement.

Il capture départ, préparation XIX et attaque retardée en 1280 × 720 puis
1920 × 1080. La progression jusqu'à XIX utilise des victoires simulées pour
atteindre l'écran : ce n'est pas une preuve de run gagnée. Le télégraphe vient,
lui, d'un vrai lancement dans l'arène I, HUD désactivé pour isoler le contrôle.
Une sortie processus réussie ne suffit pas : `summary.json` vérifie aussi les
erreurs moteur et les assertions. Inspecter les PNG pour juger la lisibilité.
