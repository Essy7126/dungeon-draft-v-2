# Statistiques : consulter, comprendre, investir — 30 septembre 2026

Le [contre-audit ultérieur](STATS_SEPARATION_REVIEW_2026-09-30.md) a reproduit
deux limites non couvertes par les validations ci-dessous : réorientation
immédiate sans confirmation et aperçu inchangé pour Contact/Distance.

## Recherche et limites

Le lien fourni vers le sujet « Interface Dofus Unity âme cœur » a été tenté
directement ; son contenu n’a pas été récupéré. Le devblog officiel de 2025
sur les éléments d’interface renvoie une vérification JavaScript. Aucun contenu
de ces deux pages n’est présenté ici comme effectivement lu.

- **2010, correction de DOFUS 2.0.** Le texte du devblog Ankama reproduit par
  JeuxOnLine explique le retour d’accès directs, les difficultés causées par
  les clics supplémentaires, le regroupement personnage/équipement dans
  l’inventaire et un onglet pour les caractéristiques avancées. La stabilité
  des habitudes et la vitesse d’utilisation y sont des motifs explicites.
  [Devblog reproduit](https://dofus.jeuxonline.info/actualite/26829/devblog-interface-20-nouveaux-changements)
- **2016, refonte 2.36.** Le devblog reproduit expose une charte cohérente,
  des éléments déplaçables/redimensionnables et des infobulles structurées.
  L’objectif déclaré est d’améliorer les usages en préservant les repères.
  [Devblog reproduit](https://dofus.jeuxonline.info/actualite/51181/236-refonte-interfaces)
- **Unity et réception en 2025.** Le compte rendu détaillé de la 3.1 relève
  encore des critiques sur les modules et leur placement initial. C’est un
  retour de joueurs, pas une mesure représentative de satisfaction.
  [Présentation de la 3.1](https://www.dofuspourlespros.com/mise-a-jour-301.html)
  Son passage sur les interfaces est accessible dans les résultats indexés ;
  l’ouverture complète de la page a échoué. Les sources consultées ne permettent
  pas d’affirmer que l’interface Unity est largement appréciée aujourd’hui.

Les deux captures fournies illustrent surtout une organisation lisible :
identité courte, icône constante par statistique, libellés à gauche, valeurs
alignées, groupes séparés, détails facultatifs et action de répartition distincte.
La présence de nombreuses statistiques dans DOFUS ne justifie pas d’ajouter des
statistiques sans effet à Catabase.

**Interprétation de design :** l’intérêt de cette référence réside dans la
rapidité de lecture et la mémoire des emplacements. Ajouter des textures ou des
cadres à chaque valeur ne résout pas une interface qui mélange plusieurs tâches.
On conserve notre matière brune et nos symboles ; on réduit les encadrements
internes au profit de lignes, de groupes et d’alignements.

## Intégration

1. **Stats → Résumé** : fenêtre de 720 px de large au maximum prévu, portrait,
   classe/niveau, PV, six statistiques de combat et six éléments. Aucun champ
   de dépense, d’équipement ou de spécialisation. Résumé visible sans défiler
   à 1280×720. Les statistiques affichées sont permanentes, équipement inclus ;
   les PV montrent la vie actuelle.
2. **Détails** : deuxième onglet, tableau Base / Aptitudes / Équipement / Total,
   calcul des maîtrises et effets d’équipement. Le contenu détaillé défile,
   tandis que l’accès à la répartition reste fixe. Les plafonds et l’exclusion
   des effets temporaires sont indiqués.
3. **Répartir mes points** : fenêtre distincte. Éléments et aptitudes à gauche,
   aperçu des effets sur les sorts à droite, confirmation en pied de fenêtre.
   La réorientation est repliée derrière une action explicite.
4. **Retour** : fermer sans confirmer abandonne uniquement le brouillon ;
   revenir après validation rafraîchit les valeurs. La fenêtre revient à
   l’écran appelant : fiche de statistiques ou progression de niveau.
5. **Classe & améliorations** : conserve les choix de classe, avec un accès
   explicite à la répartition. Les formulaires ne sont plus côte à côte.
   Le verrou de spécialisation au niveau 4 reste actif.

Le changement concerne les fenêtres du mode Cartes consommables. Les interfaces
Classique et les anciennes règles restent distinctes. Le calcul, les budgets,
la transaction d’allocation et la sauvegarde existants sont réutilisés.
Ce lot ne crée pas un gestionnaire de fenêtres flottantes simultanées.

## Fichiers

- `ui/expedition/player_statistics_view.gd` : nouvelle consultation sans mutation.
- `ui/expedition/consumable_player_dossier.gd` : séparation des sections.
- `ui/expedition/consumable_progression_editor.gd` : formulaire et aperçu dédiés.
- `ui/expedition/expedition_screen.gd` : dimensions, navigation et retour.
- `tools/consumable_cards/dossier_capture.gd`, `verify_dossier.ps1` : contrôles natifs.

## Validation

Import et thème : PASS, 3 tests / 37 assertions.
`artifacts/dev/20260930-204744-test-test_unit_test_consumable_cards_interface_theme.gd-76ba4cca/gut-strict-report.json`

Le premier rendu a révélé des nombres repliés verticalement dans l’en-tête,
malgré un parcours fonctionnel. Correction : largeur intrinsèque des nombres
et des titres courts conservée, puis contrôle supplémentaire des lignes et
de la visibilité du résumé. L’inspection visuelle est indispensable.

Après correction : dossier et butin PASS aux résolutions 1280×720 et 1600×900,
36 captures. Résumé, détails et allocation inspectés à 720p.
`artifacts/dev/20260930-205311-player-dossier-d131fa82/report.json`

Parcours souris/Échap : PASS, 36 captures. L’ouverture et le retour utilisent
de vrais événements de souris ; Échap est injecté dans le viewport. L’abandon
du brouillon conserve l’état et la validation persiste les maîtrises.
`artifacts/dev/20260930-205650-player-dossier-74a43025/report.json`

Suite Catabase élargie : **FAIL**, 852 tests exécutés, 104 336 assertions,
16 cas en échec et erreurs de nettoyage à la sortie. Le rapport reste rouge.
`artifacts/dev/20260930-205114-test-catabase-a69fc03c/gut-strict-report.json`
Le JUnit précise notamment des attentes de catalogue de 46 sorts/12 objets
contre 84/22, deux apparences contre trois, des contrats de décors et formations,
des parcours de lancement/seuil, et un débordement de l’inventaire classique
de reliques. Aucun de ces tests n’est neutralisé ou ajouté à une liste d’exceptions.
Ce relevé ne prouve pas à lui seul que tous ces échecs préexistaient à la passe.

Suite ciblée Cartes consommables : **PASS, 201 tests, 20 702 assertions**,
sans diagnostic bloquant. Import propre.
`artifacts/dev/20260930-210045-test-consumable-v2-1698e346/gut-strict-report.json`

Le contrôle du niveau 4 confirme un accès séparé aux spécialisations, le verrou
de continuation avant choix et le retour à la répartition.
`artifacts/dev/20260930-210223-player-dossier-210e50ac/report.json`

Le dernier relevé ajoute la consultation des quatre aptitudes dans Détails et
une capture de cette partie défilante : **PASS, 38 captures**, processus terminés
sans diagnostic, à 1280×720 et 1600×900. La partie détaillée défilante a également
été inspectée visuellement à 720p, ainsi que le résumé à 900p.
`artifacts/dev/20260930-210529-player-dossier-2eb82372/report.json`

Formatage ciblé vérifié avec conservation de structure ; `git diff --check`
sans erreur. Les anciens grands scripts gardent des modifications localisées.
Les documents de conception ajoutés par d’autres travaux sont préservés.
