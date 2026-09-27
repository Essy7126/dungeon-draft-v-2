# S23 — corrections intégrées et audit terminé, 26 septembre 2026

Demande : harmoniser échelle entre salles, couleur et proportions des clips, rendre les raccords discrets. Sources S19/S20 et marche native approuvées conservées.

Audit : haltes à 9–24 % de la hauteur de peinture, combat cumulant calibration de grille, profil 1.58–1.9 et caméra. Haltes seules appliquent un filtre de teinte. S22 mesure une hauteur de pose accroupie comme stature. Les sources ont aussi des différences réelles de dessin (capuche angulaire native, ronde dans les attaques).

Implémentation : stature commune de 100 px à 1600×900 (90 px à 1440×950), compensant le cadrage initial des salles et conservant le zoom manuel. Palette par matière commune, poids continus et corrections constantes par atlas. Ajustements de taille bornés à 0.90–1.00 après contrôle visuel : les facteurs issus de la seule surface opaque réduisaient trop certaines têtes. Marche native, temps de contact, VFX et ruée à l'arrivée conservés. Fondu entre les dessins rejeté : deux silhouettes apparaissaient en transparence. Aucun fondu artificiel final.

Captures de diagnostic : landmarks_{E,SE,S,NE,N}.png. Les boîtes automatiques sont des candidats : certaines englobent une lame, ne pas les traiter comme mesures validées.

Preuve visuelle finale : artifacts/dev/passe-rive-s23-20260926-143603, 168 contrôles PASS, 98 captures, 17 scènes réelles dont les cinq salles tactiques et le seuil. Référence mesurée 89.999996–90.000004 px. Zoom manuel 1.5× et redimensionnement contrôlés. Palette : distance RGB des 175 médianes matière réduite de 87.39 %, mesure de couleur uniquement. 50 atlas S19/S20 inchangés (SHA-256).

Validation fraîche terminée : Cartes 121/121 et natif 13/13 PASS. Haltes 53/54 et audio 102/106 : quatre tests distincts de parcours/départ restent en échec, détaillés dans VALIDATION.md (attentes de lieux/profondeurs et compteurs de départ immédiat ; ne passent pas par le rendu modifié). Gameplay : passe-rive-s22-20260926-145900, 565 contrôles, sept attaques et quatre ruées PASS. Flow : passe-rive-flow-20260926-150019, vraie victoire IA et reprise disque PASS. Aucun processus de validation S23 restant.

Une autre tâche utilise le moteur principal, NE PAS interrompre. Copie isolée conservée avec les preuves : C:/Users/paolo/Documents/Codex/2026-09-19/lis-la-conversation-x20/artifacts/s23_validation/project ; manifeste ../snapshot.json. Les 13 fichiers runtime concernés sont identiques au projet principal par empreinte. Sources runtime copiées, médias liés en lecture uniquement ; ne jamais éditer ses PNG/GLB. Lanceurs/collecteur dans tools du workspace ; source Git consultée en lecture seulement. Les modifications concurrentes postérieures hors apparence ne sont pas certifiées par ces rapports.

Limite : les dessins natifs et d'attaque gardent des différences de construction de capuche/proportions. Les mesures ne certifient pas une identité anatomique parfaite ; des poses de raccord dessinées sur un master commun seront nécessaires. VALIDATION.md, README.md et docs/current/content.md sont à jour. Revue : artifacts/dev/passe-rive-s23-review-20260926/review.html. Préserver les modifications concurrentes et les fenêtres utilisateur ; aucun commit/push demandé ou effectué.
