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
# 🚀 Architecture de Sécurité & Performance NGINX

Cette configuration transforme NGINX en un véritable **pare-feu applicatif (WAF)** et un **serveur de cache** haute performance, en plus de son rôle de serveur web.

---

## 🚦 Section 1 : Redirection HTTP vers HTTPS (Le "Vigile")

L'intégralité du trafic non sécurisé (port 80) est immédiatement et définitivement redirigée vers sa contrepartie sécurisée (port 443). C'est la première ligne de défense et une "best practice" absolue.

```nginx
# Redirection HTTP → HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ewengadonnaud.xyz www.ewengadonnaud.xyz;
    return 301 https://$server_name$request_uri;
}
```

### Explication

* **`listen 80;` et `listen [::]:80;`** : Ouvre le port 80 pour les connexions IPv4 et IPv6. Sans cela, les utilisateurs tapant `http://...` recevraient une erreur "connexion refusée".

* **`return 301 ...`** : C'est la directive la plus importante. Elle envoie un code "Moved Permanently" (Déplacé Définitivement).
  * **Pour le SEO** : C'est la méthode la plus propre. Elle dit à Google et aux autres moteurs de recherche que la seule version "officielle" (canonique) du site est en `https://`.
  * **Pour l'utilisateur** : Le navigateur se souviendra de ce choix et tentera d'utiliser `https://` directement lors des prochaines visites.

* **`$server_name$request_uri;`** : Ces variables NGINX assurent que la redirection est parfaite.
  * `$server_name` reprend le domaine demandé (ex: `www.ewengadonnaud.xyz`).
  * `$request_uri` reprend le chemin complet (ex: `/un-projet.html`).
  * **Résultat** : `http://.../page` redirige bien vers `https://.../page` et non vers la page d'accueil.

---

## 🔒 Section 2 : Configuration HTTPS Principale (Le "Fort")

C'est le cœur du réacteur. Ce bloc écoute sur le port 443, gère le déchiffrement SSL/TLS et sert le contenu du site.

```nginx
# Configuration HTTPS principale
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ewengadonnaud.xyz www.ewengadonnaud.xyz;
    
    root /var/www/mon-portfolio;
    index index.html;
    
    # --- SSL Certificates ---
    # Les chemins vers les certificats (ssl_certificate) 
    # et la clé privée (ssl_certificate_key) sont ici.
    # Ils sont gérés par Certbot et sont confidentiels.
    [CONFIDENTIEL]
    
    # --- Optimisations & Sécurité de Base ---
    
    # Cacher la version Nginx
    server_tokens off;
    
    # Recommandation : HSTS (HTTP Strict Transport Security)
    # Décommentez la ligne ci-dessous pour un A+ sur SSL Labs
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ... la suite de la configuration (sécurité, cache...)
    # est détaillée dans les sections suivantes ...
    
# } # <- Le bloc se ferme tout à la fin
```

### Explication

* **`listen 443 ssl;`** : Indique à NGINX d'écouter sur le port 443 et d'activer le protocole SSL/TLS pour ce bloc.

* **`http2 on;`** : Active le protocole HTTP/2. C'est une optimisation de performance majeure. Il permet au navigateur de télécharger plusieurs fichiers (images, CSS, JS) en parallèle sur une seule connexion (multiplexage), au lieu d'ouvrir une nouvelle connexion pour chaque fichier (coûteux en temps).

* **`[CONFIDENTIEL]`** : La clé privée (`privkey.key`) est le secret absolu qui garantit votre identité. Elle ne doit JAMAIS être partagée ou versionnée sur Git.

* **`server_tokens off;`** : Une mesure de sécurité simple. Par défaut, NGINX affiche sa version (ex: `Server: nginx/1.22.1`) dans les en-têtes de réponse. Cela informe les attaquants sur les failles de sécurité connues pour cette version. `off` cache cette information.
  > **Exemple :** Par défaut, NGINX répond `Server: nginx/1.22.0`. Cela donne des informations à un attaquant. Avec `server_tokens off;`, il répond simplement `Server: nginx`, cachant la version exacte (et donc les failles connues de cette version).

* **`add_header Strict-Transport-Security...`** : (Recommandé) C'est la directive HSTS. Elle dit au navigateur : "Pendant 1 an (`max-age`), ne me contacte jamais en HTTP. Ne parle qu'en HTTPS." Cela protège contre les attaques de type "man-in-the-middle".
  > **Pourquoi ?** Si un utilisateur se connecte depuis un Wi-Fi public (gare, café), une personne malveillante sur le même réseau pourrait intercepter le trafic. Le HTTPS (`httpS`) chiffre la connexion, rendant cette interception impossible.

---

