# Audit des dépendances de contenu

Outil Python standard, en lecture seule. Il examine les fichiers Git présents,
y compris les fichiers non suivis non ignorés, et relie les chemins `res://`
ainsi que les UID déclarés dans les ressources, scripts et imports.

```powershell
python tools/content_audit/audit.py data/rooms/maps --output artifacts/content_audit/maps.json
python tools/content_audit/audit.py . --check-resources --output artifacts/content_audit/resources.json
python -m unittest discover -s tools/content_audit -p 'test_*.py'
```

Le terminal ne reçoit que les comptes et le chemin du rapport. Chaque fichier
du rapport indique sa taille, ses références internes au périmètre examiné et
ses références externes. Les archives documentaires et rapports générés sont
exclus du graphe ; ils restent consultables séparément.

**Une liste vide ne prouve pas une absence d'usage.** Vérifier les chemins
construits, les scans de dossiers, les outils d'édition, les ressources binaires
et les anciennes sauvegardes. L'outil ne supprime rien et ne mesure pas la
joignabilité depuis le menu public. Valider ensuite dans Godot.

`--check-resources` échoue si une déclaration `ext_resource` de scène ou de
ressource pointe vers un fichier absent. Les laboratoires ayant leur propre
`project.godot` sont résolus depuis cette racine. Le contrôle ne couvre pas les
chemins construits en GDScript ; il complète l'import et les tests moteur.
