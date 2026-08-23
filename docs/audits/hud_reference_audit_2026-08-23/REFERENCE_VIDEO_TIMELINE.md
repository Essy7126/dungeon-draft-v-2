# Chronologie de la vidéo de référence

## Statut et authenticité

La vidéo est **vérifiée et analysée**. Les observations ci-dessous proviennent du fichier source, de deux planches contact, de trois bandes d'analyse et de 79 images extraites. Les noms de fichiers des images ne constituent pas une interprétation : l'index des keyframes fait foi.

| Champ | Valeur vérifiée |
|---|---|
| Fichier | `20260823-1411-38.3121186.mp4` |
| Taille | 392 829 854 octets |
| SHA-256 | `A1B7C49F618A04FF6795CC1076FF9D8E400FC9FBAF9544E447B31F9C21FA30B3` |
| Durée | 181,291 s |
| Vidéo | H.264 Main, 2560×1592, 30 fps, 5 435 images |
| Audio | AAC LC stéréo, 48 kHz, présent et non silencieux |
| Analyse | FFmpeg/ffprobe 9.0.1 portable, sans installation système |

L'audio a une moyenne d'environ -33 dB et un maximum de -13,1 dB. Son contenu sémantique n'a pas été transcrit; l'analyse UX repose sur l'image et ne prétend donc rien sur les annonces sonores.

## Chronologie vérifiée

| Intervalle | Écran / état observé | Grammaire d'interaction | Lecture pour Dungeon Draft |
|---|---|---|---|
| 00:00–00:05.933 | Début de tour joueur; bannière cyan « À VOTRE TOUR », HUD périphérique stable | le tour est annoncé par texte, couleur et disponibilité des commandes | ADOPT : ownership redondant et immédiat |
| 00:05.933–00:13.9 | Résolution d'une action et VFX | sélection → action → impact → retour au repos | ADAPT : formaliser la chorégraphie sans copier la carte |
| 00:14–00:23.9 | Tour adverse; bannière magenta, actions grisées | le contrôle retiré au joueur est explicite; aucune intention ennemie future n'est montrée | ADOPT la clarté; ALREADY_PRESENT l'absence d'intention future |
| 00:24–00:29.9 | Retour joueur, survol, focus de cible, action sélectionnée | plateau assombri, unités/cases pertinentes éclairées, PV/attaque contextuels, tooltip bas | ADOPT le focus; ADAPT aux capacités fixes de Dungeon Draft |
| 00:30–00:50 | Enchaînement ciblage, multi-cible, projectile et impact | la scène centrale reste dégagée; le HUD secondaire s'efface pendant le geste | ADAPT : hiérarchie dynamique et lock unifié |
| 00:50–01:02 | Transition puis action adverse | changement d'ownership lisible sans dévoiler la future cible | ALREADY_PRESENT côté règle; présentation à renforcer |
| 01:02–01:30 | Alternance mouvement, survols, zones et impacts | les états hover, selected et resolving sont visuellement distincts | ADAPT : même séparation d'états, autre vocabulaire visuel |
| 01:30–01:54 | Actions successives; à 01:54 avertissement de fin de tour | modal « tous les personnages n'ont pas joué » avec Oui/Non et option de mémorisation | ADOPT le principe d'erreur évitée; ADAPT au système de tour DD |
| 01:55–02:23 | Dernières alternances de combat | même boucle ownership → focus → résolution → impact | ADAPT : un orchestrateur de présentation est justifié |
| 02:23–02:25.3 | Ennemi à 3 PV, impact final `-3`, transition victoire | l'issue naît du dernier impact avant le changement d'écran | ADOPT : causalité et victoire locale lisibles |
| 02:25.3–02:27.9 | Écran victoire initial | rupture nette avec le combat, personnage et progression conservés | ADAPT au post-combat existant |
| 02:28–02:31.7 | Plein écran niveau 4; quatre choix; tooltip au survol | choix de progression isolé avant les récompenses | ADAPT : séparer décision et récapitulatif lorsque pertinent |
| 02:31.8–02:36.1 | Retour victoire; XP, monnaies, objet, Continuer | récompenses révélées avant sortie | ALREADY_PRESENT + ADAPT : conserver le flow DD, renforcer la mise en scène |
| 02:36.1–02:37.9 | Transition hexagonale | le changement de contexte est masqué par une transition dédiée | ADAPT, sans reprendre l'habillage |
| 02:38–02:44.2 | Retour monde | continuité run → monde visible | ALREADY_PRESENT dans GameManager |
| 02:44.2–02:47.5 | Overlay « BOUTIQUE DÉBLOQUÉE » | déblocage contextuel avant accès | ADAPT pour les déblocages de Dungeon Draft |
| 02:47.5–02:51.1 | Boutique / tutoriel / offres | écran méta distinct du combat | REJECT pour monétisation et économie additionnelle |
| 02:51.2–02:52.9 | Monde avec toast de progression | confirmation courte après fermeture | ADAPT : accusé de réception contextuel |
| 02:52.9–02:57.8 | Équipement/build plein écran | personnage, emplacements, compagnons, sorts, recherche/collection | ALREADY_PRESENT fonctionnellement; ne pas copier l'organisation 1:1 |
| 02:57.9–03:00.0 | Personnalisation puis retour monde | onglets cosmétiques, familier, skins | REJECT comme priorité de reconstruction HUD |

