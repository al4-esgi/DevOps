# Incident Log — Étape 6

## Incident #001

**Date :** 2026-05-19  
**Durée :** ~8 minutes (détecté : 14:32 UTC — résolu : 14:40 UTC)  
**Sévérité :** Haute — service n8n inaccessible en production  
**Équipe :** DevOps TP1

---

### Symptômes observés

- `https://n8n.devops.vlxx.fr` retourne HTTP 502 Bad Gateway
- Uptime Kuma (status.devops.vlxx.fr) déclenche une alerte « DOWN » pour le monitor n8n
- Les smoke tests CronJob échouent avec `[FAIL] n8n → HTTP 000`
- Dozzle montre que le pod `n8n-*` est en état `CrashLoopBackOff`

---

### Cause racine

Le pod n8n a tenté de démarrer avant que le pod PostgreSQL soit prêt à accepter des connexions.  
La `readinessProbe` de postgres n'avait pas encore passé (`initialDelaySeconds: 10`) mais n8n
essayait déjà de se connecter à la base, provoquant une erreur de connexion fatale qui faisait
crasher le processus Node.js. k8s relanças le pod en boucle (CrashLoopBackOff) avec un
back-off exponentiel, d'où l'indisponibilité prolongée.

**Root cause technique :** absence d'`initContainer` ou de `depends_on` (équivalent k8s) entre
n8n et postgres dans le manifest de déploiement.

---

### Résolution

1. Ajout d'un `initContainer` dans `k3s/n8n/deployment.yaml` qui attend que postgres soit
   accessible avant de démarrer le conteneur principal n8n :
   ```yaml
   initContainers:
     - name: wait-for-postgres
       image: busybox:1.36
       command: ['sh', '-c', 'until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done']
   ```
2. `kubectl rollout restart deployment/n8n -n devops`
3. Vérification dans Dozzle : pod démarré proprement, logs n8n sans erreur de connexion DB.
4. Uptime Kuma repasse en vert sous 2 minutes après le redémarrage.

---

### Ce qui aurait été fait différemment

| Point d'amélioration | Action corrective |
|---|---|
| Pas de dépendance explicite entre n8n et postgres | Ajouter l'`initContainer` dès la première configuration du déploiement |
| Alerte reçue uniquement après 5 min (délai Uptime Kuma par défaut) | Réduire l'intervalle de check à 60s dans Uptime Kuma pour les services critiques |
| Aucun runbook documenté | Rédiger un runbook de redémarrage manuel pour chaque service dans le `README.md` |
| La `livenessProbe` n8n pointait sur `/healthz` sans vérifier la connectivité DB | Implémenter un endpoint `/healthz` custom dans n8n qui valide la connexion base |
| Pas de notification d'équipe | Configurer les alertes Uptime Kuma vers un canal Slack/Discord de l'équipe |

---

## Uptime Kuma — Endpoints enregistrés

| Monitor | URL | Intervalle | Statut attendu |
|---|---|---|---|
| n8n | https://n8n.devops.vlxx.fr/healthz | 60s | HTTP 200 |
| Dozzle | https://dozzle.devops.vlxx.fr/ | 60s | HTTP 200 |
| Uptime Kuma | https://status.devops.vlxx.fr/ | 60s | HTTP 200 |
| Caddy (probe) | http://167.235.145.88/ | 60s | HTTP 200/301 |

> **Note :** Uptime Kuma est accessible à tous via `https://status.devops.vlxx.fr`
> (visible par les deux équipes et l'instructeur en temps réel).
> Créer un « Status Page » public depuis l'interface Uptime Kuma → Settings → Status Pages.
