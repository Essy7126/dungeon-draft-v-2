# Lecture comparée des sorts et des ennemis

25 septembre 2026 — Dungeon Draft, référence Git `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.

**Le problème principal n'est pas un manque de sorts. Nous avons beaucoup d'outils, mais plusieurs classes les utilisent selon des règles trop proches. Les références les plus instructives donnent une fonction nouvelle à une ressource, à une position ou à une action ordinaire.** Notre bestiaire et notre moteur de terrain contiennent déjà une partie de cette richesse ; la proposition consommable V1 ne la représente pas entièrement.

Ce dossier compare les contrats de sorts, leurs enchaînements et les réponses adverses. Il distingue systématiquement le jeu Godot actuel de la proposition indépendante `consumable_v1`. Aucune règle du jeu n'a été modifiée.

## Parcours de lecture

1. [Lectures comparées, jeu par jeu](LECTURES_COMPAREES.md) : DOFUS, WAVEN, Baldur's Gate 3, Divinity: Original Sin 2 Definitive Edition, Slay the Spire 1 ; sorts de personnages et capacités ennemies.
2. [Audit et propositions prioritaires](AUDIT_ET_PRIORITES.md) : écarts concrets, redondances, calculs, huit pistes avec limites et critères d'essai.
3. [Inventaire local complet](INVENTAIRE_LOCAL.md) : les **112 définitions de cartes des catalogues actuels**, puis les **48 familles de la V1**. Les lignes historiques de compatibilité `s_*` sont exclues.
4. [Sources et limites de vérification](SOURCES.md) : dates, versions, statut des annonces et lacunes documentaires.
5. [Fiche de reprise](WORKLOG.md) : fichiers, vérifications réellement exécutées, prochaines étapes.

## Conclusions à retenir

- **Identité des classes :** neuf familles d'effets normalisées apparaissent dans les quatre classes actuelles. Ce partage n'est pas un défaut en soi ; les passifs et spécialités actuels différencient surtout les circonstances d'un bonus numérique. Les déplacements de Pikuxala ou les bombes du Roublard montrent comment changer la manière de planifier un tour.
- **Progression V1 :** 33 améliorations sur 48 n'augmentent que les dégâts directs. Des choix de cible, de maintien, de conversion ou de trajectoire offriraient une progression plus variée. Les améliorations Godot actuelles ont déjà des changements de portée, de franchissement et de durée : ne pas les confondre avec celles de la V1.
- **Un résultat chiffré :** à Prouesse 40, sans bonus ni résistance, Garde ferme → Heurt du rempart produit **60 dégâts et conserve 46 de garde**. Garde ferme → Répercussion produit **47,6 dégâts et supprime la garde**, pour les mêmes 4 PA et deux copies. La portée supérieure de Répercussion empêche d'en déduire une domination dans toutes les situations ; son rôle rare reste à renforcer.
- **Bestiaire :** Conducteur + Molosses, Collecteur + Porteurs, Fournaise préparée et Appel du passeur sont des bases à préserver. La V1 simplifiée ne permet pas de mesurer correctement leur valeur tactique.
- **Cartes consommables :** emprunter les conversions et les décisions de Slay the Spire, mais recalculer leur prix en copies perdues dans la run. Son épuisement temporaire au combat ne correspond pas à notre consommation définitive.
- **Préparation du deck :** avec trois copies de chacun de deux outils nécessaires, leur présence simultanée en main initiale de cinq cartes passe de **51,45 % avec 15 cartes à 16,53 % avec 30**. Le plafond de 30 ne doit pas devenir une taille obligatoire ; les moteurs de classe doivent rester praticables sans une main parfaite.

## Ce que cette étude permet, et ce qu'elle ne prouve pas

Lecture exhaustive des trois catalogues locaux de cartes ciblés, lecture des fabriques et des principaux kits ennemis concernés ; sélection approfondie de mécanismes externes. Ce n'est pas l'inventaire de tous les sorts de cinq jeux, ni une mesure de leur popularité.

L'inventaire local porte sur la variante Cartes et la V1 proposée. Les techniques propres à la variante Classique et les anciens laboratoires ne sont pas recensés exhaustivement ; les manques décrits concernent les kits étudiés.

Les références DOFUS incluent des versions historiques explicitement datées. Pour WAVEN, les kits de héros sont détaillés, mais les sources accessibles sur les ennemis donnent surtout des corrections partielles : leurs coûts et contrats complets ne sont pas présentés comme vérifiés. Les annonces de refonte ne sont pas assimilées à une version livrée.

Les comptages et huit séquences locales ont été exécutés. Les probabilités de main ont été contrôlées par énumération exhaustive. **Aucun test Godot, aucune session de jeu et aucun test joueur n'a été effectué pour ce dossier.** Les propositions sont à prototyper, pas des réglages validés.
