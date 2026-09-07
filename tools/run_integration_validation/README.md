# Catabase — parcours d'intégration réel et borné

Ce runner vérifie Dungeon Draft, jamais DOFUS. Il n'est pas une simulation d'équilibrage. Il ne modifie aucun fichier de ressource canonique et n'ajoute aucun point de vie/PA/PM, déplacement forcé ou appel direct au SpellCaster. Une copie mémoire superficielle de la run sélectionnée fixe uniquement le seed QA (2401 par défaut).

## Parcours

1. Ouvre la vraie sélection, choisit la run `odyssey.tres`, actionne son bouton d'aventure.
2. Observe la vraie intro, utilise `request_skip()`, puis le bouton de transition réel. Aucun démarrage substitué.
3. Déploie via `DeploymentController.on_cell_clicked`. Vérifie les cinq ressources de salles et le terrain enregistré prêt ; chaque salle remplace le contexte, pas le HUD persistant.
4. Vérifie le kit canonique **Péléide → Percée fulgurante → Tir du Pélion → Garde d'airain** entre sélection, loadout réel, Unit et HUD, ainsi que l'identité des textures d'icônes.
5. Ouvre inventaire/codex par les boutons HUD, ferme par Échap injecté dans le viewport, vérifie le verrouillage et le retour des contrôles. Alterne OBJETS/SORTS et vérifie l'exclusivité de la touche 1.
6. Actionne les vrais boutons de sorts ; choisit parmi les highlights publics puis appelle `GridView.update_hover()/click_at()`. Déplacements et fins de tour passent aussi par le HUD et sa confirmation. Limite : six activations joueur par salle.
7. Exige une résolution de chacun des quatre sorts : événement `spell_cast` unique, coût PA et effet réels. En salle IV, exige **Le Dialecticien**, identifié par `data/units/enemies/philosopher_mage.tres` et sa scène visuelle canonique, puis une activation IA commencée et terminée ; ses `action_resolved` sont consignés séparément. Il ne s'agit pas du Mage allié du trio ; la classe visuelle ne constitue pas une preuve de rendu 3D.
8. **Après les actions réelles uniquement**, accélère la victoire via `Battle._end_battle(true)`. Chaque accélération figure sous `forced_outcomes` ; elle ne prouve pas une victoire organique.
9. Pilote les phases post-combat via `advance_or_skip()`, `select_reward_by_id()` et `confirm_selected_reward()`. Vérifie le garde de progression avant récompense, les quatre transitions et le résultat victoire 5/5.
10. Actionne le bouton du résultat vers le refuge et vérifie le nettoyage. `--include-loss` ajoute un second départ réel, une garde réellement lancée puis une **défaite QA forcée** et son nettoyage.

## Lancement coordonné

Un seul processus GPU à la fois. Pas d'import global. Exemple PowerShell (dossier de sortie unique par exécution) :

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' `
  --path 'C:/Users/paolo/Documents/dungeon-draft-v-2' `
  --log-file 'C:/CHEMIN/ABSOLU/EXISTANT/native.log' `
  'res://tools/run_integration_validation/RunIntegrationQARunner.tscn' -- `
  --output-root=C:/CHEMIN/ABSOLU/EXISTANT `
  --resolution=1600x900 `
  --seed=2401 `
  --capture-resolutions=1600x900,1920x1080 `
  --include-loss
```

Sans `--capture-resolutions`, les captures utilisent `--resolution`. Les noms contiennent jalon, horodatage UTC et dimensions. Les captures `combat` conservent le début de tour ; `idle` attend la fin naturelle du bandeau. `--evidence-head=<sha>` consigne un SHA fourni ; **le runner ne certifie pas ce SHA ni la propreté Git**. `--seed=2401` remplace le seed sur une **copie mémoire** de la seule run sélectionnée et désactive son tirage aléatoire, sans sauver la ressource. La valeur effective est assertée et les valeurs canoniques restent consignées. Le hash SHA-256 du fichier source est contrôlé au début et à la fin. Les noms effectifs du renderer, driver et périphérique graphique sont consignés ; aucune équivalence entre Forward+/D3D12 et OpenGL n'est supposée.

`run_integration_report.json` est écrit progressivement : assertions, chronologie, événements, casts, déplacements, classes visuelles, icônes, lifecycle et sorties forcées. Conserver stdout, stderr et journal natif : les erreurs tardives du moteur peuvent n'apparaître que sur stderr/stdout.

## Smoke de parsing

