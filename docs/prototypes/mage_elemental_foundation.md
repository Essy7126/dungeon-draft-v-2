# Fondation élémentaire du Mage

## Identité

Le Mage du trio fixe est un **Mage de combat élémentaire**. Il reste un
lanceur de sorts pur, sans attaque physique ni énergie dédiée. Son identité
tactique repose sur quatre disciplines indépendantes :

1. **Pyromancie** (`mage_fire`) — dégâts, explosions et feu persistant ;
2. **Cryomancie** (`mage_ice`) — obstacles, ralentissement et verrouillage
   spatial ;
3. **Foudromancie** (`mage_lightning`) — zone, saturation et propagation
   future ;
4. **Géomancie** (`mage_earth`) — impact, poussée et protection future.

Ces identifiants sont propres au Mage. En particulier, `mage_fire` et
`mage_lightning` ne partagent aucun état avec la discipline `mage` de l’Elfe.
Les quatre disciplines possèdent uniquement leur rang 1 sans seuil suivant ni
choix. Elles peuvent accumuler de l’XP, mais ne produisent donc aucun écran de
progression incomplet.

## Loadout initial

Les quatre sorts sont connus et équipés dans cet ordre :

| Emplacement | Sort | `spell_id` | `discipline_id` |
| --- | --- | --- | --- |
| 1 | Boule de feu | `mage_fireball` | `mage_fire` |
| 2 | Mur de glace | `mage_ice_wall` | `mage_ice` |
| 3 | Tempête orageuse | `mage_thunderstorm` | `mage_lightning` |
| 4 | Onde sismique | `mage_seismic_wave` | `mage_earth` |

La Boule de feu du Mage reste distincte de `elf_fireball` et conserve son
gameplay, son VFX et son audio historiques. Le Mur de glace conserve sa pose de
terrain validée tout en recevant l’identité stable du Mage.

## Tempête orageuse

Paramètres de production :

- coût : 3 PA ;
- portée : 5 avec ligne de vue ;
- cible : ennemi ou cellule libre ;
- zone : carré de rayon 1, soit 3 × 3 ;
- élément : `LIGHTNING` ;
- dégâts : 7 par cible ;
- délai d’impact : 0,31 seconde ;
- aucun terrain, statut, drain, déplacement ou impact secondaire.

Le pipeline reste entièrement data-driven. `Spell.impact_delay_seconds`
détermine le délai et `SpellCaster.begin_cast()` engage les coûts au release
sans appliquer les effets. Un `SpellImpactScheduler` appartenant à la bataille
déclenche ensuite `SpellCaster.resolve_cast()` exactement une fois. Le contexte
refuse une seconde résolution, ce qui empêche doubles dégâts, doubles rapports
et double XP.

Le Mage joue `DD_Mage_Cast` et atteint son release absolu à `0,933333 s`. À ce
moment :

1. les coûts et la cible sont validés ;
2. le VFX est instancié sur le centre logique de la cellule ciblée ;
3. un Timer déterministe de `0,31 s` est armé ;
4. l’impact résout une fois toutes les cibles encore présentes dans le carré.

La mort du Mage après le release n’annule pas le contexte engagé. En revanche,
la destruction de la bataille détruit le scheduler et ses Timers enfants :
aucune callback ne survit au nettoyage de salle ou de run.

Le VFX reste sans autorité de gameplay. Sa scène autonome joue `cast` pendant
0,80 seconde, émet son signal visuel `impact_reached` vers 0,31 seconde, puis se
libère. Son watchdog est fixé à 1,5 seconde et `cancel()` ne produit aucun
impact visuel tardif. Les éclairs multiples sont uniquement graphiques.

## Onde sismique

Paramètres de production :

- coût : 2 PA ;
- portée : 3 avec ligne de vue ;
- cible : ennemi ou cellule libre sur le même axe cardinal ;
- forme : ligne d’une cellule de large depuis le Mage jusqu’à la cellule ;
- dégâts : 6 ;
- élément : `EARTH` ;
- poussée : une case, loin du Mage, pour chaque ennemi touché ;
- aucun terrain, statut, bouclier automatique ou rang 2.

`EARTH` est ajouté en fin de l’énum `Spell.Element` afin de préserver toutes les
valeurs numériques historiques. Les résistances élémentaires restent
data-driven et aucune interaction Terre supplémentaire n’est inventée.

La poussée réutilise `_push_unit`, donc respecte obstacles, unités, limites de
grille et collisions existantes. Une poussée impossible ne rend pas le cast
invalide : les dégâts déjà résolus restent valides.

Le VFX final de Géomancie reste à produire. Aucun asset artistique complexe ou
feedback de sol sémantiquement inadapté n’a été ajouté dans ce lot.

## XP et cycle de run

`CharacterProgressionService` crédite exactement `+1 XP` à la discipline du
sort après un `spell_cast` réussi. L’attribution est liée à l’instance runtime
exacte du lanceur :

- plusieurs cibles de Tempête orageuse donnent toujours une seule XP ;
- l’Elfe et le Gardien ne reçoivent rien lors d’un cast du Mage ;
- les quatre progressions du Mage sont indépendantes entre elles ;
- l’XP persiste entre les salles via le même `CharacterRunState` ;
- une nouvelle run ou `cleanup_run_state()` recrée des progressions à zéro.

## Intégration au trio

L’ordre reste Elfe → Mage → Gardien. La barre d’action du Mage présente
exactement quatre boutons et masque l’attaque physique via
`basic_attack_enabled = false`, sans branche sur `unit_id` ou un nom affiché.

L’écran de présentation lit les quatre disciplines depuis `UnitData`, affiche
le rôle « Mage de combat élémentaire » et ne montre aucun badge provisoire sur
le Mage. Le Gardien reste le seul membre portant son badge provisoire.

## Limites et prochaine étape

- Validation graphique native recommandée pour la calibration additive de
  Tempête orageuse sur les décors réels.
- Le feedback visuel final d’Onde sismique reste à produire.
- Aucun rang 2, `SkillUpgradeData`, nouvelle énergie ou sauvegarde persistante
  n’est défini ici.
- Prochaine étape : conception, simulation puis équilibrage des rangs 2 des
  quatre disciplines du Mage.
