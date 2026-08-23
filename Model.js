// Pure helpers for iamstarcode.football. Parses the normalized ESPN payload
// produced by football.py into display rows.

// ESPN states: pre (scheduled), in (live), post (finished).
function parseEvents(payload) {
  if (!payload || !Array.isArray(payload.events)) return []
  var out = []
  for (var i = 0; i < payload.events.length; i++) {
    var e = payload.events[i]
    if (!e || !e.home || !e.away) continue
    out.push({
      id: String(e.id || ""),
      date: String(e.date || ""),
      time: String(e.time || ""),
      status: normalizeStatus(e),
      statusDetail: String(e.status || ""),
      home: String(e.home.shortName || e.home.name || ""),
      away: String(e.away.shortName || e.away.name || ""),
      homeScore: scoreOrDash(e.home),
      awayScore: scoreOrDash(e.away),
      league: String(e.league || ""),
      url: String(e.url || "")
    })
  }
  return out
}

function scoreOrDash(team) {
  var s = String(team && team.score || "")
  return s !== "" && s !== "—" ? s : "-"
}

function normalizeStatus(e) {
  if (e.completed || e.state === "post") return "FT"
  if (e.state === "in") return "LIVE"
  return "NS"
}

function sortRows(rows) {
  var order = { "LIVE": 0, "NS": 1, "FT": 2 }
  return rows.slice().sort(function(a, b) {
    var da = order[a.status] !== undefined ? order[a.status] : 3
    var db = order[b.status] !== undefined ? order[b.status] : 3
    if (da !== db) return da - db
    return String(a.date).localeCompare(String(b.date))
      || String(a.time).localeCompare(String(b.time))
  })
}

function pad2(value) { return value < 10 ? "0" + value : String(value) }

function todayKey(now) {
  return now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate())
}

var WEEKDAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

// "2026-08-22" -> "TODAY" / "TOMORROW" / "SAT 22"
function dayLabel(dateStr, now) {
  var m = String(dateStr || "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!m) return ""
  var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var diff = Math.round((d - today) / 86400000)
  if (diff === 0) return "TODAY"
  if (diff === 1) return "TOMORROW"
  return WEEKDAYS[d.getDay()] + " " + d.getDate()
}

// Mixed display list: day separators interleaved with match rows.
function buildDisplayRows(rows, now) {
  var out = []
  var lastDay = ""
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (row.date !== lastDay) {
      lastDay = row.date
      out.push({ type: "day", label: dayLabel(row.date, now) })
    }
    out.push({ type: "match", row: row })
  }
  return out
}

function liveRow(rows) {
  for (var i = 0; i < rows.length; i++)
    if (rows[i].status === "LIVE") return rows[i]
  return null
}

function nextRow(rows) {
  for (var i = 0; i < rows.length; i++)
    if (rows[i].status === "NS") return rows[i]
  return null
}

// Bar tooltip: live score beats next fixture beats plain label.
function tooltipLabel(rows) {
  var live = liveRow(rows)
  if (live) return "LIVE · " + live.home + " " + live.homeScore + "-" + live.awayScore + " " + live.away
  var next = nextRow(rows)
  if (next) return "Next: " + next.home + " vs " + next.away + " · " + dayLabel(next.date, new Date()) + " " + next.time
  return "Football Scores"
}

// leagueCode -> human label for the picker.
var LEAGUES = [
  { code: "eng.1", label: "Premier League" },
  { code: "esp.1", label: "La Liga" },
  { code: "ita.1", label: "Serie A" },
  { code: "ger.1", label: "Bundesliga" },
  { code: "fra.1", label: "Ligue 1" },
  { code: "por.1", label: "Primeira Liga" },
  { code: "ned.1", label: "Eredivisie" },
  { code: "usa.1", label: "MLS" },
  { code: "uefa.champions", label: "Champions League" },
  { code: "uefa.europa", label: "Europa League" },
  { code: "world.cup", label: "World Cup" }
]

function leagueLabel(code) {
  for (var i = 0; i < LEAGUES.length; i++)
    if (LEAGUES[i].code === code) return LEAGUES[i].label
  return code
}