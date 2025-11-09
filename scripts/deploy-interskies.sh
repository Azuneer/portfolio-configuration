#!/bin/bash

################################################################################
# Script de Déploiement Complet - interskies.com
################################################################################
# Ce script réplique l'intégralité de la configuration sécurisée du VPS
# pour le déploiement du nouveau site interskies.com
#
# Basé sur la configuration de ewengadonnaud.xyz
# Adapté pour: interskies.com
################################################################################

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

print_step "🚀 Script de Déploiement - interskies.com"

echo "Ce script va configurer:"
echo "  - Système de base (Debian)"
echo "  - Firewall (UFW)"
echo "  - NGINX avec configuration sécurisée"
echo "  - Fail2ban avec toutes les jails"
echo "  - Script d'auto-update avec notifications Discord"
echo "  - SSL/TLS avec Certbot"
echo ""
read -p "Voulez-vous continuer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

################################################################################
# COLLECTE DES INFORMATIONS
################################################################################

print_step "📋 Collecte des informations"

# Domaine
read -p "Nom de domaine principal (défaut: interskies.com): " DOMAIN
DOMAIN=${DOMAIN:-interskies.com}

read -p "Inclure www.$DOMAIN? (y/n, défaut: y): " -n 1 -r INCLUDE_WWW
echo
INCLUDE_WWW=${INCLUDE_WWW:-y}

# Webhook Discord
read -p "URL du Webhook Discord pour les notifications (optionnel): " DISCORD_WEBHOOK

# Email pour Let's Encrypt
read -p "Email pour Let's Encrypt: " LETSENCRYPT_EMAIL

# Résumé
echo ""
print_warning "RÉSUMÉ DE LA CONFIGURATION:"
echo "  - Domaine: $DOMAIN"
if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
    echo "  - Avec www: Oui (www.$DOMAIN)"
fi
echo "  - Webhook Discord: ${DISCORD_WEBHOOK:-Non configuré}"
echo "  - Email Let's Encrypt: $LETSENCRYPT_EMAIL"
echo ""
read -p "Confirmer ces paramètres? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Configuration annulée"
    exit 1
fi

################################################################################
# 1. MISE À JOUR DU SYSTÈME
################################################################################

print_step "1️⃣  Mise à jour du système"

apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y

print_success "Système mis à jour"

################################################################################
# 2. INSTALLATION DES PAQUETS ESSENTIELS
################################################################################

print_step "2️⃣  Installation des paquets essentiels"

apt-get install -y \
    nginx \
    fail2ban \
    ufw \
    curl \
    wget \
    git \
    certbot \
    python3-certbot-nginx \
    sudo \
    vim \
    htop

print_success "Paquets installés"

################################################################################
# 3. CONFIGURATION DU FIREWALL (UFW)
################################################################################

print_step "3️⃣  Configuration du firewall (UFW)"

# Désactiver UFW temporairement pour configuration
ufw --force disable

# Configuration par défaut
ufw default deny incoming
ufw default allow outgoing

# Autoriser HTTP et HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Activer UFW
ufw --force enable

print_success "Firewall configuré et activé"

################################################################################
# 4. CRÉATION DE L'ARBORESCENCE WEB
################################################################################

print_step "4️⃣  Création de l'arborescence web"

WEB_ROOT="/var/www/$DOMAIN"
mkdir -p $WEB_ROOT
chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

