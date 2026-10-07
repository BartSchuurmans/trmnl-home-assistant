# LaraPaper for Home Assistant: the official LaraPaper image plus the TRMNL framework
# (so screens render without fetching it from trmnl.com), Home Assistant's /data,
# options and ingress, pre-rendering and MQTT device sensors.
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

# Point LaraPaper at the bundled framework instead of trmnl.com, and drop the Inter
# stylesheet from fonts.bunny.net (the framework ships Inter itself). OPcache on, as in
# LaraPaper's own docker-compose.
ENV TRMNL_BLADE_FRAMEWORK_CSS_URL=/trmnl-framework/3.3.1/plugins.min.css \
    TRMNL_BLADE_FRAMEWORK_JS_URL=/trmnl-framework/3.3.1/plugins.min.js \
    PHP_OPCACHE_ENABLE=1
RUN view=/var/www/html/resources/views/vendor/trmnl/components/screen.blade.php \
    && sed -i '/fonts\.bunny\.net/d' "$view" \
    && ! grep -q 'fonts\.bunny\.net' "$view"

COPY rootfs /
RUN chmod +x /etc/entrypoint.d/10-homeassistant.sh \
    /etc/s6-overlay/s6-rc.d/larapaper-ha-prerender/run \
    /etc/s6-overlay/s6-rc.d/larapaper-ha-mqtt/run

# Renders recipe screens ahead of time, so the TRMNL doesn't wait on a render, and
# publishes the TRMNL devices to Home Assistant through MQTT discovery. Both run as s6
# services next to LaraPaper's scheduler (rootfs/etc/s6-overlay).
COPY ha/prerender.php ha/mqtt.php /opt/larapaper-ha/

# Home Assistant ingress: see IngressServiceProvider.php and 10-homeassistant.sh
COPY --chown=www-data:www-data ha/IngressServiceProvider.php /var/www/html/app/Providers/
COPY --chown=www-data:www-data ha/ingress.js /var/www/html/public/larapaper-ha/
RUN providers=/var/www/html/bootstrap/providers.php \
    && sed -i 's/^];$/    App\\Providers\\IngressServiceProvider::class,\n];/' "$providers" \
    && grep -q 'App\\Providers\\IngressServiceProvider::class' "$providers"
