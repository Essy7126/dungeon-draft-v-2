# Rééquilibrage des arbres de compétences v2

## Contrat commun

La valeur de prototype `400` des deux Boules de feu initiales (Elfe Mage et
Mage Pyromancie) est remplacée par `25` dégâts. À 1 PA, portée 14, croix de rayon
2 et terrain de lave, cette base reste au-dessus des sorts initiaux à 5–8 dégâts
sans conserver une exécution automatique. Ce correctif est nécessaire pour que le
profil sans progression ne termine pas automatiquement les six salles.

Les douze arbres conservent leur topologie, leurs exclusions et leurs seize
feuilles finales. Les seuils cumulés sont désormais `0 / 5 / 12 / 21 / 30`.
Chaque nœud a été relu dans son contexte : les gains de portée, zone, poussée,
durée, mobilité, purification, terrain et vulnérabilité déjà perceptibles sont
conservés ; le premier bonus numérique inférieur au plancher utile de chaque
arbre est renforcé à 5 points. Les effets conditionnels restent cumulables
uniquement selon les groupes et modes déjà portés par les ressources.

La puissance utile visée pour un chemin spécialisé est 100 % au rang 1,
120–130 % au rang 2, 140–160 % au rang 3, 170–200 % au rang 4 et 210–260 % au
rang 5. Les capstones existants apportent tous un changement tactique : zone,
terrain persistant, contrôle, mobilité, protection partagée, seconde cible ou
exécution conditionnelle. Aucun nœud ne combine une réduction de PA avec une
hausse de dégâts et de zone.

## Tableau avant / après

| Héros | Arbre et sort de base | Base utile | Choix renforcé | Avant | Après | Gain fonctionnel | Courbe spécialisée R1→R5 |
|---|---|---|---|---:|---:|---|---|
| Elfe | Archer — Tir précis | 2 PA, portée 7, 7 dégâts physiques | Œil d’aigle | +3 dégâts à ≥4 cases | +5 dégâts | le premier embranchement de précision dépasse clairement le tir de base | 100/125/150/190/235 % |
| Elfe | Assassin — Frappe sournoise | 2 PA, portée 1, 7 dégâts physiques | Dans le dos | +4 dégâts arrière | +5 dégâts arrière | la prise de dos devient une récompense tactique nette | 100/125/150/190/235 % |
| Elfe | Mage — Boule de feu | 1 PA, portée 14, croix, 25 dégâts feu + terrain | Cœur incandescent | +3 centre | +5 centre | impact central lisible malgré la valeur du sort de base | 100/120/150/190/240 % |
| Elfe | Soigneur — Soin sylvestre | 2 PA, portée 5, soin mono-cible | Sève abondante / Écorce protectrice | +3 soin / +3 bouclier | +5 soin / +5 bouclier | deux choix R2 de valeur immédiate comparable | 100/125/150/190/235 % |
| Mage | Géomancie — Onde sismique | 2 PA, ligne, 6 dégâts, poussée 1 | Onde renforcée | +2 dégâts de ligne | +5 dégâts de ligne | alternative offensive comparable à +1 poussée | 100/125/150/190/240 % |
| Mage | Pyromancie — Boule de feu | 1 PA, portée 14, croix, 25 dégâts feu + terrain | Conflagration | +2 dégâts de zone | +5 dégâts de zone | différence visible sur chaque cible de l’AOE | 100/125/155/195/250 % |
| Mage | Cryomancie — Mur de glace | 1 PA, portée 6, terrain en ligne | Gel mordant | 3 dégâts à la création | 5 dégâts à la création | branche dégâts comparable à l’extension de deux cellules | 100/125/150/190/240 % |
| Mage | Foudromancie — Tempête orageuse | 3 PA, portée 5, carré 3×3, 7 dégâts | Surcharge | +2 dégâts de zone | +5 dégâts de zone | premier embranchement offensif significatif sur une AOE coûteuse | 100/125/155/195/245 % |
| Guerrier | Assaut — Charge | 2 PA, ligne, déplacement, 5 dégâts | Impact puissant | +3 dégâts | +5 dégâts | choix dégâts comparable au gain de portée | 100/125/150/190/235 % |
| Guerrier | Brutalité — Frappe lourde | 2 PA, portée 1, 8 dégâts | Coup brutal | +3 dégâts | +5 dégâts | la spécialisation mono-cible gagne une identité dès R2 | 100/125/155/195/245 % |
| Guerrier | Rempart — Garde | 2 PA, portée 1, 6 boucliers | Bouclier renforcé | +3 boucliers | +5 boucliers | le choix défensif absorbe réellement un impact supplémentaire | 100/125/155/195/240 % |
| Guerrier | Furie — Tourbillon | 3 PA, adjacence, 5 dégâts de zone | Lames lourdes | +2 dégâts de zone | +5 dégâts de zone | alternative offensive comparable à la poussée circulaire | 100/125/155/195/245 % |

