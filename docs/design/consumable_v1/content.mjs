// Authoritative proposed V1 manifest. Independent of the public Godot rules.
export const rules = {
  version: '1.0.1-theory', source_commit: '6a500c545f04d3e4c53a99d3643d0c4d844e303f',
  initialCards: 15, deckCap: 30, copiesPerFamily: 3, initialGold: 40,
  ap: 4, mp: 3, hand: 5, grid: 7,
  fallbackDamage: .28, fallbackGuard: .25, guardCap: 2.5, resistanceCap: .4, retaliation: .25,
  collapseStart: 9, collapseStep: .025, turnLimit: 24,
  hp: [110,135,165,200,240,290,350,420,500,600,635,675],
  prowess: [18,22,27,33,40,48,57,68,82,100,106,112],
  xp: [100,125,145,175,195,215,245,265,295,325,355,345],
  xpThresholds: [0,100,220,360,520,700,900,1120,1360,1700,1990,2300],
  attributeLevels: [2,4,6,8,10,12], trainingLevels: [4,8,12],
  attributes: { power:.05, vitality:.06, resolveArmor:.02, resolveGuard:.05 },
  loot: {
    sizes:[2,2,2,1,1,1,1], tiers:['normal','normal','elite','rare','legendary','god','immortal'],
    rates:[[1,.50,.05,.005,0,0,0],[1,.60,.10,.015,.001,0,0],[1,.75,.18,.04,.004,.0003,0],[1,.90,.28,.08,.01,.0015,.0002]],
    gear:[.06,.08,.10,.12], relic:[.002,.004,.008,.012], nativeOrShared:.7,
  },
  economy: { goldNormal:35, goldElite:65, bagPrice:36, bagCards:6, bagsPerVisit:2,
    normalSingle:8, tradeInput:3, tradesPerVisit:2, healPrice:25, healFraction:.30,
    freeRefugeHeal:.35, freePrebossHeal:.50, familyRespec:35,
    sell:{normal:1,elite:3,rare:10,legendary:25,god:60,immortal:120},
    buy:{normal:8} },
};
export const classes = [
  {id:'assassin',name:'Assassin',passive:'Premier impact direct sur une cible isolée : +0,25 P.',specs:['execution','ambush'],starters:['a01','a02','a04','n02','n03']},
  {id:'gardien',name:'Gardien',passive:'La première attaque ennemie absorbée au moins en partie par la garde, chaque tour, renvoie 0,25 P physiques à son auteur.',specs:['bastion','crusher'],starters:['g01','g02','g03','n05','n03']},
  {id:'arpenteur',name:'Arpenteur',passive:'Premier impact direct à distance 3 ou plus : +1 PM.',specs:['sniper','skirmish'],starters:['r01','r02','r03','n02','n03']},
  {id:'thaumaturge',name:'Thaumaturge',passive:'Première marque, brûlure ou entrave appliquée : +0,20 P de garde.',specs:['pyre','frost'],starters:['t01','t02','t03','n02','n03']},
];
export const specs = {
  execution:'Premier impact sur une cible à 35 % PV ou moins : +0,30 P.',
  ambush:'Premier impact après deux cases parcourues : +0,30 P de garde.',
  bastion:'Première garde produite par une carte du tour : +25 %.',
  crusher:'Première cible effectivement poussée : subit 0,25 P physiques supplémentaires.',
  sniper:'Premier impact à distance 4 ou plus : +0,25 P.',
  skirmish:'Premier impact après deux cases parcourues : +1 PM.',
  pyre:'Première brûlure appliquée par tour : +0,10 P par tic.',
  frost:'Première entrave appliquée par tour : +0,30 P de garde.',
};
// id, name, class, rarity, AP, min range, max range, damage coefficient, opcode, amount, extra.
const rows = [
  ['n01','Estoc','shared','normal',1,1,1,.55,'hit',0,{}],
  ['n02','Garde brève','shared','normal',1,0,0,0,'guard',.45,{}],
  ['n03','Pas latéral','shared','normal',1,1,2,0,'move',2,{}],
  ['n04','Heurt','shared','normal',1,1,1,.25,'push',1,{}],
  ['n05','Trait court','shared','normal',1,2,4,.45,'hit',0,{}],
  ['n06','Repérage','shared','normal',1,1,4,.20,'mark',.35,{}],
  ['n07','Entrave légère','shared','normal',1,1,3,.20,'slow',1,{}],
  ['n08','Recentrage','shared','normal',1,0,0,0,'draw',2,{}],
  ['a01','Ouvrir la garde','assassin','normal',1,1,2,.35,'mark',.45,{}],
  ['a02','Frapper la faille','assassin','normal',2,1,1,.95,'hit',0,{condition:'marked',bonus:.55}],
  ['a03','Entaille tenace','assassin','normal',2,1,1,.70,'burn',.15,{duration:2}],
  ['a04','Attaque oblique','assassin','normal',2,1,1,1.05,'hit',0,{condition:'moved',bonus:.35}],
  ['g01','Garde ferme','gardien','normal',2,0,0,0,'guard',1.15,{}],
  ['g02','Heurt du rempart','gardien','normal',2,1,1,1.0,'hit',0,{condition:'guarded',bonus:.50}],
  ['g03','Repousser','gardien','normal',2,1,1,.80,'push',2,{}],
  ['g04','Ramener au front','gardien','normal',1,2,3,.20,'pull',1,{}],
  ['r01','Trait tendu','arpenteur','normal',2,2,5,1.0,'hit',0,{}],
  ['r02','Trait de recul','arpenteur','normal',2,2,4,.70,'push',1,{}],
  ['r03','Flèche entravante','arpenteur','normal',2,2,4,.60,'slow',2,{}],
  ['r04','Volée croisée','arpenteur','normal',3,2,4,.60,'hit',0,{shape:'cross'}],
  ['t01','Trait de givre','thaumaturge','normal',2,1,4,.65,'slow',1,{}],
  ['t02','Braise tenace','thaumaturge','normal',2,1,3,.55,'burn',.18,{duration:2}],
  ['t03','Sceau ombreux','thaumaturge','normal',1,1,4,.25,'mark',.40,{}],
  ['t04','Éclat de braise','thaumaturge','normal',3,1,3,.65,'hit',0,{shape:'cross'}],
  ['a05','Bond spectral','assassin','elite',2,1,3,0,'blink',3,{}],
  ['a06','Dernier verdict','assassin','elite',3,1,2,1.30,'hit',0,{condition:'execute',bonus:.70}],
  ['a07','Pointe franche','assassin','elite',2,1,3,.90,'hit',0,{pierce:1}],
  ['g05','Contre préparé','gardien','elite',2,0,0,0,'counter',.90,{counter:.50}],
  ['g06','Choc de masse','gardien','elite',2,1,1,.90,'push',2,{}],
  ['g07','Dette du bronze','gardien','elite',3,1,2,1.20,'hit',0,{condition:'absorbed',bonus:.50}],
  ['r05','Au-delà du front','arpenteur','elite',2,1,4,0,'blink',4,{}],
  ['r06','Pluie de pointes','arpenteur','elite',3,2,5,.85,'hit',0,{shape:'cross'}],
  ['r07','Trait harpon','arpenteur','elite',2,2,5,.55,'pull',2,{}],
  ['t05','Bûcher des ombres','thaumaturge','elite',2,1,4,0,'firefield',.35,{shape:'cross',duration:2}],
  ['t06','Jardin de givre','thaumaturge','elite',2,1,4,0,'icefield',1,{shape:'cross',duration:2}],
  ['t07','Prélèvement','thaumaturge','elite',2,1,3,.75,'drain',.50,{}],
  ['a08','Couper le souffle','assassin','rare',2,1,3,.70,'disrupt',.50,{}],
  ['a09','Sommeil marqué','assassin','rare',3,1,3,0,'stasis',1,{}],
  ['g08','Bastion vivant','gardien','rare',3,0,0,0,'guard',1.90,{}],
  ['g09','Répercussion','gardien','rare',2,1,3,.50,'guardburst',.60,{cap:1.20}],
  ['r08','Permutation','arpenteur','rare',2,1,5,0,'swap',0,{}],
  ['r09','La longue vue','arpenteur','rare',3,3,6,1.75,'hit',0,{}],
  ['t08','Convergence','thaumaturge','rare',3,1,4,.80,'converge',1,{shape:'cross'}],
  ['t09','Résonance du sceau','thaumaturge','rare',3,1,4,.90,'hit',0,{condition:'marked',bonus:.80}],
  ['l01','Orage du passage','shared','legendary',3,0,0,1.10,'storm',0,{shape:'radius2',type:'magic'}],
  ['l02','Grâce du bronze','shared','legendary',2,0,0,0,'heal',1.50,{shield:.50}],
  ['d01','Décret du dernier souffle','shared','god',3,0,0,0,'edict',1,{}],
  ['i01','Seconde aurore','shared','immortal',4,0,0,0,'renew',.60,{shield:1,endTurn:true}],
];
export const cards = rows.map(([id,name,affinity,rarity,ap,min,max,damage,op,amount,extra]) => {
  let upgrade = damage > 0 ? {damage:damage+.15} : ['guard','counter','heal'].includes(op) ? {amount:amount+.25}
    : ['move','blink'].includes(op) ? {max:max+1,amount:amount+1}
    : op==='draw' ? {amount:amount+1} : op==='icefield' ? {duration:3}
    : op==='firefield' ? {amount:amount+.10} : op==='swap'||op==='stasis' ? {max:max+1}
    : op==='edict' ? {shield:.60} : op==='renew' ? {amount:.75} : {};
  return {id,name,affinity,rarity,ap,min,max,damage,op,amount,type:affinity==='thaumaturge'?'magic':'physical',shape:'single',...extra,upgrade};
});
export const cardById = Object.fromEntries(cards.map(c=>[c.id,c]));
export const equipment = [
  ['w_blade','Lame des brèches','weapon',1,55,{melee:.12}],
  ['w_bow','Arc des longues rives','weapon',1,60,{ranged:.10,range:1,mp:-1}],
  ['w_staff','Bâton des braises','weapon',1,55,{magic:.12}],
  ['b_leather','Cuir du passage','body',1,50,{hp:.12}],
  ['b_plate','Cuirasse pesante','body',2,65,{armor:.12,mp:-1}],
  ['b_robe','Robe de cendre','body',2,65,{magicResist:.12,guard:.10}],
  ['h_watch','Masque du guetteur','head',1,65,{hand:1}],
  ['h_bronze','Casque du seuil','head',1,50,{openingShield:.60}],
  ['h_sage','Diadème patient','head',2,55,{guard:.15}],
  ['f_quick','Sandales du détour','feet',1,55,{mp:1}],
  ['f_brace','Solerets du rempart','feet',2,60,{melee:.08,armor:.04}],
  ['f_flow','Bottes du reflux','feet',2,65,{ranged:.06,mp:1,guard:-.10}],
  ['s_life','Ceinture des vivants','belt',1,55,{hp:.16}],
  ['s_care','Trousse du passeur','belt',2,55,{healing:.30,hp:.04}],
  ['s_guard','Sangle de bronze','belt',2,55,{guard:.20}],
  ['j_cup','Pendentif écarlate','amulet',3,80,{lifesteal:.10}],
  ['j_shard','Éclat téméraire','amulet',3,75,{damage:.08,hp:-.06}],
  ['j_eye','Œil des distances','amulet',3,80,{range:1,firstHitReduction:.12}],
].map(([id,name,slot,stage,price,mods])=>({id,name,slot,stage,price,mods}));
export const relics = [
  ['thread','Fil du détour',90,'Le premier déplacement par carte de chaque tour rend 1 PM.'],
  ['bronze','Urne patiente',95,'Si de la garde a absorbé des dégâts, gagne 0,25 P de garde au prochain tour.'],
  ['embers','Mèche obstinée',95,'Les brûlures et zones de feu infligent +0,10 P par tic.'],
  ['obole','Obole fendue',90,'Une élimination directe rapporte 4 or, maximum 20 par combat.'],
  ['archive','Agrafe des archives',95,'La première carte à 3 PA ou plus du combat coûte 1 PA de moins.'],
  ['mirror','Miroir du bronze',100,'La première attaque reçue de chaque combat renvoie 0,40 P ; aucun déclenchement récursif.'],
  ['cup','Coupe des blessures',100,'Les deux premières éliminations directes du combat soignent chacune 0,35 P.'],
  ['seal','Sceau du chasseur',95,'Une marque appliquée gagne +0,20 P de bonus au prochain impact.'],
].map(([id,name,price,rule])=>({id,name,price,rule}));
export const enemyTypes = {
  brute:{name:'Brute',weight:3,attack:.10,range:1,mp:2,type:'physical',armor:.08},
  archer:{name:'Archer',weight:1.2,attack:.08,range:4,mp:1,type:'physical',armor:0},
  hound:{name:'Molosse',weight:2.4,attack:.08,range:1,mp:3,type:'physical',armor:0},
  mage:{name:'Lamie',weight:1.8,attack:.08,range:3,mp:2,type:'magic',armor:0},
  priest:{name:'Officiant',weight:1.5,attack:.055,range:3,mp:1,type:'magic',armor:0,support:.25},
  guard:{name:'Porte-égide',weight:2.5,attack:.09,range:1,mp:2,type:'physical',armor:.20},
  boss:{name:'Pâris — prototype',weight:7,attack:.14,range:3,mp:2,type:'physical',armor:.10,boss:true},
};
export const maps = {
  plain:{name:'Le seuil',walls:[],hazard:'none'},
  pillars:{name:'Les colonnes',walls:[[2,2],[4,2],[2,4],[4,4]],hazard:'none'},
  forge:{name:'La presse',walls:[[2,2],[4,2],[2,4],[4,4]],hazard:'forge'},
  garden:{name:'Le jardin',walls:[[2,3],[4,3]],hazard:'garden'},
  convoy:{name:'Le convoi',walls:[[2,2],[4,2],[2,4],[4,4]],hazard:'convoy'},
  hourglass:{name:'Le sablier',walls:[[2,2],[4,2],[2,4],[4,4]],hazard:'hourglass'},
  reservoir:{name:'Les réservoirs',walls:[[2,2],[4,2],[2,4],[4,4]],hazard:'reservoir'},
};
const routeRows = [
  [1,'normal','plain',1.4,['brute']],
  [2,'normal','pillars',3.0,['brute','archer']],
  [3,'normal','plain',4.2,['archer','brute','brute']],
  [5,'normal','forge',6.0,['mage','brute','hound']],
  [6,'elite','hourglass',8.4,['brute','archer','hound','priest']],
  [8,'normal','garden',6.6,['priest','hound','brute']],
  [10,'elite','pillars',6.8,['guard','brute']],
  [12,'normal','convoy',6.6,['priest','archer','archer','brute']],
  [13,'normal','reservoir',6.0,['mage','hound','guard']],
  [15,'elite','pillars',8.4,['guard','archer','mage','priest']],
  [17,'normal','garden',5.4,['archer','hound','mage']],
  [20,'boss','pillars',12.0,['boss','mage','hound']],
];
export const route = routeRows.map(([depth,kind,map,hpBudget,roster],index)=>({index:index+1,level:index+1,depth,kind,map,hpBudget,roster,
  shopAfter:[3,5,7,10,11].includes(index+1),refugeAfter:[5,7,10,11].includes(index+1),
  relicGuaranteed:[5,10].includes(index+1)}));
export const ranks = ['normal','elite','rare','legendary','god','immortal'];
export function upgradedCard(id,trained=[]) {const c=cardById[id];if(!c)throw Error(`Unknown card ${id}`);return trained.includes(id)?{...c,...c.upgrade}:c;}
export const manifest = {rules,classes,specs,cards,equipment,relics,enemyTypes,maps,route};
