# Planner — AI-Powered Leisure Activity Planner for iOS

**Author:** Carlo Cancellieri
**License:** Apache 2.0
**Repository:** [github.com/ccancellieri/plan-viewer](https://github.com/ccancellieri/plan-viewer)
**Status:** Active development

## Overview

A self-contained leisure activity planner built as a [Scriptable](https://scriptable.app/) widget for iOS. Uses LLM APIs to discover activities and generates interactive Leaflet maps — all running entirely on-device with local iCloud Drive storage.

## Key Features

- **Multi-LLM support** — Claude, Gemini, Perplexity, DeepSeek, and more
- **Interactive maps** — Generates Leaflet-based HTML maps with activity markers
- **Fully local** — No server, no App Store, no backend required
- **GPS integration** — Automatically detects location or manual search
- **Multi-language** — English and Italian i18n support
- **iCloud storage** — Maps and plans stored in iCloud Drive

## Architecture

Single-file Scriptable script (~1500 lines) that:
1. Prompts user for location, dates, and preferences
2. Calls LLM APIs to find activities with geolocation data
3. Renders an interactive Leaflet map with categorized markers
4. Stores maps locally for offline access

## Technology

- JavaScript (Scriptable iOS runtime)
- Leaflet.js for map rendering
- OpenStreetMap Nominatim for geocoding
- Multiple LLM API integrations
- WebView for in-app map display