## OBSERVÉ DANS LA VIDÉO

- Le centre du plateau reste la zone de lecture primaire; portraits, ownership et actions vivent en périphérie.
- Le joueur distingue le tour joueur du tour adverse par une bannière textuelle, une couleur et l'état des commandes.
- Le ciblage concentre l'attention : la scène est assombrie, les cibles utiles sont éclairées et les statistiques courantes apparaissent au besoin.
- Une action sélectionnée est soulevée, puis cède la place au VFX, au nombre d'impact et au retour au repos.
- Aucun aperçu de future cible, case ou intention ennemie n'est visible.
- La victoire forme une chaîne complète : dernier impact → transition → victoire → choix de niveau → récompenses → monde → déblocage → écrans méta.

## INFÉRÉ SUR SON ARCHITECTURE

La cohérence de cette chorégraphie suggère un orchestrateur de présentation ou une machine d'états UI qui distingue au minimum `PLAYER_IDLE`, `TARGETING`, `RESOLVING`, `ENEMY_TURN`, `MODAL` et `POST_COMBAT`. C'est une **inférence**, pas un fait sur le code de la référence : aucun code source n'a été inspecté.

## TRANSFÉRABLE À DUNGEON DRAFT

- ADOPT : centre tactique libre, ownership redondant, focus contextuel, causalité impact→mort→victoire.
- ADAPT : survol/sélection/ciblage, verrou d'entrée, avertissement de fin de tour, séquence de victoire et retour monde.
- ALREADY_PRESENT : quatre capacités fixes, coûts, VFX/dégâts, inventaire/loadout, post-combat, absence d'intentions ennemies futures.

## NON TRANSFÉRABLE

La référence utilise une main de cartes dynamique et plusieurs compteurs de ressources; ces mécanismes ne doivent pas être importés. La boutique monétisée, les offres et la personnalisation cosmétique ne sont pas des priorités du contrat HUD de Dungeon Draft. La référence fournit une grammaire de rythme et de hiérarchie, pas un modèle mécanique ni un design à reproduire.

## Preuves

- `reference/contact-sheet-01.png`, `reference/contact-sheet-02.png`
- `reference/analysis-strip-01.png` à `reference/analysis-strip-03.png`
- `reference/keyframes/INDEX.md` et 79 images extraites
- `reference/ffprobe.json`, `reference/audio-analysis.log`, journaux de détection de scènes