## 🛡️ Section 3 : Pare-feu Applicatif (Défense Active)

C'est ici que NGINX cesse d'être un simple serveur web et devient un bouclier de sécurité actif. C'est une défense en profondeur qui complète fail2ban.

### 3.1. Anti-DoS (Limitation de Débit)

```nginx
    # Rate limiting
    limit_req zone=general burst=20 nodelay;
```

C'est le "videur" à l'entrée. Il protège contre les attaques DoS et les bots de scraping agressifs.

* **`zone=general`** : Utilise une zone mémoire (définie dans `nginx.conf`) pour compter les requêtes par IP.
* **`burst=20`** : Autorise un "pic" de 20 requêtes. C'est essentiel pour qu'un chargement de page normal (qui peut inclure 15-20 images, scripts, etc.) soit instantané.
* **`nodelay`** : Dit à NGINX de servir les 20 requêtes du "burst" immédiatement, sans les retarder. Toute requête au-delà du "burst" sera mise en attente (ou rejetée), protégeant le serveur.

> **Analogie :** C'est un "videur" à l'entrée. Il laisse entrer les gens à un rythme normal. Si un groupe de 20 (`burst`) arrive, il les laisse passer. Mais si un bus de 200 personnes arrive d'un coup (attaque DoS), il leur dit d'attendre et ne les laisse entrer qu'au compte-gouttes, protégeant le serveur.

### 3.2. Liste Noire Manuelle (Bannissement d'IPs)

```nginx
    # Bannir les IPs malveillantes
    deny 195.178.110.160;
    deny 104.23.221.142;
    deny 104.23.221.143;
    deny 35.233.210.231;
    deny 34.187.212.26;
    deny 34.11.205.87;
    deny 136.117.72.223;
    deny 35.197.17.94;
    deny 35.185.243.182;
    deny 34.168.16.43;
```

C'est une liste noire manuelle. Ces IPs ont été identifiées (probablement via les logs ou fail2ban) comme des attaquants persistants. Le `deny` est plus rapide que fail2ban car il est lu directement par NGINX au démarrage. C'est un complément parfait à la défense automatisée.

### 3.3. Filtrage des Méthodes HTTP

```nginx
    # Bloquer les méthodes HTTP non autorisées
    if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
    }
```

Un portfolio statique n'a besoin que de 3 méthodes :

* **GET** : Pour récupérer une page ou un fichier.
* **HEAD** : Pour vérifier si un fichier existe (utilisé par les caches, les bots).
* **POST** : Uniquement si vous avez un formulaire de contact.

Toutes les autres méthodes (PUT, DELETE, CONNECT, TRACE...) sont inutiles pour un visiteur et sont à 99% des tentatives d'attaque. On les bloque donc.

> **Pourquoi ?** Un navigateur a seulement besoin de `GET` (voir la page) ou `POST` (envoyer un formulaire). Des méthodes comme `DELETE` ou `PUT` n'ont rien à faire sur un portfolio et sont souvent utilisées par des attaquants.

### 3.4. Blocage de Chemins (Anti-Scan de Vulnérabilités)

```nginx
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
```

C'est l'une des défenses les plus efficaces. 99% du "bruit" des bots sur Internet consiste à scanner des vulnérabilités connues (WordPress, PHP, etc.), même si votre site n'est pas concerné.

* **`location ~* ...`** : Le `~*` signifie "correspondance par expression régulière (`~`), insensible à la casse (`*`)".
* **`^/(wp-|...)`** : Le `^` signifie "commence par". Bloque tout ce qui commence par `/wp-`.
* **`(\.env|\.git|...)`** : Le `|` signifie "OU". C'est une mesure critique. Elle bloque l'accès à :
  * **`/.git/`** : Exposer ce dossier permettrait à quiconque de télécharger tout le code source du site.
  * **`/.env`** : Exposer ce fichier révélerait tous les secrets (clés d'API, mots de passe).

> **Exemple critique :** Bloquer `/.git/`. Si ce dossier était accidentellement exposé, un attaquant pourrait télécharger tout le code source du site, y compris d'éventuels secrets (clés d'API, etc.).

### 3.5. Le "Mur de Briques" : `return 444`

**Pourquoi 444 et pas 403 Forbidden ?**

* Un **403** est une réponse polie. Le serveur dit "Je te vois, tu n'as pas le droit, voici une page d'erreur". Cela consomme des ressources (CPU, bande passante) pour générer et envoyer cette réponse.
* Un **`return 444`** est une instruction spécifique à NGINX qui signifie : "Ferme la connexion. Immédiatement. Sans envoyer de réponse."

> **Explication :** Un code `403 Forbidden` dit à l'attaquant "Non, tu n'as pas le droit". Un code `444` lui raccroche au nez sans rien dire. C'est plus efficace pour décourager les scanners.

