# Paris : sprites d’effets

La source native RGBA contient 32 dessins : quatre phases pour `arrow`, `frost`, `fire`, `vortex`, `impact`, `whip`, `hellfire` et `transform`. Les flèches pointent vers la droite et le fouet se déploie de gauche à droite ; le moteur effectue les rotations nécessaires vers la cible.

```powershell
node tools/paris_sprite_pipeline/build_effects.cjs --inspect
node tools/paris_sprite_pipeline/build_effects.cjs
node --test tools/paris_sprite_pipeline/build_effects.test.cjs
```

Les fenêtres et leurs ancres sont inscrites dans `effects_source_layout.json`, lié au SHA-256 exact du PNG source. Les séparations verticales varient par colonne afin de conserver les couronnes hautes. Les 32 rectangles couvrent exactement une fois toute l’image. Les résidus alpha présents dans les séparations sont conservés, y compris alpha 1 ; il n’y a ni détourage par couleur, ni segmentation, ni nettoyage de bord. La séparation entre les troisièmes poses du fouet et de la couronne contient un halo léger atteignant alpha 36/255, déclaré dans la revue et partagé par la découpe. Aucun pixel n’est supprimé pour masquer ce chevauchement de la source.

Chaque animation utilise un rayon et une échelle communs à ses quatre phases. Les ancres restent fixes et les extinctions gardent leur taille et leur intensité relatives. Une marge transparente de 12 pixels protège les cellules finales de 256 × 256. Le redimensionnement interpole normalement les canaux RGBA ; avant cette étape, la somme des alphas de chaque extraction est contrôlée pour détecter toute perte. Le collage dans l’atlas et sa relecture PNG sont vérifiés octet par octet. À l’échelle 1, le test vérifie l’identité de tous les pixels RGBA, alpha 1 compris.

Le résultat comprend `effects.png` en 1024 × 2048, les huit clips de `effects.tres`, les manifestes de provenance et trois aperçus sur fonds clair, gris et sombre. Ne pas importer les aperçus dans le rendu du combat : les ressources du moteur utilisent exclusivement l’atlas transparent.

Les neuf ressources `icons/*.tres` réutilisent directement la pose 2 : huit icônes raccordées aux sorts de Paris et une icône de métamorphose disponible. Les sorts partageant le même effet réutilisent aussi son illustration. Les durées de référence sont 0,20 s pour les flèches, 0,30 s pour le vortex et l’impact, 0,34 s pour le fouet, 0,40 s pour la couronne et 0,90 s pour la métamorphose. Le runtime adapte le vortex de téléportation à 0,48 s et l’impact de la flèche de feu à 0,30 s ; ces valeurs sont déclarées dans le manifeste.

Les tests Node contrôlent les sources opaques, fenêtres invalides, couvertures incomplètes, pixels alpha de bord non revus, cadres vides, ancres invalides, extinction, identité RGBA à l’échelle 1, ressources, icônes et reproductibilité de l’atlas livré. Ils ne remplacent pas les combats réels du harnais Paris.
