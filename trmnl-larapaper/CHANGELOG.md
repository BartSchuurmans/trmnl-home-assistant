# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
The version mirrors the [LaraPaper](https://github.com/usetrmnl/larapaper) release
the add-on bundles, so add-on 0.44.0 ships LaraPaper 0.44.0. A wrapper-only fix
between upstream releases takes a `-1`, `-2` suffix.

Each entry starts with the bundled LaraPaper release's own notes (on the version that
first bundles it), followed by the add-on's own changes under "Home Assistant add-on".

## [0.44.0] - 2026-10-08

### LaraPaper 0.44.0

From the [LaraPaper 0.44.0 release](https://github.com/usetrmnl/larapaper/releases/tag/0.44.0):

This release expands firmware OTA support for TRMNL BWRY, updates iCal parsing with expanded date ranges, adds recipe catalog sorting options and reworks key UI views with a new design. TRMNL Framework is bumped to version 3.4.0.

#### What's Changed
* feat: add Liquid support to Markup plugin
* feat: add support for TRMNL BWRY firmware OTA updates
* feat: upgrade to om/icalparser major version 5
* feat: upgrade to new IcalParser v5 API
* feat(#292): increase iCal date window from (-7, +30) days to (-7, +45) days by [@BartSchuurmans](https://github.com/BartSchuurmans) in [#301](https://github.com/usetrmnl/larapaper/pull/301)
* feat(#295): implement HTML purification for recipe settings field author bio, description, help_text
* feat: add GET and PATCH /api/devices/{id} in the shape of TRMNL's API by [@BartSchuurmans](https://github.com/BartSchuurmans) in [#306](https://github.com/usetrmnl/larapaper/pull/306)
* feat: added sorting options in TRMNL recipe catalog
* feat: enable MCP stdio server on local environments
* feat: add support for `TRMNL_BLADE_FRAMEWORK_BASE_URL`
* feat: rework dashboard with view with `flux:card`
* feat: rework device and playlist view with `flux:card`
* feat: rework plugin grid view with `flux:card`
* fix(#297): support `no_screen_padding` and `dark_mode` in recipe configuration
* fix(#267): add css model identifier warning
* fix(#291): reset image cache when render-affecting settings change
* fix(#294): links in recipe description fields open new tab
* fix: mobile optimize devices overview screens
* fix: remove fixed width and height from app logo SVG
* fix: remove unused inter font via bunny cdn
* fix: support serving under a sub-path via X-Forwarded-Prefix by [@BartSchuurmans](https://github.com/BartSchuurmans) in [#304](https://github.com/usetrmnl/larapaper/pull/304)
* chore: update TRMNL Framework to 3.4.0
* chore: add transform incompatibility warning
* chore: fix Dev Container by [@BartSchuurmans](https://github.com/BartSchuurmans) in [#300](https://github.com/usetrmnl/larapaper/pull/300)

#### New Contributors
* [@BartSchuurmans](https://github.com/BartSchuurmans) made their first contribution in [#300](https://github.com/usetrmnl/larapaper/pull/300)

#### New Supporters
Thank you for your support: Johan, 16tools.com and jfkmdd

**Full Changelog**: [0.43.1...0.44.0](https://github.com/usetrmnl/larapaper/compare/0.43.1...0.44.0)

### Home Assistant add-on

- LaraPaper 0.44.0 as a Home Assistant add-on, with the TRMNL framework 3.3.1 built in,
  its data in `/data`, the web UI through ingress and a token-free Home Assistant proxy
  for recipes.
