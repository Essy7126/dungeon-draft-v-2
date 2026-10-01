# Contre-audit de la séparation des statistiques

Audit demandé après l’intégration du 30 septembre 2026. Relecture des changements,
des règles appelées et des tests, puis reproduction native isolée. Aucun code
de production modifié pendant cet audit.

## P1 — La réorientation contourne la confirmation promise

`ui/expedition/consumable_progression_editor.gd:105-108`

Le panneau indique que les changements restent un aperçu jusqu’à confirmation,
mais le bouton Réorientation complète appelle directement la transaction réelle.
Au refuge de profondeur 11, niveau 8, un clic consomme l’usage unique, remet
maîtrises/aptitudes à zéro, efface la spécialisation et sauvegarde. Le bouton
Appliquer n’a jamais été pressé ; fermer ne rétablit rien.

Le comportement immédiat était déjà présent dans l’éditeur réutilisé. La nouvelle
présentation promet désormais une confirmation générale sans expliquer cette
exception. Les conséquences sur la spécialisation ne sont pas annoncées non plus.

Correction recommandée : confirmation dédiée indiquant les points rendus,
la spécialisation effacée et l’usage unique consommé. Distinguer cette transaction
de la validation du brouillon. Tester annulation et confirmation séparément.

## P2 — L’aperçu ne démontre pas l’intérêt de Contact et Distance

`ui/expedition/consumable_progression_editor.gd:209-214`

L’appel à `Math.component` ne transmet aucune distance. Le moteur applique
Contact à 1 case et Distance à 3 cases ou plus ; sans contexte, ces deux bonus
sont absents. Reproduction : un rang Contact (+6 %) puis un rang Distance (+6 %)
laissent chacun l’intégralité du texte d’aperçu inchangée.

Le texte « hors conditions de portée » évite une fausse promesse numérique,
mais l’écran ne remplit pas sa fonction de comparaison pour ces investissements.
Ce défaut préexistait à la nouvelle composition et n’a pas été traité.

Correction recommandée : aperçu contextualisé à 1 case / 3 cases ou plus, avec
distance annoncée ; ou comparaison explicite du bonus conditionnel. Ne pas
augmenter artificiellement tous les dégâts en permanence.

Autre limite de cette même prévisualisation : elle retient les quatre premières
familles possédées, selon l’ordre des copies, sans prioriser les cartes du deck
ni celles affectées par le changement. Un sort pertinent peut ne pas apparaître.

## Couverture et lecture visuelle

- La séparation Résumé / Détails / Répartition, les retours, les chiffres alignés
  et la confirmation fixe améliorent effectivement le parcours normal.
- Les tests de la passe précédente vérifient surtout une allocation élémentaire
  au niveau 2, les retours et les verrous. La présence des aptitudes est contrôlée,
  pas l’impact de leurs choix dans l’aperçu ; la réorientation n’est pas exercée.
- Le mode consultation du banc est simulé avec `inspection_only`, sans monter
  tout le HUD persistant. Il ne prouve donc pas tous les conflits de focus/modales
  de la vraie run. Aucun défaut d’Échap supplémentaire n’est établi ici.
- Une suspicion sur la sauvegarde a été écartée comme constat global : le HUD
  persistant possède bien un dialogue d’échec et une action Réessayer. Un banc
  qui le remplace par `null` ne permet pas d’affirmer que cette protection manque.
- Le tableau Détails perd ses en-têtes lorsque l’on descend très bas. C’est une
  amélioration ergonomique possible, pas un défaut bloquant démontré.

## Preuves nouvelles

Probe : `artifacts/dev/stats-audit-20260930/probe.gd` et `probe.tscn`.
Exécution : `artifacts/dev/20260930-211613-stats-adversarial-audit-68676576/`.
Processus terminé, code 0, aucun diagnostic moteur. Le code 0 signifie que
le scénario de reproduction est terminé, pas que les interfaces sont sans défaut.

`findings.json` confirme :

- `contact_preview_unchanged: true`
- `distance_preview_unchanged: true`
- `reset_immediate_without_apply: true`
- `reset_survives_close: true`
- `saved_reset_used: true`

