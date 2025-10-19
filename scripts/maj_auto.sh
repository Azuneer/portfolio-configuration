#!/bin/bash

# URL du Webhook Discord, lue depuis la variable d'environnement DISCORD_WEBHOOK_URL
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-""}"

# Nom du serveur pour l'identification dans les notifications
HOSTNAME=$(hostname)

# Fichier de log pour la sortie de la mise à jour
LOG_FILE="/var/log/system_update_$(date +'%Y-%m-%d').log"

# --- Fonctions de notification Discord ---

# Fonction pour envoyer un message de succès
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
  curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
}

# Fonction pour envoyer un message d'échec
send_failure_notification() {
  ERROR_LOG=$(tail -n 20 "$LOG_FILE") # Récupère les 20 dernières lignes du log
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
        "value": "```
$ERROR_LOG
```"
      }
    ],
    "footer": {
      "text": "Date: $(date -u --iso-8601=seconds)"
    }
  }]
}
EOF
)
  curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
}

# --- Début du script de mise à jour ---

echo "--- Début de la mise à jour système : $(date) ---" > "$LOG_FILE"

# Mise à jour des fichiers systèmes
# La commande ci-dessous est pour les systèmes basés sur Debian/Ubuntu.
# Adaptez-la si vous utilisez un autre gestionnaire de paquets (ex: yum, dnf, pacman).
if sudo apt-get update -y >> "$LOG_FILE" 2>&1 && sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
  echo "--- Mise à jour terminée avec succès : $(date) ---" >> "$LOG_FILE"
  send_success_notification
else
  echo "--- Échec de la mise à jour : $(date) ---" >> "$LOG_FILE"
  send_failure_notification
fi

echo "--- Fin du script ---" >> "$LOG_FILE"

exit 0
