// Pure helpers for Canto Now Playing: picking Canto's MPRIS player, the pill
// text, and reading Canto's Visual Bridge file. No QML types in here, so the
// dev tests run this very file under node (see dev/tests/Model.test.js).

// The bus names Canto registers. It owns both on one connection, so the shell
// can list Canto twice; the short one wins.
var BUS_NAMES = ["org.mpris.mediaplayer2.canto", "org.mpris.mediaplayer2.io.github.gusthanks.canto"]
var DESKTOP_ENTRIES = ["canto", "io.github.gusthanks.canto"]

// Rank of a player as Canto: 0 for the short bus name, 1 for the app id bus
// name, 2 for a match on identity or desktop entry only, -1 for any other app.
function cantoRank(player) {
  if (!player) return -1
  var bus = String(player.dbusName || "").toLowerCase()
  var index = BUS_NAMES.indexOf(bus)
  if (index !== -1) return index
  var entry = String(player.desktopEntry || "").toLowerCase()
  if (DESKTOP_ENTRIES.indexOf(entry) !== -1) return 2
  if (String(player.identity || "") === "Canto") return 2
  return -1
}

// Canto's player among all MPRIS players, or null when Canto is not running.
// Other players (browsers, Spotify) are never picked.
function pickCantoPlayer(players) {
  var best = null
  var bestRank = 99
  var list = players || []
  for (var i = 0; i < list.length; i++) {
    var rank = cantoRank(list[i])
    if (rank === -1) continue
    if (rank < bestRank) { best = list[i]; bestRank = rank }
  }
  return best
}

// Artists as one line: MPRIS gives a string (or a list), the bridge a list.
function artistLine(artists) {
  if (artists === undefined || artists === null) return ""
  if (typeof artists === "string") return artists.trim()
  var names = []
  for (var i = 0; i < artists.length; i++) {
    var name = String(artists[i] || "").trim()
    if (name) names.push(name)
  }
  return names.join(", ")
}

// "Title · Artist", or whichever of the two is there.
function trackLabel(title, artist) {
  var t = String(title || "").trim()
  var a = String(artist || "").trim()
  if (t && a) return t + " · " + a
  return t || a
}

// The two things the pill's text can show. Clicking the text switches.
function normalizedMode(value, fallback) {
  var v = String(value === undefined || value === null ? "" : value).toLowerCase()
  if (v === "title" || v === "lyric") return v
  return fallback === "lyric" ? "lyric" : "title"
}

function otherMode(mode) {
  return normalizedMode(mode) === "lyric" ? "title" : "lyric"
}

// Lyric mode shows the line when there is one; otherwise (bridge off, an
// instrumental break, unsynced lyrics) it falls back to the track, and the
// pill dims its lyric glyph so the mode stays clear.
function showsLyric(mode, lyric) {
  return normalizedMode(mode) === "lyric" && String(lyric || "").trim() !== ""
}

// Splits a lyric line into pages that each fit maxWidth, breaking only
// between words. `measure(text)` returns the drawn width (TextMetrics in QML,
// a stub in the tests). A word wider than a page is cut by characters, so
// nothing is ever elided. A line that fits is one page.
function paginate(text, maxWidth, measure) {
  var line = String(text || "").replace(/\s+/g, " ").trim()
  if (!line) return []
  if (!(maxWidth > 0) || measure(line) <= maxWidth) return [line]
  var words = line.split(" ")
  var pages = []
  var current = ""
  for (var i = 0; i < words.length; i++) {
    var word = words[i]
    var candidate = current ? current + " " + word : word
    if (measure(candidate) <= maxWidth) { current = candidate; continue }
    if (current) pages.push(current)
    current = ""
    // A word too wide for a page on its own: cut it into page-wide pieces.
    while (measure(word) > maxWidth && word.length > 1) {
      var n = word.length - 1
      while (n > 1 && measure(word.slice(0, n)) > maxWidth) n--
      pages.push(word.slice(0, n))
      word = word.slice(n)
    }
    current = word
  }
  if (current) pages.push(current)
  return pages
}

// How long each page of a line stays, in ms. With `endsInMs` (newer Canto:
// time until the next line, read when the line started) the pages share 90%
// of it, at least 1.2 s each. Older Canto sends no timing, so `lineMs` (how
// long the previous line lasted) stands in, between 1.2 s and 3 s a page;
// with neither, 1.6 s a page.
var PAGE_DEFAULT_MS = 1600
var PAGE_MIN_MS = 1200
var PAGE_MAX_ESTIMATED_MS = 3000

function pageInterval(pageCount, lineMs, endsInMs) {
  if (!(pageCount > 1)) return 0
  if (endsInMs > 0) return Math.round(Math.max(PAGE_MIN_MS, endsInMs * 0.9 / pageCount))
  if (!(lineMs > 0)) return PAGE_DEFAULT_MS
  return Math.round(Math.max(PAGE_MIN_MS, Math.min(PAGE_MAX_ESTIMATED_MS, lineMs * 0.9 / pageCount)))
}