Les trois captures ont été inspectées : choix Contact, avant réorientation,
après un unique clic de réorientation. Données de laboratoire isolées ; aucune
sauvegarde du joueur touchée. Les 201 tests verts et les 16 échecs de la suite
Catabase cités précédemment sont des résultats antérieurs, non réexécutés ici.

Conclusion : la séparation des usages est une amélioration, mais la promesse
d’aperçu/confirmation n’est pas cohérente sur tous les choix. Priorité à la
réorientation, puis à la pertinence de l’aperçu, avant une nouvelle passe décorative.


## Suite — refonte et vérification des corrections

La passe suivante corrige les deux constats ci-dessus. Ils décrivent l’état
antérieur ; ils ne doivent pas être présentés comme des défauts encore ouverts.

- Réorientation : fenêtre de confirmation distincte, points remboursés et perte
  de spécialisation annoncés, usage unique explicite. Le focus initial est sur
  « Garder ma répartition ». Annuler et Échap préservent le brouillon et l’état
  enregistré. Seule la confirmation appelle la transaction existante.
- Répartition : exemples tirés uniquement du deck préparé, familles dédoublonnées,
  versions améliorées conservées. Les effets dont la valeur change passent devant
  les autres. Les dégâts directs sont calculés à des distances autorisées par
  la carte : 1 case, 2 cases, puis un exemple à 3 cases ou plus si possible.
- Présentation : comparaisons compactes nom / effet / distance / avant-après,
  gains et pertes teintés, bonus d’aptitudes explicités même quand l’arrondi ne
  change aucun dégât. L’avertissement de dépassement explique le bouton désactivé.
- Les règles de combat et les montants de progression n’ont pas été modifiés
  par cette passe. Le nouvel aperçu appelle le calcul partagé.

Le premier contrôle natif a trouvé un défaut d’Échap dans la nouvelle fenêtre.
Il a été corrigé avec un traitement local à la fenêtre ; le contrôle suivant
passe aux deux résolutions. Le premier test de Contact utilisait le niveau 1 :
8,8 et 9,328 s’arrondissent tous deux à 9. La comparaison positive utilise
maintenant le niveau 8, et un test séparé conserve explicitement ce cas d’arrondi.

### Limites conservées dans le verdict

L’aperçu est un échantillon de quatre effets de base (dégâts et composante
principale de soin/garde/marque/dégâts périodiques), pas une simulation complète
contre une cible. Il exclut les défenses, les déclenchements conditionnels,
les dégâts dérivés de garde sacrifiée et les autres composantes secondaires.
La réserve n’est pas utilisée. Ces limites sont annoncées dans l’écran.
Les captures utilisent les vraies fenêtres mais une session de test isolée ;
elles ne valident pas l’équilibrage d’une run entière ni tous les empilements
du HUD persistant. Le tableau Détails n’a pas encore d’en-tête fixe au défilement.

La suite générale Catabase demeure non verte dans le relevé précédent
(16 échecs sur 852 tests, plus diagnostics de fermeture). Elle n’est pas
assimilée à la suite ciblée Cartes et aucun échec n’a été supprimé pour cette passe.

### Preuves finales

Contrôle natif final : **PASS**, 44 captures à 1280×720 et 1600×900,
six processus terminés avec code 0, sans diagnostic moteur.
`artifacts/dev/20260930-214840-player-dossier-ad3c8195/report.json`

Inspection visuelle effectuée sur le résumé à 720p, les comparaisons à 720p
et 900p, ainsi que la confirmation à 720p. Les commandes restent atteignables,
les comparaisons sont alignées et le texte de confirmation ne déborde pas.

Suite ciblée Cartes consommables : **PASS, 205 tests, 20 723 assertions**,
aucun échec ni diagnostic bloquant, import validé.
`artifacts/dev/20260930-214906-test-consumable-v2-0992fdcc/gut-strict-report.json`

Formatage ciblé avec vérification de structure et `git diff --check` : PASS.
Les modifications concurrentes de Passe-rive, du routage VFX, du moteur de
cartes et des documents de conception ont été préservées.

Verdict : P1 et P2 corrigés sur les scénarios reproduits. Aucun nouveau blocage
constaté dans ce périmètre. Les limites de couverture et le dernier état rouge
de la suite générale restent explicitement mentionnés ci-dessus.