# Page de test temporaire
cat > $WEB_ROOT/index.html << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN - En construction</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
        }
        h1 { font-size: 3em; margin-bottom: 0.2em; }
        p { font-size: 1.2em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$DOMAIN</h1>
        <p>Site en construction</p>
        <p style="font-size: 0.9em; opacity: 0.8;">Configuration déployée avec succès ✓</p>
    </div>
</body>
</html>
EOF

print_success "Arborescence web créée: $WEB_ROOT"

################################################################################
# 5. CONFIGURATION NGINX
################################################################################

print_step "5️⃣  Configuration NGINX"

# Créer la zone de rate limiting dans nginx.conf
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    # Rate limiting zone\n    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;' /etc/nginx/nginx.conf
    print_success "Zone de rate limiting ajoutée à nginx.conf"
fi

# Configuration du site
if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
    SERVER_NAMES="$DOMAIN www.$DOMAIN"
else
    SERVER_NAMES="$DOMAIN"
fi

cat > /etc/nginx/sites-available/$DOMAIN << EOF
# Configuration NGINX - $DOMAIN (HTTP seulement - avant SSL)
# Déployé par deploy-interskies.sh
# SSL sera configuré automatiquement par Certbot

server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAMES;

    root $WEB_ROOT;
    index index.html index.htm;

    # Cacher la version Nginx
    server_tokens off;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;

    # Bloquer les méthodes HTTP non autorisées
    if (\$request_method !~ ^(GET|HEAD|POST)\$) {
        return 444;
    }

    # Cache des images (1 an)
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Cache des fonts (1 an)
    location ~* \.(woff|woff2|ttf|otf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Cache CSS et JS (6 mois)
    location ~* \.(css|js)\$ {
        expires 6M;
        add_header Cache-Control "public";
    }

    # Bloquer WordPress et scans de vulnérabilités
    location ~* ^/(wp-|wordpress|cgi-bin) {
        return 444;
    }

    # Bloquer les fichiers sensibles
    location ~* /(\.env|\.git|config\.php|phpinfo|setup-config) {
        return 444;
    }

    # Bloquer les chemins d'administration suspects
    location ~* ^/(admin|api/\.env|backend/\.env|_profiler) {
        return 444;
    }

    # Favicon
    location = /favicon.ico {
        access_log off;
        log_not_found off;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Robots.txt
    location = /robots.txt {
        access_log off;
        log_not_found off;
        expires 1y;
        add_header Cache-Control "public";
    }

    # Route principale
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Activer le site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Désactiver le site par défaut
rm -f /etc/nginx/sites-enabled/default

# Tester la configuration
nginx -t

print_success "Configuration NGINX créée et activée"

################################################################################
# 6. CONFIGURATION FAIL2BAN
################################################################################

print_step "6️⃣  Configuration Fail2ban"

# Créer les fichiers de filtre

# Filter nginx-404
cat > /etc/fail2ban/filter.d/nginx-404.conf << 'EOF'
# Fail2Ban filter pour bloquer les scans de répertoires (404 excessifs)
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 404
ignoreregex =
EOF

# Filter nginx-noscript
cat > /etc/fail2ban/filter.d/nginx-noscript.conf << 'EOF'
# Fail2Ban filter pour bloquer les tentatives d'exploitation de scripts
[Definition]
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
ignoreregex =
EOF

# Filter nginx-badbots
cat > /etc/fail2ban/filter.d/nginx-badbots.conf << 'EOF'
# Fail2Ban filter pour bloquer les bots malveillants
[Definition]
failregex = ^<HOST> -.*"(.*SemrushBot.*|.*AhrefsBot.*|.*MJ12bot.*|.*DotBot.*)"
ignoreregex = .*(googlebot|bingbot|Baiduspider|facebookexternalhit).*
EOF

# Filter nginx-noproxy
cat > /etc/fail2ban/filter.d/nginx-noproxy.conf << 'EOF'
# Fail2Ban filter pour bloquer les tentatives d'utilisation comme proxy
[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

# Configuration jail.local
cat > /etc/fail2ban/jail.local << EOF
# Configuration Fail2ban - $DOMAIN
# Déployé par deploy-interskies.sh

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = ${LETSENCRYPT_EMAIL}
sendername = Fail2Ban-$DOMAIN
action = %(action_)s

# Jail NGINX - Scans 404
[nginx-404]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 60
bantime = 3600

# Jail NGINX - NoScript
[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 5
findtime = 300
bantime = 7200

# Jail NGINX - Bad Bots
[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
findtime = 600
bantime = 86400

# Jail NGINX - HTTP Auth
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

# Jail NGINX - Limit Req
[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 600
bantime = 7200

# Jail NGINX - No Proxy
[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
findtime = 300
bantime = 86400
EOF

# Redémarrer fail2ban
systemctl restart fail2ban
systemctl enable fail2ban

print_success "Fail2ban configuré avec toutes les jails"

################################################################################
# 7. SCRIPT D'AUTO-UPDATE
################################################################################

print_step "7️⃣  Configuration du script d'auto-update"

SCRIPTS_DIR="/root/scripts"
mkdir -p $SCRIPTS_DIR

cat > $SCRIPTS_DIR/maj_auto.sh << 'EOFSCRIPT'
#!/bin/bash

# Script de Mise à Jour Automatique avec Notifications Discord
# Pour interskies.com

# URL du Webhook Discord, lue depuis la variable d'environnement
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-""}"

# Nom du serveur pour l'identification dans les notifications
HOSTNAME=$(hostname)

# Fichier de log pour la sortie de la mise à jour
LOG_FILE="/var/log/system_update_$(date +'%Y-%m-%d').log"

# --- Fonctions de notification Discord ---

send_success_notification() {
  MESSAGE="✅ La mise à jour automatique du système sur **$HOSTNAME** s'est terminée avec succès."
  JSON_PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Rapport de mise à jour automatique",
    "description": "$MESSAGE",
    "color": 3066993,
    "footer": {
      "text": "Date: $(date -u --iso-8601=seconds)"
    }
  }]
}
EOF
)
  if [ -n "$WEBHOOK_URL" ]; then
    curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
  fi
}

send_failure_notification() {
  ERROR_LOG=$(tail -n 20 "$LOG_FILE")
  MESSAGE="❌ Échec de la mise à jour automatique du système sur **$HOSTNAME**."
  JSON_PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Rapport de mise à jour automatique",
    "description": "$MESSAGE",
    "color": 15158332,
    "fields": [
      {
        "name": "Extrait du log d'erreur",
        "value": "\`\`\`
$ERROR_LOG
\`\`\`"
      }
    ],
    "footer": {
      "text": "Date: $(date -u --iso-8601=seconds)"
    }
  }]
}
EOF
)
  if [ -n "$WEBHOOK_URL" ]; then
    curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
  fi
}

# --- Début du script de mise à jour ---

echo "--- Début de la mise à jour système : $(date) ---" > "$LOG_FILE"

if sudo apt-get update -y >> "$LOG_FILE" 2>&1 && sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
  echo "--- Mise à jour terminée avec succès : $(date) ---" >> "$LOG_FILE"
  send_success_notification
else
  echo "--- Échec de la mise à jour : $(date) ---" >> "$LOG_FILE"
  send_failure_notification
fi

echo "--- Fin du script ---" >> "$LOG_FILE"

exit 0
EOFSCRIPT

chmod +x $SCRIPTS_DIR/maj_auto.sh

print_success "Script d'auto-update créé: $SCRIPTS_DIR/maj_auto.sh"

if [ -n "$DISCORD_WEBHOOK" ]; then
    print_warning "Configuration de la tâche cron pour l'auto-update..."

    # Ajouter au crontab de root avec le webhook
    CRON_LINE="0 3 */2 * * DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK\" /bin/bash $SCRIPTS_DIR/maj_auto.sh"

    # Vérifier si la ligne existe déjà
    if ! crontab -l 2>/dev/null | grep -q "maj_auto.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        print_success "Tâche cron ajoutée (tous les 2 jours à 3h)"
    else
        print_warning "Tâche cron déjà existante"
    fi
else
    print_warning "⚠ Webhook Discord non configuré. Configuration manuelle nécessaire:"
    echo "   sudo crontab -e"
    echo "   Ajouter: 0 3 */2 * * DISCORD_WEBHOOK_URL=\"votre_webhook\" /bin/bash $SCRIPTS_DIR/maj_auto.sh"
fi

################################################################################
# 8. REDÉMARRAGE DES SERVICES
################################################################################

print_step "8️⃣  Redémarrage des services"

systemctl restart nginx
print_success "NGINX redémarré"

systemctl restart fail2ban
print_success "Fail2ban redémarré"

################################################################################
# 9. CONFIGURATION SSL (OPTIONNEL)
################################################################################

print_step "9️⃣  Configuration SSL avec Let's Encrypt"

echo "Le certificat SSL peut être généré maintenant ou plus tard."
echo "Note: Votre domaine doit pointer vers ce serveur pour que la validation fonctionne."
echo ""
read -p "Voulez-vous générer le certificat SSL maintenant? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
        certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m $LETSENCRYPT_EMAIL
    else
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $LETSENCRYPT_EMAIL
    fi

    if [ $? -eq 0 ]; then
        print_success "Certificat SSL généré avec succès"

        print_warning "Application de la configuration NGINX complète avec sécurité renforcée..."

        # Appliquer la configuration complète avec SSL et toutes les sécurités
        cat > /etc/nginx/sites-available/$DOMAIN << 'EOFNGINX'
# Configuration NGINX - interskies.com
# Déployé par deploy-interskies.sh - Version complète avec SSL
# Adapté de la configuration ewengadonnaud.xyz

# Redirection HTTP → HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name SERVER_NAMES_PLACEHOLDER;
    return 301 https://\$server_name\$request_uri;
}

# Configuration HTTPS principale
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name SERVER_NAMES_PLACEHOLDER;

    root WEB_ROOT_PLACEHOLDER;
    index index.html index.htm;

    # SSL Certificates (configurés par Certbot)
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # Cacher la version Nginx
    server_tokens off;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Autres headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;

    # Bloquer les méthodes HTTP non autorisées
    if (\$request_method !~ ^(GET|HEAD|POST)\$) {
        return 444;
    }

    # Cache des images (1 an)
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Cache des fonts (1 an)
    location ~* \.(woff|woff2|ttf|otf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Cache CSS et JS (6 mois)
    location ~* \.(css|js)\$ {
        expires 6M;
        add_header Cache-Control "public";
    }

    # Bloquer WordPress et scans de vulnérabilités
    location ~* ^/(wp-|wordpress|cgi-bin) {
        return 444;
    }

    # Bloquer les fichiers sensibles
    location ~* /(\.env|\.git|config\.php|phpinfo|setup-config) {
        return 444;
    }

    # Bloquer les chemins d'administration suspects
    location ~* ^/(admin|api/\.env|backend/\.env|_profiler) {
        return 444;
    }

    # Favicon
    location = /favicon.ico {
        access_log off;
        log_not_found off;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Robots.txt
    location = /robots.txt {
        access_log off;
        log_not_found off;
        expires 1y;
        add_header Cache-Control "public";
    }

    # Route principale
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOFNGINX

        # Remplacer les placeholders
        sed -i "s|SERVER_NAMES_PLACEHOLDER|$SERVER_NAMES|g" /etc/nginx/sites-available/$DOMAIN
        sed -i "s|WEB_ROOT_PLACEHOLDER|$WEB_ROOT|g" /etc/nginx/sites-available/$DOMAIN
        sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /etc/nginx/sites-available/$DOMAIN

        # Tester et recharger
        if nginx -t; then
            systemctl reload nginx
            print_success "Configuration NGINX complète appliquée avec succès"
        else
            print_error "Erreur dans la configuration NGINX"
            print_warning "La configuration Certbot de base reste active"
        fi
    else
        print_error "Échec de la génération du certificat SSL"
        print_warning "Vous pouvez le faire manuellement plus tard avec:"
        if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
            echo "   certbot --nginx -d $DOMAIN -d www.$DOMAIN"
        else
            echo "   certbot --nginx -d $DOMAIN"
        fi
    fi
else
    print_warning "Configuration SSL reportée. Pour générer le certificat plus tard:"
    if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
        echo "   certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    else
        echo "   certbot --nginx -d $DOMAIN"
    fi
fi

################################################################################
# FIN DU DÉPLOIEMENT
################################################################################

print_step "✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"

echo ""
echo "======================================================"
echo "           RÉSUMÉ DE LA CONFIGURATION"
echo "======================================================"
echo ""
echo "🌐 Domaine: $DOMAIN"
if [[ $INCLUDE_WWW =~ ^[Yy]$ ]]; then
    echo "   (avec www.$DOMAIN)"
fi
echo ""
echo "📁 Racine web: $WEB_ROOT"
echo "   Placez vos fichiers HTML/CSS/JS dans ce dossier"
echo ""
echo "🛡️  Sécurité:"
echo "   - Fail2ban: actif avec 6 jails (NGINX uniquement)"
echo "   - Firewall UFW: actif"
echo "   - NGINX: configuré avec WAF et rate limiting"
echo ""
echo "🔄 Auto-update:"
echo "   Script: $SCRIPTS_DIR/maj_auto.sh"
echo "   Fréquence: Tous les 2 jours à 3h"
echo "   Logs: /var/log/system_update_*.log"
echo ""
echo "📊 Commandes utiles:"
echo "   - Status Fail2ban: fail2ban-client status"
echo "   - Voir les bans: fail2ban-client status nginx-404"
echo "   - Status NGINX: systemctl status nginx"
echo "   - Logs NGINX: tail -f /var/log/nginx/access.log"
echo "   - Test config NGINX: nginx -t"
echo "   - Renouvellement SSL: certbot renew"
echo ""
echo "🎯 Prochaines étapes:"
echo "   1. Testez votre site: http://$DOMAIN (puis https://)"
echo "   2. Déployez vos fichiers dans $WEB_ROOT"
echo "   3. Surveillez les logs et Fail2ban"
echo "   4. Configurez des sauvegardes régulières"
echo ""
echo "======================================================"
echo ""

print_success "Configuration déployée avec succès pour $DOMAIN !"

exit 0
