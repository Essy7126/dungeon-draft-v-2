# Le camp des compagnons — les tailleurs de l'ombre

Halte de repos de l'étape IV, après **La garde des sources** sur le trajet du
puits. Le camp conserve son identité de parcours et son service existant :
repos gratuit de 30 % des PV maximum, une fois, puis reprise du chemin.

Les anciens tailleurs ont installé une toile rapiécée et trois couchettes dans
une poche sèche de la carrière. Les blocs partiellement extraits, les coins,
pics et paniers de déblais montrent leur travail. Le feu encore entretenu et
les outils rangés suggèrent leurs relais. Une niche représente **Hadès au
sceptre et Cerbère à trois têtes** ; grenades et oboles portent la mémoire de
leurs offrandes. La roche bleu-gris, les lanternes de bronze et la lueur de
magma derrière la sortie assurent le raccord avec les deux maps précédentes.

## Essayer

```powershell
./tools/camp_companions_review/open.ps1
./tools/camp_companions_review/verify.ps1
./tools/halt_workshop/halt.ps1 verify -Map res://data/halts/companions_quarry_v1.json
./dev.ps1 test test/unit/test_companions_quarry_binding.gd
```

Le lanceur ouvre la vraie destination **d04_0**, graine **2401**, avec les
victoires précédentes simulées par le laboratoire et des données utilisateur
isolées. **F8** ferme l'essai. Cliquer le foyer fait approcher Achille et ouvre
le repos ; l'arcade droite propose le départ. Les PV déjà pleins ne donnent
pas un second avantage. Aucun magasin ou gain de récit n'est ajouté au camp.

## Création et préparation

Le plan spatial et trois gabarits ont été tracés avant la génération. Échelle
H/image = **0,18**, avec la même convention de silhouette d'Achille que les
autres haltes. L'Étal du passeur original fixe la DA ; La garde des sources
sert au raccord. Les prompts exacts et les trois originaux d'image_gen intégré
sont conservés. La dernière révision remplace la fourche erronée du relief
par un sceptre simple et rend Cerbère clairement lisible à trois têtes.

- Source de production : `asset/map/painted/halts/companions_quarry_v1/source-v3.png`,
  **1672 × 941**, originale, sans redimensionnement ni retouche déterministe.
- Prompt initial : `art/source/halts/companions_quarry_v1/generation_prompt.txt` ;
  corrections : `PROMPT-v2.md` et `PROMPT-v3.md` dans le même dossier.
- Calibration : `art/source/halts/companions_quarry_v1/calibrate.py`. Les
  contours sont tracés à la main ; les pixels ne définissent pas les collisions.
- Manifeste : `data/halts/companions_quarry_v1.json`. Préparer les masques avec
  l'atelier commun après toute modification de calibration.
- Raccord : `data/halts/route_bindings.json`, sélection par titre exact, type
  `hub` et profondeur IV. Le graphe et les identifiants sauvegardés sont conservés.

Les passages contournent le foyer, les tabourets et le mobilier. Le personnage
reste du côté visible des objets, sans découpe de premier plan nécessaire.
Le feu, cinq vitrages et deux lampes à huile utilisent les effets communs ;
pas de distorsion d'eau sur le sol. Crépitement local, pas de pierre, pause et
réduction des animations sont disponibles. La lave au-delà du seuil reste une
lueur peinte ; le camp est sec.

## Vérifications

La revue de l'atelier passe **281 contrôles**, **4 392 échantillons de
déplacement** et produit **52 captures** à 720p/1080p :
`artifacts/dev/20260912-132358-halt-verify-5ee50b13/summary.json`.
Le feu, les chemins et les proportions ont été inspectés dans les captures
au repos et en zoom. Le corps des tabourets et les ouvertures gardent une
échelle cohérente avec Achille ; le relief votif est volontairement plus haut.

Le contrôle de production passe **100 contrôles** et produit **8 captures**,
sans erreur :
`artifacts/dev/20260912-132655-camp-companions-production-4fb8ba59/summary.json`.
Il utilise le vrai GameManager : personnage blessé
dans la fixture, soin de 30 %, refus du doublon, reçu enregistré, reprise du
checkpoint et départ unique. Voir `WORK_NOTES.md` pour les derniers rapports.
Le raccord dédié passe 2 tests et 588 assertions ; la suite commune des haltes
passe 52 tests et 1 271 assertions après actualisation de l'énumération des
quatre haltes peintes. Rapport final :
`artifacts/dev/20260912-133613-test-halts-camp-2538de0e/gut-strict-report.json`.
Les lectures et le repos réutilisent les services existants de Catabase ;
aucune exploration physique entre deux scènes n'est ajoutée.
