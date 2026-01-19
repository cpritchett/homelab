# Stack Setup Guide

This document explains the required host paths, permissions, and setup procedures for each stack.

## Prerequisites

### Docker Network
All stacks require the `proxy_network` to exist:
```bash
docker network create proxy_network
```

### Environment Files
Each stack requires a `.env` file with actual values. Use the `.env.example` files as templates:
```bash
# For each stack
cd stacks/00-proxy
cp .env.example .env
# Edit .env with actual values

cd ../20-harbor
cp .env.example .env
# Edit .env with actual values
```

## Stack: 00-proxy (Caddy Reverse Proxy)

### Required Host Paths
```bash
# Caddy data and configuration storage
sudo mkdir -p /mnt/apps01/appdata/proxy/{caddy-data,caddy-config}
sudo chown -R 1701:1702 /mnt/apps01/appdata/proxy/
```

### Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `CADDY_DATA_PATH` | Caddy data storage | `/mnt/apps01/appdata/proxy/caddy-data` |
| `CADDY_CONFIG_PATH` | Caddy config storage | `/mnt/apps01/appdata/proxy/caddy-config` |
| `CLOUDFLARE_API_TOKEN` | DNS-01 challenge token | `your_token_here` |
| `CADDY_EMAIL` | Let's Encrypt email | `admin@example.com` |
| `TZ` | Timezone | `America/Chicago` |

### Deployment
```bash
cd stacks/00-proxy
docker compose --env-file .env up -d
```

## Stack: 20-harbor (Container Registry)

### Required Host Paths
Harbor requires extensive configuration and data directories:

```bash
# Create base directories
sudo mkdir -p /mnt/apps01/appdata/services/harbor/{config,data}
sudo mkdir -p /var/log/harbor

# Create config structure
sudo mkdir -p /mnt/apps01/appdata/services/harbor/config/common/{config,secret}
sudo mkdir -p /mnt/apps01/appdata/services/harbor/config/common/config/{core,jobservice,log,nginx,portal,registry,registryctl,shared}
sudo mkdir -p /mnt/apps01/appdata/services/harbor/config/common/secret/{core,keys,registry}
sudo mkdir -p /mnt/apps01/appdata/services/harbor/config/common/config/shared/trust-certificates

# Create data structure
sudo mkdir -p /mnt/apps01/appdata/services/harbor/data/{ca_download,database,job_logs,redis,registry}

# Set permissions
sudo chown -R 999:999 /mnt/apps01/appdata/services/harbor/data/database
sudo chown -R 999:999 /mnt/apps01/appdata/services/harbor/data/redis
sudo chown -R root:root /mnt/apps01/appdata/services/harbor/config
sudo chmod -R 755 /mnt/apps01/appdata/services/harbor/config
```

### Required Configuration Files
Harbor needs several configuration files to be created before first run:

#### 1. Core Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/core/app.conf`)
```ini
appname = harbor
runmode = prod
enablegzip = true

[prod]
httpport = 8080
```

#### 2. Registry Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/registry/config.yml`)
```yaml
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /storage
  maintenance:
    uploadpurging:
      enabled: false
  delete:
    enabled: true
http:
  addr: :5000
  relativeurls: false
  draintimeout: 60s
auth:
  htpasswd:
    realm: harbor-registry-basic-realm
    path: /etc/registry/passwd
validation:
  disabled: true
compatibility:
  schema1:
    enabled: true
```

#### 3. Registry Control Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/registryctl/config.yml`)
```yaml
---
protocol: "http"
port: 8080
log_level: info
registry_config: "/etc/registry/config.yml"
```

#### 4. Job Service Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/jobservice/config.yml`)
```yaml
---
protocol: "http"
port: 8080
log_level: INFO
```

#### 5. Nginx Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/nginx/nginx.conf`)
```nginx
worker_processes auto;
pid /tmp/nginx.pid;

events {
  worker_connections 1024;
  use epoll;
  multi_accept on;
}

http {
  tcp_nodelay on;
  
  upstream core {
    server core:8080;
  }
  
  upstream portal {
    server portal:8080;
  }
  
  log_format timed_combined '$remote_addr - '
    '"$request" $status $body_bytes_sent '
    '"$http_referer" "$http_user_agent" '
    '$request_time $upstream_response_time $pipe';

  access_log /dev/stdout timed_combined;
  
  server {
    listen 8080;
    server_name harbordomain.com;
    
    client_max_body_size 0;
    chunked_transfer_encoding on;
    
    location / {
      proxy_pass http://portal/;
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_buffering off;
      proxy_request_buffering off;
    }
    
    location /api/ {
      proxy_pass http://core/api/;
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_buffering off;
      proxy_request_buffering off;
    }
    
    location /service/ {
      proxy_pass http://core/service/;
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_buffering off;
      proxy_request_buffering off;
    }
    
    location /v2/ {
      proxy_pass http://core/v2/;
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_buffering off;
      proxy_request_buffering off;
    }
  }
}
```

