# Kubernetes — Explication des manifests (exemple : Uptime Kuma)

## Structure des fichiers

```
k3s/uptime-kuma/
├── deployment.yaml   # Ce qui tourne et comment
├── service.yaml      # Le réseau interne
└── pvc.yaml          # Le stockage persistant
```

---

## `deployment.yaml`

C'est le fichier principal. Il dit à k8s **quoi faire tourner et comment le gérer**.

```yaml
apiVersion: apps/v1
kind: Deployment        # Type d'objet : gère le cycle de vie des pods
metadata:
  name: uptime-kuma     # Nom du déploiement (utilisé par kubectl)
  namespace: devops     # Dans quel "espace" k8s il vit
```

### Replicas & Selector

```yaml
spec:
  replicas: 1           # Nombre de pods à faire tourner (1 = pas de haute dispo)
  selector:
    matchLabels:
      app: uptime-kuma  # Le Deployment contrôle les pods qui ont ce label
```

### Stratégie de déploiement

```yaml
  strategy:
    type: Recreate      # Tue l'ancien pod AVANT de créer le nouveau
                        # Obligatoire ici car le volume SQLite ne peut pas
                        # être monté par 2 pods simultanément (ReadWriteOnce)
```

> L'alternative `RollingUpdate` permet un déploiement sans downtime, mais
> est incompatible avec un volume `ReadWriteOnce`.

### Container

```yaml
      containers:
        - name: uptime-kuma
          image: louislam/uptime-kuma:1   # Tag :1 = dernière v1.x stable
                                           # :latest est risqué (breaking changes)
          ports:
            - containerPort: 3001          # Port d'écoute dans le container
                                           # Purement documentaire, c'est le Service
                                           # qui gère l'accès depuis l'extérieur
```

### Liveness Probe

> "Est-ce que le container est **vivant** ?"

```yaml
          livenessProbe:
            httpGet:
              path: /
              port: 3001
            initialDelaySeconds: 30   # Attend 30s avant le 1er check (temps de boot)
            periodSeconds: 30         # Vérifie toutes les 30s
            timeoutSeconds: 10        # Timeout de la requête HTTP
            failureThreshold: 3       # 3 échecs consécutifs → k8s KILL et RELANCE le container
```

### Readiness Probe

> "Est-ce que le container est **prêt à recevoir du trafic** ?"

```yaml
          readinessProbe:
            httpGet:
              path: /
              port: 3001
            initialDelaySeconds: 15   # Plus court que liveness : on teste plus tôt
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 5       # 5 échecs → retiré du trafic, mais pas tué
```

**Différence clé :**

| Probe | En cas d'échec |
|---|---|
| `livenessProbe` | Container **tué et redémarré** |
| `readinessProbe` | Container **retiré du load balancer** uniquement |

### Volume

```yaml
      volumes:
        - name: uptime-kuma-data
          persistentVolumeClaim:
            claimName: uptime-kuma-pvc  # Branche le PVC sur le nom logique "uptime-kuma-data"
```

---

## `service.yaml`

Sans Service, le pod est **invisible** dans le cluster. Le Service crée une entrée DNS stable
et route le trafic vers les bons pods.

```yaml
kind: Service
metadata:
  name: uptime-kuma     # Crée l'entrée DNS : uptime-kuma.devops.svc.cluster.local
  namespace: devops
spec:
  selector:
    app: uptime-kuma    # Redirige vers les pods portant ce label
  ports:
    - port: 3001        # Port exposé sur le Service (ce que les autres appellent)
      targetPort: 3001  # Port sur le container (doit matcher containerPort)
```

Les deux ports peuvent être différents. Exemple pour exposer sur le port 80 :

```yaml
    - port: 80          # Les autres services font : http://uptime-kuma:80
      targetPort: 3001  # Le container reçoit quand même sur 3001
```

> Le type par défaut `ClusterIP` rend le service accessible **uniquement depuis le cluster**.
> C'est Caddy qui fait le pont vers l'extérieur via reverse proxy.

---

## `pvc.yaml`

Sans PVC, toutes les données (monitors, historique, config) disparaissent à chaque redémarrage du pod.

```yaml
kind: PersistentVolumeClaim   # Demande de stockage persistant
metadata:
  name: uptime-kuma-pvc       # Référencé dans volumes[] du Deployment
  namespace: devops
spec:
  accessModes:
    - ReadWriteOnce            # Un seul pod peut monter ce volume en écriture à la fois
                               # Compatible avec strategy: Recreate
  resources:
    requests:
      storage: 1Gi             # Taille demandée
                               # k3s crée automatiquement le volume sur le disque local
```

**Modes d'accès disponibles :**

| Mode | Description |
|---|---|
| `ReadWriteOnce` | 1 seul pod en lecture/écriture (disque local) |
| `ReadOnlyMany` | Plusieurs pods en lecture seule |
| `ReadWriteMany` | Plusieurs pods en lecture/écriture (NFS, CephFS…) |

---

## Flux complet

```
Internet
    │  HTTPS
    ▼
Caddy (namespace: infra)
  status.devops.vlxx.fr
    └─ reverse_proxy uptime-kuma.devops.svc.cluster.local:3001
                          │
                          │  DNS interne k8s
                          ▼
                    Service (namespace: devops)
                    uptime-kuma : port 3001
                          │
                          │  selector: app=uptime-kuma
                          ▼
                    Pod uptime-kuma
                    container : port 3001
                          │
                          ▼
                    Volume /app/data
                          │
                          ▼
                    PVC 1Gi (disque hôte k3s)
```

---

## Résumé des paramètres clés à modifier

| Paramètre | Fichier | Quand le changer |
|---|---|---|
| `replicas` | deployment.yaml | Augmenter pour la haute disponibilité |
| `image` | deployment.yaml | Changer la version de l'application |
| `containerPort` | deployment.yaml | Si l'app écoute sur un port différent |
| `initialDelaySeconds` | deployment.yaml | Si l'app met longtemps à démarrer |
| `failureThreshold` | deployment.yaml | Tolérance aux erreurs transitoires |
| `port` / `targetPort` | service.yaml | Changer le port d'accès interne |
| `storage` | pvc.yaml | Augmenter si les données grossissent |
| `accessModes` | pvc.yaml | Si besoin de plusieurs pods en écriture |
