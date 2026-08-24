# Omarchy Football Scores

A livescore-style football widget for the [Omarchy](https://omarchy.org/) bar,
powered by ESPN's public API. No API key required.

## Features

- One day at a time, like livescore.com: every competition that plays that
  day, grouped under its own header (Premier League, La Liga, Serie A,
  Bundesliga, MLS, cups and more)
- Move between days with ‹ › arrows or the clickable day strip, plus a
  Today shortcut
- Live scores, kick-off times and results; live competitions are highlighted
- The bar tooltip shows the live score or the next fixture
- Middle-click the chip to force a refresh; data auto-refreshes every 60s
- Click a match row to open it on ESPN

## Install

```bash
omarchy plugin add https://github.com/iamstarcode/omarchy-plugin-football.git --enable
```

Then add the **Football Scores** widget from the bar settings.

## Update

```bash
omarchy plugin update iamstarcode.football
```

## Remove

```bash
omarchy plugin remove iamstarcode.football
```

## How it works

A small Python helper (`football.py`) takes a date and fetches that day's
scoreboard for every soccer competition from ESPN's public
`site.web.api.espn.com` header endpoint, normalizing it to JSON grouped by
competition. `Panel.qml` renders the selected day, refreshing every 60
seconds while matches are on.

## License

[MIT](LICENSE)
