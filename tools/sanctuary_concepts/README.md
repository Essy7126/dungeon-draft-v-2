# Sanctuaire d'Achille — revue de direction artistique

Les concepts sont produits avec le service **Meshy Text to Image**, modèle
`nano-banana-pro`, au format demandé 16:9. Aucune génération 3D n'est nécessaire.
Cette étape explore une carte de hub illustrée en 2D isométrique ; une image de
concept ne constitue pas à elle seule un niveau jouable.

## Génération

Depuis la racine du dépôt, installer `requests` dans un environnement Python, ou
dans `output/sanctuary-meshy-deps`, puis lancer :

```powershell
python tools/sanctuary_concepts/generate_meshy_concepts.py
```

Le script importe les fonctions du plugin Meshy installé. Il demande la clé par
une saisie masquée, la garde uniquement en mémoire, affiche le solde, puis attend
`generate` pour créer les deux concepts (18 crédits estimés au total).
Il sauvegarde prompts exacts, tâches, images et historique sous `meshy_output/`.
Le chemin du plugin se trouve en tête du script si une autre version est installée.
Ne jamais ajouter une clé API au script ou aux fichiers de suivi.

## Deux hypothèses artistiques

- **A — Cour des Sources** : calcaire miel, oliviers, eau jade, tissu terracotta,
  ambiance sacrée accueillante et lumière de fin de journée.
- **B — Refuge des Braises** : pierre cendrée, ombres indigo, bronze, eau turquoise,
  lumière ambrée des braseros, refuge protecteur dans les Enfers.

Composition commune : arrivée au centre bas, marchand en haut à gauche, oracle
en haut à droite, passage au fond, eau sur le côté. Une grande place relie les
interactions sans encombrer la silhouette d'Achille.

## Critères de revue avant intégration

1. L'image doit paraître dessinée et garder des formes lisibles à l'échelle de jeu.
2. Les axes du sol et les ancrages doivent permettre une projection 2:1 cohérente.
3. Les accès aux trois interactions doivent former un espace réellement connecté.
4. L'eau, les obstacles et le sol accessible doivent avoir des limites identifiables.
5. Les volumes de premier plan doivent pouvoir être séparés pour l'occlusion.
6. L'eau et la fumée doivent rester sur des couches animables locales.
7. La décision artistique doit distinguer qualités, défauts et corrections requises.

## Préparation du prototype

Le prototype sera une scène autonome sous `hub/sanctuary_prototype/`.
Le héros utilisera `AchillesSprite2DBackend` et les sprites du kit V2 existants.
La navigation sera définie par des contours explicites adaptés au décor retenu,
avec approches accessibles pour le marchand et l'oracle. Les obstacles ne seront
pas déduits automatiquement de la couleur de l'image.

La logique de session (`sanctuary_session.gd`) est préparée séparément : achats à
stock limité, inventaire local, choix exclusif d'une bénédiction et remise à zéro.
Elle ne modifie ni la sauvegarde ni les ressources de la run. Les panneaux devront
annoncer prix, conséquences et indisponibilités, bloquer la marche pendant leur
ouverture, puis rendre le contrôle à leur fermeture.

Après le choix artistique : préparer fond / éléments avec occlusion / masque
d'eau / fumée ; intégrer clic de déplacement et approche avant interaction ;
vérifier achats, annulation d'intention, choix exclusif, absence de Node3D et
rendu aux résolutions 1600×900 et 1200×896. Le hub de production et son flux
Archiviste restent une référence distincte pendant cette expérimentation.
