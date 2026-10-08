# LaraPaper for Home Assistant: the official LaraPaper image plus the TRMNL framework
# (so screens render without fetching it from trmnl.com), Home Assistant's /data,
# options, ingress and a token-free proxy to Home Assistant's API for recipes.
# The Supervisor (and CI) pass BUILD_FROM from build.yaml.
ARG BUILD_FROM
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Root so the entrypoint hook can take ownership of the Supervisor-mounted /data;
# PHP-FPM workers still run as www-data (serversideup-php images support this).
# hadolint ignore=DL3002
USER root

# TRMNL framework 3.3.1 (LaraPaper's default version) with its fonts, each file pinned
# by SHA-256 in assets.txt. Recipe markup can't inline it: Browsershot rejects pages
# containing "file:" and similar strings, so it is served from root-relative paths.
COPY assets.txt fetch-assets.sh /tmp/larapaper-ha/
RUN sh /tmp/larapaper-ha/fetch-assets.sh /tmp/larapaper-ha/assets.txt /opt/larapaper-ha-assets \
    && rm -rf /tmp/larapaper-ha

# Screens render from a temporary file:// page, so "/fonts/x" resolves to the
# filesystem there, and to nginx (public/) in the browser preview. The framework CSS
# refers to its fonts as "/fonts/...".
RUN for dir in trmnl-framework fonts; do \
        ln -sfn "/opt/larapaper-ha-assets/$dir" "/$dir"; \
        ln -sfn "/opt/larapaper-ha-assets/$dir" "/var/www/html/public/$dir"; \
    done

# Point LaraPaper at the bundled framework instead of trmnl.com (the explicit URLs win
# over TRMNL_BLADE_FRAMEWORK_BASE_URL and the recipe's framework_version). OPcache on, as
# in LaraPaper's own docker-compose.
ENV TRMNL_BLADE_FRAMEWORK_CSS_URL=/trmnl-framework/3.3.1/plugins.min.css \
    TRMNL_BLADE_FRAMEWORK_JS_URL=/trmnl-framework/3.3.1/plugins.min.js \
    PHP_OPCACHE_ENABLE=1

COPY rootfs /
RUN chmod +x /etc/entrypoint.d/10-homeassistant.sh

# Home Assistant ingress: see 10-homeassistant.sh
COPY --chown=www-data:www-data ha/ingress.js /var/www/html/public/larapaper-ha/

# Home Assistant's add-on linter wants the native health check rather than a watchdog:
# healthy once Laravel answers (LaraPaper's /up).
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -fsS -o /dev/null http://localhost:8080/up || exit 1
