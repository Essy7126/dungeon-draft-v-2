# Décisions d’architecture

## DUNGEON_DRAFT_STUDIO_2_0 — contexte, autorités et transactions

- Date : 2026-08-06
- Branche observée : `main`
- HEAD observé : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`
- Statut : **WORKTREE_CANDIDATE — activation CURRENT différée**

Le Studio utilise une instance partagée de `StudioProjectContext` et un graphe
de références transversal. `RunData` reste l’autorité des salles ;
`CharacterProgressionProfile` devient l’autorité d’édition Skills. Les vues
`UnitData` run-aware sont des adaptateurs et ne peuvent pas être écrites.

Arena repose sur une working copy, une projection runtime non mutante et deux
couches de terrain : base canonique et surface temporaire. Le pipeline art est
grid-first ; le manifeste v2 vérifie fingerprint, résolution, crop, géométrie,
ancres et checksums avant un réimport sans recalibration.

Les transitions de contexte, sauvegardes de run/profil et rattachements de
production sont explicites, planifiés, récupérables, relus et vérifiés. Retirer
une salle ne supprime jamais sa Resource.

## RUN_CONTENT_ISOLATION_FOUNDATION — autorité de contenu par run

- Date : 2026-08-06
- Branche vérifiée : `main`
- HEAD vérifié : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`
- Statut : **ADOPTÉE — COMPLETE WITH WARNINGS**

Chaque `RunData` choisit explicitement son contenu héroïque et son profil de
progression par la chaîne unique `RunData -> RunContentProfile -> RunHeroProfile
-> CharacterProgressionProfile`.

Les `UnitData` de base et assets visuels immuables peuvent être partagés. Les
`Spell`, disciplines, rangs, nœuds, `SpellModifier` et Resources mutables
atteignables ne sont jamais partagés involontairement entre la run principale
et la run de test. Une whitelist de types rend tout autre partage invalide.

Le chemin normal du hub ne fournit plus une autorité globale de héros : il
transmet la `RunData`, puis `GameManager.start_run()` appelle
`RunHeroResolver`. Les deux APIs d’injection explicite sont conservées et
prioritaires. Les anciennes `RunData` sans profil gardent un fallback averti et
temporaire.

Le cloneur métier multipasse et l’audit d’isolation constituent la seule voie de
création d’une progression spécifique à une run pour les futurs Studios.

## RUN_FLOW_ISOLATION_V1 — déroulement des salles

- Date : 2026-08-06
- Branche vérifiée : `main`
- HEAD vérifié : `94fcdc700cf576a15ee4134d9f3dee680626827a`
- Statut : **ADOPTÉE DANS LE DIFF LOCAL — activation CURRENT différée**
- Motif du statut : validations ciblées et runtime réussies, mais suite complète non verte sur des échecs hors périmètre déjà présents dans la baseline.

La run principale utilise un déroulement `SINGLE_ENCOUNTER` : une salle correspond
à une rencontre complète. Le système `WAVE_CHAIN` est réservé aux runs de test.
Une `RoomData` ne peut pas être partagée entre une run `SINGLE_ENCOUNTER` et une
run `WAVE_CHAIN`. Le mode de déroulement est une donnée explicite et sérialisée de
`RunData` ; il ne peut pas être déduit du nom ou du chemin de la run, du type de
build ou d’un état global de debug.

Cette décision remplace, pour la principale actuelle, l’hypothèse historique de
trois à dix vagues par salle. Elle ne supprime ni `RoomWaveData`, ni le moteur de
vagues, ni la run de test.
