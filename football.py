#!/usr/bin/env python3
"""Fetch and normalize today's football fixtures for iamstarcode.football."""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "omarchy" / "iamstarcode.football.json"
API_ROOT = "https://site.api.espn.com/apis/site/v2/sports/soccer"
USER_AGENT = "iamstarcode-football/0.3 (+https://github.com/iamstarcode/omarchy-plugin-football)"
MAX_RESPONSE_BYTES = 12_000_000
DEFAULT_LEAGUE = "eng.1"


class HTTPSOnlyRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not newurl.lower().startswith("https://"):
            raise ValueError("API redirected to a non-HTTPS connection")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def json_out(**payload: object) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def fetch_json(url: str) -> dict:
    if not url.lower().startswith("https://"):
        raise ValueError("Data source must use HTTPS")
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    opener = build_opener(HTTPSOnlyRedirectHandler())
    with opener.open(request, timeout=20) as response:
        data = response.read(MAX_RESPONSE_BYTES + 1)
    if len(data) > MAX_RESPONSE_BYTES:
        raise ValueError("API response exceeds the allowed limit")
    payload = json.loads(data.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("API returned an invalid response")
    return payload


def load_config() -> dict:
    try:
        payload = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Could not read {CONFIG_PATH}: {error}") from error
    if not isinstance(payload, dict):
        raise ValueError("Config must be a JSON object")
    return payload


def team_snapshot(competitor: dict) -> dict[str, str]:
    team = competitor.get("team", {})
    logos = team.get("logos", []) if isinstance(team, dict) else []
    logo = str(team.get("logo") or "")
    if not logo and logos and isinstance(logos[0], dict):
        logo = str(logos[0].get("href") or "")
    return {
        "id": str(team.get("id") or competitor.get("id") or ""),
        "name": str(team.get("displayName") or team.get("name") or "Team"),
        "shortName": str(team.get("shortDisplayName") or team.get("displayName") or "Team"),
        "abbreviation": str(team.get("abbreviation") or "").upper(),
        "logo": logo,
        "homeAway": str(competitor.get("homeAway") or ""),
        "score": str(competitor.get("score") or "—"),
    }


def event_timestamp(event: dict) -> datetime | None:
    raw = str(event.get("date") or "")
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return None


def normalize_event(event: dict, league: str) -> dict | None:
    timestamp = event_timestamp(event)
    if timestamp is None:
        return None
    competition = event.get("competitions", [{}])[0]
    competitors = [team_snapshot(item) for item in competition.get("competitors", [])]
    if len(competitors) < 2:
        return None
    status = competition.get("status", {}).get("type", {})
    state = str(status.get("state") or "pre")
    completed = bool(status.get("completed", False)) or state == "post"
    home = next((c for c in competitors if c["homeAway"] == "home"), competitors[0])
    away = next((c for c in competitors if c["homeAway"] == "away"), competitors[1])
    return {
        "id": str(event.get("id") or ""),
        "date": timestamp.date().isoformat(),
        "time": timestamp.strftime("%H:%M"),
        "state": state,
        "completed": completed,
        "status": str(status.get("shortDetail") or status.get("detail") or "Scheduled"),
        "home": home,
        "away": away,
        "league": str(league or "Football"),
        "url": f"https://www.espn.com/soccer/match/_/gameId/{event.get('id', '')}",
    }


def collect_events(config: dict, now: datetime | None = None, fetcher=fetch_json) -> tuple[list[dict], str]:
    now = now or datetime.now().astimezone()
    league = str(config.get("league") or DEFAULT_LEAGUE).strip().lower() or DEFAULT_LEAGUE
    today = now.date()
    end = today + timedelta(days=7)
    url = API_ROOT + "/" + league + "/scoreboard?" + urlencode({"limit": "100", "dates": f"{today:%Y%m%d}-{end:%Y%m%d}"})
    payload = fetcher(url)
    league_label = league
    leagues = payload.get("leagues", [])
    if leagues and isinstance(leagues[0], dict):
        league_label = str(leagues[0].get("abbreviation") or leagues[0].get("name") or league)
    events = []
    for raw_event in payload.get("events", []):
        item = normalize_event(raw_event, league_label)
        if item:
            events.append(item)
    events.sort(key=lambda item: item["time"])
    return events, league


def main(argv: list[str] | None = None) -> int:
    try:
        config = load_config()
        league = str(config.get("league") or DEFAULT_LEAGUE).strip().lower() or DEFAULT_LEAGUE
    except Exception as error:
        json_out(error=str(error), league="", events=[])
        return 0
    try:
        events, _ = collect_events(config)
        json_out(updated=datetime.now().astimezone().isoformat(), league=league, events=events, error="")
    except Exception as error:
        json_out(error=str(error), league=league, events=[])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())