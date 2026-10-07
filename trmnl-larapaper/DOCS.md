# LaraPaper (BYOS) for Home Assistant

![TRMNL Logo](https://github.com/usetrmnl/trmnl-home-assistant/blob/main/trmnl-ha/logo.png?raw=true)

This add-on runs [LaraPaper](https://github.com/usetrmnl/larapaper), a self-hosted TRMNL
server (BYOS) with recipes, playlists and mashups, inside Home Assistant. It is the
official LaraPaper image with these additions:

- The **TRMNL framework 3.3.1** (CSS, JS and fonts) is built into the add-on, so screens
  render without fetching it from trmnl.com. The Inter stylesheet from fonts.bunny.net
  is removed; the framework ships Inter itself.
- The database, generated screens and app key are kept in `/data`, so they survive
  updates and are part of Home Assistant backups.
- **Recipes can read Home Assistant without a token** at `http://127.0.0.1:8124` (see
  [Home Assistant access](#home-assistant-access-for-recipes)).
- **Screens are rendered ahead of time**, so the TRMNL never waits on a render.
- **Each TRMNL shows up in Home Assistant** as a device with its battery, Wi-Fi signal,
  firmware, last check-in and screen, through MQTT (see [Device sensors](#device-sensors)).
- **The web UI opens inside Home Assistant** (ingress), wherever Home Assistant is
  reachable.

## Setup

1. Set **App URL** to the address your TRMNL uses to reach this add-on, e.g.
   `http://192.168.1.10:4567`. The device downloads its screen image from there, so use
   an IP address or a name the device can resolve (`.local` names usually don't work).
2. Start the add-on and click **Open Web UI**. Register your account, then turn off
   **Allow registration**.
3. Point the TRMNL at the server. A new device starts in Wi-Fi pairing mode; to get back
   to it, hold the left and right ends of the touch bar until the screen flashes (TRMNL X)
   or hold the button on the back for 6 to 8 seconds (TRMNL OG). Connect to the **TRMNL**
   Wi-Fi network, tap **Advanced** → **Custom Server** → **Yes** and enter the App URL
   without a trailing slash, then go **Back to Wi-Fi**, pick your network and **Connect**.
   With the **Auto-Join** toggle in LaraPaper's header switched on, the device appears by
   itself. The "Please visit trmnl.com/start" screen it then shows comes from the
   firmware and can be ignored; the device picks up its playlist at the next refresh. A
   TRMNL OG on firmware older than 1.4.6 has no **Custom Server** option and needs a
   firmware update first.
4. Add recipes under **Plugins**, for example from LaraPaper's OSS catalog or the TRMNL
   catalog.

## Configuration

| Option | Default | What it does |
| --- | --- | --- |
| App URL | empty | The address in the screen links LaraPaper gives the TRMNL (`APP_URL`) |
| Allow registration | on | Whether anyone reaching the web UI can create an account |
| Home Assistant access for recipes | `calendars` | What `http://127.0.0.1:8124` lets recipes read, see below |
| Render screens ahead of time | on | See [Rendering ahead of time](#rendering-ahead-of-time) |
| Device sensors in Home Assistant | on | See [Device sensors](#device-sensors) |

## Home Assistant access for recipes

Recipes that poll Home Assistant normally need its URL and a long-lived access token.
In this add-on they can poll `http://127.0.0.1:8124` instead, with no token: the add-on
forwards those requests to Home Assistant with its own access. Only GET requests from
inside the add-on get through, and only these paths:

| Setting | Paths |
| --- | --- |
| `off` | none |
| `calendars` (default) | `/api/calendars`, `/api/calendars/<entity>?start=...&end=...`, and `/api/weather/<weather entity>` |
| `read` | the above, plus `/api/states`, `/api/states/<entity>` and `/api/history/period/...` |

`/api/weather/<weather entity>` (for example `/api/weather/weather.home`) returns that
entity's daily forecast. Home Assistant only gives forecasts through a service call
(POST `weather.get_forecasts`), which a recipe can't make, so the add-on makes that one
call for it.

Recipes run in the add-on's own browser, so every recipe you install can read what this
setting allows, whichever recipe you set it up for. Leave it at `calendars` unless a
recipe needs more, and only install recipes you trust with `read`.

## Rendering ahead of time

LaraPaper renders a recipe only when the TRMNL asks for its screen and the recipe's data
is older than its refresh interval. The TRMNL gives up after 15 seconds, which a render on
a Home Assistant machine can take, and then shows an error. The add-on renders each
polling recipe in a device's playlists shortly before its refresh interval runs out, so
the TRMNL gets a ready screen. Mashups are still rendered when the TRMNL asks.

## Device sensors

With the **Mosquitto broker** add-on installed (and the MQTT integration set up, which
Home Assistant offers once the broker runs), every TRMNL in LaraPaper appears under
**Settings** → **Devices & services** → **MQTT** as its own device, named as in
LaraPaper. Each one has:

| Entity | What it shows |
| --- | --- |
| Battery | Charge in % (from the battery voltage the TRMNL reports) |
| Charging, USB connected | On or off (newer firmware only) |
| Firmware | The installed version, and an update when LaraPaper knows a newer one; **Install** has the TRMNL install it when it next wakes |
| Wi-Fi signal | In dBm |
| Last seen | When the TRMNL last asked for its screen |
| Online | Off once it hasn't asked for twice its refresh interval plus 5 minutes (not while it sleeps) |
| Screen | The screen the TRMNL was last given, as an image |
| Sleep mode, Sleep from, Sleep until | Turn sleep mode on or off and set its times |
| Refresh interval | How often the TRMNL wakes, in seconds |
| Refresh screen | Fetches its recipes' data and renders them again now, for the TRMNL's next wake |
| Battery voltage | Off by default |
| Temperature, humidity, CO2, pressure | Only for a TRMNL with such a sensor attached |

The values update within seconds of each check-in. Changes you make in Home Assistant
reach the TRMNL the next time it wakes, as changes in LaraPaper do. A device you delete in
LaraPaper is removed from Home Assistant too. The add-on finds the broker by itself;
without one it checks again every few minutes.

## The web UI

**Open Web UI** (and **Show in sidebar** on the add-on's page) shows LaraPaper inside
Home Assistant, which passes it on through its own connection (ingress). It works
wherever Home Assistant does, for example through Home Assistant Cloud or your own remote
access, so LaraPaper itself never has to be reachable from the internet. You still log in
to LaraPaper there; passkeys you created at `http://<ha-ip>:4567` don't work under Home
Assistant's address, a password does.

At home, the web UI is also at the App URL (port 4567), next to the TRMNL's device API.

## What still goes online

Rendering the TRMNL framework doesn't. LaraPaper's own background jobs still try to
reach the internet: a daily firmware check, a weekly device-model list update and an
update check in the web UI. They fail harmlessly when there's no connection. Recipes
that load their own scripts, fonts or images from the internet (charts, maps, a
calendar library) still need it, and so does a recipe that asks for a framework version
other than 3.3.1.

## Security

This add-on is meant for trusted home networks. Port 4567 serves the TRMNL device API
and the web UI; don't expose it to the internet (use **Open Web UI** from outside).
Ingress on port 8099 only answers Home Assistant's own proxy. The Home Assistant proxy
on `127.0.0.1:8124` is only reachable from inside the add-on.

## Updating

The add-on's version is the LaraPaper release it runs (`0.43.1` runs LaraPaper 0.43.1).
A fix to the add-on alone between LaraPaper releases adds `-1`, `-2`.
