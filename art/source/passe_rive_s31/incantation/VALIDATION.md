# Incantation — validation du 28 septembre 2026

**Terminée en V1 dans les huit orientations, pour les six cartes attribuées.**

- Suite Passe-Rive : **65 tests / 10 703 assertions PASS**, `artifacts/dev/20260928-233131-test-passe-rive-8bb03228/gut-strict-report.json`. Déclenchement unique à 590 ms, douze poses, échelle/appui/main stables, toutes les attributions et interruptions.
- Combat : **96 lancers / 2 139 contrôles PASS**, `artifacts/dev/passe-rive-incantation-cards-20260928-233406/report.json`. Six cartes × base/amélioration × huit directions ; 401 captures, dont 112 images du film. Coût réel, copie consommée, absence d'effet anticipé, bonne orientation, boucliers, marque, glace et retour natif.
- Contrôle complémentaire Sommeil marqué : **16 lancers / 379 contrôles PASS**, `artifacts/dev/passe-rive-incantation-cards-20260928-234050/report.json`. Présence directe de `stasis` et `stasis_ward` après consommation de la marque ; le journal générique « 0 unité(s) » d'un sort sans dégâts ne sert pas de preuve.
- Présentation : **64 images** des huit vues, `artifacts/dev/passe-rive-incantation-directions-20260928-232930/`. Prière, mains hautes, ouverture et récupération revues.
- Quatre GDScript dédiés formatés et vérifiés ; contrôle des espaces Git des fichiers suivis concernés réussi.

Les nouveaux PNG ne portent aucun VFX peint. Les effets de chaque carte restent ceux du routeur de production. Les captures montrent notamment le sceau ciblé, le gain de garde et les cases de glace.

Contours, largeur apparente et amplitude varient légèrement selon les dessins ; les fondus peuvent se voir au ralenti. Les mains jointes sont partiellement masquées par la tête dans les vues de dos. Le banc prépare cartes/prérequis et suspend l'IA, il ne simule pas une run complète depuis le menu. Sources imagegen et prompts exacts conservés, pixels non retouchés par script.

Médias sous `review/`, provenance des captures dans `review/provenance.json`. La génération et l'intégration SE historique restent disponibles sous `art/source/passe_rive_s26/`.
