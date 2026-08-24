# Skill Tree Studio 2.0 — descripteurs d’effets

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

`SkillEffectEditorRegistry` fournit un contrat métier à tous les effets de production : les 33 valeurs de `SpellModSkillTreeEffect.EffectType` et les 13 autres classes concrètes de `SpellModifier` cataloguées.

Chaque `SkillEffectEditorDescriptor` définit : identifiant, nom, classe/type, champs réellement applicables, visibilité guidée, unité, cible, condition, durée, fréquence, empilement, phrase et validation. L’Inspecteur ne maintient pas une seconde liste locale de propriétés par type : il rend uniquement les champs déclarés par le descripteur.

Les 33 types possèdent des libellés distincts et sont regroupés par familles dans le sélecteur. Une valeur historique devenue inerte reste sérialisée sans être effacée et produit un avertissement. La section repliable **Comment fonctionne cet effet ?** expose les règles en lecture seule dans l’onglet **Effets** ; aucun onglet technique supplémentaire n’est créé.

Les bonus de PM utilisent l’unité **PM** et les poussées l’unité **cases**. Pour **Déplacement — du lanceur**, le mode avancé expose aussi l’option **Exiger un chemin dégagé**, réellement consultée par le runtime.

`SkillTreeEffectSummaryService` utilise le registre pour les classes concrètes. Une classe réellement inconnue affiche « descripteur métier manquant », ce qui est une erreur actionnable ; aucun effet connu ne retombe sur « effet spécialisé ». Le validateur bloque une couverture ou un champ de descripteur invalide.

La preview runtime continue d’appeler `SpellCaster`. L’onglet présente d’abord un résumé joueur du sort avant/après, la trace d’effets, les deltas nommés par scénario et les avertissements ; il n’est plus réduit à un JSON brut.
