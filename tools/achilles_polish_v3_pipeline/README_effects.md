# Effets d’Achille V3

Build mécanique de deux planches générées : six variantes, quatre phases par variante, soit 48 dessins. Les couleurs et formes proviennent des sources ; le script ne dessine, ne tourne et ne retourne aucun sprite.

```powershell
node tools/achilles_polish_v3_pipeline/build_effects.cjs
node tools/achilles_polish_v3_pipeline/build_effects.cjs --inspect
node --test tools/achilles_polish_v3_pipeline/build_effects.test.cjs
```

Le layout effects_layout.json est lié au SHA-256 et aux dimensions des sources. Les fenêtres partitionnent chaque source exactement une fois. Les ancres sont déclarées sur l’axe de la flèche ou sur le point d’impact ; le script ne recentre jamais les phases d’après leur centre de masse.

Une seule échelle est appliquée à toute la feuille de projectiles, et une autre à toute la feuille d’impacts. Chaque variante conserve ses proportions et les phases d’extinction restent petites. Tous les sprites sont encadrés dans 256×256, pivot (128,128), marge transparente minimale 12 pixels.

Sources actuelles :

- Projectiles RGBA natif, 1536×1024. Aucun pixel supprimé, y compris les résidus d’alpha 1 présents dans les gouttières.
- Impacts RGB 1024×1536, fond magenta. Le mode magenta est explicitement déclaré ; le détourage par script a été autorisé par l’utilisateur. Distances 50/100 autour de (255,0,255), alpha progressif entre seuils et décontamination du fond sur les seuls pixels de bord. Le manifeste compte les pixels supprimés et les pixels adoucis. Aucun contour d’effet visible ne touche une séparation après extraction.

Une validation refuse tout fond opaque en mode native, toute couleur de détourage inconnue, toute source changée, toute fenêtre qui recoupe/omet des pixels et tout rayon visible coupé. Les réglages ne suppriment jamais automatiquement un damier ambigu.

Sorties : assets/vfx/achilles_polish_v3/effects.png (1024×3072), effects.tres et manifest.json. La resource contient 12 clips neufs arrow/impact plus reach, heavy, piercing, death_line et volley. Les 4 clips sweep, guard, dust et barrier référencent directement les mêmes régions de l’ancien atlas V2 ; cet atlas n’est jamais réécrit.

La sélection appartient à `AchillesSpellVisualResolver` : forme Volée/Perforante/Ligne de mort d’abord, puis poussée résolue (`arrow_heavy`), puis Allonge acquise (`arrow_reach`), sinon bronze. `stopping_arrow_selected` reste une information de maîtrise ; il ne sélectionne aucun projectile lourd et ne confirme aucun contrôle. Les couleurs cyan/ivoire ne créent aucun dégât élémentaire.

Le build redécode l’atlas PNG et compare les 48 régions octet pour octet avec les sprites préparés. Les 8 tests vérifient aussi la reconstruction des fichiers effectivement livrés, sans ignorer les tests quand un asset manque. Les JPEG de revue sur gris/clair/sombre sont enregistrés sous artifacts/achilles_polish_v3/effects_review.

Les durées de resource sont 0,20 s pour les flèches, 0,22 s pour les impacts. Le vrai runtime reste synchronisé aux événements de combat, pas à une fin de clip qui déclencherait des dégâts.


## Foudre de l'expédition

`build_lightning.cjs` prépare séparément la nouvelle feuille 4×2, sans altérer les seize clips physiques existants :

```powershell
node tools/achilles_polish_v3_pipeline/build_lightning.cjs
node tools/achilles_polish_v3_pipeline/build_lightning.cjs --inspect
node --test tools/achilles_polish_v3_pipeline/build_lightning.test.cjs
```

La source native RGBA mesure 1774×887. Ses 34 116 664 unités d'alpha sont conservées, y compris les franges d'alpha 1–5 aux frontières examinées. Les huit fenêtres partitionnent exactement la source. Une échelle fixe par ligne conserve la taille du pic d'impact et la petite extinction ; les queues des flèches restent complètes.

Sorties : `assets/vfx/achilles_polish_v3/lightning.png` (1024×512), `lightning.tres` et `lightning_manifest.json`. Les deux clips s'appellent `arrow_lightning` et `impact_lightning` ; chaque case mesure 256×256 avec pivot (128,128). Les trois tests vérifient reconstruction identique, conservation de l'alpha, échelles communes, huit régions après décodage PNG et refus des sources/fenêtres/ancres invalides.

Les cartes élémentaires lisent le véritable `Spell.element`. Feu/Glace réemploient l'atlas de Paris, Foudre cette ressource, soins confirmés celui du philosophe. Le catalogue fixe le délai réel de vol à 0,20 s pour douze tirs d'expédition ; aucun délai ni dégât n'est inventé par le renderer.