Avec `--headless`, la garde GPU produit `parse_smoke_reached_gpu_guard: true`, puis une sortie non nulle. Cela prouve seulement que le script a compilé et exécuté jusqu'à cette garde ; **aucun parcours, asset 3D ni comportement n'est validé**.

## Limites

- Événements de boutons/viewport injectés dans Godot : aucune certification de saisie OS, focus Windows ou souris physique.
- Victoires accélérées : aucune preuve d'équilibrage ni de réussite de la run sans intervention QA.
- Aucun téléport/boost/remise à zéro du budget ne masque un échec. Un sort inaccessible sous six activations produit un échec documenté.
- Certaines références internes (`_unit_views`, `_deployment`, listes de boutons) sont lues pour observer les identités. La seule sortie forcée est explicitement signalée.
- Une activation IA complétée ne signifie pas nécessairement un sort lancé : débuts/fins de tour, actions et casts sont distingués.

## Reprise finale : trois processus GPU sérialisés

État et preuves antérieures : [VALIDATION_NOTES.md](VALIDATION_NOTES.md). Ne lancer cette reprise qu'après stabilisation du travail Paris et vérification de chargement Catabase. Ces commandes ne sont pas une assertion qu'elles ont déjà été exécutées. Les deux E2E utilisent explicitement Forward+/D3D12, la galerie son chemin Windows/OpenGL3. Les dossiers finaux sont distincts des captures historiques.

```powershell
$runQaProject = 'C:/Users/paolo/Documents/dungeon-draft-v-2'
$runQaGodot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe'
$runQaBase = "$runQaProject/artifacts/run_integration_20260906"
foreach ($relative in @('data/characters/paris/animations.tres', 'assets/characters/paris/sprites_v1/paris_portrait.tres')) {
  if (-not (Test-Path -LiteralPath "$runQaProject/$relative")) {
    throw "Dépendance encore absente : $relative. Préserver le travail parallèle, ne pas contourner."
  }
}
$runQaJobs = @(
  @{ Name='e2e_final_1200'; Scene='res://tools/run_integration_validation/RunIntegrationQARunner.tscn';
     Method='forward_plus'; Driver='d3d12'; UserArgs=@('--resolution=1200x896','--seed=2401','--include-loss') },
  @{ Name='e2e_final_1920'; Scene='res://tools/run_integration_validation/RunIntegrationQARunner.tscn';
     Method='forward_plus'; Driver='d3d12'; UserArgs=@('--resolution=1920x1080','--seed=2401','--include-loss') },
  @{ Name='hud_canonical'; Scene='res://tools/ui_snapshots/HudGrayboxCaptureRunner.tscn';
     Method='gl_compatibility'; Driver='opengl3'; UserArgs=@('--premium-achilles') }
)
foreach ($job in $runQaJobs) {
  $runQaDirectory = "$runQaBase/$($job.Name)"
  if (Test-Path -LiteralPath $runQaDirectory) {
    throw "Dossier déjà présent : $runQaDirectory. Archiver la preuve ou choisir un nouveau suffixe, ne pas écraser."
  }
  New-Item -ItemType Directory -Path $runQaDirectory | Out-Null
  $runQaOutput = if ($job.Name -eq 'hud_canonical') {
    'res://artifacts/run_integration_20260906/hud_canonical'
  } else { $runQaDirectory }
  $runQaArguments = @('--path', $runQaProject, '--display-driver', 'windows',
    '--rendering-method', $job.Method, '--rendering-driver', $job.Driver,
    '--log-file', "$runQaDirectory/native.log", $job.Scene, '--',
    "--output-root=$runQaOutput") + $job.UserArgs
  $runQaProcess = Start-Process -FilePath $runQaGodot -ArgumentList $runQaArguments `
    -WindowStyle Hidden -Wait -PassThru `
    -RedirectStandardOutput "$runQaDirectory/stdout.log" `
    -RedirectStandardError "$runQaDirectory/stderr.log"
  if ($runQaProcess.ExitCode -ne 0) {
    throw "Échec $($job.Name), code $($runQaProcess.ExitCode). Lire les trois logs avant de continuer."
  }
}
```

Attendus : chaque E2E doit rapporter `ok=true`, seed 2401 appliqué, quatre sorts canoniques réellement résolus, victoire 5/5 et défaite avec retour propre. La galerie doit annoncer 44 succès/0 échec, soit 11 états sur 4 résolutions. Inspecter également stderr et les captures : un JSON de contrats vert n'efface pas des erreurs de fermeture du moteur.
