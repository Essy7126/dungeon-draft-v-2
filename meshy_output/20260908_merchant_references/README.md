# Trois références artistiques de maps marchandes

**Trois images 2D générées avec Meshy / Nano Banana Pro, puis inspectées visuellement.**

Direction artistique : pierre bleu sombre moussue, racines, bronze ancien, bougies ambrées et magie turquoise. Les personnages sont absents. Les objets et les espaces de circulation sont composés pour préparer de futures interactions ; les achats et les dialogues ne sont pas implémentés.

**Coût réel : 27 crédits (9 par image). Solde final vérifié : 1 147 crédits.** La clé a été utilisée uniquement dans le processus de génération et n’a pas été enregistrée dans les fichiers.

## Le Comptoir des archives

Une boutique de reliques aménagée dans une bibliothèque ancienne. Comptoir en L, trois présentoirs isolés et lumière turquoise discrète au fond.

![Le Comptoir des archives](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125410_01-comptoir-des-archives_01a080a7/01_comptoir_des_archives.png)

[PNG original](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125410_01-comptoir-des-archives_01a080a7/01_comptoir_des_archives.png) — 1376 × 768 px — 1.17 Mio.

Points d’interaction envisagés : Grimoire sur pupitre, Coffret de reliques, Cristal serti de bronze, Comptoir du marchand.

Identifiant Meshy : `01a080a7-5c54-766b-baf6-c8504b1daefc`.

## La Halle sous les racines

Un petit bazar souterrain sous des racines monumentales. Trois étals distincts entourent une place praticable et une fontaine basse.

![La Halle sous les racines](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125455_02-halle-sous-les-racines_01a080a8/02_halle_sous_les_racines.png)

[PNG original](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125455_02-halle-sous-les-racines_01a080a8/02_halle_sous_les_racines.png) — 1376 × 768 px — 1.59 Mio.

Points d’interaction envisagés : Étal d’équipement, Étal de provisions, Kiosque d’objets enchantés, Fontaine ancienne.

Identifiant Meshy : `01a080a8-0dcf-7079-ac15-f799fb8f1b74`.

## L’Apothicairerie du bassin

Une échoppe d’alchimie organique et chaleureuse. Comptoir courbe, fioles espacées, plantes et distillateur de bronze autour d’un bassin discret.

![L’Apothicairerie du bassin](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125605_03-apothicairerie-du-bassin_01a080a9/03_apothicairerie_du_bassin.png)

[PNG original](C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2/meshy_output/20260908_125605_03-apothicairerie-du-bassin_01a080a9/03_apothicairerie_du_bassin.png) — 1376 × 768 px — 1.51 Mio.

Points d’interaction envisagés : Plateau de potions, Bocaux d’ingrédients, Distillateur de bronze, Comptoir de l’apothicaire.

Identifiant Meshy : `01a080a9-2162-7787-a269-873582387d25`.

## Lecture artistique

La Halle sous les racines est la plus proche de la bibliothèque de référence, avec son cadre immersif, ses canaux et ses engrenages. Le Comptoir des archives et l’Apothicairerie du bassin utilisent une présentation de pièce ouverte, plus proche d’une maquette isométrique. Les trois proposent des objets distincts et une circulation centrale dégagée. Les illustrations sont des références artistiques et ne constituent pas des maps jouables validées.

## Fichiers et vérifications

- `briefs.json` : prompts complets, paramètres et provenance des images sources.
- `references/` : copies à l’identique des deux pièces jointes, avec empreintes SHA-256.
- `jobs.json` : identifiants Meshy, chemins des sorties, état des téléchargements et crédits consommés.
- `review.json` : formats, dimensions, tailles et relevé de validation.
- Chaque dossier de résultat contient l’image originale, le prompt, la réponse de tâche et les métadonnées. L’historique est enregistré dans `meshy_output/history.json`.

Les trois tâches ont réussi. Les PNG ont été chargés et contrôlés, puis inspectés visuellement pour la cohérence artistique, l’absence de personnages et d’interface, et la lisibilité des objets. Aucun import moteur, test gameplay ni test d’achat n’a été exécuté : aucune intégration au jeu n’a été effectuée. Les dossiers sont exclus de l’import Godot avec `.gdignore`.

## Reprise technique

`generate.py` utilise les fonctions officielles du plugin Meshy. Il conserve les identifiants pour reprendre les tâches existantes sans en créer de nouvelles lors d’une relance. Sans `--generate`, il vérifie seulement les fichiers et l’environnement. Pour un lancement nécessitant une clé temporaire, `--key-prompt` effectue une saisie masquée sans persistance.

```powershell
& 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 -u 'meshy_output/20260908_merchant_references/generate.py' --generate --key-prompt
```

Documentation du service : [API Meshy image-to-image](https://docs.meshy.ai/en/api/image-to-image).
