# Préparation de la refonte Cartes V2

Demande : préparer toute la refonte pour une mise en place au tour suivant.
Ce travail ferme un contrat de conception et d'intégration ; il ne bascule pas
le jeu public et ne présente pas les calculs comme un playtest.

- Base Git : c6ab5a72c1789e4cc285300c9bbae9c78524fa05.
- Travaux locaux de sélection, Passe-rive s19–s22, VFX et documentation conservés.
- Pas de délégation. Catalogue V1 et enquêtes antérieures conservés comme références.
- Livrable : docs/design/cartes_refonte_v2_2026-09-26/.
- Livré : README, REGLES, CATALOGUE, CONTENU_ET_RENCONTRES,
  PARCOURS_JOUEUR, INTEGRATION ; manifeste complet 2.0.0-design.1,
  générateur, vérificateur et empreintes des sources V1.
- Points déjà vérifiés : Godot utilise une défausse et une sauvegarde de frontière ;
  ClassCards révision 3 et ecosystem_revision 2 ne sont pas une version libre
  pour y injecter les nouveaux contrats. Le terrain a déjà un résolveur partagé.
- Vérifications exécutées : 49 contrôles de cohérence, 21 liens locaux,
  3 876 mains énumérées pour l'ouverture préparée, conversions de garde,
  budget d'or, coût ciblé, PV du boss et réservoir indépendant du héros.
- Première exécution du vérificateur corrigée : il vérifiait son propre fichier
  de sortie avant création. Seule la dernière exécution complète vaut succès.
- Aucune simulation complète V2, aucun test Godot ni playtest humain revendiqué.

## Décisions principales

- 48 familles, 23 retouchées ; aucun changement de rareté ni dilution du pool.
- 15 copies initiales, remplissage à 5, 4 PA/3 PM, normale d'ouverture.
- Passif de classe + spécialisation, compteurs distincts, huit spécialisations.
- Relais de marque spécialisé ; Ancre remplace le PM de classe ; Répercussion
  à sacrifice choisi ; eau normale et réactions branchées sur le terrain commun.
- Un Standard V2 initial ; aucun multiplicateur de difficulté historique hérité.
- Nouveau fichier de sauvegarde, checkpoint par action ; anciennes runs conservées.
- L0 à L5 définis dans INTEGRATION.md. Prochaine étape : L0 profil/données puis
  L1 consommation/checkpoint, sans publier de fonctionnalités encore inopérantes.

## Suite et limites

- Préparation achevée ; coefficients candidats à calibrer après implémentation.
- Ne pas lancer le résolveur V1 avec le manifeste V2 : nouveaux effets et
  sémantiques, explicitement incompatibles. Les anciens taux de victoire restent V1.
- Les contrôles requis du moteur commun et la réception humaine sont décrits
  pour la mise en place ; aucune bascule du produit n'est réalisée dans ce tour.
