# 🛡️ Configuration Sécurité & Performance (VPS Portfolio)

Ce document détaille l'architecture de sécurité et d'optimisation mise en place sur le serveur VPS (Infomaniak) hébergeant le portfolio `ewengadonnaud.xyz`.

L'approche repose sur une défense multi-couches :
1.  **Fail2ban** : Pour la défense active et automatisée. Il lit les journaux (logs) et agit comme un garde qui expulse les visiteurs suspects.
2.  **NGINX** : Pour le filtrage web, la protection applicative et l'optimisation. Il agit comme un filtre à l'entrée du site.
3.  **Certbot** : Pour le chiffrement SSL/TLS (HTTPS), garantissant que la connexion entre le visiteur et le site est privée.

---

## 📈 Fail2ban : Stratégie de Défense Active

Fail2ban est configuré pour surveiller en temps réel les journaux du système. Il identifie les comportements malveillants (scans, brute force) et bannit dynamiquement les adresses IP correspondantes au niveau du pare-feu.

### Jails Nginx (Protection de la couche Web)

Ces "prisons" (jails) surveillent les logs de NGINX pour bloquer les attaques ciblant le site.

| Jail | Fonction Principale | Détection (Fichier de log) | Logique & Impact |
| :--- | :--- | :--- | :--- |
| **nginx-404** | Anti-scan de répertoires | `/var/log/nginx/access.log` | **Explication :** Un scanner automatisé va tester des centaines d'URL communes (ex: `/admin`, `/login`, `/backup.zip`) pour trouver une faille. Chacun de ces tests génère une erreur 404. Cette jail repère cette rafale d'erreurs 404 provenant d'une même IP et la bannit.<br>• **Impact : 139 bannissements.** |
| **nginx-noscript** | Anti-exploitation de vulnérabilités | `/var/log/nginx/access.log` | **Explication :** Bloque les tentatives d'exécution de scripts sur le serveur. Même si mon site est statique (pas de PHP/SQL), les bots l'ignorent et tentent quand même des attaques (ex: `GET /index.php?cmd=ls`). Cette jail bloque ces tentatives.<br>• **Impact : 157 bannissements.** |
| **nginx-badbots** | Blocage de bots malveillants | `/var/log/nginx/access.log` | **Explication :** Chaque visiteur (navigateur ou bot) s'annonce avec un "User-Agent" (ex: `Chrome/105...` ou `Googlebot`). Les bots malveillants utilisent des User-Agents connus (ex: `SemrushBot`, `AhrefsBot` s'ils sont trop agressifs, ou des scanners). Cette jail les filtre. |
| **nginx-http-auth** | Protection d'accès restreint | `/var/log/nginx/error.log` | **Explication :** Si une partie du site était protégée par la petite fenêtre grise d'authentification NGINX (login/mot de passe), cette jail empêcherait un attaquant de "deviner" le mot de passe en essayant des milliers de combinaisons (brute force). |
| **nginx-limit-req** | Protection Anti-DoS | `/var/log/nginx/error.log` | **Explication :** NGINX est configuré pour limiter le nombre de requêtes (voir section NGINX). Si une IP dépasse *quand même* cette limite, NGINX note une erreur. Fail2ban voit cette erreur et bannit l'IP pour une durée plus longue. C'est une double protection. |
| **nginx-noproxy** | Blocage de proxy ouvert | `/var/log/nginx/access.log` | **Explication :** Des attaquants pourraient essayer d'utiliser le serveur comme "relais" (proxy) pour attaquer d'autres sites web, masquant ainsi leur véritable IP. Cette jail détecte et bloque ces tentatives. |

### Jail SSH (Protection du Serveur)

C'est la règle la plus critique pour protéger l'accès administratif au serveur (la "porte d'entrée" du VPS).

| Jail | Fonction Principale | Détection (Log) | Logique & Impact |
| :--- | :--- | :--- | :--- |
| **sshd** | Anti-brute force SSH | `Journaux systemd (journalctl)` | **Explication :** Un attaquant va tenter de se connecter en SSH en essayant des combinaisons classiques (comme `root/password`, `admin/123456`, `user/user`). Cette jail compte les échecs. Après 3 ou 5 échecs, l'IP est bannie pour plusieurs heures.<br>• **Impact : 419 bannissements sur 31 298 tentatives !** |

