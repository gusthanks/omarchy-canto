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

// What the pill says: the synced lyric line when that is on and there is one,
// otherwise the track.
function pillText(showLyric, lyric, title, artist) {
  var line = String(lyric || "").trim()
  if (showLyric && line) return line
  return trackLabel(title, artist)
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

// The lyric line to show for the MPRIS track, or "". The frame must be active,
// carry a line, and describe the same track MPRIS reports (a leftover file from
// an earlier session never leaks a wrong line). With `now` set, a frame that
// stopped updating while MPRIS says it is playing counts as stale.
function bridgeLyric(frame, mprisTitle, mprisPlaying, now) {
  if (!frame || !frame.active || !frame.lyric) return ""
  if (now && mprisPlaying && frame.updatedAt && now - frame.updatedAt > STALE_MS) return ""
  if (mprisTitle && frame.title && normalizedTitle(mprisTitle) !== normalizedTitle(frame.title)) return ""
  return frame.lyric
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
    pillText: pillText,
    labelWidth: labelWidth,
    parseBridge: parseBridge,
    normalizedTitle: normalizedTitle,
    bridgeLyric: bridgeLyric,
    wheelStep: wheelStep,
    STALE_MS: STALE_MS
  }
}
