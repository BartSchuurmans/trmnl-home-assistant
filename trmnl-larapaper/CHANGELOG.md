# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
The version mirrors the [LaraPaper](https://github.com/usetrmnl/larapaper) release
the add-on bundles, so add-on 0.43.1 ships LaraPaper 0.43.1. A wrapper-only fix
between upstream releases takes a `-1`, `-2` suffix.

## [0.43.1] - 2026-10-07

### Added

- LaraPaper 0.43.1 as a Home Assistant add-on, with the TRMNL framework 3.3.1 built in,
  its data in `/data`, the web UI through ingress, a token-free Home Assistant proxy for
  recipes, screens rendered ahead of time and each TRMNL as an MQTT device. Ported from
  the LaraPaper (local) app in BartSchuurmans/trmnl-rolling-month-calendar, without its
  calendar-recipe parts.
