# Contrat de déploiement LAN Observatory

## Limites de confiance

- Source de production : exclusivement `origin/main` après fetch.
- Construction : checkout détaché, propre et jetable.
- Publication : uniquement une release entièrement validée et adressée par SHA.
- Service : fichiers de `dist/` de la release active, jamais le dépôt.
- Échec : pointeur actif conservé ou restauré ; état `update_failed` public et
  message sans chemin privé.

Le serveur Node n’accepte que `GET` et `HEAD`, refuse les traversées et les
répertoires, résout les liens réels sous `dist`, applique `nosniff`, refuse les
frames, n’ajoute aucun CORS et ne possède aucune route d’écriture. `index.html`
et `latest.json` sont `no-store`, les assets Vite hashés sont `immutable`, les
autres fichiers sont `no-cache`.

Endpoints :

```text
GET /__observatory/healthz
GET /__observatory/status.json
GET / et fichiers statiques sous dist/
```

La liaison `0.0.0.0` rend le service techniquement joignable sur le LAN. La
règle Windows optionnelle reste limitée à TCP/8080, profil privé et sous-réseau
local. Aucun runner auto-hébergé, token, secret, NAT ou hébergement Internet
n’appartient à ce contrat.
