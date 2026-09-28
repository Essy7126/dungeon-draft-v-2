# Outils de l'audit gameplay du 28 septembre 2026

Ces outils observent les règles Cartes intégrées ; ils ne changent aucun fichier de production et n'estiment pas un taux de victoire.

```powershell
./tools/gameplay_audit_2026_09_28/probe.ps1 -Capture
node tools/gameplay_audit_2026_09_28/calculate.mjs docs/audits/gameplay_2026-09-28/observations.json docs/audits/gameplay_2026-09-28/calculs.json
```

Le lanceur utilise le moteur résolu par les outils du dépôt et prend le verrou Godot. S'il est déjà occupé, la sonde échoue plutôt que de lancer un second moteur concurrent. APPDATA/LOCALAPPDATA sont isolés dans le dossier `artifacts/dev/` créé pour l'exécution. Les sauvegardes personnelles ne sont pas utilisées. Sans `-Capture`, le relevé fonctionne en headless.

`probe.gd` étend le harnais existant `tools/consumable_cards/audit_live_integration.gd` : douze scènes réelles, parcours seed 33 par le premier nœud proposé, difficulté normale. Il ajoute les 32 profils des trois branches, les aperçus de route et les mesures de chemin depuis le premier déploiement légal. Les mesures d'accès aux commandes acceptent leur case ou une case adjacente ; une copie de grille sans unités sépare blocage d'occupation et terrain permanent. La distance de contact compte des pas sur le chemin de coût minimal ; le coût d'interaction compte bien des PM.

**Fixtures héritées :** victoires déclarées pour avancer ; téléportation près du levier pour les captures ; pression et seuil de boss arrangés pour vérifier leur résolution. La sonde n'est pas une campagne jouée. Les dispositions observées ne sont pas un échantillon de tous les déploiements possibles.

`calculate.mjs` lit le catalogue actuel et une observation complète. Il calcule exactement les lois de drop pertinentes et les mains par combinatoire. Il ne reproduit pas le PRNG Godot et n'invente aucune politique de combat. Les règles de calcul correspondent à la V2 auditée : sept canaux, deux garanties de relique, 70 % natif/commun, une ouverture, 4 or par élimination pour Obole. Après une refonte de ces règles, adapter le modèle à son implémentation ; le hash du catalogue permet d'identifier la version utilisée, sans certifier à lui seul la concordance avec d'anciennes observations.

Pour un nouvel audit, remplacer l'entrée par le `observations.json` de la nouvelle exécution. Ne pas combiner silencieusement l'observation archivée de `6e8d2605` avec un catalogue plus récent. Les assertions contrôlent les dimensions et quelques identités mathématiques ; elles ne remplacent pas les tests du moteur.

Le rapport, les observations et les résultats archivés sont dans [docs/audits/gameplay_2026-09-28](../../docs/audits/gameplay_2026-09-28/).
