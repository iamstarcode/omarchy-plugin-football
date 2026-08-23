# Omarchy Football Scores

Live football scores and upcoming fixtures in the [Omarchy](https://omarchy.org/)
bar, powered by ESPN's public API. No API key required.

## Features

- Today's matches with live scores, kick-off times and results
- Fixtures for the week ahead, grouped by day
- The bar chip lights up while a match is live
- Tooltip shows the live score or your next fixture
- Pick your league from 11 options: Premier League, La Liga, Serie A,
  Bundesliga, Ligue 1, Primeira Liga, Eredivisie, MLS, Champions League,
  Europa League and the World Cup
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

A small Python helper (`football.py`) fetches a 7-day scoreboard window from
ESPN's public `site.api.espn.com` endpoint for the selected league and
normalizes it to JSON. `Panel.qml` renders today's matches plus upcoming
fixtures, refreshing every 60 seconds. Your league choice is stored in
`~/.config/omarchy/iamstarcode.football.json`.

## License

[MIT](LICENSE)
