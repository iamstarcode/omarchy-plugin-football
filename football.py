#!/usr/bin/env python3
"""Fetch and normalize one day of football fixtures (all competitions) for iamstarcode.football."""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import date as date_cls
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "omarchy" / "iamstarcode.football.json"
API_ROOT = "https://site.web.api.espn.com/apis/v2/scoreboard/header"
USER_AGENT = "iamstarcode-football/0.4 (+https://github.com/iamstarcode/omarchy-plugin-football)"
MAX_RESPONSE_BYTES = 12_000_000
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


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


def parse_date(raw: str | None) -> date_cls:
    text = str(raw or "").strip()
    if text and not DATE_RE.match(text):
        raise ValueError("Date must look like YYYY-MM-DD")
    if not text:
        return datetime.now().astimezone().date()
    try:
        return date_cls.fromisoformat(text)
    except ValueError as error:
        raise ValueError(f"Invalid date {text!r}") from error


def team_snapshot(competitor: dict) -> dict[str, str]:
    team = competitor.get("team", {}) or {}
    return {
        "id": str(competitor.get("id") or team.get("id") or ""),
        "name": str(competitor.get("displayName") or team.get("displayName") or competitor.get("name") or "Team"),
        "shortName": str(competitor.get("shortDisplayName") or competitor.get("displayName") or "Team"),
        "abbreviation": str(competitor.get("abbreviation") or "").upper(),
        "homeAway": str(competitor.get("homeAway") or ""),
        "score": str(competitor.get("score") if competitor.get("score") not in (None, "") else "—"),
    }


def event_timestamp(event: dict) -> datetime | None:
    raw = str(event.get("date") or "")
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return None


def normalize_event(event: dict) -> dict | None:
    timestamp = event_timestamp(event)
    if timestamp is None:
        return None
    competitors = [team_snapshot(item) for item in event.get("competitors", [])]
    if len(competitors) < 2:
        return None
    status = (event.get("fullStatus") or {}).get("type", {}) or {}
    state = str(status.get("state") or event.get("status") or "pre")
    completed = bool(status.get("completed", False)) or state == "post"
    home = next((c for c in competitors if c["homeAway"] == "home"), competitors[0])
    away = next((c for c in competitors if c["homeAway"] == "away"), competitors[1])
    detail = str(status.get("shortDetail") or status.get("detail") or event.get("summary") or "Scheduled")
    return {
        "id": str(event.get("id") or ""),
        "date": timestamp.date().isoformat(),
        "time": timestamp.strftime("%H:%M"),
        "state": state,
        "completed": completed,
        "status": detail,
        "home": home,
        "away": away,
        "url": str(event.get("link") or ""),
    }


def normalize_group(league: dict) -> dict | None:
    events = []
    for raw_event in league.get("events", []) or []:
        item = normalize_event(raw_event)
        if item:
            events.append(item)
    if not events:
        return None
    events.sort(key=lambda item: (item["time"], item["id"]))
    return {
        "league": str(league.get("name") or league.get("slug") or "Competition"),
        "abbreviation": str(league.get("abbreviation") or ""),
        "slug": str(league.get("slug") or ""),
        "events": events,
    }


def collect_groups(day: date_cls, fetcher=fetch_json) -> list[dict]:
    url = API_ROOT + "?" + urlencode({"sport": "soccer", "dates": f"{day:%Y%m%d}"})
    payload = fetcher(url)
    groups = []
    for sport in payload.get("sports", []) or []:
        for league in sport.get("leagues", []) or []:
            group = normalize_group(league)
            if group:
                groups.append(group)
    return groups


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        day = parse_date(args[0] if args else None)
    except Exception as error:
        json_out(error=str(error), date="", groups=[])
        return 0
    try:
        groups = collect_groups(day)
        json_out(updated=datetime.now().astimezone().isoformat(), date=day.isoformat(), groups=groups, error="")
    except Exception as error:
        json_out(error=str(error), date=day.isoformat(), groups=[])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
