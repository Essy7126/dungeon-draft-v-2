# Blocage ImageGen avec référence — diagnostic local

**Résolu le 10 septembre 2026 à 18 h 42.** Le constat initial ci-dessous est
historique ; la résolution et les vérifications figurent à la fin.

Constat au 10 septembre 2026, 18 h 07 Europe/Paris. Projet : Git `2473c335`.

## Essai et résultat

L'utilisateur a réattaché le PNG Passe-rive. Le fichier joint est visible et son
chemin local est fourni :
`C:/Users/paolo/AppData/Local/Temp/codex-clipboard-989de287-b1bd-4712-b80e-c4d39f750509.png`.
L'appel ImageGen utilisant cette référence échoue avant génération, comme avec
la copie du projet. Aucun nouveau dessin de contact ni animation n'a été produit.
Un nouvel envoi de l'image n'est pas une solution vérifiée.

## Preuves lues

`C:/Users/paolo/.codex/.sandbox/setup_error.json` :

```json
{"code":"helper_unknown_error","message":"apply deny-read ACLs"}
```

Extrait ciblé de `C:/Users/paolo/.codex/.sandbox/sandbox.2026-09-10.log`,
à 17:59:34 heure locale :

```text
setup error: apply deny-read ACLs
0: parse deny-read ACL state C:\Users\paolo\.codex\.sandbox\deny_read_acl_state.json
1: expected value at line 1 column 1
setup refresh: exited with status ExitStatus(ExitStatus(1))
```

La lecture hexadécimale de `deny_read_acl_state.json` montre exactement 22 octets
`00`, sans JSON. Sa date de dernière écriture affichée est le 28 août 2026 à
18:42:53 ; cette date ne prouve ni le moment ni la cause de la corruption.
Le journal identifie l'échec de parsing comme cause immédiate du blocage.
La cause de la corruption n'est pas déterminée.

## Limites et reprise

Diagnostic en lecture seule : aucun état de sandbox, ACL, mode de permissions ou
configuration Codex n'a été modifié. Aucun secret consulté, aucune clé/API externe
utilisée. Pas de réparation improvisée du fichier d'état des restrictions.

La [documentation officielle OpenAI](https://learn.chatgpt.com/docs/windows/windows-sandbox)
recommande, quand le sandbox cesse de fonctionner, de redémarrer Codex puis de
relancer sa configuration élevée si nécessaire. Elle ne fournit pas de procédure
spécifique de récupération de ce fichier corrompu ; un redémarrage seul ne garantit
donc pas la réparation. Si l'erreur persiste, utiliser cet extrait pour un
diagnostic/support ciblé, sans transmettre le répertoire `.sandbox-secrets`.

Après réparation : vérifier une lecture sandbox simple, puis exécuter une seule
fois `contact_prompt.txt` avec `reference_choisie.png`. Examiner la fidélité du
visage, de la tenue et des équipements ainsi que les appuis avant toute séquence.

## Résolution vérifiée après la demande de réparation

1. `windowsSandbox/setupStart`, mode `elevated`, a été exécuté via l'app-server
   local officiel. La notification a annoncé `success: true`, mais le test de
   lecture a encore échoué sur le JSON corrompu. Ce succès de configuration seul
   n'était donc pas une réparation du problème observé.
2. Après vérification que le fichier contenait toujours exactement 22 octets
   nuls, il a été mis de côté avec sauvegarde vérifiée par SHA-256 :
   `C:/Users/paolo/.codex/.sandbox/deny_read_acl_state.corrupt-20260910-184150.bak`.
   Aucun contenu JSON de remplacement n'a été inventé. Codex a lui-même recréé
   le fichier lors du prochain lancement sandbox.
3. Le fichier recréé est un JSON valide, avec propriété `principals`.
   L'empreinte de `config.toml` est inchangée ; les ACL contrôlées sur `.codex`,
   la racine du projet et `.git` sont identiques avant/après. Un essai de création
   d'un fichier temporaire directement dans Documents, hors de la racine du
   projet, a été refusé comme attendu. Ce contrôle ciblé n'est pas un audit
   exhaustif des permissions de tout le poste.
4. Lecture de la référence et du prompt sans élévation : succès. `view_image` :
   succès. ImageGen avec référence : succès, premier dessin d'estoc enregistré
   dans `contact_estoc_v1.png`. La génération produit toutefois un RGB avec
   damier peint ; cette limite du livrable artistique est distincte de l'incident
   d'accès maintenant résolu.

Preuves locales : `artifacts/dev/codex-sandbox-repair/repair_before.json` et
`repair_after.json`. La mise de côté du cache est une réparation locale ciblée,
pas une procédure de récupération spécifiquement documentée par OpenAI.
