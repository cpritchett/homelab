# renovate: datasource=docker depName=1password/op
FROM 1password/op:2@sha256:57d7d6a2bb2b74b2cf8111f6afb2973c74772198f82ea30359a53faae9fff5b1

# Add jq for JSON processing required by op-export-stack-env.sh
USER root
RUN apt-get update && apt-get install -y --no-install-recommends jq && rm -rf /var/lib/apt/lists/*
USER opuser

ENTRYPOINT ["/bin/sh", "-lc"]