#### 6. Portal Configuration (`/mnt/apps01/appdata/services/harbor/config/common/config/portal/nginx.conf`)
```nginx
worker_processes auto;
pid /tmp/nginx.pid;

events {
  worker_connections 1024;
}

http {
  server {
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    location / {
      try_files $uri $uri/ /index.html;
    }
    
    location /api {
      return 404;
    }
  }
}
```

#### 7. Log Configuration Files
```bash
# rsyslog_docker.conf
sudo tee /mnt/apps01/appdata/services/harbor/config/common/config/log/rsyslog_docker.conf << 'EOF'
$ModLoad imuxsock
$WorkDirectory /var/spool/rsyslog
$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
$IncludeConfig /etc/rsyslog.d/*.conf
*.info;mail.none;authpriv.none;cron.none /var/log/docker/docker.log
EOF

# logrotate.conf
sudo tee /mnt/apps01/appdata/services/harbor/config/common/config/log/logrotate.conf << 'EOF'
/var/log/docker/*.log {
  daily
  rotate 52
  compress
  delaycompress
  missingok
  notifempty
  create 644 10000 10000
}
EOF
```

#### 8. Secret Files
```bash
# Create placeholder secret files
sudo touch /mnt/apps01/appdata/services/harbor/config/common/secret/core/private_key.pem
sudo touch /mnt/apps01/appdata/services/harbor/config/common/secret/keys/secretkey
sudo touch /mnt/apps01/appdata/services/harbor/config/common/secret/registry/root.crt

# Set proper permissions
sudo chmod 600 /mnt/apps01/appdata/services/harbor/config/common/secret/core/private_key.pem
sudo chmod 600 /mnt/apps01/appdata/services/harbor/config/common/secret/keys/secretkey
sudo chmod 644 /mnt/apps01/appdata/services/harbor/config/common/secret/registry/root.crt
```

### Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `HARBOR_CONFIG_PATH` | Harbor config directory | `/mnt/apps01/appdata/services/harbor/config` |
| `HARBOR_DATA_PATH` | Harbor data directory | `/mnt/apps01/appdata/services/harbor/data` |
| `HARBOR_LOG_PATH` | Harbor log directory | `/var/log/harbor` |
| `CLOUDFLARE_API_TOKEN` | DNS-01 challenge token | `your_token_here` |
| `HARBOR_ADMIN_PASSWORD` | Harbor admin password | `secure_password_here` |
| `POSTGRES_PASSWORD` | Database password | `secure_db_password_here` |
| `HARBOR_CORE_SECRET` | Internal core secret | `random_string_32_chars` |
| `HARBOR_JOBSERVICE_SECRET` | Internal job secret | `random_string_32_chars` |
| `TZ` | Timezone | `America/Chicago` |

### Deployment
```bash
cd stacks/20-harbor
docker compose --env-file .env up -d
```

## Deployment Order

Deploy stacks in this order due to dependencies:

1. **proxy** - Creates the `proxy_network` and provides reverse proxy
2. **harbor** - Connects to `proxy_network` for external access

## Komodo Integration

When using Komodo:

1. **Create Stacks**: Configure each stack in Komodo UI
2. **Set Environment Variables**: Use the Komodo UI to set all environment variables from the `.env.example` files
3. **Deploy**: Use Komodo's deployment interface instead of manual `docker compose` commands

## Troubleshooting

### Common Issues

**Permission Errors:**
- Ensure directories exist with correct ownership
- Check that user IDs match container expectations

**Harbor Won't Start:**
- Verify all configuration files are present
- Check that secret files exist (even if empty)
- Ensure database directory has correct permissions

**Network Errors:**
- Confirm `proxy_network` exists: `docker network ls`
- Verify containers can communicate within the network

### Useful Commands

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f [service_name]

# Restart specific service
docker compose restart [service_name]

# Rebuild and restart
docker compose up -d --force-recreate [service_name]
```

## Security Considerations

- All host paths should be owned by appropriate users
- Secret files should have restrictive permissions (600)
- Environment variables containing secrets should never be committed to git
- Use strong, unique passwords for all services
- Regularly update container images for security patches