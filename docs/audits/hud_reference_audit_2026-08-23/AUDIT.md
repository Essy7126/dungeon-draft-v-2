# Audit comparatif HUD, flow et architecture UI

Date : 2026-08-23  
Branche : `main`  
SHA : `52921204c5e4b52f195f0bf0269c1530f9b59b3f`  
Verdict formel : **PARTIAL_REBUILD**

## Réponse directrice

Dungeon Draft ne doit être ni reconstruit totalement, ni simplement repeint. Les autorités de gameplay, les données, les scènes, la progression et les flows actuels sont réutilisables. En revanche, la vidéo confirme qu'une couche de présentation cohérente manque entre ces systèmes : ownership, focus de ciblage, verrou d'entrée, modalité, causalité de l'impact et passage à la victoire sont aujourd'hui distribués. La bonne stratégie est une **reconstruction partielle, incrémentale et compatible**, autour d'un contrat de présentation explicite, puis l'extraction progressive de la dette `action_bar.gd`.

Le compromis principal est de préserver TurnQueue, SpellCaster, Unit, Pathfinder, RunData, GameManager et les écrans fonctionnels, tout en reconstruisant les adaptateurs et contrôleurs de présentation qui les exposent. Aucun deck, aucune nouvelle ressource et aucune intention ennemie future ne doivent être importés de la référence.

## Référence vidéo vérifiée

Le fichier de 392 829 854 octets a pour SHA-256 `A1B7C49F618A04FF6795CC1076FF9D8E400FC9FBAF9544E447B31F9C21FA30B3`. Il dure 181,291 s, en 2560×1592 à 30 fps, avec audio AAC stéréo présent. Deux planches contact, trois bandes d'analyse et 79 keyframes soutiennent la chronologie.

La référence montre une périphérie stable et un centre tactique libre. Les tours utilisent texte, couleur et disponibilité des commandes. Lors du ciblage, le décor est assombri tandis que cibles, cases et valeurs pertinentes gagnent en contraste. La boucle sélection→VFX→impact→retour est nette. Le dernier impact déclenche une chaîne continue victoire→niveau→récompenses→monde→déblocage. Aucune cible, case ou intention ennemie future n'est annoncée.

## Constats déterminants

- **OBSERVÉ vidéo** : le focus de ciblage réduit temporairement le bruit sans déplacer le plateau ni multiplier les panneaux.
- **OBSERVÉ vidéo** : ownership joueur/adversaire est redondant; la modal de fin de tour prévient une erreur avant validation.
- **OBSERVÉ vidéo** : la victoire découle visuellement du dernier impact et se poursuit jusqu'au retour monde.
- **OBSERVÉ code/runtime DD** : le HUD persistant se branche via GameManager; Battle conserve plusieurs fallbacks complets.
- **OBSERVÉ** : le Recraft dépend d'un large contrat implicite du `action_bar.gd` historique; classement `DETTE_A_EXTRAIRE`.
- **BUG REPRODUIT** : tooltip épinglé au-dessus du menu pause.
- **OBSERVÉ** : le HUD promet Échap pour annuler alors que Battle ne traite que le clic droit; PersistentRunUI peut ouvrir pause.
- **OBSERVÉ** : le lock est robuste pour les sorts mais pas uniformisé pour mouvement/attaque de base.
- **OBSERVÉ runtime** : 150 px de bande basse = 20,83 % à 720p contre 13,89 % à 1080p; inspect/log/timeline recouvrent le plateau.
- **OBSERVÉ runtime** : Odyssey exécute quatre vraies actions d'Achille, dégâts, mort, post-combat et résultat; First Run charge le trio dans six vraies salles.
- **DIVERGENCE** : 114/123 tests sélectionnés passent; 9 échecs et un runner évolution dérivé empêchent toute baseline verte.

## Validation visuelle synthétique

À 1280×720, le plateau lutte contre quatre zones persistantes : timeline, inspect, journal et bande basse. Le journal (370×250 à partir de y=520) déborde et le bandeau occupe 20,83 % de la hauteur. À 1920×1080, la bande tombe à 13,89 %, mais les panneaux gardent une présence importante. PA/PM/PV et les quatre capacités sont lisibles; le coût est visible. La distinction cible légale/illégale repose trop sur la couleur et une cible illégale n'est pas expliquée. La défaite est forte; la victoire est seulement valorisée au post-combat.

Le contraste avec la vidéo ne justifie pas de copier son layout : il justifie un mode focus qui atténue les surfaces secondaires, une ownership plus redondante et une séquence d'issue locale. Les timings fins entrée→feedback/impact/release n'ont pas été instrumentés; les runners et la vidéo prouvent l'ordre, pas des budgets en millisecondes.

## Performance et cycle de vie

Les boutons/slots de sort sont reconstruits lors de `build_spell_buttons` à chaque mise à jour de tour. Le Recraft connecte/déconnecte les signaux du contexte et des unités, avec tests dédiés. Timeline/inspect/journal/tooltip sont recréés par Battle; PersistentRunUI survit à la run. Les runtimes graphiques passent mais ferment avec des fuites GPU/RID, ObjectDB et ressources. Sans profiler ni attribution par type, c'est un diagnostic à investiguer, pas une preuve de régression HUD.

## Accessibilité et entrées

Pause montre un focus visible et fonctionne en `PROCESS_MODE_ALWAYS`; inventaire/arbre/évolution suivent le même principe. Les raccourcis de capacités sont visibles. Échap est contradictoire en ciblage, la couleur est un indicateur quasi unique de légalité, la raison d'indisponibilité positionnelle manque, et navigation clavier complète/réduction des mouvements ne sont pas prouvées. La référence fournit un bon principe de redondance texte+couleur+état, à adapter.

## Livrables

- [Chronologie référence](REFERENCE_VIDEO_TIMELINE.md)
- [Flow actuel](CURRENT_SCREEN_FLOW.md)
- [Architecture HUD](CURRENT_HUD_ARCHITECTURE.md)
- [Signaux et états](SIGNAL_AND_STATE_MAP.md)
- [Matrice comparative](COMPARISON_MATRIX.md)
- [Registre des constats](FINDINGS_REGISTER.md)
- [Contrat cible](TARGET_HUD_CONTRACT.md)
- [Roadmap](ROADMAP.md)
- [Index des preuves](EVIDENCE_INDEX.md)

## Critères d'acceptation

Satisfaits : Git/SHA, vidéo/hash/métadonnées/timecodes, deux planches contact, 79 keyframes, architecture, layers, autorités, héritage/fallbacks, plus de 20 captures, First Run/Odyssey, 1280/1920, overlays, actions réelles, post-combat, plus de 15 constats, contrat cible, roadmap et aucune modification production.

Limites restantes : certaines captures Battle reposent sur Odyssey ou sur un fixture de layer clairement étiqueté; le runner évolution est dérivé; l'audio n'a pas été transcrit; aucun profiler attribuable par type n'a été exécuté. Ces limites réduisent la précision de quelques constats mais ne bloquent plus le verdict **PARTIAL_REBUILD**.
