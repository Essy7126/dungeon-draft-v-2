import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';

// Modèles fermés de conception : ne charge ni Godot ni les moteurs Ankama.
const results = [];
let assertions = 0;
const eq = (a, b) => { assert.deepEqual(a, b); assertions++; };
const near = (a, b) => { assert.ok(Math.abs(a-b) < 1e-9); assertions++; };
const add = (id, hypothese, resultats) => results.push({id, hypothese, resultats});
const choose = (n,k) => {
  if (k < 0 || k > n) return 0;
  let x=1; for(let i=1;i<=k;i++) x=x*(n-i+1)/i;
  return x;
};

// 1 : une clef n'est pas garantie par sa présence dans le deck.
const access = (n,k,h) => 1-choose(n-k,h)/choose(n,h);
const hands = [15,30].map(n=>({deck:n,copies:3,main:5,acces:access(n,3,5)}));
near(access(30,3,5), 88/203);
eq(access(30,0,5),0); eq(access(5,1,5),1);
add('main_clef','Pioche uniforme sans remise ; trois copies utiles ; aucune sélection.',hands);

// 2 : combiner deux familles est un problème différent de trouver une clef.
const combo = (n,k,h) => 1-2*choose(n-k,h)/choose(n,h)+choose(n-2*k,h)/choose(n,h);
eq(combo(6,3,6),1);
add('main_deux_outils','Trois A et trois B, disjoints ; main de cinq.',[15,30].map(n=>({deck:n,probabilite:combo(n,3,5)})));

// 3 : transférer la protection dans le temps peut aider ou nuire.
const shifted = (a,b)=>.5*a+1.5*b;
eq(shifted(120,40),120); eq(shifted(40,120),200);
add('protection_differee','Impacts finaux hypothétiques de 120/40 ou 40/120 ; aucun soin ni autre réduction.',{
  sans_effet:160,ordre_favorable:shifted(120,40),ordre_defavorable:shifted(40,120)
});

// 4 : coût de lancement et coût net ne se confondent pas.
const refund = (ap, cost, back) => ap < cost ? {legal:false,ap} : {legal:true,ap:ap-cost+back};
eq(refund(0,1,1),{legal:false,ap:0}); eq(refund(1,1,1),{legal:true,ap:1});
add('paiement_initial','Une commande coûte 1 PA puis rend 1 PA ; la copie est détruite.',{
  zero_ap:refund(0,1,1),un_ap:refund(1,1,1),copies_consommees:1
});

// 5 : coût croissant d'une infrastructure persistante.
const bombCosts = [0,1,2].map(existing=>2+existing);
eq(bombCosts.reduce((a,b)=>a+b,0),9);
add('infrastructure','Trois poses successives sans bombe détruite ; au moins deux tours pour respecter deux poses/tour.',{
  couts:bombCosts,total_pa:9,copies_si_adaptation_consommable:3
});

// 6 : exemple de risque Ecaflip, sans extrapoler les bornes non documentées.
const risk = .5+(.6-.4);
near(risk,.7); near(98*risk,68.6);
add('risque_contextuel','Tout ou rien N245 : lanceur 60 % PV, cible 40 %, base 98, sans mitigation.',{
  probabilite_retour:risk,auto_degats_moyens_bruts:98*risk
});

// 7 : conversion Hémophilie, sans appliquer de maîtrise/résistance.
const poison = .04*245*10;
near(poison,98);
add('conversion_poison','Dix niveaux Hémorragie, N245 ; coefficient de la fiche Hémophilie.',{base_poison:poison,categorie:'mêlée',moment:'début du tour de la cible'});

// 8 : prototype original, la charge compte les impacts directs effectifs.
const pressure = packets => {
  let hp=100, charge=4;
  for(const damage of packets){ if(hp<=0) break; hp=Math.max(0,hp-damage); if(damage>0&&hp>0) charge++; }
  return {hp,charge,ultime_prochaine_activation:hp>0&&charge>=6};
};
eq(pressure([40]).hp,pressure([10,10,10,10]).hp);
eq(pressure([40]).ultime_prochaine_activation,false);
eq(pressure([10,10,10,10]).ultime_prochaine_activation,true);
eq(pressure([100,1]).charge,4);
add('charge_par_impact','Prototype Catabase : 100 PV, charge 4, seuil 6 ; pas de charge post-mortem ; aucun sort Ankama simulé.',{
  gros_impact:pressure([40]),petits_impacts:pressure([10,10,10,10]),coup_letal:pressure([100,1])
});

// 9 : déplacer l'origine d'une zone n'équivaut pas à déplacer une cible dedans.
const dist=(a,b)=>Math.abs(a[0]-b[0])+Math.abs(a[1]-b[1]);
const hero=[3,3], target=[4,4], bossBefore=[7,3], bossAfter=[4,3];
const inRing=(cell,origin,r)=>dist(cell,origin)===r;
eq(inRing(target,bossBefore,1),false); eq(inRing(target,bossAfter,1),true);
eq(inRing(hero,bossAfter,1),true);
add('origine_mobile','Prototype : anneau Manhattan exact 1 ; tous les occupants autres que sa source sont concernés.',{
  ennemi_avant:inRing(target,bossBefore,1),ennemi_apres:inRing(target,bossAfter,1),heros_apres:inRing(hero,bossAfter,1)
});