// The maxWidth setting, in unscaled pixels, kept in a sane range.
function labelWidth(value, fallback) {
  var n = parseInt(value, 10)
  if (isNaN(n)) n = fallback === undefined ? 240 : fallback
  return Math.max(120, Math.min(600, n))
}

// One Visual Bridge frame ($XDG_RUNTIME_DIR/canto/state.json) reduced to what
// the widget uses. Returns null when the text is not a Canto frame (a missing
// or broken file), so the caller can keep its last good frame.
function parseBridge(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!data || typeof data !== "object" || data.app !== "canto") return null
  var track = data.track && typeof data.track === "object" ? data.track : null
  return {
    active: data.active === true,
    playing: data.playing === true,
    title: track ? String(track.title || "") : "",
    artists: track ? artistLine(track.artists) : "",
    lyric: typeof data.lyric === "string" ? data.lyric.trim() : "",
    // Newer Canto builds also send the lines around the current one and when
    // the next starts. Older ones leave the keys out (hasNeighbors false), so
    // the widget falls back to its own memory and estimate.
    hasNeighbors: "lyric_previous" in data || "lyric_next" in data,
    previous: typeof data.lyric_previous === "string" ? data.lyric_previous.trim() : "",
    next: typeof data.lyric_next === "string" ? data.lyric_next.trim() : "",
    endsInMs: Math.max(0, Number(data.lyric_ends_in_ms) || 0),
    updatedAt: Number(data.updated_at_ms) || 0
  }
}

function normalizedTitle(s) {
  return String(s || "").toLowerCase().replace(/\s+/g, " ").trim()
}

// How long a playing frame stays believable. Canto writes ~15 times a second
// while playing, so a gap this long means it stopped writing (a crash, or the
// bridge turned off without the final frame).
var STALE_MS = 5000

// Whether a frame describes the MPRIS track right now: active, about the
// same track (a leftover file from an earlier session never leaks a wrong
// line), and, with `now` set, still updating while MPRIS says it is playing.
function bridgeFrameValid(frame, mprisTitle, mprisPlaying, now) {
  if (!frame || !frame.active) return false
  if (now && mprisPlaying && frame.updatedAt && now - frame.updatedAt > STALE_MS) return false
  if (mprisTitle && frame.title && normalizedTitle(mprisTitle) !== normalizedTitle(frame.title)) return false
  return true
}

// The lyric line to show for the MPRIS track, or "".
function bridgeLyric(frame, mprisTitle, mprisPlaying, now) {
  if (!frame || !frame.lyric) return ""
  return bridgeFrameValid(frame, mprisTitle, mprisPlaying, now) ? frame.lyric : ""
}

// A tiny memory of the lyric, fed each time the line changes: the line before
// the current one (the popup shows it above) and how long the last line
// lasted (the page timing estimate). It starts over on a new track. A
// duration outside 0.3 to 15 s (a seek, a pause) is not trusted.
function lyricHistory(state, lyric, trackKey, now) {
  var s = state || {}
  var line = String(lyric || "").trim()
  if (s.track !== trackKey)
    return { track: trackKey, line: line, previous: "", changedAt: line ? now : 0, lineMs: 0 }
  if (line === s.line) return s
  if (!line) return { track: s.track, line: "", previous: s.line || s.previous || "", changedAt: s.changedAt || 0, lineMs: s.lineMs || 0 }
  var lineMs = s.lineMs || 0
  if (s.line && s.changedAt) {
    var lasted = now - s.changedAt
    if (lasted >= 300 && lasted <= 15000) lineMs = lasted
  }
  return { track: s.track, line: line, previous: s.line || s.previous || "", changedAt: now, lineMs: lineMs }
}

// Mouse wheel to next/previous. Touchpads send many small deltas, so they add
// up to one notch (120) before anything happens, and a short cooldown after
// each skip keeps one swipe from skipping a whole album.
var WHEEL_NOTCH = 120
var WHEEL_COOLDOWN_MS = 400

function wheelStep(state, deltaY, now) {
  var acc = (state && state.acc) || 0
  var last = (state && state.last) || 0
  if (last && now - last < WHEEL_COOLDOWN_MS) return { acc: 0, last: last, action: "" }
  acc += deltaY
  if (acc >= WHEEL_NOTCH) return { acc: 0, last: now, action: "previous" }
  if (acc <= -WHEEL_NOTCH) return { acc: 0, last: now, action: "next" }
  return { acc: acc, last: last, action: "" }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    cantoRank: cantoRank,
    pickCantoPlayer: pickCantoPlayer,
    artistLine: artistLine,
    trackLabel: trackLabel,
    normalizedMode: normalizedMode,
    otherMode: otherMode,
    showsLyric: showsLyric,
    paginate: paginate,
    pageInterval: pageInterval,
    labelWidth: labelWidth,
    parseBridge: parseBridge,
    normalizedTitle: normalizedTitle,
    bridgeFrameValid: bridgeFrameValid,
    bridgeLyric: bridgeLyric,
    lyricHistory: lyricHistory,
    wheelStep: wheelStep,
    STALE_MS: STALE_MS
  }
}
