# Sources, versions et contradictions

Consultation : 25 septembre 2026. Les liens individuels des **91 fiches** sont dans [DOFUS](DOFUS.md) et [WAKFU](WAKFU.md). Les analyses sont originales ; les tableaux paraphrasent les propriétés utiles et ne reproduisent pas les descriptions complètes.

## Hiérarchie des preuves

| Statut | Signification | Ce que cela ne prouve pas |
|---|---|---|
| Fiche directement lue | Effets, coûts et conditions réellement visibles dans le navigateur | Exactitude du parseur, version live, résolution réelle dans le client |
| Annonce du studio | Intention ou changement annoncé par Ankama | Livraison si la source parle seulement de bêta ou d'intention |
| Note reproduite/indexée | Texte de changement retrouvé dans une copie ou un index, source originale identifiée quand possible | Inspection intégrale du document original |
| Guide / témoignage | Explication d'auteur ou expérience individuelle | Représentativité des joueurs, taux de victoire, règle inchangée depuis sa rédaction |
| Déduction / modèle | Conséquence calculée à partir d'hypothèses écrites | Test du moteur des jeux ou preuve globale d'équilibrage |

## Références de travail

| Référence | Lecture et utilisation |
|---|---|
| [DOFUS, Xélor](https://dofusdb.com/classes/xelor-5), [Pandawa](https://dofusdb.com/classes/pandawa-12), [Féca](https://dofusdb.com/en/classes/feca-1) | Navigation des listes puis fiches individuelles. Base communautaire affichant 3.6.9.9. 22 + 8 + 6 fiches retenues. Les 22 Xélor ne sont pas toutes les variantes du jeu. |
| [WAKFULI, Xélor](https://wakfuli.com/encyclopedia/spells/xelor), [Pandawa](https://wakfuli.com/encyclopedia/spells/pandawa), [Féca](https://wakfuli.com/encyclopedia/spells/feca) | 21 actifs/élémentaires Xélor, 20 passifs Xélor, 8 Pandawa, 6 Féca. Niveau 245 sélectionné. Site non officiel, pas de patch de données certifié. |
| [Guide Xélor — MethodWakfu](https://methodwakfu.com/bien-debuter/classes/la-classe-xelor/) | Affiche 12 janvier 2026. Utile pour comprendre l'infrastructure ; contient des contrats antérieurs à 1.92. Aucune adoption intégrale de son deck recommandé. |
| [Règles générales — MethodWakfu](https://methodwakfu.com/bien-debuter/informations-generales/) | Consultation du retrait PA/PM, de la résistance et des catégories de dégâts. Source communautaire ; utilisée pour modèles explicitement bornés. |
| [Mise à jour 1.87 — Wakfu Wiki](https://wakfu.wiki.gg/wiki/Update_1.87) | Extraits indexés lus. Baisse de dégâts et d'explosivité, limitation de Cadrans, ajustements chiffrés. Étape historique, pas coefficients N245 contemporains. |
| [Mise à jour 1.92 — Wakfu Wiki](https://wakfu.wiki.gg/wiki/Update_1.92) | Extrait indexé détaillé lu ; ouverture de la page complète bloquée en 403. Corrobore Aiguille, Tempus, Suspension et Connaissance du passé visibles dans WAKFULI. |
| [Notes officielles 1.92 — Havre-Enclos](https://www.wakfu.com/fr/mmorpg/actualites/maj/1770251-havre-enclos/details) | Adresse récupérée depuis le lien de l'annonce officielle Steam. Ouverture 403 : **pas présentée comme une lecture directe réussie**. |
| [Annonces officielles WAKFU sur Steam](https://steamcommunity.com/app/215080/allnews/?l=french) | Lecture web et navigateur. 1.92 en ligne le 16 juin ; 1.93 le 22 septembre 2026. Intentions de conception des classes publiées le 15 juillet, distinguées des changements livrés. Agrégateur évolutif : retrouver l'article par titre/date. |
| [Refonte Xélor 2014 — JeuxOnline](https://dofus.jeuxonline.info/actualite/46528/refonte-classe-xelor-annoncee) | Reproduction du texte développeur. Explique notamment la contrepartie temporelle de Flou. Aucun chiffre historique substitué au catalogue moderne. |
| [Guide Unity communautaire, novembre 2024](https://www.reddit.com/r/Dofus/comments/1h0841d) | Définition historique du Téléfrag et de ses remboursements. Non certifiée pour 3.6.9.9. |
| [Variantes Xélor, mai 2026](https://www.reddit.com/r/DOFUS_FRANCE/comments/1tp2r33/xelor_question_variantes_de_sorts/) | Retours individuels sur Complice/Cadran, solo/équipe et adaptation au combat. Pas une enquête statistique. |
| [Réactions à la refonte WAKFU, avril 2021](https://www.reddit.com/r/wakfu/comments/mje0i7) | Un témoignage apprécie une identité plus cohérente autour des PW et déplacements. Réception historique seulement. |
| [Discussion de guide WAKFU 1.79](https://www.reddit.com/r/wakfu/comments/130fkqn) | Un autre témoignage associe une refonte à son départ. Sert à rappeler qu'une règle élégante ne garantit pas l'adhésion des anciens joueurs. |

## Contradictions et décisions prises

| Point | Sources en tension | Décision de l'étude |
|---|---|---|
| Connaissance du passé | Guide : revenus de cycle ; WAKFULI : +50 % PV au Cadran contre +2 PW de coût | La note 1.92 explique le changement. Retenir le bonus PV dans la fiche ; ne pas additionner ancien passif et nouveau revenu inné. |
| Tempus fugit | Guide : transport limité à 4 ; WAKFULI : 6 | Note 1.92 corroborante : six retenu pour la fiche actuelle, quatre historique. |
| Aiguille | Bandeau 4 PA ; effet « jusqu'à 4 » | Note 1.92 précise le reliquat 1–3 accepté à dégâts inchangés. Calculer un coût variable, pas quatre obligatoires ni quatre supplémentaires. |
| Distorsion WAKFU | Guide de classe +100 % par cycle ; page générale +50 % ; note 1.87 historique +100 % | Coefficient contemporain non certifié. Aucun total de burst actuel calculé avec une valeur choisie arbitrairement. |
| Niveau 200 / 245 | Notes d'équilibrage parfois N200 ; WAKFULI affiché N245 | Ne pas interpréter une différence de base comme un buff sans normaliser le niveau. |
| Lucha L'ambrée | Porteur et non-Porteur simultanément dans Conditions | Contradiction vérifiée visuellement. Ne pas déclarer le sort impossible : branches ou opérateurs manquants. |
| Six Roses / Souffle Laiteux | Plusieurs blocs de valeurs et états sans conditions suffisantes | Ne pas sommer ni choisir le coefficient le plus élevé. Simulation fidèle bloquée à ce niveau. |
| Goutte / Orbe / Immunité | Conditions de Bouclier, Berger, Armure de la Paix, Pacifié mal qualifiées | Coûts/effets lisibles conservés ; légalité exacte d'états non certifiée. |
| Dévouement / Réfraction / Propulsion | Plusieurs lignes semblables dans les effets | Branches possibles, pas preuve de double application. |
| DOFUS « zéro lancer par tour » | Présent sur des sorts utilisables avec relance | Sentinelle ou champ incomplet ; valeur traduite par « inconnu ». |
| DOFUS effets numériques bruts | Identifiants secondaires, par exemple bonus de Rayon Obscur | Aucun coefficient inventé à partir d'un identifiant. |
| Rempart DOFUS | Description disponible, réduction chiffrée absente | Ne pas publier de classement de rendement contre Bouclier Féca. |

## Ce que l'évolution apprend sur l'équilibrage

La séquence historique Xélor WAKFU est plus instructive qu'un tier-list. Les notes 1.87 réduisent la puissance offensive. Celles de 1.92 expliquent ensuite que l'investissement initial reste trop lourd et appauvrit les tours suivants. La correction porte alors sur l'accès et les ressources, notamment Aiguille et le Cadran. **Notre déduction : puissance finale et coût de mise en route doivent être mesurés séparément.**

En juillet 2026, Ankama décrit aussi une rigidité Féca qui ne produit pas assez de richesse en contrepartie, et souhaite assouplir certains outils Roublard. La sortie 1.93 annonce la refonte Pandawa et des équilibrages ciblés ; elle ne permet pas d'affirmer que toutes les intentions de juillet ont été livrées. **Notre déduction : ajouter des conditions n'est bénéfique que si elles créent des décisions intéressantes et lisibles.**

Les témoignages historiques divergents sur le Xélor WAKFU ne permettent pas de dire « les joueurs adorent ce kit ». Ils suggèrent de mesurer séparément plaisir des nouveaux joueurs, maîtrise acquise et perte de repères des anciens.

## Ce qu'exigerait une connaissance entièrement certifiée

Pour chaque sort : version du client, niveau, fiche complète avec passifs/équipement, puis observation d'une situation normale et d'un cas limite. Pour les interactions : journal d'événements comprenant dépenses, remboursements, déplacements, états et déclenchements. Tester en particulier cibles mortes, stabilisées, case occupée, double cycle, dégâts absorbés, critiques et plusieurs lanceurs.

L'étude livre une connaissance documentaire approfondie et ses déductions. **Elle ne prétend ni couvrir toutes les classes/variantes/ennemis des deux jeux, ni remplacer leur exécution réelle.** La séparation des inconnues rend le travail réutilisable sans transformer une supposition en règle.
