# WAVEN — lecture du cœur du jeu

Demande du 26 septembre 2026 : approfondir les règles, cartes, héros, ennemis,
statistiques et progression, puis croiser historique développeurs et retours
de joueurs ayant pratiqué les builds. La demande privilégie WAVEN lui-même.

## État de travail

- HEAD de départ : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05` ; nombreuses
  modifications de sprites, sélection et VFX appartenant à d'autres travaux.
- Travail documentaire seulement. Ne pas confondre les simulations Catabase
  antérieures avec une validation du moteur WAVEN.
- Lecture directe des interfaces WavenDB et Waven Build : stats de héros,
  trente-deux options de passifs sur huit héros, distinction visuelle PvE/PvP. Certaines valeurs
  divergent entre bases ; dater et attribuer chaque valeur.
- WavenDB affiche une référence 0.17 ; Waven Build propose des liens 0.20,
  ce qui ne garantit pas que toutes ses fiches ont été mises à jour.
- Terminé : 15 sorts et coûts, cinq équipements, quatre compagnons ; curseur
  1/50 comparé avec talents et runes conservés. Reconstruction exacte des stats.
- Notes officielles 0.17, 0.19, 0.20, 0.23 et 0.23.5 lues dans le navigateur.
  Annonce Survie 2026 et réponses de Koko accessibles ; limite de l'ancien
  dossier levée pour ces textes. Témoignage d'essai du 11 juillet distingué
  des inquiétudes préalables à la démonstration.
- Pages complètes Collecteur/Piscine lues : sept ennemis étudiés. Leur version
  n'est pas garantie ; pas de fausses courbes PV/ATK par niveau.
- Dossier livré : `docs/design/waven_coeur_du_jeu_2026-09-26/README.md`,
  KITS_ET_COMBAT.md, ENNEMIS_ET_RENCONTRES.md, EVOLUTION_ET_JOUEURS.md,
  SOURCES.md, calculs.mjs et CALCULS.json.
- Vérification exécutée : 26 assertions et énumération indépendante des
  4 368 mains du modèle Survie. Aucune exécution du client WAVEN.
- Vérification documentaire : 16 liens locaux contrôlés dans cinq fichiers
  Markdown, aucun manquant. Sorties de calcul isolées par `.gdignore`.
- HEAD revérifié inchangé avant livraison ; modifications concurrentes
  sélection/sprites/VFX et suppression d'un autre dossier documentaire préservées.

## Décisions de méthode

- Utiliser les pages et infobulles réellement lues ; pas de valeurs déduites
  d'une image illisible ou d'une recherche mélangeant DOFUS/WAKFU/WAVEN.
- Les icônes crâne/épées expliquent plusieurs descriptions doublées :
  ne pas les traiter comme deux effets cumulables ni deux patchs successifs.
- Séparer règle lue, témoignage, hypothèse de calcul et observation runtime.
- Pas de délégation. Aucun code du jeu modifié.

## Limites et éventuelle suite

- Les coefficients choisis sont datés, notamment Pikuxala 60 % et Apostruker
  50 % en PvE 0.17 contre 45/35 dans un constructeur.
- L'armure à −41,67 % est un scénario à bonus additifs, pas un nerf global
  mesuré de Justelame. L'ordre des gains de Piven reste une hypothèse explicite.
- Pour aller plus loin : relevé dans le client, version/mode fixés, logs
  d'événements et statistiques ennemies par palier. Aucun prérequis d'accès
  au client n'a été inventé, aucun compte ou jeu installé.
