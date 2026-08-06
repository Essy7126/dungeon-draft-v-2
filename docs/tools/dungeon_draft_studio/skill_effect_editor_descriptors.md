# Skill Tree Studio 2.0 — descripteurs d’effets

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

`SkillEffectEditorRegistry` fournit un contrat métier à tous les effets de production : les 33 valeurs de `SpellModSkillTreeEffect.EffectType` et les 13 autres classes concrètes de `SpellModifier` cataloguées.

Chaque `SkillEffectEditorDescriptor` définit : identifiant, nom, classe/type, champs guidés, unité, cible, condition, durée, fréquence, empilement, phrase et validation. L’inspecteur affiche ces informations avant les propriétés exportées ; Archer/Eagle Eye est donc éditable sans ouvrir le `.tres` manuellement.

`SkillTreeEffectSummaryService` utilise le registre pour les classes concrètes. Une classe réellement inconnue affiche « descripteur métier manquant », ce qui est une erreur actionnable ; aucun effet connu ne retombe sur « effet spécialisé ». Le validateur bloque une couverture ou un champ de descripteur invalide.

La preview runtime continue d’appeler `SpellCaster`. L’onglet présente d’abord un résumé joueur du sort avant/après, la trace d’effets, les deltas nommés par scénario et les avertissements ; il n’est plus réduit à un JSON brut.

