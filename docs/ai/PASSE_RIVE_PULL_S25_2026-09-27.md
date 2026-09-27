# Ramener au front — S25

Demande : créer le crochet spectral proposé pour Passe-Rive. Carte actuelle `cc2_g04`, 1 PA, portée 2–3, dégâts physiques coefficient 0,2 ; attraction d'une case, deux pour la version améliorée. Les règles de la carte ne sont pas modifiées.

## État et choix

- Source : outil imagegen intégré, atlas transparent de 12 dessins référencé sur le repos SE, le coup haut et le modèle 3D. V01 conservée, V02 resserre les mains lors de la traction.
- Lecture : 11 poses sur 890 ms. Le dessin 2 est exclu du montage car la main opposée levée rompait la continuité du lancer. Le premier vrai tirage est le dessin 6, à 400 ms. Aucun pixel source retouché par script.
- SHA-256 V02 : `bd42fed82e4daa9f4c72e7f288621e8070d72090336bf276674b96bf4fc7db12`.
- Une échelle issue de la pose neutre (334 px), semelle arrière recalée sur le même appui que le repos natif. La palette utilise le traitement commun S23 ; pas de zoom ou de fondu de silhouettes entre poses.
- Le crochet réutilise l'asset bronze existant et un fil spectral fin. Il prend son origine dans la main dessinée. Son horloge vient du corps ; la translation de cible n'est rejouée visuellement qu'après un déplacement confirmé. Les PV et cases logiques ne sont jamais écrits par le VFX.
- Première animatique SE. Les autres directions restent neutres avec statut `pending_direction`, et ne sont pas présentées comme dessinées.

## Fichiers de cette étape

`assets/characters/PasseRive/sprites_s25/pull.png/json`, `passe_rive_pull_body.gd`, intégration dans `passe_rive_s19_backend.gd` et liaison g04. `passe_rive_pull_tether.gd` ; contexte de cible optionnel transmis par `battle/unit_view.gd` au visuel Passe-Rive. Banc `tools/class_card_vfx/passe_rive_s25/arena.tscn`, lanceur `play.ps1`, tests `test_passe_rive_s25.gd` ajoutés aux suites Cartes et Catabase.

## Vérification finale

Le formateur a été corrigé en explicitant une expression de calcul de pivot trop longue. Les premiers lancements de tests ont attendu les autres commandes Godot sur le même projet ; leurs rapports bloqués ne sont pas des succès. Les autres tâches n'ont pas été arrêtées.

- Tests ciblés finaux : **5 tests / 98 assertions PASS**, `artifacts/dev/20260927-144724-test-test_unit_test_passe_rive_s25.gd-3ae9bbcf`.
- Capture initiale `artifacts/dev/passe-rive-pull-20260927-144816` : carte normale correctement jouée (pose 6 à la libération, 1 PA, copie consommée, une case attirée). Les positions capturées progressent vers la destination après la traction, sans saut. La seconde répétition échoue sur `once_per_activation` : rapport conservé en échec. Le banc appelle maintenant `hero.start_turn()` entre les essais ; aucune règle de carte contournée dans la production.
- Inspection du repos, de la traction et des positions réelles de cible effectuée ; les points de main de préparation/récupération ont été affinés dans les métadonnées, sans retouche du dessin.
- Capture corrigée **PASS : deux lancers, 133 contrôles, 98 images dont 91 images de film**, `artifacts/dev/passe-rive-pull-20260927-190930`. Carte normale : une case ; améliorée : deux. Pas de dommage ni de déplacement précoce ; 1 PA et une vraie copie consommés par lancer ; une seule libération, retour au repos et nettoyage du fil. Le champ hérité `card_count=112` est celui du catalogue historique du banc, pas sa couverture : les deux cas réels sont dans `casts`.
- Inspection du tableau repos/projection/tension/traction/récupération et des captures améliorées : main reliée au fil, arrière-pied posé, cible rapprochée. Le lecteur de captures vérifie l'échelle constante et neuf positions intermédiaires de cible, sans recul ni dépassement. Le GIF conserve le temps réel à 1 ms près sur la capture ; l'arrondi cumulé évite d'accélérer les images 60 fps au format GIF.
- Vérification finale propre à Passe-Rive : **18 tests / 2 945 assertions PASS, aucune erreur**, `artifacts/dev/passe-rive-pull-final-20260927-191402`. Ce lancement runtime réutilise les ressources déjà importées et ses propres données utilisateur.
- Vérification élargie : 51 tests / 3 144 assertions réussies, mais verdict **FAIL** à la fermeture (125 objets et 14 ressources encore ouverts), `artifacts/dev/passe-rive-pull-regression-20260927-191204`. Ces mêmes diagnostics sont reproduits en exécutant seulement les 33 tests existants de préparation/récupération/déplacement, sans les suites Passe-Rive : `artifacts/dev/passe-rive-pull-existing-lifecycle-20260927-191347`. Ne pas transformer ce résultat en PASS global.
- Suite Cartes complète `artifacts/dev/20260927-144912-test-cards-0656c8ae` : **incomplète, timeout de 900 s**, sans JUnit final. Ce n'est pas une validation de toute la suite. La capture qui attendait derrière elle n'a pas été exécutée et a aussi été écartée. Une autre campagne globale conserve des processus ; elle n'a pas été interrompue. Les derniers contrôles et la capture ont utilisé le runtime déjà importé, sans nouvel import concurrent et avec des données isolées.
- Formateur : les dix scripts GDScript concernés sont conformes. Sources Python et lanceur PowerShell analysés sans erreur.

## Résultat livré

Dans le workspace de conversation : `outputs/passe_rive_pull_S25/review/ramener_au_front.gif`, `audit_poses.png`, `review.html`, `capture_provenance.json`. Les prompts, deux versions graphiques et le README sont conservés dans `outputs/passe_rive_pull_S25`.

La fenêtre interactive S25 a été lancée avec `play.ps1` (helper PID 33580), signal `PASSE_RIVE_S25_READY` constaté et stderr vide. Le lanceur interactif ne monopolise pas le verrou des validations ; les captures automatiques le prennent toujours. Les autres processus de l'utilisateur restent ouverts.

Étape livrée : animatique SE et intégration de la carte normale/améliorée. Suite artistique éventuelle après avis : ajuster le rythme et les intervalles, puis dessiner les autres directions. Le bilan global de la suite Cartes et les ressources non libérées par les anciens tests restent distincts de la validation ciblée obtenue ici.
