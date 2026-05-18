# TP1 - Infrastructure locale avec K3s

Stack déployée :
- **n8n** — outil d'automatisation de workflows
- **PostgreSQL** — base de données pour n8n
- **Dozzle** — visualisation des logs des pods

---

## Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installé et démarré
- [Homebrew](https://brew.sh/) installé

---

## Installation des outils

```bash
# k3d : fait tourner K3s dans Docker
brew install k3d

# kubectl : CLI pour interagir avec le cluster
brew install kubectl

# task : task runner pour les commandes du projet
brew install go-task
```

---

## Lancer l'infrastructure

### 1. Créer le cluster K3s

```bash
k3d cluster create devops \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer"
```

> Les ports 80 et 443 sont mappés sur ton Mac pour que les Ingress soient accessibles.

### 2. Vérifier que le cluster est prêt

```bash
kubectl get nodes
# NAME                  STATUS   ROLES                  AGE
# k3d-devops-server-0   Ready    control-plane,master   ...
```

### 3. Déployer les manifests

```bash
kubectl apply -f k3s/namespace.yaml
kubectl apply -R -f k3s/
```

### 4. Vérifier que les pods tournent

```bash
kubectl get pods -n devops
# NAME                        READY   STATUS    RESTARTS   AGE
# postgres-...                1/1     Running   0          ...
# n8n-...                     1/1     Running   0          ...
# dozzle-...                  1/1     Running   0          ...
```

---

## Accès aux services

Les services ne sont pas exposés directement sur ton Mac. Il faut utiliser le port-forward pour y accéder via `localhost`.

### Via Task (recommandé)

```bash
task forward
```

Lance les deux port-forwards en parallèle. `Ctrl+C` pour tout couper.

### Manuellement

```bash
# n8n sur localhost:5678
kubectl port-forward svc/n8n 5678:5678 -n devops

# dozzle sur localhost:8080
kubectl port-forward svc/dozzle 8080:8080 -n devops
```

> `svc/n8n` est la syntaxe `type/nom` de kubectl. `svc` est l'abréviation de `service`.
> Ces deux commandes sont équivalentes :
> ```bash
> kubectl port-forward svc/n8n 5678:5678 -n devops
> kubectl port-forward service/n8n 5678:5678 -n devops
> ```

| Service | URL |
|---|---|
| n8n | http://localhost:5678 |
| Dozzle | http://localhost:8080 |

---

## Commandes utiles (via Task)

```bash
task up            # Crée le cluster et déploie tout
task down          # Supprime le cluster
task restart       # Recrée le cluster et redéploie
task status        # Affiche l'état des pods
task logs          # Affiche les logs de tous les pods
task forward       # Port-forward n8n (5678) et dozzle (8080)
task forward:n8n   # Port-forward uniquement n8n
task forward:dozzle # Port-forward uniquement dozzle
task redeploy      # Réapplique les manifests sans recréer le cluster
task restart:pods  # Redémarre tous les pods
```

---

## Configuration

### Modifier les credentials Postgres

Les credentials sont stockés dans `k3s/postgres/secret.yaml` en base64.

Pour encoder une valeur :
```bash
echo -n "mon_mot_de_passe" | base64
```

Puis mettre à jour le secret dans le cluster :
```bash
kubectl apply -f k3s/postgres/secret.yaml
kubectl rollout restart deployment/postgres -n devops
kubectl rollout restart deployment/n8n -n devops
```

---

## Arrêter / Supprimer

```bash
# Arrêter le cluster (les données sont conservées)
k3d cluster stop devops

# Redémarrer le cluster
k3d cluster start devops

# Supprimer complètement le cluster
k3d cluster delete devops
```