---

## 🚀 NGINX : Configuration Web Renforcée

NGINX sert de pare-feu applicatif (WAF) de première ligne et d'outil d'optimisation.

### 🔒 Sécurité SSL/HTTPS & Protocoles

* **Redirection Forcée** : Tout le trafic `http://` est redirigé en `https://` (code `301`).
    > **Pourquoi ?** Si un utilisateur se connecte depuis un Wi-Fi public (gare, café), une personne malveillante sur le même réseau pourrait intercepter le trafic. Le HTTPS (`httpS`) chiffre la connexion, rendant cette interception impossible.

* **Certificats Let's Encrypt** : Gestion automatisée des certificats SSL (via `certbot`).

* **HTTP/2** : Protocole activé pour améliorer la vitesse de chargement (permet au navigateur de télécharger plusieurs fichiers en parallèle sur une seule connexion).

* **Discrétion** (`server_tokens off;`) :
    > **Exemple :** Par défaut, NGINX répond `Server: nginx/1.22.0`. Cela donne des informations à un attaquant. Avec `server_tokens off;`, il répond simplement `Server: nginx`, cachant la version exacte (et donc les failles connues de cette version).

### 🛡️ Protection contre les Attaques

* **Limitation de Débit (Rate Limiting)**
    * Une zone `general` est définie, autorisant des pics courts (`burst=20`).
    > **Analogie :** C'est un "videur" à l'entrée. Il laisse entrer les gens à un rythme normal. Si un groupe de 20 (`burst`) arrive, il les laisse passer. Mais si un bus de 200 personnes arrive d'un coup (attaque DoS), il leur dit d'attendre et ne les laisse entrer qu'au compte-gouttes, protégeant le serveur.

* **Filtrage des Méthodes HTTP**
    * Seules les méthodes `GET`, `HEAD`, et `POST` sont autorisées.
    > **Pourquoi ?** Un navigateur a seulement besoin de `GET` (voir la page) ou `POST` (envoyer un formulaire). Des méthodes comme `DELETE` ou `PUT` n'ont rien à faire sur un portfolio et sont souvent utilisées par des attaquants.
    * Les autres méthodes sont rejetées avec un code `444` (Connexion fermée).
    > **Explication :** Un code `403 Forbidden` dit à l'attaquant "Non, tu n'as pas le droit". Un code `444` lui raccroche au nez sans rien dire. C'est plus efficace pour décourager les scanners.

* **Blocage de Chemins Sensibles**
    * Les requêtes vers des chemins sensibles sont bloquées (code `444`).
    > **Exemple critique :** Bloquer `/.git/`. Si ce dossier était accidentellement exposé, un attaquant pourrait télécharger tout le code source du site, y compris d'éventuels secrets (clés d'API, etc.).

* **Blocage d'IPs Manuelles**
    * Une liste de 10 IPs (identifiées comme attaquants récurrents) est bannie "en dur" dans NGINX, en complément de Fail2ban.

### ⚡ Optimisation des Performances

* **Cache Agressif (Cache-Control)**
    * Images, Polices (`1 an`), CSS/JS (`6 mois`).
    > **Analogie :** Quand un visiteur charge le site, son navigateur "prend une photo" du logo et des polices. Le serveur lui dit : "Garde ces photos pendant 1 an (`immutable`) et ne me les redemande pas". La prochaine fois qu'il visite, la page se charge instantanément car tout est déjà sur son ordinateur.

* **Optimisation des Logs**
    * `access_log off;` pour tous les assets statiques (images, fonts, css, js).
    > **Pourquoi ?** Garder un journal de chaque fois que `logo.png` est chargé est inutile et consomme des ressources (écritures disque). On ne garde les logs que pour les pages HTML, qui sont bien plus importantes à suivre.

---

## 🏗️ Architecture de Service

* **Domaine(s)** : `ewengadonnaud.xyz` et `www.ewengadonnaud.xyz`
* **Racine Web** : `/var/www/mon-portfolio`
* **Type de Site** : Statique (HTML/CSS/JS). C'est un avantage en soi : l'absence de base de données ou de langage serveur (PHP, Python) réduit massivement la "surface d'attaque".