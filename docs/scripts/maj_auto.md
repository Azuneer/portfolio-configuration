# Documentation du Script de Mise à Jour Automatique (`maj_auto.sh`)

Ce document détaille le fonctionnement, l'installation et la configuration du script `maj_auto.sh`.

## 1. Objectif du Script

Le script `maj_auto.sh` a pour but d'automatiser entièrement le processus de mise à jour d'un serveur Linux. Il effectue les actions suivantes :
- Met à jour la liste des paquets.
- Applique les mises à jour disponibles.
- Envoie une notification sur un salon Discord pour informer de l'état de l'opération (succès ou échec).
- Conserve un journal détaillé de chaque opération de mise à jour.

## 2. Fonctionnalités

- **Automatisation complète** : Conçu pour être exécuté par un planificateur de tâches (`cron`) sans intervention manuelle.
- **Notifications claires** : Utilise les "Embeds" de Discord pour des notifications propres et lisibles.
- **Rapports d'erreur** : En cas d'échec, la notification inclut les dernières lignes du journal d'erreurs pour un diagnostic rapide.
- **Sécurisé** : Ne stocke aucun secret (comme l'URL du webhook) en clair dans le script. La configuration se fait via une variable d'environnement.
- **Adaptable** : Bien que configuré pour Debian/Ubuntu (`apt-get`), le script peut être facilement adapté à d'autres gestionnaires de paquets (`yum`, `dnf`, `pacman`, etc.).

## 3. Prérequis

Avant d'utiliser le script, assurez-vous que les éléments suivants sont installés et configurés sur votre serveur :
- Un système d'exploitation Linux (ex: Debian, Ubuntu, CentOS).
- Le paquet `curl` (généralement installé par défaut).
- Le paquet `sudo`.
- Une URL de Webhook Discord valide pour le salon où les notifications doivent être envoyées.

## 4. Installation et Configuration

Suivez ces étapes pour rendre le script opérationnel.

### Étape 1 : Placer le script sur le serveur

Assurez-vous que le fichier `maj_auto.sh` est présent sur votre serveur, par exemple dans `/home/votre_user/scripts/maj_auto.sh`.

### Étape 2 : Rendre le script exécutable

Donnez au script les permissions d'exécution avec la commande suivante :
```bash
chmod +x /chemin/vers/votre/maj_auto.sh
```

### Étape 3 : Configurer la variable d'environnement

Pour des raisons de sécurité, l'URL du webhook Discord n'est pas écrite dans le script. Elle doit être fournie via une variable d'environnement nommée `DISCORD_WEBHOOK_URL`.

La méthode recommandée est de la définir directement dans la tâche `cron` qui exécutera le script.

## 5. Utilisation

### Exécution manuelle (pour tester)

Pour tester le script manuellement, vous devez définir la variable d'environnement dans votre session et utiliser `sudo -E` pour que `sudo` préserve cette variable.

```bash
# 1. Définissez la variable dans votre terminal
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/votre/url"

# 2. Exécutez le script avec les privilèges root et l'environnement conservé
sudo -E /chemin/vers/votre/maj_auto.sh
```

### Exécution automatisée (Cron)

C'est le mode d'utilisation principal.

1.  Ouvrez l'éditeur de crontab pour l'utilisateur `root` :
    ```bash
    sudo crontab -e
    ```
2.  Ajoutez une ligne pour planifier l'exécution. La variable d'environnement est déclarée directement sur la ligne.

**Exemple (tous les deux jours à 3h00 du matin) :**
```cron
# Mettre à jour le système tous les deux jours et notifier Discord
0 3 */2 * * DISCORD_WEBHOOK_URL="votre_url_webhook_ici" /bin/bash /chemin/absolu/vers/maj_auto.sh
```

## 6. Fichiers de Log

- Le script crée un fichier de log pour chaque exécution dans `/var/log/`.
- Le nom du fichier est formaté comme suit : `system_update_AAAA-MM-JJ.log`.
- Ce fichier contient la sortie complète des commandes `apt-get update` et `apt-get upgrade`, ce qui est essentiel pour le débogage en cas de problème.