## Audit exhaustif des choix

La notation `=` signifie « effet v1 conservé à l’identique en v2 » parce qu’il
respecte déjà le plancher tactique. Le texte affiché et la donnée runtime sont
alignés pour chaque changement numérique.

### Elfe — Archer

- R2 : Œil d’aigle `+3→+5 dégâts à distance` ; Flèche de recul `= poussée 1`.
- R3 : Longue portée `= +2 portée` ; Tir perforant `= vulnérabilité physique` ; Flèche entravante `= −1 PM` ; Trait d’impact `= collision +4`.
- R4 : Vue parfaite `+3→+5 dégâts à ≥6 cases` ; Stabilisation `+2→+5 dégâts` ; Pointe barbelée `= saignement 2×2` ; Brèche ouverte `= 2 charges` ; Flèche clouante `= −2 PM` ; Recul tactique `= +1 PM` ; Trait de siège `= poussée +1` ; Fracas `= collision +4`.
- R5 : Tir parfait `= portée +1 et dégâts conditionnels +6` ; Trait transperçant `= seconde cible à 50 %` ; Flèche de siège `= poussée 3 et collision 8` ; Flèche d’arrêt `= −2 PM et collision 4`.

### Elfe — Assassin

- R2 : Dans le dos `+4→+5 dégâts arrière` ; Lame venimeuse `= poison 2×2`.
- R3 : Exécutrice `= +4 sous 40 % PV` ; Repli `= +1 PM` ; Empoisonneuse `= poison +1/tour` ; Saboteuse `= −1 PM`.
- R4 : Coup fatal, Ouverture, Allonge elfique, Pas léger, Toxines persistantes, Double dose, Tendon tranché et Affaiblissement `= effets conditionnels/contrôle existants`.
- R5 : Assassinat, Lame fantôme, Venin mortel et Sabotage `= exécution, portée, poison ou contrôle transformant`.

### Elfe — Mage

- R2 : Cœur incandescent `+3→+5 centre` ; Braises persistantes `= terrain +1 tour`.
- R3 : Détonation, Explosion élargie, Incendiaire et Souffle ardent `= centre, zone, brûlure ou poussée`.
- R4 : Noyau ardent, Portée arcanique, Grande explosion, Éclats brûlants, Braises longues, Feu mordant, Souffle puissant et Fracas ardent `= effets existants`.
- R5 : Comète elfique, Nova elfique, Incendie sauvage et Onde explosive `= capstones dégâts/zone/terrain/collision`.

### Elfe — Soigneur

- R2 : Sève abondante `+3→+5 soin` ; Écorce protectrice `+3→+5 bouclier`.
- R3 : Sauveteuse, Régénératrice, Bastion naturel et Garde mobile `= soin conditionnel, régénération, bouclier ou PM`.
- R4 : Miracle mineur, Racines lointaines, Sève longue, Sève riche, Écorce épaisse, Protection partagée, Élan sylvestre et Purification `= effets existants`.
- R5 : Miracle sylvestre, Floraison, Écorce vivante et Élan protecteur `= purge, soin de groupe, protection partagée ou mobilité`.

### Mage — Géomancie

- R2 : Onde renforcée `+2→+5 dégâts de ligne` ; Recul tectonique `= poussée +1`.
- R3 : Fracture, Faille prolongée, Fracasseur et Éboulement `= vulnérabilité, portée, collision ou −1 PM`.
- R4 : Brèche profonde, Fracture durable, Portée tellurique, Secousse puissante, Écrasement, Projection, Terrain instable et Secousse `= effets existants`.
- R5 : Cataclysme, Faille majeure, Impact tectonique et Glissement de terrain `= capstones vulnérabilité/portée/collision/contrôle`.

### Mage — Pyromancie

