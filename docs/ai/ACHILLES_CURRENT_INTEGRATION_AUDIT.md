# Achille — audit d’intégration Odyssée

Date : 2026-08-23
Statut : **PRODUCTION_RUNTIME — ARTISTIC_POLISH_REQUIRED**

## Verdict

Achille V2 est le personnage de grille de la run solo L’Odyssée dans ses trois
salles. La chaîne de production charge son rig 3D, son pool de 24 animations,
ses quatre capacités et son interface dédiée. Le backend 2D historique reste un
mode dégradé paresseux réservé à une erreur 3D vérifiée ; il n’est ni instancié
ni visible pendant le parcours nominal.

## Présentation et dimensions

- Les trois profils peints enregistrent un profil Achille dédié.
- Les échelles finales sont 1,974 dans la forêt, puis 2,0 dans le volcan et
  l’espace, dans l’enveloppe visuelle déjà acceptée pour le trio.
- Le viewport reste en 384 × 384, avec une caméra orthographique à 2,6 afin de
  préserver les animations amples.
- Le billboard V2 est affiché à 125 px et le cadrage interne est décalé de
  0,35 m en hauteur.
- Les 20 clips Meshy sont vérifiés à 0 %, 50 % et 98 % : personnage visible et
  marge minimale de 16 px sur chacun des quatre bords. L’ancrage aux pieds est
  vérifié séparément sur la présentation de référence.

## Contrat de jeu vérifié

- Trois salles de production et un seul héros Achille.
- 110 PV, 14 initiative, 6 PA, 3 PM et 18 puissance, sans attaque de base.
- Frappe de lance, Percée, Balayage et Garde d’airain utilisent leurs vrais
  handlers de ciblage, leurs coûts/effets et quatre clips distincts.
- Un chemin de 1 à 5 cases sélectionne la marche ; 6 cases ou plus sélectionne
  la course rapide. Avec 3 PM de base, cette seconde branche exige un bonus.
- Percée conserve la grille comme autorité et resynchronise la vue avec sa case
  finale.
- Impact, mort par fondu, rechargement de la vue, initiative 3D, transitions et
  écran de résultat sont exercés par le smoke graphique.

## Validation automatisée

- Contrat de production : 4/4 tests, 351 assertions.
- Run solo Odyssée : 19/19 tests, 286 assertions.
- Présentation et cadrage : 5/5 tests, 198 assertions.
- Pool d’animations V2 : 8/8 tests, 151 assertions.
- Full-flow graphique Godot 4.7.1 : PASS, 3/3 salles, 4/4 sorts et 13 captures.

Le full-flow utilise les scènes, Resources et handlers de production. Il force
les changements de salle via l’état du gestionnaire après les validations de
combat ; il ne prétend donc pas remplacer un playtest humain complet.

## Limites conservées

- Le retarget structurel est exploitable mais les mains, appuis, coutures de
  boucle et futurs contacts d’arme demandent encore une passe artistique.
- La source Meshy ne contient pas de clip de mort ; le fondu reste le rendu de
  production.
- Le portrait du grand HUD reste l’illustration 2D historique, tandis que la
  timeline et le corps de grille utilisent la V2 3D.
- Percée se recale correctement mais sans interpolation visuelle entre les deux
  cases.
- Les diagnostics renderer/RID/ObjectDB émis à la fermeture de certains runners
  restent surveillés ; les contrôles fonctionnels terminent avec un code 0.
