```mermaid
graph TD
    subgraph "Serveur VPS"
        direction TB

        subgraph "1. Visualisation"
            Grafana(<b>Grafana</b><br>Le tableau de bord central)
        end

        subgraph "2. Stockage (Bases de données)"
            Prometheus(<b>Prometheus</b><br>Stocke les métriques<br>ex: 'CPU = 10%')
            Loki(<b>Loki</b><br>Stocke les lignes de logs<br>ex: 'GET / 200')
        end

        subgraph "3. Collecte (Agents)"
            NodeExporter(<b>Node Exporter</b><br>Expose les métriques du système)
            Promtail(<b>Promtail</b><br>Lit et envoie les fichiers de logs)
        end

        subgraph "4. Sources de Données (Natives)"
            System(Métriques OS<br>CPU, RAM, Disque, Réseau)
            NginxMetrics(Métriques NGINX<br>Requêtes/sec)
            Logs(Fichiers de Log<br>/var/log/nginx/*<br>/var/log/fail2ban.log)
        end
    end

    subgraph "Extérieur"
        User(Vous [Admin])
    end

    %% --- Définition des flux ---

    %% Flux Métriques
    System -->|Expose via /metrics| NodeExporter
    NginxMetrics -->|Expose via /metrics| NodeExporter
    Prometheus -->|Scrape (Tire les données)| NodeExporter
    Grafana -->|Requête (Source de données)| Prometheus

    %% Flux Logs
    Logs -->|Lit et "Suit"| Promtail
    Promtail -->|Push (Pousse les données)| Loki
    Grafana -->|Requête (Source de données)| Loki
    
    %% Flux Utilisateur
    User -->|Consulte via le navigateur| Grafana
```
