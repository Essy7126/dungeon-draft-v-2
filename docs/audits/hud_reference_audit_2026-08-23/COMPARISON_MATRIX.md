# Matrice comparative

Les verdicts distinguent ce qui doit être adopté comme principe, adapté au système existant, conservé car déjà présent, ou explicitement rejeté.

| Fonction | Preuve vidéo | Dungeon Draft runtime | Dungeon Draft code | Écart | Verdict transfert |
|---|---|---|---|---|---|
| Cadre périphérique stable | 00:00–02:25 | bande basse + panneaux périphériques | layers distribués | structure DD plus envahissante | ADOPT |
| Centre du plateau libre | combat entier, surtout 00:26 et 00:40 | encombré en 720p | inspect/log/timeline persistants | DD masque davantage l'espace tactique | ADOPT |
| Ownership du tour | 00:00 cyan; 00:14 magenta; commandes grisées | actif visible timeline/HUD, ennemi moins marqué | TurnQueue sain, présentation distribuée | redondance visuelle insuffisante | ADAPT |
| Barre d'actions | barre basse de cartes dynamiques | quatre slots fixes, PA visibles | Recraft sur `action_bar.gd` | fonction présente; modèle mécanique différent | ALREADY_PRESENT |
| Hover / tooltip | 00:26, 00:29 | tooltip riche + panneau inspect | TooltipManager layer 120 | contexte réparti sur trop de zones | ADAPT |
| Sélection | 00:28, 01:44, 02:06 : action soulevée | bordure/libellé; Échap trompeur | TurnState + miroir HUD | état sélectionné moins net | ADAPT |
| Coût / indisponibilité | compteurs + actions grisées | coût PA et disabled visibles | `Unit.can_use_*` | déjà présent, raison parfois partielle | ALREADY_PRESENT |
| Ciblage légal | 00:26, 00:40, 01:24 | zones couleur; périphérie reste forte | Battle/SpellCaster | cible illégale peu expliquée | ADAPT |
| Focus tactique | scène assombrie, cibles et stats éclairées | inspect/log restent dominants | aucun orchestrateur de focus unique | hiérarchie dynamique manquante | ADOPT |
| Résolution et lock | sélection→VFX→impact→retour répété | retour idle prouvé; lock inégal hors sort | async Battle/VFX/Unit | contrat de résolution fragmenté | ADAPT |
| VFX / dégâts | 00:44, 01:48, 02:24 | actions Achille et nombres prouvés | VFXManager/Unit | capacité déjà solide | ALREADY_PRESENT |
| Mort / causalité | ennemi 3 PV à 02:23, `-3` à 02:24, victoire | mort/défaite lisibles | Battle outcome | victoire locale moins affirmée | ADAPT |
| Avertissement fin de tour | 01:54 modal Oui/Non | pas d'équivalent prouvé | modalité distribuée | prévention d'erreur absente | ADOPT puis ADAPT |
| Progression niveau | 02:28–02:31.7 | arbre et évolution existent | PersistentRunUI/SkillTree | structure différente, fonction présente | ADAPT |
| Victoire / récompenses | 02:25.3–02:36.1 en étapes | post-combat lisible, victoire Battle faible | PostCombatScreen | chaîne de causalité moins continue | ADAPT |
| Monde / hub | 02:38–02:44.2 | hub et choix de run réels | GameManager | déjà présent | ALREADY_PRESENT |
| Déblocage contextuel | 02:44.2 overlay puis monde | progression existe | GameManager/PersistentRunUI | accusé visuel à formaliser | ADAPT |
| Loadout / inventaire | 02:54 écran complet | inventaire complet, sélection combat restaurée | overlay layer 40 | fonction présente | ALREADY_PRESENT |
| Personnalisation | 02:58.8 | non requise par le contrat HUD | hors cœur tactique | coût sans gain prioritaire | REJECT |
| Post-combat | victoire→niveau→récompenses→sortie | phases explicites, tests reward en échec | PostCombatScreen | baseline à stabiliser | ALREADY_PRESENT + ADAPT |
| Deck/main de cartes | visible durant tout le combat | absent; quatre capacités fixes | contrat actuel fixe | incompatible avec le mandat | REJECT |
| Ressources/économie supplémentaires | plusieurs compteurs et boutique | 6 PA/3 PM | règles actuelles | incompatible avec le mandat | REJECT |
| Intentions ennemies futures | aucune cible/case future visible | non affichées | EnemyTurnRunner | aligné avec le mandat | ALREADY_PRESENT |
| Boutique monétisée | 02:48–02:51 | hors périmètre | hors HUD tactique | non transférable | REJECT |

## Ce que Dungeon Draft doit apprendre de la référence

La référence ne vaut pas par ses cartes, mais par sa hiérarchie : le plateau reste prioritaire, l'ownership est impossible à manquer, le ciblage réduit temporairement le bruit, puis la résolution rend la causalité visible. Dungeon Draft doit adopter cette grammaire et l'adapter à ses quatre capacités fixes, à ses PA/PM et à ses autorités existantes.

## Ce que Dungeon Draft ne doit surtout pas copier

Pas de deck ni main dynamique, pas de nouvelle ressource (énergie/Ferveur/Éveil/rage/combo), pas de coup signature artificiel, pas de cible/case/intention ennemie future. La boutique, les offres et la personnalisation cosmétique ne justifient aucune reconstruction du HUD tactique.

## Synthèse des verdicts

- **ADOPT** : centre tactique libre, focus contextuel, ownership redondant, prévention d'erreur, causalité impact→issue.
- **ADAPT** : hover, sélection, ciblage, lock, modalité, victoire, progression et déblocages.
- **ALREADY_PRESENT** : quatre capacités, coûts PA/PM, VFX/dégâts, hub, inventaire, post-combat et absence d'intentions ennemies futures.
- **REJECT** : deck, ressources additionnelles, économie monétisée et personnalisation comme priorité HUD.
