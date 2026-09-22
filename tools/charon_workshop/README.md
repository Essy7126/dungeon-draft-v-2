# Charon — prototype jouable de la run Cartes

Ouvrir `charon_lab.tscn` dans Godot 4.7.1 et lancer la scène avec **F6**.
Depuis la racine du dépôt, avec le moteur du projet :

```powershell
./tools/charon_workshop/play.ps1
```

Le lanceur réutilise le moteur configuré par `dev.ps1 doctor` ; un chemin explicite
peut être fourni avec `-GodotPath`.

Le prototype est isolé : aucune sauvegarde, récompense persistante ou modification
de la route publique. Les chiffres se règlent dans `default_profile.tres`.

## Jouer

- Choisir une classe et une graine, puis **Rejouer**. Achille : 240 PV, 4 PA,
  3 PM, prouesse 40. Quatre vraies classes et leurs passifs, rang de maîtrise 2.
- Cliquer une case verte pour marcher. Cliquer une carte puis une cible pour
  lancer ; Échap revient au déplacement. Espace termine le tour.
- Les gestes « Frappe de secours » et « Se protéger » utilisent les actions
  existantes de la run, sans consommer de carte. Le panneau droit défile si nécessaire.
- Deck de dix cartes : deux frappes, deux gardes, deux déplacements, deux
  poussées et deux signatures de classe. Main de quatre, conservation d'une
  carte et recomposition à 1 PA selon les règles existantes.
- Vaincre Charon suffit. Les Porteurs survivants n'obligent pas à nettoyer
  la salle après la victoire.

## Rencontre

Charon : 220 PV, 4 PA, 2 PM. Deux Porteurs : 50 PV, attaque de 12 à PO 1–4,
2 PM. Leurs morts laissent une obole sur leur case, ramassée automatiquement
par Achille, y compris lors d'un déplacement forcé.

Charon prépare une traversée à ses activations 1, 4, 7… et la résout lors de
l'activation suivante. Préparation et résolution consomment chacune l'activation
entière. Trajet cardinal fixé de cinq cases maximum, tronqué par la bordure ou
un terrain infranchissable ; 44 dégâts physiques à chaque occupant, même allié.
Le bateau spectral traverse les occupants et termine sur la dernière case libre
du trajet. Il ne suit pas le héros après l'annonce.

Aux autres activations, Charon approche puis peut utiliser un crochet aligné
(2 PA, PO 2–5, 18 dégâts, attire 2), puis une rame (2 PA, contact, 26 dégâts,
pousse 2). Une utilisation de chaque sort par activation.

Deux bornes B sont permanentes. Sur la borne ou à distance Manhattan 1, dépenser
1 PA et 1 obole permet de tourner le trajet de 90° à gauche/droite, ou d'armer
une herse : prochaine traversée annulée et 35 dégâts physiques à Charon.
Un seul changement par préparation. Survoler affiche le trajet de remplacement.
Un trajet vide est refusé sans paiement. Déplacer Charon hors de son point de
départ annule également la traversée et lui fait perdre son activation.

## Réutilisation du projet

Grille construite avec `ArenaDefinition`, `ArenaTerrainRegistry` et
`ArenaRuntimeProjectionService` du Studio. Cartes, pioche, passifs, boucliers,
états, cibles, dégâts et déplacements reposent sur les services actuels.
Seuls le cycle de rencontre Charon, les bornes/oboles et la présentation
schématique sont propres au laboratoire. Aucune règle de combat commune copiée.

La pioche est reproductible ; le hasard interne éventuel du moteur de combat
n'est pas une promesse de replay complet. Les équipements et la progression
de run sont exclus de ce premier essai afin de comparer les classes à statistiques
identiques. L'IA de Charon est un script déterministe de rencontre.

## Validation

Au 22 septembre 2026 : 15/15 tests Charon (137 assertions) après la dernière
correction UI ; suite monstres 92/92 avant cette correction ; suite cartes 76/77,
avec l'échec connu d'unicité des illustrations existantes. Rapports et détails
dans `docs/audits/charon_prototype_suivi_2026-09-22.md`. Captures réelles inspectées
en 1280 × 720 et 1200 × 896.

```powershell
./dev.ps1 test test/unit/test_catabase_monster_charon_prototype.gd
./dev.ps1 test monsters
./dev.ps1 test cards
```

Tester manuellement les trois voies : dégâts directs, déplacement des Porteurs
dans la traversée, ramassage puis borne. Le journal conserve les événements et
le bilan compte cartes, esquives, herses et coups sur les alliés de Charon.
Ces compteurs ne constituent pas une validation d'équilibrage.

Les quatre parcours automatisés de la graine 42 gagnent en 8 à 9 tours, avec
134 à 188 PV restants. Ce réglage est permissif : il valide un laboratoire de
mécaniques, pas encore la difficulté d'un mini-boss de run. Ces parcours ne
remplacent pas un test humain et ne démontrent pas que les bornes sont nécessaires.

Capture réelle : lancer avec `-- --charon-capture=CHEMIN_ABSOLU.png`. La scène
passe une activation pour afficher le télégraphe, capture puis quitte.
