## 🛡️ Configuration Sécurisée de mon VPS

## 🎯 Objectif
Documentation de la configuration de mon VPS hébergeant [ewengadonnaud.xyz](https://ewengadonnaud.xyz)

## 🏗️ Architecture
- OS : Debian 13 "trixie"
- Serveur web : Nginx
- Applications : Portfolio statique, dashboard avec vue d'affluences (GoAccess), monitoring up status (Uptime Kuma)
- Hébergeur : Infomaniak 

## 🔒 Sécurisation

### 1. SSH Hardening
- Désactivation connexion root
- Authentification par clé SSH uniquement
- Changement du port par défaut
- Configuration fail2ban

### 2. Filtrage Web
- Différentes "Jails" fail2ban présentes pour contrer les attaques
- Configuration renforcée de NGINX

### 3. Certificats SSL
- Let's Encrypt avec renouvellement automatique

## 📝 Scripts d'automatisation
Voir dossier `/scripts` portfolio-configuration
