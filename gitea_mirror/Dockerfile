ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24-2026.10.1

# The official image holds the application: the compiled web interface, its dependencies and the
# database migrations. Only those files are taken from it. The Debian system underneath is not,
# because the app is meant to run on the Home Assistant base image with bashio and s6-overlay.
# renovate: datasource=docker depName=ghcr.io/raylabshq/gitea-mirror
ARG GITEA_MIRROR_VERSION=v3.46.0
FROM ghcr.io/raylabshq/gitea-mirror:${GITEA_MIRROR_VERSION} AS gitea-mirror

# The runtime in its Alpine (musl) build; upstream runs on the same bun release.
# renovate: datasource=docker depName=docker.io/oven/bun
ARG BUN_VERSION=1.3.14-alpine
FROM docker.io/oven/bun:${BUN_VERSION} AS bun

FROM ${BUILD_FROM}

# Alpine's busybox is built without the httpd applet and sqlite3; git and git-lfs are what the
# application shells out to (pre-sync backups, push targets, LFS). bun needs the C++ runtime.
RUN apk add --no-cache \
    # renovate: datasource=repology depName=alpine_3_24/libstdc++
    libstdc++=15.2.0-r5 \
    # renovate: datasource=repology depName=alpine_3_24/libgcc
    libgcc=15.2.0-r5 \
    # renovate: datasource=repology depName=alpine_3_24/git
    git=2.54.0-r0 \
    # renovate: datasource=repology depName=alpine_3_24/git-lfs
    git-lfs=3.7.1-r2 \
    # renovate: datasource=repology depName=alpine_3_24/sqlite
    sqlite=3.53.4-r0 \
    # renovate: datasource=repology depName=alpine_3_24/curl
    curl=8.23.0-r0 \
    # renovate: datasource=repology depName=alpine_3_24/jq
    jq=1.8.2-r0 \
    && git lfs install --system \
    && addgroup -S -g 1001 gitea-mirror \
    && adduser -S -D -H -u 1001 -G gitea-mirror -h /data/home gitea-mirror

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
RUN bun --version

WORKDIR /app
COPY --from=gitea-mirror /app/node_modules ./node_modules
COPY --from=gitea-mirror /app/dist ./dist
COPY --from=gitea-mirror /app/drizzle ./drizzle
COPY --from=gitea-mirror /app/package.json ./package.json
# The application keeps its database and secrets in data/; Home Assistant keeps /data.
RUN ln -s /data /app/data

COPY rootfs/ /
COPY licenses/ /usr/share/licenses/gitea-mirror/
COPY LICENSE THIRD_PARTY_NOTICES.md /usr/share/licenses/gitea-mirror/

# Git does not keep the executable bit when files are uploaded through the GitHub API.
RUN chmod a+x /usr/lib/gitea-mirror/*.sh \
    && find /etc/s6-overlay/s6-rc.d -type f \( -name run -o -name finish \) -exec chmod a+x {} +

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8099 \
    DATABASE_URL=file:data/gitea-mirror.db

ARG BUILD_VERSION=1.0.0-alpha.1
ARG BUILD_ARCH=amd64
RUN mkdir -p /etc/gitea-mirror && echo "${BUILD_VERSION}" >/etc/gitea-mirror/version
LABEL io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.source="https://github.com/seb5594/Home-Assistant-Gitea-Mirror-App"

HEALTHCHECK --interval=1m --timeout=10s --start-period=1m --retries=3 \
    CMD ["/usr/lib/gitea-mirror/healthcheck.sh"]
