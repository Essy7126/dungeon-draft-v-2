# Enquête gameplay approfondie — suivi

Demande : reprendre l'audit trop superficiel avec étude des sorts, chiffres, mécaniques, expériences des joueurs, intentions des développeurs et changements de versions. Aucun changement de gameplay demandé.

Base : ad1f4c58 ; arbre partagé modifié par un travail sur les salles. Ne pas modifier ces fichiers. Le premier rapport constitue une hypothèse à réexaminer, pas la conclusion de cette enquête.

Livrables prévus : dossier de sources vérifiables ; fiches détaillées par système et historique de changements ; inventaire quantifié du gameplay actuel ; confrontation et recommandations argumentées avec limites.

Couverture : deckbuilders (Slay the Spire 1/2 séparés, Monster Train 1/2 séparés, Balatro, Wildfrost, Fights in Tight Spaces) ; tactiques (Dofus, Wakfu, Waven, BG3, DOS2, Into the Breach). Étudier particulièrement placement, tempo, combinaisons, identité, contre-jeu et progression.

Méthode : ouvrir les sources importantes, croiser mécanique / explication développeur / retours contradictoires. Ne pas présenter comme regardée une vidéo dont seule la description a été lue. Distinguer jeu disponible, refonte annoncée et version historique. Ne pas convertir des témoignages auto-sélectionnés en statistiques de population.

État au 23 septembre : dossiers détaillés et synthèse rédigés dans les quatre fichiers `enquete_gameplay_2026-09-23*.md` hors cette fiche. Environ 10 700 mots dans les trois dossiers détaillés, 59 URL distinctes. Lecture ciblée des règles dégâts/états, deck, XP, classes, équipement, butin, adversaires et salles accomplie. Les sources non accessibles et les incertitudes de versions sont explicites.

Export exécuté : `artifacts/dev/20260923-135932-enquete-catalogue-corrige-8cb2b8cd/` : 112 cartes, 29 effets, 7 200 tirages indépendants. Code de sortie 0, erreur système de certificats conservée dans les journaux ; pas de validation moteur sans erreur. Première invocation expirée et non comptée. Aucune campagne de combats ou tests utilisateurs effectuée.

Conclusions : développer des moteurs plutôt que le nombre de frappes ; première expression tôt ; clarifier les états de mobilité ; rendre explicite la consommation du premier passif ; traiter acquisition et plafond étranger comme contraintes de construction. Les systèmes disque/braise/urne du Classique sont des points d'appui. Le projet Waven annoncé en 2025 n'est pas confondu avec le guide d'équipement 2026 ; l'AMA Larian 2026 critique le verrou d'armure magique de DOS2.

Suite après cette livraison : les prototypes et essais proposés sont des recommandations, pas des implémentations autorisées implicitement par cet audit. Aucun fichier de gameplay modifié. Arbre partagé encore modifié sur les salles ; le contexte exact de l'export est conservé dans `context.json`.
