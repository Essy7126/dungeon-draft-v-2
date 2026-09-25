# Lecture comparée des sorts — fiche de reprise

Demande : lire des sorts de personnages ET d'ennemis de DOFUS, WAVEN, Baldur's Gate, Divinity et Slay the Spire, puis les comparer aux nôtres.

- Début : 25 septembre 2026. Référence Git : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.
- Deux périmètres locaux distincts : catalogues Godot actuels et proposition `consumable_v1` 1.0.1-theory. Aucune modification du gameplay prévue.
- Références choisies : DOFUS PC (versions signalées), WAVEN (kits documentés, annonces séparées), Baldur's Gate 3, Divinity: Original Sin 2 Definitive Edition, Slay the Spire 1.
- Lecture locale : 60 cartes de base, 28 d'initiation, 24 avancées ; fabrique des sorts, modificateurs d'écosystème et progression des kits ennemis. Les anciennes cartes `s_*` conservées pour les sauvegardes ne comptent pas dans le catalogue public.
- Constat initial : les kits ennemis Godot sont plus riches que les sept archétypes du laboratoire V1. Préserver le ciblage des soutiens, les préparations interruptibles, les invocations et les formations.
- État : dossier de comparaison terminé, avec limites documentaires explicites. Aucun fichier de gameplay modifié.

## Livrables

- `README.md` : entrée et conclusions principales.
- `LECTURES_COMPAREES.md` : sorts et capacités ennemies des cinq références, limites et comparaison G/V1.
- `AUDIT_ET_PRIORITES.md` : diagnostic local, résultats calculés, huit propositions non implémentées et ordre de prototype.
- `SOURCES.md` : registre de sources, versions, nature des preuves et lacunes.
- `INVENTAIRE_LOCAL.md`, `inventaire_local.json` : 112 définitions Godot et 48 familles V1 ; le JSON conserve les empreintes SHA-256 de douze fichiers de référence.
- `audit_local.mjs` : extraction et contrôle des catalogues.
- `comparaisons_calculees.mjs`, `calculs_comparatifs.json` : huit séquences légales du modèle V1 et quatre probabilités de main vérifiées par énumération.

## Décisions importantes

- Ne pas diagnostiquer une absence de chimie dans le moteur : les réactions sont déjà définies et le service les applique aux surfaces dynamiques concernées. La couverture des cartes reste à établir.
- Ne pas assimiler le bestiaire simplifié V1 aux kits Godot : priorité à la représentation des soutiens, préparations, invocations et transition de Pâris avant un nouvel équilibrage global.
- La spécialisation Godot remplace le passif de classe dans la branche lue ; le modèle V1 combine ses propres mécanismes. Ne pas mélanger les deux calculs.
- Répercussion V1 : sa recette naturelle perd face à Heurt au contact dans le scénario mesuré. L'avantage de portée interdit de conclure à une domination universelle.
- Le moteur de chaque classe doit être accessible avec les communes ; le drop de sacs sur les mobs reste la base économique demandée.

## Vérifications exécutées le 25 septembre 2026

1. `node docs/design/spell_comparison_2026-09-25/audit_local.mjs` : succès ; 112 IDs Godot uniques, 48 IDs V1 uniques, 33 améliorations de seuls dégâts directs, neuf familles normalisées communes aux quatre classes.
2. `node docs/design/spell_comparison_2026-09-25/comparaisons_calculees.mjs` : succès ; huit séquences passent la légalité du modèle ; quatre probabilités concordent avec l'énumération exhaustive.
3. Vérification documentaire locale : six Markdown, 144 liens locaux et 29 tableaux ; aucune cible absente, ancre de ligne hors fichier, structure de tableau incorrecte, espace final ou caractère de remplacement détecté à l'exécution.
4. `git status --short`, `git diff --stat`, `git rev-parse HEAD` : HEAD inchangé ; aucune modification suivie ; nouveaux livrables dans ce dossier seulement. Les dossiers de conception non suivis déjà présents ont été préservés.

**Non exécutés :** import moteur, suites Godot, parties manuelles, mesures de satisfaction et simulations de runs modifiées. Les suites antérieures du laboratoire ne sont pas présentées comme réexécutées ici. Les huit propositions n'ont pas été implémentées ni validées en jeu.

## Reprise sur un autre ordinateur

Les documents utilisent des liens relatifs au dépôt. Transférer ce dossier **et** `docs/design/consumable_v1/` : ce dernier reste non suivi dans l'état observé et n'est pas inclus dans le seul commit de référence. Aucun commit ni push n'a été effectué pendant cette lecture.

À la reprise, comparer les empreintes du JSON avant de réutiliser les chiffres. Les régénérations ne mettent pas automatiquement à jour les conclusions narratives.

Suite de conception recommandée : enrichir les rencontres du laboratoire avec les mécaniques Godot existantes, puis prototyper Répercussion et la préparation de main séparément. Lacune documentaire spécifique : bestiaire WAVEN complet à capturer dans une version identifiée ; DOFUS historique à confronter au client contemporain si l'objectif devient un catalogue 2026 exact.
