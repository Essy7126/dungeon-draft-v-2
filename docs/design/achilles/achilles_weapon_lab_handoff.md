# Achilles — handoff vers un futur laboratoire d'arme

## Statut figé

La Gate A issue de `ACHILLES_3D_SWORD_ODYSSEY_FULL_INTEGRATION_V1` est archivée comme candidat historique, pas comme décision d'équipement.

`HISTORICAL_WEAPON_GATE_A_CANDIDATE`
`VALID_INPUT_FOR_FUTURE_WEAPON_LAB`
`NOT_RUNTIME_SELECTED`
`NOT_CURRENT`
`NOT_PRODUCTION`

Le checkpoint observé correspond à la branche `integration/achilles-3d-sword-odyssey-v1`, HEAD `924a9799d70e0aa2230a1e97bf705ee0d7fd17d9`. Il reste en lecture seule et ne doit pas être consommé par le run personnage seul.

## Ce que la Gate A fournit

- trois propositions historiques : A `COMPACT`, B `REFERENCE`, C `HEROIC` ;
- des captures statiques sous un contrat de caméra commun ;
- des transformations candidates distinctes ;
- un inventaire de limites et des preuves de provenance.

Ces trois propositions restent des entrées de comparaison possibles pour un futur laboratoire. Aucune n'est sélectionnée : `selected_variant = null`.

## Ce que la Gate A ne prouve pas

- La fermeture des doigts était `STUDIO_ONLY_STATIC_FINGER_OVERLAY_NOT_SOURCE_ACTION`.
- Le contact main/poignée pendant le mouvement n'a pas été validé.
- La persistance du contact sur les quatre Actions et les directions n'a pas été validée.
- Aucune attache runtime, animation sémantique, salle Odyssey, transition ou performance n'a été validée avec une arme.
- L'option D historique signifiait « aucune variante », pas une approbation tacite.

## Contrat du futur laboratoire

Un futur laboratoire d'arme devra :

1. importer les preuves historiques comme données de comparaison isolées ;
2. maintenir A, B et C sans favori automatique ;
3. obtenir un choix humain explicite ou enregistrer un rejet ;
4. revalider l'échelle, le pivot, la garde, le contact et les occlusions sur les animations et directions réellement retenues ;
5. produire un profil runtime distinct seulement après décision ;
6. prouver que l'intégration n'altère ni gameplay ni source canonique personnage.

La mission actuelle ne commence pas cette étape. Son runtime doit fonctionner avec `equipment_enabled = false` et `weapon_profile = null`, sans charger ou rechercher une ressource d'arme.

## Preuves de handoff

Le dossier d'artifact `01_gate_a_handoff/` contient le manifeste du checkpoint, la classification exhaustive des 44 fichiers historiques et le handoff différé. Ces documents peuvent nommer la preuve historique ; les scènes, tests et outils runtime de cette mission ne le peuvent pas.
