FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

# renovate: datasource=github-releases depName=1Password/op-cli
ARG OP_VERSION=2.30.3
ARG OP_SHA256=a16307ebcecb40fd091d7a6ff4f0c380c3c0897c4f4616de2c5d285e57d5ee28

SHELL ["/bin/ash", "-eu", "-c"]

RUN apk add --no-cache \
    ca-certificates \
    curl \
    jq \
    unzip \
    && curl -fsSL "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_amd64_v${OP_VERSION}.zip" -o /tmp/op.zip \
    && echo "${OP_SHA256}  /tmp/op.zip" | sha256sum -c - \
    && unzip -p /tmp/op.zip op > /usr/local/bin/op \
    && chmod +x /usr/local/bin/op \
    && rm /tmp/op.zip \
    && apk del unzip curl

ENTRYPOINT ["/bin/sh", "-lc"]
