# Déploiement k3s avec Caddy comme reverse proxy

Stack : **n8n** + **Dozzle** exposés via **Caddy** (TLS automatique Let's Encrypt) sur un serveur k3s.

---

## Prérequis

- Un serveur Linux (Debian/Ubuntu recommandé) avec accès root
- Un utilisateur non-root avec accès SSH
- Des enregistrements DNS pointant vers l'IP du serveur :
  ```
  n8n.devops.vlxx.fr     A  167.235.145.88
  dozzle.devops.vlxx.fr  A  167.235.145.88
  ```

---

## 1. Installer k3s

Se connecter au serveur :

```bash
ssh -p 47474 -i ~/.ssh/id_rsa_github dev@167.235.145.88
```

Installer k3s avec Traefik désactivé dès le départ (on utilise Caddy à la place) :

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
```

Vérifier que k3s est bien démarré :

```bash
sudo systemctl status k3s
sudo kubectl get nodes
```

Le nœud doit être en état `Ready` au bout de quelques secondes.

---

## 2. Accès kubectl sans sudo

Par défaut, le kubeconfig de k3s n'est lisible que par root. Pour l'utiliser avec ton utilisateur :

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config
```

Vérifie :

```bash
kubectl get nodes
```

---

## 3. Exporter le kubeconfig en local

Depuis ta machine locale, copie le kubeconfig via scp :

```bash
mkdir -p ~/.kube
scp -P 47474 -i ~/.ssh/id_rsa_github dev@167.235.145.88:/etc/rancher/k3s/k3s.yaml ~/.kube/config-devops
```

k3s inscrit `127.0.0.1` comme adresse du serveur API. Remplace-la par l'IP publique :

```bash
sed -i '' 's/127.0.0.1/167.235.145.88/g' ~/.kube/config-devops
```

Utilise ce kubeconfig :

```bash
export KUBECONFIG=~/.kube/config-devops
```

Pour le rendre permanent, ajoute la ligne dans ton `~/.zshrc` ou `~/.bashrc`.

Ou pour le fusionner avec ta config kubectl existante :

```bash
export KUBECONFIG=~/.kube/config:~/.kube/config-devops
kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
```

Vérifie depuis ta machine locale :

```bash
kubectl get nodes
```

---

## 4. Désactiver Traefik (si k3s déjà installé avec Traefik)

Si k3s a été installé sans l'option `--disable traefik`, il faut le désactiver manuellement pour libérer les ports 80/443 pour Caddy.

Édite ou crée `/etc/rancher/k3s/config.yaml` sur le serveur :

```bash
sudo nano /etc/rancher/k3s/config.yaml
```

```yaml
disable:
  - traefik
```

Redémarre k3s :

```bash
sudo systemctl restart k3s
```

Vérifie que Traefik est bien supprimé :

```bash
kubectl get pods -n kube-system | grep traefik
# Ne doit rien retourner
```

---

## 5. Structure des manifests

```
k3s/
├── namespace.yaml          # namespace "devops"
├── caddy/
│   ├── namespace.yaml      # namespace "infra"
│   ├── configmap.yaml      # Caddyfile avec les reverse_proxy
│   ├── deployment.yaml     # Pod Caddy avec hostNetwork: true
│   ├── service.yaml        # ClusterIP 80/443
│   └── pvc.yaml            # Stockage des certificats Let's Encrypt
├── dozzle/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── pvc.yaml
│   └── rbac.yaml
├── n8n/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
└── postgres/
    ├── deployment.yaml
    ├── service.yaml
    ├── pvc.yaml
    └── secret.yaml
```

---

## 6. Points clés de la config Caddy

### Caddyfile (`caddy/configmap.yaml`)

Caddy gère le TLS automatiquement via Let's Encrypt. Il suffit de déclarer le nom de domaine :

```
n8n.devops.vlxx.fr {
  reverse_proxy n8n.devops.svc.cluster.local:5678
}

dozzle.devops.vlxx.fr {
  reverse_proxy dozzle.devops.svc.cluster.local:8080
}
```

Les adresses DNS internes k8s suivent le format : `<service>.<namespace>.svc.cluster.local`.

### hostNetwork (`caddy/deployment.yaml`)

Caddy utilise `hostNetwork: true` pour se binder directement sur les ports 80/443 du nœud, contournant la restriction k3s sur les NodePorts (limités à 30000-32767) :

```yaml
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
```

### PVC pour les certificats (`caddy/pvc.yaml`)

Le volume `/data` stocke les certificats Let's Encrypt. Sans PVC, les certificats seraient regénérés à chaque redémarrage du pod (Let's Encrypt applique un rate limit strict).

---

## 7. Déploiement

```bash
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/caddy/
kubectl apply -f k3s/dozzle/
kubectl apply -f k3s/n8n/
kubectl apply -f k3s/postgres/
```

---

## 8. Vérification

```bash
# État des pods
kubectl get pods -n infra
kubectl get pods -n devops

# Logs Caddy (négociation TLS)
kubectl logs -n infra -l app=caddy -f

# Test HTTPS
curl -I https://n8n.devops.vlxx.fr
curl -I https://dozzle.devops.vlxx.fr
```

Les logs Caddy doivent afficher `certificate obtained successfully` pour chaque domaine.
