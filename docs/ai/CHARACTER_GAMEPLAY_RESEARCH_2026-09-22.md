# Recherche : création et profondeur du personnage

22 septembre 2026. Demande : recherche approfondie sur la création de personnage
comme choix de gameplay, confrontée à Catabase Cartes. Pas une nouvelle commande
d'implémentation. Base lue : `b6973d6d`, arbre propre au départ.

- Lecture du produit, catalogue, passifs/spécialisations, progression, audits des
  20–21 septembre et salles tactiques récemment intégrées.
- Corpus : BG3, DOFUS, WAKFU, Divinity Original Sin 2, Gloomhaven, Slay the Spire,
  Monster Train, Hades, Last Epoch, Grim Dawn et Griftlands. Sources de studios,
  conférence du concepteur et reproductions identifiées de devblogs Ankama.
- Décision de conception : identité mécanique disponible dès le départ ;
  doctrines qui changent une règle ; cartes et drops qui transforment cette
  identité ; groupes ennemis qui contestent les mêmes ressources.
- Contrainte : aucune fondation sur l'annonce de la prochaine attaque ennemie.
- Livrable : `docs/design/character_creation_gameplay_research_2026-09-22.md`.
- Vérification : confrontation aux sources et au code ; contrôle des liens
  locaux et diff documentaire. Aucun nouveau test de run dans cette recherche.
- Contrôle final : dossier d'environ 6 900 mots, 31 liens, aucune cible locale
  manquante ; inventaire JSON confirmé à 112 familles publiques. Seuls les deux
  nouveaux documents de cette recherche apparaissent dans le statut Git.
- Suite proposée dans le dossier : prototype Gardien, deux doctrines, deux
  groupes ennemis et trois terrains ; seuils de décision avant généralisation.

Les mesures de septembre 20–21 sont des preuves historiques explicitement
datées. Les salles convoi/réservoir sont présentes dans le code courant ; ne pas
reprendre le diagnostic antérieur comme si ces systèmes n'existaient pas.
