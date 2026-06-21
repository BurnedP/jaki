# Kindle Daily

A local-first daily dashboard for a jailbroken Kindle, built as a KOReader plugin. To-dos, habit tracking, and weather on one glanceable home screen — plus a Continue Reading strip so it can stand in as the device's everyday home.

Built and tested on a **Kindle Paperwhite 12th gen (2024)** running KOReader v2026.03.

## What it does

- **Home** — date + greeting, a full weather section (icon, big temp, condition, H/L, hourly), To-Dos and Habits side by side, and recent books to jump back into.
- **To-Dos** — Today / Later / Done, tap to toggle, hold to delete.
- **Habits** — streaks and a 7-day grid, tap to mark today.
- **Weather** — current + hourly + daily, via [Open-Meteo](https://open-meteo.com) (no API key).
- **Settings** — toggle home modules, set location/name/units.

Everything except weather works fully offline; weather caches its last result.

## Layout

```
kindledaily.koplugin/
  _meta.lua            plugin metadata
  main.lua             entry point (registers menu item, launches app)
  app.lua              full-screen shell: status bar, body router, bottom nav
  taprow.lua           reusable tappable-row widget
  ui_helpers.lua       fonts, boxes, icons, wrapped text, dividers
  assets.lua           resolves the plugin dir for bundled assets
  store.lua            LuaSettings-backed persistence + id counter
  model_todos.lua      to-do model
  model_habits.lua     habit model (streaks, 7-day cells)
  prefs.lua            app preferences / home-module toggles
  dateutil.lua         date keys, header date, greeting
  weather_service.lua  Open-Meteo geocode + forecast (keyless)
  weather_icons.lua    WMO code -> bundled SVG glyph
  screen_*.lua         home / todos / habits / weather / settings
  icons/               SVG weather + book glyphs
docs/                  design brief + mockup
scripts/deploy.sh      push to a connected Kindle over MTP
```

## Deploy

Connect the Kindle over USB in **file-transfer (MTP)** mode, then:

```bash
./scripts/deploy.sh
```

Then **restart KOReader** on the device. KOReader caches Lua modules in memory, so a full restart (not just reopening the plugin) is required to load changes.

Open from KOReader: top menu → **More tools** → **Kindle Daily**.

## Notes

- Data lives in KOReader's settings dir (`kindledaily.lua`); it survives plugin updates.
- Weather needs a location set in Settings; it uses Open-Meteo, no signup.
- Book covers use KOReader's cached cover DB when available, falling back to a book glyph.
