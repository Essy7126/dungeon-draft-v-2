# Sources, versions et limites

Recherche du 26 septembre 2026. Base locale `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, avec modifications locales en cours. Les sources V1 sont identifiées par SHA-256 dans [EXPERIENCES.json](EXPERIENCES.json).

## WAVEN : publications de l'équipe

| Référence | Date | Accès et portée |
|---|---|---|
| [AnkamaLive : WAVEN en 2025, résumé](https://steamcommunity.com/games/2343650/announcements/detail/548983985537024963) | 16 avril 2025 | Texte officiel lu dans le [flux Steam français](https://steamcommunity.com/app/2343650/announcements/?l=french), section du même titre. Diagnostic et intentions de refonte, pas preuve de livraison. |
| [Community Update #2](https://steamcommunity.com/games/2343650/announcements/detail/535482620603007529) | 5 août 2025 | Corps lu dans le même flux officiel. La page individuelle ne fournissait que l'enveloppe Steam au lecteur. Cette note révise plusieurs intentions d'avril. |
| [Version 0.13.1, publication Ankama sur Steam](https://steamcommunity.com/games/2343650/announcements/detail/3824179810347938047) | 15 novembre 2023 | Texte de patch de l'équipe, retrouvé dans sa [reproduction SteamDB](https://steamdb.info/patchnotes/12707588/), qui donne ce lien d'origine. Le corps de la page d'origine n'a pas pu être relu directement. Cas historiques, jamais présentés comme la balance 2026. |

Les notes de patch sont utilisées comme témoignage primaire de l'équipe, avec leur mode d'accès indiqué. Aucun guide communautaire n'est traité comme une spécification actuelle du moteur.

## Actualité 2026 : frontière de vérification

Le [sujet officiel consacré à l'Ankama Convention](https://forum.waven-game.com/en/41-news/6784-ankama-25th-anniversary-convention-waven) a été retrouvé, mais son contenu est bloqué par une vérification JavaScript. Aucun contournement effectué. Le programme de [Japan Expo](https://paris.japan-expo.com/fr/ankama-convention) ne fournit pas les règles de combat nécessaires à cette étude.

Des comptes rendus communautaires de juillet 2026 signalent une démonstration du mode Survie ; ils servent de pistes de recherche, pas de preuve technique de ses règles. Le rapport ne certifie donc **ni le déploiement actuel de la refonte, ni les règles détaillées de la démonstration 2026**. Les annonces de 2025 restent nommées et datées comme telles. Une requête complémentaire à l'API publique Steam a échoué au niveau de l'authentification TLS ; aucune donnée issue de cette tentative n'est utilisée.

Les guides consultés en recherche présentent aussi des valeurs incompatibles pour certaines interactions d'armure de Justelame. Sans version et niveau comparables ni source primaire accessible, aucun de ces coefficients n'alimente les calculs. Les modèles d'armure du rapport sont des scénarios Catabase explicitement hypothétiques.

## Sources locales relues

- [Produit courant](../../current/product.md) et [README du projet](../../../README.md) : parcours public et travaux de sélection.
- [Cartes actuelles](../../../core/expedition/catabase_cards.gd), [modificateur de classe](../../../core/expedition/class_card_modifier.gd), [ressources de salle](../../../core/expedition/card_tactical_resource_rules.gd) : comportement des sources Godot.
- [Règles V1 proposées](../consumable_v1/REGLES_V1.md), [contenu](../consumable_v1/content.mjs), [combat](../consumable_v1/combat.mjs), [runs et bot](../consumable_v1/run.mjs), [marchand](../consumable_v1/market.mjs) : expérience indépendante du runtime.
- [Audit précédent](../gameplay_critique_2026-09-25/README.md), [comparaison des sorts](../spell_comparison_2026-09-25/AUDIT_ET_PRIORITES.md), [transposition de Slay the Spire](../slay_the_spire_complete_2026-09-25/APPLICATION_CATABASE.md), [identité Dofus/Wakfu](../dofus_wakfu_spell_identity_2026-09-25/IDENTITE_ET_EQUILIBRAGE.md) : propositions à critiquer ; leurs résultats antérieurs ne sont pas recomptés comme nouvelles expériences.

Le statut des personnages est donné par `docs/current/content.md`. Aucune conclusion d'inutilité n'est tirée de leur absence du menu. Les changements de sélection et de sprites d'autres tâches sont préservés.
