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

### 4. Configurer les domaines locaux

```bash
echo "127.0.0.1  n8n.local dozzle.local" | sudo tee -a /etc/hosts
```

### 5. Vérifier que les pods tournent

```bash
kubectl get pods -n devops
# NAME                        READY   STATUS    RESTARTS   AGE
# postgres-...                1/1     Running   0          ...
# n8n-...                     1/1     Running   0          ...
# dozzle-...                  1/1     Running   0          ...
```

---

## Accès aux services

| Service    | URL                          |
|------------|------------------------------|
| n8n        | http://n8n.local             |
| Dozzle     | http://dozzle.local          |

---

## Commandes utiles (via Task)

```bash
task up        # Crée le cluster et déploie tout
task down      # Supprime le cluster
task restart   # Recrée le cluster et redéploie
task status    # Affiche l'état des pods
task logs      # Affiche les logs de tous les pods (via kubectl)
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
