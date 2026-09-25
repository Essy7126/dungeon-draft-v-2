# Extension — classes, monstres et boss DOFUS / WAKFU

Étude du **25 septembre 2026**. Suite du [premier dossier d'identité des sorts](../README.md), préparée pour être reprise dans le dépôt sur un autre ordinateur.

## Ce qui a été ajouté

- **155 nouvelles fiches lues et analysées : 80 DOFUS, 75 WAKFU.** Cinq sorts/passifs pour chacune des 16 classes DOFUS et 15 classes WAKFU encore absentes. Toutes les classes des catalogues consultés sont désormais représentées dans l'ensemble des deux dossiers, avec une profondeur variable ; pas tous leurs sorts.
- **42 entrées de bestiaire**, dont **11 boss**, réparties en six rencontres DOFUS et cinq WAKFU. Étude des déclencheurs, de la géométrie, des auxiliaires, des fenêtres et des contradictions de version.
- Comparaison aux **cinq salles tactiques existantes** de Catabase et à leurs règles/IA ; quatre axes de classe et quatre prototypes ennemis proposés, non implémentés.
- **16 cas calculés, 32 assertions réussies**, avec hypothèses et résultats exportés. Aucun combat Ankama/Godot exécuté.

Avec le dossier précédent : **246 fiches de sorts/passifs**, soit 116 DOFUS et 130 WAKFU. Ce total mesure la lecture, pas une certification exhaustive des effets : certains états restent explicitement inconnus.

## Lire et reprendre

| Document | Usage |
|---|---|
| [Classes DOFUS](CLASSES_DOFUS.md) | Coûts, effets et boucles des seize classes supplémentaires. |
| [Classes WAKFU](CLASSES_WAKFU.md) | Quinze kits, arbitrages de passifs, descriptions recoupées et effets encore ambigus. |
| [Bestiaire DOFUS](BESTIAIRE_DOFUS.md) | Royalmouth, Ben, Tengu, Comte, Nileza, Vortex et auxiliaires sélectionnés. |
| [Bestiaire WAKFU](BESTIAIRE_WAKFU.md) | Bouftous, Steamers, Bworkana, Vandaliénés et Crocodailles. |
| [Application à Catabase](ANALYSE_POUR_CATABASE.md) | Existant relu, manques précis, prototypes, drop sur mobs et critères d'essai. |
| [Calculs et résultats](CALCULS.md) | Probabilités de main, coût d'accès, temporalité, attrition et cas spatiaux. |
| [Résultats détaillés](resultats_calcules.json) | Données des modèles et chronologies réutilisables. |
| [Sources et limites](SOURCES_ET_LIMITES.md) | À lire avant de réutiliser un chiffre ou une règle historique. |
| [Suivi de reprise](WORKLOG.md) | Base Git, fichiers, validations et travaux restant à faire. |

## Conclusions prioritaires

**Nos salles possèdent déjà des mécaniques pertinentes.** Il faut approfondir leurs interactions et leur coût en copies, en conservant leurs réponses accessibles par la position et les commandes de salle.

**Les monstres donnent leur valeur aux cartes.** Un soutien vivant, un compteur d'impacts, une zone mobile ou une mort différée peut inverser le classement de deux attaques ayant les mêmes dégâts totaux. Le test sur une cible isolée ne suffit pas.

**Les cartes consommables exigent des garanties supplémentaires.** Borner les soins/renforts sur tout le combat ; ne pas multiplier les droits au drop avec les résurrections ; fournir une solution indépendante d'une carte précise pour tout verrou obligatoire. Avec trois copies utiles dans trente cartes, une main de cinq ne trouve l'outil que dans **43,35 %** des cas du modèle uniforme.

**L'identité de classe vient des conversions et de leurs contreparties.** Construire puis exploiter ou sacrifier ; garder une réserve ou la dépenser ; changer le bénéficiaire ou le moment de résolution. Ces choix sont plus structurants qu'une augmentation uniforme de puissance avec la rareté.

## Vérifications reproductibles

```powershell
node docs/design/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/calculs.mjs
node docs/design/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/verifier_dossier.mjs
```

Ces fichiers existent localement dans le dépôt. Aucun commit ni push effectué ; ils ne sont pas encore automatiquement disponibles sur l'autre ordinateur.