- R2 : Conflagration `+2→+5 dégâts de zone` ; Brasier durable `= terrain +1 tour`.
- R3 : Noyau instable, Maître des explosions, Incendiaire et Sol ardent `= centre, zone, brûlure ou terrain`.
- R4 : Détonation intense, Projection lointaine, Superficie accrue, Chaleur extrême, Feu dévorant, Braises éternelles, Terrain persistant et Fournaise `= effets existants`.
- R5 : Supernova, Bombardement, Enfer et Mer de flammes `= capstones zone/portée/brûlure/terrain`.

### Mage — Cryomancie

- R2 : Mur étendu `= deux cellules visibles` ; Gel mordant `3→5 dégâts à la création`.
- R3 : Glace tenace, Cristallomancie, Geôlier du froid et Cristallisation `= durée, bouclier, PM ou vulnérabilité`.
- R4 : Mur durable, Projection glaciale, Glace miroir, Passage sûr, Gel profond, Froid tranchant, Fragilité glacée et Point de rupture `= effets existants`.
- R5 : Forteresse gelée, Sanctuaire de glace, Hiver brutal et Prison cristalline `= capstones terrain/protection/contrôle/vulnérabilité`.

### Mage — Foudromancie

- R2 : Surcharge `+2→+5 dégâts de zone` ; Champ statique `= −1 PM`.
- R3 : Cœur de l’orage, Front orageux, Paralysie et Conductivité `= centre, zone, durée ou vulnérabilité`.
- R4 : Impact central, Orage lointain, Supercellule mineure, Haute tension, Entrave majeure, Électricité résiduelle, Charge persistante et Arc secondaire `= effets existants`.
- R5 : Cœur de tonnerre, Supercellule, Paralysie complète et Orage conducteur `= capstones centre/zone/contrôle/chaînage`.

### Guerrier — Assaut

- R2 : Élan prolongé `= +1 portée` ; Impact puissant `+3→+5 dégâts`.
- R3 : Intercepteur, Armure d’élan, Bélier et Percuteur `= mobilité libre, bouclier, poussée ou collision`.
- R4 : Course longue, Repositionnement, Avant-garde, Protection mobile, Projection, Impact lourd, Collision brutale et Plaie d’impact `= effets existants`.
- R5 : Charge tactique, Avant-garde suprême, Bélier de guerre et Impact dévastateur `= capstones mobilité/protection/poussée/collision`.

### Guerrier — Brutalité

- R2 : Coup brutal `+3→+5 dégâts` ; Entaille profonde `= saignement 2×2`.
- R3 : Exécuteur, Brise-armure, Boucher et Plaie ouverte `= exécution, vulnérabilité ou saignement`.
- R4 : Coup fatal, Allonge martiale, Armure fendue, Frappe repoussante, Hémorragie, Coup appuyé, Plaie béante et Tendon sectionné `= effets existants`.
- R5 : Décapitation, Armure pulvérisée, Hémorragie brutale et Plaie incapacitante `= capstones exécution/vulnérabilité/DoT/contrôle`.

### Guerrier — Rempart

- R2 : Bouclier renforcé `+3→+5 boucliers` ; Garde mobile `= +1 PM`.
- R3 : Bastion, Protection partagée, Ordre d’assaut et Purification martiale `= protection, attaque chargée ou purge`.
- R4 : Fortification, Vigilance, Serment, Soutien durable, Commandement, Marche forcée, Nettoyage complet et Garde purifiante `= effets existants`.
- R5 : Forteresse vivante, Serment du protecteur, Ordre de guerre et Protection absolue `= capstones protection de groupe/mobilité/purge`.

### Guerrier — Furie

- R2 : Lames lourdes `+2→+5 dégâts de zone` ; Cercle de force `= poussée 1`.
- R3 : Ravageur, Faucheur, Contrôleur et Projection circulaire `= dégâts, saignement, PM ou poussée`.
- R4 : Tourbillon renforcé, Cercle élargi, Lames dentelées, Moisson longue, Fauchage, Balayage lourd, Onde circulaire et Fracas circulaire `= effets existants`.
- R5 : Tempête d’acier, Moissonneur, Balayage total et Onde de choc `= capstones zone/DoT/contrôle/collision`.

## Validation des chemins

Chaque arbre conserve 2 choix au rang 2, 4 au rang 3, 8 au rang 4 et 4
capstones au rang 5. Le résolveur continue donc d’exposer seize chemins finaux
valides par arbre. Les tests vérifient les 192 feuilles finales, l’absence de
modificateur nul, les seuils et la progression spécialisée/diversifiée.
