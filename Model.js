// Pure helpers for iamstarcode.football. Parses the normalized ESPN payload
// produced by football.py (one day, grouped by competition) into display rows.

// ESPN states: pre (scheduled), in (live), post (finished).
function parseGroups(payload) {
  if (!payload || !Array.isArray(payload.groups)) return []
  var out = []
  for (var i = 0; i < payload.groups.length; i++) {
    var g = payload.groups[i]
    if (!g || !Array.isArray(g.events)) continue
    var rows = []
    for (var j = 0; j < g.events.length; j++) {
      var e = g.events[j]
      if (!e || !e.home || !e.away) continue
      rows.push({
        id: String(e.id || ""),
        date: String(e.date || ""),
        time: String(e.time || ""),
        status: normalizeStatus(e),
        statusDetail: String(e.status || ""),
        home: String(e.home.shortName || e.home.name || ""),
        away: String(e.away.shortName || e.away.name || ""),
        homeScore: scoreOrDash(e.home),
        awayScore: scoreOrDash(e.away),
        url: String(e.url || "")
      })
    }
    if (rows.length > 0)
      out.push({
        league: String(g.league || "Competition"),
        abbreviation: String(g.abbreviation || ""),
        slug: String(g.slug || ""),
        rows: sortRows(rows)
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
    return String(a.time).localeCompare(String(b.time))
  })
}

function pad2(value) { return value < 10 ? "0" + value : String(value) }

function isoDate(d) {
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function todayIso() { return isoDate(new Date()) }

function addDays(iso, days) {
  var m = String(iso || "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!m) return todayIso()
  var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  d.setDate(d.getDate() + days)
  return isoDate(d)
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
  if (diff === -1) return "YESTERDAY"
  return WEEKDAYS[d.getDay()] + " " + d.getDate()
}

// Short chip label for the day strip: "TODAY" / "MON 24"
function chipLabel(dateStr, now) {
  var m = String(dateStr || "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!m) return ""
  var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var diff = Math.round((d - today) / 86400000)
  if (diff === 0) return "TODAY"
  return WEEKDAYS[d.getDay()] + " " + d.getDate()
}

// Safe defaults so QML bindings never see undefined on mixed-type rows.
var EMPTY_ROW = { id: "", date: "", time: "", status: "NS", statusDetail: "",
  home: "", away: "", homeScore: "-", awayScore: "-", url: "" }

// Flat display list: league headers interleaved with match rows.
// `alt` marks odd match rows inside a group for zebra shading.
function buildDisplayRows(groups) {
  var out = []
  for (var i = 0; i < groups.length; i++) {
    var g = groups[i]
    out.push({ type: "league", label: g.league, live: groupHasLive(g.rows), row: EMPTY_ROW, alt: false })
    for (var j = 0; j < g.rows.length; j++)
      out.push({ type: "match", label: "", live: false, row: g.rows[j], alt: j % 2 === 1 })
  }
  return out
}

function groupHasLive(rows) {
  for (var i = 0; i < rows.length; i++)
    if (rows[i].status === "LIVE") return true
  return false
}

function liveRow(groups) {
  for (var i = 0; i < groups.length; i++)
    for (var j = 0; j < groups[i].rows.length; j++)
      if (groups[i].rows[j].status === "LIVE") return groups[i].rows[j]
  return null
}

function nextRow(groups) {
  for (var i = 0; i < groups.length; i++)
    for (var j = 0; j < groups[i].rows.length; j++)
      if (groups[i].rows[j].status === "NS") return groups[i].rows[j]
  return null
}

// Bar tooltip: live score beats next fixture beats plain label.
function tooltipLabel(groups) {
  var live = liveRow(groups)
  if (live) return "LIVE · " + live.home + " " + live.homeScore + "-" + live.awayScore + " " + live.away
  var next = nextRow(groups)
  if (next) return "Next: " + next.home + " vs " + next.away + " · " + next.time
  return "Football Scores"
}
