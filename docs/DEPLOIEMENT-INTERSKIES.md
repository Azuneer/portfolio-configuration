# 🚀 Guide de Déploiement - interskies.com

Ce guide explique comment utiliser le script `deploy-interskies.sh` pour déployer l'intégralité de la configuration sécurisée sur un nouveau serveur VPS pour interskies.com.

## 📋 Table des matières

- [Prérequis](#prérequis)
- [Préparation](#préparation)
- [Exécution du script](#exécution-du-script)
- [Configuration détaillée](#configuration-détaillée)
- [Vérification post-déploiement](#vérification-post-déploiement)
- [Maintenance](#maintenance)
- [Dépannage](#dépannage)

---

## 🎯 Prérequis

### Serveur

- **OS**: Debian 12+ ou Ubuntu 22.04+ (recommandé: Debian 13 "trixie")
- **RAM**: Minimum 1 Go (recommandé: 2 Go+)
- **Stockage**: Minimum 10 Go
- **Accès**: Root ou utilisateur avec sudo

### Domaine

- Nom de domaine enregistré (interskies.com)
- DNS configuré pour pointer vers l'IP du serveur:
  - Enregistrement A: `interskies.com` → IP du serveur
  - Enregistrement A: `www.interskies.com` → IP du serveur

### Connexion

- Accès SSH root initial
- Clé SSH générée sur votre machine locale

---

## 🔧 Préparation

### 1. Générer une paire de clés SSH (si nécessaire)

Sur votre machine locale:

```bash
ssh-keygen -t ed25519 -C "votre_email@example.com"
```

Afficher votre clé publique:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copiez le contenu (commence par `ssh-ed25519 ...`).

### 2. Créer un Webhook Discord (optionnel mais recommandé)

Pour recevoir des notifications de mise à jour:

1. Ouvrir Discord
2. Allez dans les paramètres du serveur → Intégrations
3. Créer un Webhook
4. Copier l'URL du webhook (ressemble à: `https://discord.com/api/webhooks/...`)

### 3. Transférer le script sur le serveur

Depuis votre machine locale:

```bash
# Se connecter au serveur en root
ssh root@IP_DU_SERVEUR

# Créer un dossier temporaire
mkdir -p /tmp/deploy

# Télécharger le script depuis ce repo (ou copier manuellement)
cd /tmp/deploy
```

**Option 1: Cloner le repo** (recommandé)
```bash
apt-get update && apt-get install -y git
git clone https://github.com/Azuneer/portfolio-configuration.git
cd portfolio-configuration/scripts
```

**Option 2: Copier depuis votre machine**
```bash
# Sur votre machine locale:
scp scripts/deploy-interskies.sh root@IP_DU_SERVEUR:/tmp/deploy/
```

---

## 🚀 Exécution du script

### Lancement

```bash
# Se placer dans le bon répertoire
cd /tmp/deploy

# Rendre le script exécutable (si nécessaire)
chmod +x deploy-interskies.sh

# Exécuter le script en tant que root
sudo ./deploy-interskies.sh
```

### Questions interactives

Le script vous posera plusieurs questions:

| Question | Exemple de réponse | Note |
|----------|-------------------|------|
| Nom de domaine principal | `interskies.com` | Sans http/https |
| Inclure www? | `y` | Recommandé |
| Utilisateur SSH | `admin` | Ou votre nom |
| Port SSH personnalisé | `2222` | Différent de 22 |
| Webhook Discord | `https://discord.com/api/webhooks/...` | Optionnel |
| Email Let's Encrypt | `votre@email.com` | Pour les alertes SSL |

**Important**: Le script affichera un résumé. Vérifiez-le attentivement avant de confirmer!

### Étape critique: Clé SSH

Lorsque le script demande:
```
Voulez-vous ajouter votre clé SSH maintenant? (y/n)
```

Répondez `y` et collez votre clé SSH publique (celle générée à l'étape de préparation), puis:
- Appuyez sur **Entrée**
- Appuyez sur **Ctrl+D** pour terminer

---

## 🔍 Configuration détaillée

Le script configure automatiquement:

### 1. Système de base

- Mise à jour complète du système
- Installation des paquets essentiels:
  - NGINX (serveur web)
  - Fail2ban (protection contre les attaques)
  - UFW (firewall)
  - Certbot (certificats SSL)
  - Outils de diagnostic (curl, wget, htop, vim)

### 2. SSH Hardening

- Création d'un utilisateur non-root
- Désactivation de la connexion root
- Authentification par clé SSH uniquement (pas de mot de passe)
- Port SSH personnalisé
- Limite de tentatives de connexion

### 3. Firewall (UFW)

Ports ouverts:
- `SSH_PORT/tcp` (celui que vous avez choisi)
- `80/tcp` (HTTP - pour redirection)
- `443/tcp` (HTTPS)

Tout le reste est bloqué par défaut.

### 4. NGINX

Configuration complète incluant:

**Sécurité:**
- Redirection automatique HTTP → HTTPS
- Rate limiting (protection DoS)
- Blocage des méthodes HTTP dangereuses
- Blocage des chemins d'attaque (WordPress, PHP, etc.)
- Blocage des fichiers sensibles (/.git, /.env, etc.)
- Headers de sécurité (HSTS, X-Frame-Options, etc.)

**Performance:**
- HTTP/2 activé
- Cache agressif pour les images (1 an)
- Cache pour les polices (1 an)
- Cache pour CSS/JS (6 mois)
- Logs désactivés pour les fichiers statiques

### 5. Fail2ban

7 "jails" configurées:

| Jail | Protection contre | Seuil |
|------|------------------|-------|
| `sshd` | Brute force SSH | 3 tentatives / 24h ban |
| `nginx-404` | Scan de répertoires | 10 erreurs 404 / 1h ban |
| `nginx-noscript` | Exploitation de scripts | 5 tentatives / 2h ban |
| `nginx-badbots` | Bots malveillants | 2 détections / 24h ban |
| `nginx-http-auth` | Brute force auth | 5 tentatives / 1h ban |
| `nginx-limit-req` | DoS (double protection) | 5 dépassements / 2h ban |
| `nginx-noproxy` | Utilisation comme proxy | 2 tentatives / 24h ban |

### 6. Script d'auto-update

- Exécution: Tous les 2 jours à 3h du matin
- Notifications Discord en cas de succès ou d'échec
- Logs: `/var/log/system_update_YYYY-MM-DD.log`

### 7. SSL/TLS

- Certificats Let's Encrypt gratuits
- Renouvellement automatique
- Protocoles modernes (TLSv1.2 et TLSv1.3)
- Chiffrement fort

---

## ✅ Vérification post-déploiement

### 1. Tester SSH (CRITIQUE!)

**AVANT de fermer votre session root actuelle**, ouvrez une nouvelle fenêtre terminal et testez:

```bash
ssh -p PORT_SSH UTILISATEUR@IP_DU_SERVEUR
```

Exemple:
```bash
ssh -p 2222 admin@123.45.67.89
```

Si cela fonctionne:
- Tapez `exit` pour fermer la session de test
- Vous pouvez maintenant fermer la session root

Si cela ne fonctionne PAS:
- NE FERMEZ PAS la session root!
- Vérifiez votre clé SSH: `cat ~/.ssh/authorized_keys`
- Vérifiez le port: `grep "Port" /etc/ssh/sshd_config`

### 2. Vérifier NGINX

```bash
# Status
sudo systemctl status nginx

# Test de configuration
sudo nginx -t

# Voir les logs
sudo tail -f /var/log/nginx/access.log
```

### 3. Vérifier le site

Ouvrez un navigateur:
- http://interskies.com → Doit rediriger vers https://
- https://interskies.com → Page "En construction" doit s'afficher

### 4. Vérifier Fail2ban

```bash
# Status général
sudo fail2ban-client status

# Status d'une jail spécifique
sudo fail2ban-client status sshd

# Voir les IPs bannies
sudo fail2ban-client status nginx-404
```

### 5. Vérifier le Firewall

```bash
sudo ufw status verbose
```

Doit afficher:
```
Status: active
...
PORT_SSH/tcp     ALLOW IN    Anywhere
80/tcp           ALLOW IN    Anywhere
443/tcp          ALLOW IN    Anywhere
```

### 6. Vérifier le SSL

Si vous avez généré le certificat:
- https://www.ssllabs.com/ssltest/analyze.html?d=interskies.com
- Note attendue: A ou A+

### 7. Tester le script d'auto-update

```bash
# Exécuter manuellement (en tant que root)
sudo -E DISCORD_WEBHOOK_URL="votre_webhook" /home/UTILISATEUR/scripts/maj_auto.sh

# Vérifier le log
cat /var/log/system_update_$(date +'%Y-%m-%d').log
```

Si le webhook est configuré, vous devriez recevoir une notification Discord.

---

## 🔄 Maintenance

### Déployer votre site

Remplacez la page de test par votre vrai site:

```bash
# Supprimer la page de test
sudo rm /var/www/interskies.com/index.html

# Copier vos fichiers (depuis votre machine locale)
scp -P PORT_SSH -r ./mon-site/* UTILISATEUR@IP_DU_SERVEUR:/tmp/

# Sur le serveur
sudo mv /tmp/mon-site/* /var/www/interskies.com/
sudo chown -R www-data:www-data /var/www/interskies.com
sudo chmod -R 755 /var/www/interskies.com
```

Ou utiliser Git:

```bash
cd /var/www/interskies.com
sudo git clone https://github.com/votre-compte/votre-site.git .
```

### Commandes utiles

```bash
# NGINX
sudo systemctl restart nginx
sudo systemctl reload nginx  # Recharge config sans coupure
sudo nginx -t                # Tester la config avant reload

# Fail2ban
sudo fail2ban-client status
sudo fail2ban-client set JAIL_NAME unbanip IP_ADDRESS
sudo systemctl restart fail2ban

# Certificats SSL
sudo certbot renew --dry-run  # Test de renouvellement
sudo certbot renew            # Renouvellement forcé
sudo certbot certificates     # Voir les certificats

# Firewall
sudo ufw status
sudo ufw allow PORT/tcp       # Ouvrir un port
sudo ufw deny PORT/tcp        # Fermer un port
sudo ufw reload

# Logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
sudo journalctl -u nginx -f
sudo journalctl -u fail2ban -f
```

### Ajouter des IPs à la liste noire manuelle

Si une IP vous attaque constamment:

```bash
sudo nano /etc/nginx/sites-available/interskies.com
```

Ajoutez dans le bloc `server` HTTPS:
```nginx
deny 123.45.67.89;
```

Puis:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Surveiller les performances

```bash
# Utilisation système
htop

# Connexions actives
sudo ss -tuln

# Statistiques NGINX
sudo apt-get install -y goaccess
sudo goaccess /var/log/nginx/access.log --log-format=COMBINED
```

---

## 🐛 Dépannage

### Problème: Cannot connect via SSH

**Symptômes**: `Connection refused` ou timeout

**Solutions**:
1. Vérifiez le port:
   ```bash
   # Sur le serveur
   sudo grep "Port" /etc/ssh/sshd_config
   ```

2. Vérifiez le firewall:
   ```bash
   sudo ufw status | grep SSH_PORT
   ```

3. Vérifiez que SSH tourne:
   ```bash
   sudo systemctl status sshd
   ```

4. Regardez les logs:
   ```bash
   sudo journalctl -u sshd -n 50
   ```

### Problème: Site inaccessible

**Symptômes**: Erreur 502/503 ou timeout

**Solutions**:
1. Vérifier NGINX:
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

2. Vérifier les logs:
   ```bash
   sudo tail -50 /var/log/nginx/error.log
   ```

3. Vérifier les permissions:
   ```bash
   ls -la /var/www/interskies.com
   # Doit être: drwxr-xr-x www-data www-data
   ```

4. Redémarrer NGINX:
   ```bash
   sudo systemctl restart nginx
   ```

### Problème: SSL ne fonctionne pas

**Symptômes**: Erreur de certificat ou "Not secure"

**Solutions**:
1. Vérifier Certbot:
   ```bash
   sudo certbot certificates
   ```

2. Regénérer le certificat:
   ```bash
   sudo certbot --nginx -d interskies.com -d www.interskies.com --force-renewal
   ```

3. Vérifier la config NGINX:
   ```bash
   sudo grep "ssl_certificate" /etc/nginx/sites-available/interskies.com
   ```

### Problème: Fail2ban ne bannit pas

**Symptômes**: Attaques continues, pas de bannissement

**Solutions**:
1. Vérifier le status:
   ```bash
   sudo fail2ban-client status
   sudo fail2ban-client status JAIL_NAME
   ```

2. Vérifier les logs:
   ```bash
   sudo tail -f /var/log/fail2ban.log
   ```

3. Tester un filtre:
   ```bash
   sudo fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/nginx-404.conf
   ```

4. Redémarrer:
   ```bash
   sudo systemctl restart fail2ban
   ```

### Problème: Script d'auto-update ne s'exécute pas

**Symptômes**: Pas de notifications Discord, système non mis à jour

**Solutions**:
1. Vérifier le cron:
   ```bash
   sudo crontab -l | grep maj_auto
   ```

2. Exécuter manuellement:
   ```bash
   sudo -E DISCORD_WEBHOOK_URL="votre_webhook" /home/USER/scripts/maj_auto.sh
   ```

3. Vérifier les logs:
   ```bash
   cat /var/log/system_update_*.log
   sudo grep CRON /var/log/syslog
   ```

---

## 📚 Ressources supplémentaires

- [Documentation NGINX](https://nginx.org/en/docs/)
- [Documentation Fail2ban](https://www.fail2ban.org/)
- [Documentation UFW](https://help.ubuntu.com/community/UFW)
- [Documentation Certbot](https://certbot.eff.org/)
- [SSL Labs Test](https://www.ssllabs.com/ssltest/)
- [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/)

---

## 🔐 Bonnes pratiques de sécurité

1. **Sauvegardez régulièrement**:
   - Configuration: `/etc/nginx`, `/etc/fail2ban`, `/etc/ssh`
   - Site web: `/var/www/interskies.com`
   - Base de données (si applicable)

2. **Surveillez les logs**:
   - Consultez régulièrement `/var/log/nginx/`
   - Vérifiez les bannissements Fail2ban
   - Surveillez les tentatives SSH: `sudo journalctl -u sshd`

3. **Maintenez à jour**:
   - Le script d'auto-update s'occupe du système
   - Mais vérifiez manuellement de temps en temps

4. **Testez les sauvegardes**:
   - Restaurez régulièrement une sauvegarde sur un serveur de test
   - Assurez-vous de pouvoir récupérer en cas de problème

5. **Utilisez des mots de passe forts**:
   - Pour l'utilisateur système (si vous en définissez un)
   - Pour toutes les applications tierces

6. **Limitez l'accès**:
   - N'ouvrez que les ports nécessaires
   - Utilisez un VPN pour les services administratifs si possible

---

## 📞 Support

En cas de problème:

1. Consultez la section [Dépannage](#dépannage)
2. Vérifiez les logs du service concerné
3. Consultez la documentation officielle
4. Recherchez l'erreur sur Google/Stack Overflow

---

**Bon déploiement! 🚀**

*Ce guide a été généré automatiquement avec le script `deploy-interskies.sh` basé sur la configuration éprouvée de ewengadonnaud.xyz.*
