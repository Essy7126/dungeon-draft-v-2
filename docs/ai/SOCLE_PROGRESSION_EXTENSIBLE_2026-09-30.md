# Socle de progression extensible — premier lot

Demande : commencer la précision du socle en considérant Pâris comme un acte
possible d'une run plus grande.

- HEAD de départ : `a3b0c7dc4c6841c722e5db3d90c6151696dec7b9`.
- Travail concurrent conservé : statistiques/dossier UI, capture, documentation
  courante et dossiers de recherche précédents. Ne pas reformater ces fichiers.
- Périmètre : contrat de progression validé à partir du manifeste existant,
  calculs de niveau et budgets communs, identité de profil sauvegardée,
  compatibilité v1/legacy et banc de profil prolongé.
- Les nombres jouables de l'acte Pâris restent inchangés ; aucune route d'acte
  II ni nouvelle courbe d'équilibrage n'est publiée dans ce lot.
- Les limites de route et les contrats de sources/statuts restent des lots
  suivants ; leur suppression arbitraire n'ouvrirait pas une run valide.
- Vérifications : référence Cartes avant changements, tests de profil et
  suite Cartes après, import/global/contrats CI concernés et harnais Battle.

État : premier lot implémenté et contrôles terminés ; CI du dépôt encore rouge.

- Source : `rules.prototypeProgression` du manifeste ; nouveau contrat pur
  `core/expedition/consumable_progression_profile.gd` et façade v1 compatible.
- Raccordements : Math, adaptation Champion, State, allocation Integration,
  validation Catalogue, niveau des bilans Checkpoint.
- Sauvegarde : `progression_profile_id` ; absence ancienne rattachée à une
  identité Pâris figée ; refus atomique des profils inconnus.
- Fixture 18 niveaux : XP Champion réelle, budgets, calculs injectés, isolation
  des vues et anciennes sauvegardes ; aucune activation d'une campagne future.
- Contrat et suite : `docs/current/progression_profiles.md` ; lien dans v1.
- Référence avant : `artifacts/dev/20260930-214118-test-consumable-v2-72740b21/`,
  204 tests, échec de prévisualisation ajouté dans le travail UI concurrent.
- Profil ciblé : `artifacts/dev/20260930-220627-test-test_unit_test_consumable_cards_progression_profile.gd-c0e4722c/`,
  PASS, 9 tests / 163 assertions.
- Cartes : `artifacts/dev/20260930-221023-test-cards-97d1a990/`, PASS,
  372 tests / 34 814 assertions. Après ce passage : durcissement du type de
  schemaVersion et cinq assertions supplémentaires, à vérifier par le global.
- Audit contenu : `artifacts/dev/20260930-socle-progression-ci/`, 7 tests Python
  passants ; références sérialisées vérifiées, aucune cible absente. Premier
  lancement corrigé pour la configuration Git safe.directory du sandbox.
- Formateur limité aux deux nouveaux scripts et à la façade v1 ; pas de
  reformatage des interfaces ou des changements concurrents.

- Global : `artifacts/dev/20260930-222132-test-all-9f0b8f24/`, 3 418 tests /
  306 266 assertions, 165 tests en échec et sortie Godot `-1073741819`.
  Les 165 identités échouées correspondent exactement au rapport global du
  29 septembre (HEAD antérieur, pas une nouvelle référence avant ce lot).
  Le profil ciblé y termine ses neuf tests sans échec après le durcissement.
  Comparaison : `20260930-socle-progression-ci/global-comparison.json`.
  Allowlist exacte rejetée : 165 observés / 8 attendus, sortie anormale et
  entrées attendues manquantes ; aucun élargissement de la liste.
- Studio : `artifacts/dev/20260930-225939-test-studio-291d3134/`, 522 tests /
  17 552 assertions, 28 échecs, tous présents dans ce même rapport antérieur.
  Les diagnostics portent notamment sur les contrats de sauvegarde et de
  récupération des éditeurs, non modifiés dans ce lot.
- Battle Thaumaturge : `artifacts/dev/20260930-232249-prototype-v1-passe-rive-f1e9248c/`,
  PASS, 6 scénarios / 1 728 cas numériques / aucun diagnostic.
  Ces fixtures ne sont pas une mesure du taux de victoire ou de l'équilibrage.
- Portabilité CI : 17 chemins locaux existants dans
  `vfx/class_cards/cel/art/provenance.json`, fichier non modifié ; gate rouge.
- Mesures : `20260930-socle-progression-ci/mesures.json`, 169 911 répartitions
  élémentaires complètes × 20 aptitudes = 3 398 220 couples théoriques, pas
  autant de builds mesurés. XP réellement distribuée 2 440 ; boss sans XP
  selon le contrôleur actuel ; 140 XP au-delà du seuil 12. Ne pas confondre
  avec les 2 785 de toutes les entrées déclarées (345 finales non versées).
- Empreintes des onze sources/test/UID propres au lot conservées dans
  `20260930-socle-progression-ci/source-fingerprints.json` après le global.

- Profil final isolé : `artifacts/dev/20260930-233451-test-test_unit_test_consumable_cards_progression_profile.gd-2b5831e3/`,
  PASS, 9 tests / 168 assertions / aucun diagnostic / sortie 0.
- CI smokes : `artifacts/dev/20260930-232636-progression-ci-smokes-9ce7b4e6/`.
  Filtre d'import exact de CI passé, aucune erreur de script ; le contrôle
  strict signale néanmoins Spine DLL et fuites de ressources à la fermeture.
  Rencontre : scénario `ok: true`, canonique intact et sortie 0, mais fuite
  d'une ressource. Objets : cast Dictionary invalide dans `_remember_ui_state`
  du Studio existant, sortie 1. Terrain headless : renderer sans image, sortie 1.
- Terrain avec OpenGL : `artifacts/dev/20260930-233251-progression-terrain-gl-c7bc4de3/`,
  cinq PNG 1280×720 archivés et sortie 0 ; diagnostics de fuite à la fermeture,
  donc pas de verdict strict vert ni de certification visuelle générale.
- GUT a changé deux timestamps d'artifacts suivis dans
  `artifacts/arena_studio/arena_studio_test/` via `test_arena_studio_v1`.
  Sorties générées copiées dans la preuve dev avant restitution des seuls
  timestamps initiaux. La gate d'absence de mutation reste échouée.
- Onze empreintes propres au lot inchangées après global, Studio, Battle et
  smokes ; `20260930-socle-progression-ci/final-checks.json` et
  `final-source-check.json`. Diff sans erreur d'espacement. Changements
  concurrents UI et Pâsse-Rive conservés ; aucun commit ni modification CI.

Prochain lot : registre des profils et contrat campagne/actes, identifiants des
reçus, fin de Pâris et bilan intermédiaire, raccordements des gardes de poursuite
et des plafonds/libellés UI. Puis sources d'effets, stocks et budgets de contenu.
Relire Git avant reprise. Les anciens rapports mathématiques ne sont pas des
preuves fraîches après modification des sources.