// 10 : la géométrie est figée avant les morts d'un effet simultané.
const actors=[{id:'chef',hp:20},{id:'garde',hp:25},{id:'heros',hp:100}];
const impacted=actors.map(x=>({...x,hp:Math.max(0,x.hp-32)}));
eq(impacted.map(x=>x.hp),[0,0,68]);
add('impact_simultane','Trois entités déjà incluses dans une explosion de 32 ; mourir en premier ne tronque pas la liste.',impacted);

// 11 : conversion des réservoirs existants ; borne brute, pas dégâts moteur.
const bank = (stored, thieves)=>{
  const stolen=Math.min(stored,thieves),left=stored-stolen;
  return {charges_perdues:stolen,degats_bruts:22*left,soins_ennemis_max:12*stolen};
};
eq(bank(6,0),{charges_perdues:0,degats_bruts:132,soins_ennemis_max:0});
eq(bank(6,3),{charges_perdues:3,degats_bruts:66,soins_ennemis_max:36});
eq(bank(1,3).charges_perdues,1);
add('reservoirs_existants','Catalogue/règles locaux : 6 PA stockés, décharge 1 PA, 22/charge, vol 1 et soin ≤12 par ennemi proche.',{
  protege:bank(6,0),trois_voleurs:bank(6,3),rendement_brut_par_pa_total:132/7,
  ecart_pression_max:132-66+36
});

// 12 : borne d'attrition, sans IA, portée, blocage ou variance.
const demand=(hp,heal,heals,perCard)=>Math.ceil((hp+heal*heals)/perCard);
eq(demand(360,60,0,30),12); eq(demand(360,60,3,30),18);
add('budget_soins','Boss original 360 PV ; coups effectifs 30/copie ; soin 60 ; coût de 2 PA/copie ; aucune autre défense.',{
  aucun_soin:{cartes:12,pa:24},trois_soins:{cartes:18,pa:36},
  economie_copies_par_soin_empeche:2,
  soin_illimite:'aucune borne de stock garantie sans hypothèse de rythme de dégâts'
});

// 13 : droit au butin rattaché à l'identité initiale, non aux morts.
const original=new Set(['a','b']), paid=new Set();
const loot=[];
for(const id of ['a','a','invocation','b','a','invocation']){
  const eligible=original.has(id)&&!paid.has(id);
  if(eligible)paid.add(id);
  loot.push({id,drop:eligible});
}
eq(loot.filter(x=>x.drop).length,2);
add('butin_unique','Proposition : seuls les ennemis initiaux ont une éligibilité ; résurrection conserve identité ; invocation ne crée pas de droit.',loot);

// 14 : un plafond simultané n'est pas un plafond d'attrition.
const waves = turns=>Math.floor((turns-1)/4)+1;
eq(waves(1),1);eq(waves(13),4);
add('renforts_bornes','Exemple original : appel T1 puis chaque quatre tours, renfort tué avant appel suivant ; plafond vivant jamais atteint.',{
  appels_en_13_tours:waves(13),avec_budget_total_deux:Math.min(2,waves(13)),
  conclusion:'le plafond vivant seul ne borne pas le nombre total de renforts'
});

// 15 : transposer un seuil collectif au solo peut le rendre inaccessible.
const trace=[];let p=0;
for(let turn=1;turn<=12;turn++){p=.5*p+3;trace.push({turn,p});}
eq(trace.every(x=>x.p<6),true);
add('seuil_solo','Prototype original : moitié de réserve conservée, +3/t, seuil 12 ; aucune dépense ni arrondi.',{
  trace,limite:6,seuil:12,accessible:false,
  variante_seuil_5_premier_tour:trace.find(x=>x.p>=5).turn
});

// 16 : la résolution d'une clef exige au moins une voie garantie.
const canUnlock=({cardInHand,freeRoomAction,ap,roomCost})=>cardInHand||(freeRoomAction&&ap>=roomCost);
eq(canUnlock({cardInHand:false,freeRoomAction:false,ap:6,roomCost:2}),false);
eq(canUnlock({cardInHand:false,freeRoomAction:true,ap:2,roomCost:2}),true);
eq(canUnlock({cardInHand:false,freeRoomAction:true,ap:1,roomCost:2}),false);
add('voie_de_secours','Proposition : commande de salle réutilisable coûtant 2 PA ; son accès spatial reste à vérifier dans Godot.',{
  sans_carte_sans_commande:false,sans_carte_commande_2_pa:true,
  limite:'la formule ne prouve ni un chemin libre ni la survie jusqu’au levier'
});

const report={date:'2026-09-25',portee:'Modèles documentaires et propositions ; aucun moteur de jeu exécuté.',cas:results.length,assertions,resultats:results};
writeFileSync(new URL('./resultats_calcules.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(`${results.length} cas ; ${assertions} assertions réussies.`);
console.log(JSON.stringify({hands,combos:[15,30].map(n=>combo(n,3,5)),reservoir:report.resultats.find(x=>x.id==='reservoirs_existants').resultats},null,2));
