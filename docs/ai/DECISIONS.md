# Décisions d’architecture

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