C'est l'équivalent de raccrocher au nez de l'attaquant. C'est plus rapide, économise les ressources du serveur et déroute les scanners automatisés qui attendent une réponse.

---

## ⚡ Section 4 : Optimisation & Performance (Cache)

Cette section configure le cache côté client pour rendre le site quasi-instantané lors des visites ultérieures. C'est essentiel pour un bon score de performance (Lighthouse, PageSpeed).

### 4.1. Cache Agressif : Images & Polices

```nginx
    # Cache des images (1 an)
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Cache des fonts (1 an)
    location ~* \.(woff|woff2|ttf|otf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
```

C'est la stratégie de cache la plus performante.

* **`expires 1y;`** : Dit au navigateur : "Conserve ce fichier pendant 1 an."
* **`add_header Cache-Control "public, immutable";`** :
  * **`public`** : Le fichier peut être mis en cache par le navigateur, mais aussi par des proxys intermédiaires ou des CDN.
  * **`immutable`** : C'est une promesse. On dit au navigateur : "Ce fichier (ex: `logo.png` ou `font.woff2`) ne changera jamais. Fais-moi confiance. Ne viens même pas me redemander s'il est à jour." C'est le cache le plus puissant qui existe.
* **`access_log off;`** : Une optimisation de performance côté serveur. Inutile d'écrire une ligne dans un fichier log chaque fois qu'un `logo.png` est chargé. Cela réduit drastiquement les écritures disque (I/O), ce qui est crucial sur un VPS.

> **Analogie :** Quand un visiteur charge le site, son navigateur "prend une photo" du logo et des polices. Le serveur lui dit : "Garde ces photos pendant 1 an (`immutable`) et ne me les redemande pas". La prochaine fois qu'il visite, la page se charge instantanément car tout est déjà sur son ordinateur.

> **Pourquoi ?** Garder un journal de chaque fois que `logo.png` est chargé est inutile et consomme des ressources (écritures disque). On ne garde les logs que pour les pages HTML, qui sont bien plus importantes à suivre.

### 4.2. Cache Statique : CSS & JS

```nginx
    # Cache CSS et JS (6 mois)
    location ~* \.(css|js)$ {
        expires 6M;
        add_header Cache-Control "public";
    }
```

On utilise la même logique, mais sans `immutable`.

* **Pourquoi ?** Parce que les fichiers `style.css` ou `app.js` sont susceptibles d'être modifiés lors d'une mise à jour du site.
* **`Cache-Control "public"`** dit au navigateur de garder une copie, mais de quand même venir vérifier (via un en-tête `If-Modified-Since` ou `ETag`) si une nouvelle version est disponible. Si le fichier n'a pas changé, le serveur répond `304 Not Modified` (très rapide) ; s'il a changé, il envoie la nouvelle version.

---

## 🗂️ Section 5 : Service du Site (Le "Routeur")

Enfin, cette section gère la logique de base pour servir les fichiers du site.

```nginx
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
        try_files $uri $uri/ =404;
    }
}
```

### Explication

* **`location = /favicon.ico`** : Le `=` indique une correspondance exacte, ce qui est la vérification la plus rapide possible pour NGINX. On applique les mêmes optimisations de cache et de log que pour les autres images.

* **`log_not_found off;`** : Empêche NGINX de remplir les logs d'erreurs si ces fichiers (favicon, robots.txt) n'existent pas. Les navigateurs les demandent toujours automatiquement.

* **`location / { ... }`** : C'est le bloc "attrape-tout" final. Si aucune autre `location` plus spécifique n'a correspondu, celle-ci s'applique.

* **`try_files $uri $uri/ =404;`** : C'est le cœur d'un site statique. NGINX va essayer, dans l'ordre :
  * **`$uri`** : De trouver un fichier qui correspond exactement à l'URL. (Ex: `/contact.html` → NGINX cherche `/var/www/mon-portfolio/contact.html`).
  * **`$uri/`** : S'il ne trouve pas de fichier, il regarde si c'est un dossier. (Ex: `/blog/` → NGINX cherche `/var/www/mon-portfolio/blog/index.html`).
  * **`=404`** : S'il n'a toujours rien trouvé, il renvoie une erreur 404 (Page non trouvée).

---

## 🏗️ Architecture de Service

* **Domaine(s)** : `ewengadonnaud.xyz` et `www.ewengadonnaud.xyz`
* **Racine Web** : `/var/www/mon-portfolio`
* **Type de Site** : Statique (HTML/CSS/JS). C'est un avantage en soi : l'absence de base de données ou de langage serveur (PHP, Python) réduit massivement la "surface d'attaque".