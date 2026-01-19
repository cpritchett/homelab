# Harbor secrets - stored in 1Password, rendered locally into .env (never commit .env)
HARBOR_ADMIN_PASSWORD=op://homelab/harbor/HARBOR_ADMIN_PASSWORD
HARBOR_DB_PASSWORD=op://homelab/harbor/HARBOR_DB_PASSWORD
HARBOR_CORE_SECRET=op://homelab/harbor/HARBOR_CORE_SECRET
HARBOR_JOBSERVICE_SECRET=op://homelab/harbor/HARBOR_JOBSERVICE_SECRET

# Caddy reads this from proxy/.env, but label plugin expects env var at runtime.
# If your caddy container already has CLOUDFLARE_API_TOKEN env set, you can omit this here.
CLOUDFLARE_API_TOKEN=op://homelab/cloudflare-dns01/CLOUDFLARE_API_TOKEN
