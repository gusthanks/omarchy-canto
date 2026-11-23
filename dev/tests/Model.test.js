import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

// Run with `node --test dev/tests/` (or dev/run.sh test): no dependencies.
// Tests run against the real Model.js (a QML JavaScript resource that also
// exports through `module.exports` when one exists), the real i18n/ catalogs
// and the harness's mock Visual Bridge file.
const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const mod = { exports: {} }
new Function('module', readFileSync(join(root, 'Model.js'), 'utf8'))(mod)
const {
  cantoRank, pickCantoPlayer, artistLine, trackLabel, labelWidth,
  normalizedMode, otherMode, showsLyric, paginate, pageInterval, lyricHistory,
  neighborLines, progressFraction,
  parseBridge, bridgeLyric, wheelStep, STALE_MS
} = mod.exports

const catalog = code => JSON.parse(readFileSync(join(root, 'i18n', code + '.json'), 'utf8'))

describe('pickCantoPlayer', () => {
  const spotify = { dbusName: 'org.mpris.MediaPlayer2.spotify', identity: 'Spotify', desktopEntry: 'spotify' }
  const firefox = { dbusName: 'org.mpris.MediaPlayer2.firefox.instance_1_42', identity: 'Mozilla Firefox' }
  const cantoShort = { dbusName: 'org.mpris.MediaPlayer2.canto', identity: 'Canto', desktopEntry: 'canto' }
  const cantoAppId = { dbusName: 'org.mpris.MediaPlayer2.io.github.gusthanks.Canto', identity: 'Canto', desktopEntry: 'canto' }

  it('never picks another player', () => {
    assert.equal(pickCantoPlayer([spotify, firefox]), null)
    assert.equal(pickCantoPlayer([]), null)
    assert.equal(pickCantoPlayer(null), null)
    assert.equal(cantoRank(spotify), -1)
  })
  it('prefers the short bus name when Canto shows up twice', () => {
    assert.equal(pickCantoPlayer([spotify, cantoAppId, cantoShort]), cantoShort)
    assert.equal(pickCantoPlayer([cantoAppId, firefox]), cantoAppId)
  })
  it('falls back to identity or desktop entry', () => {
    const flatpak = { dbusName: 'org.mpris.MediaPlayer2.canto.instance2', identity: 'Canto' }
    assert.equal(pickCantoPlayer([firefox, flatpak]), flatpak)
    assert.equal(cantoRank({ dbusName: 'x', desktopEntry: 'io.github.gusthanks.Canto' }), 2)
  })
})

describe('labels', () => {
  it('joins artists from a list or keeps a string', () => {
    assert.equal(artistLine(['Lumen Coast', ' Ana Vale ', '']), 'Lumen Coast, Ana Vale')
    assert.equal(artistLine('Lumen Coast'), 'Lumen Coast')
    assert.equal(artistLine(null), '')
  })
  it('builds Title · Artist with either part missing', () => {
    assert.equal(trackLabel('Paper Lanterns', 'Lumen Coast'), 'Paper Lanterns · Lumen Coast')
    assert.equal(trackLabel('Paper Lanterns', ''), 'Paper Lanterns')
    assert.equal(trackLabel('', 'Lumen Coast'), 'Lumen Coast')
    assert.equal(trackLabel('', ''), '')
  })
  it('clamps the width setting', () => {
    assert.equal(labelWidth(undefined), 240)
    assert.equal(labelWidth('300'), 300)
    assert.equal(labelWidth(20), 120)
    assert.equal(labelWidth(5000), 600)
    assert.equal(labelWidth('abc', 200), 200)
  })
})

describe('modes', () => {
  it('normalizes the mode setting and toggles', () => {
    assert.equal(normalizedMode('lyric'), 'lyric')
    assert.equal(normalizedMode('LYRIC'), 'lyric')
    assert.equal(normalizedMode('nonsense'), 'title')
    assert.equal(normalizedMode(undefined, 'lyric'), 'lyric')
    assert.equal(otherMode('title'), 'lyric')
    assert.equal(otherMode('lyric'), 'title')
  })
  it('lyric mode shows the line only when there is one', () => {
    assert.equal(showsLyric('lyric', 'a line'), true)
    assert.equal(showsLyric('lyric', '  '), false)
    assert.equal(showsLyric('lyric', null), false)
    assert.equal(showsLyric('title', 'a line'), false)
  })
})

describe('paginate', () => {
  const measure = t => t.length * 10 // a monospace stub: 10 px per character

  it('a line that fits is one page', () => {
    assert.deepEqual(paginate('the tide came in anyway', 330, measure), ['the tide came in anyway'])
  })
  it('splits a long line at word boundaries, every page fits', () => {
    const line = 'we kept the porch light burning and the tide came in anyway'
    const pages = paginate(line, 330, measure)
    assert.deepEqual(pages, ['we kept the porch light burning', 'and the tide came in anyway'])
    for (const p of pages) assert.ok(measure(p) <= 330, p)
    assert.equal(pages.join(' '), line)
  })
  it('keeps every word and can make more than two pages', () => {
    const line = 'one two three four five six seven eight nine ten eleven twelve'
    const pages = paginate(line, 120, measure)
    assert.ok(pages.length > 2)
    for (const p of pages) assert.ok(measure(p) <= 120, p)
    assert.equal(pages.join(' '), line)
  })
  it('cuts a word wider than a page by characters, never elides', () => {
    const pages = paginate('supercalifragilistic ok', 100, measure)
    for (const p of pages) assert.ok(measure(p) <= 100, p)
    assert.equal(pages.join('').replace(/ /g, ''), 'supercalifragilisticok')
  })
  it('collapses spaces and gives nothing for an empty line', () => {
    assert.deepEqual(paginate('  a   b  ', 330, measure), ['a b'])
    assert.deepEqual(paginate('', 330, measure), [])
    assert.deepEqual(paginate(null, 330, measure), [])
  })
})

describe('pageInterval', () => {
  it('one page needs no timer', () => {
    assert.equal(pageInterval(1, 4000), 0)
    assert.equal(pageInterval(0, 0), 0)
  })
  it("with Canto's timing, the pages share 90% of the time left", () => {
    assert.equal(pageInterval(2, 0, 4200), 1890)
    assert.equal(pageInterval(2, 2000, 8000), 3600)
    assert.equal(pageInterval(3, 0, 2000), 1200)
  })
  it('defaults to 1.6 s per page without an estimate', () => {
    assert.equal(pageInterval(2, 0), 1600)
  })
  it('shares the estimated line time, between 1.2 s and 3 s a page', () => {
    assert.equal(pageInterval(2, 4000), 1800)
    assert.equal(pageInterval(3, 2000), 1200)
    assert.equal(pageInterval(2, 20000), 3000)
  })
})

describe('lyricHistory', () => {
  it('remembers the previous line and how long it lasted', () => {
    let h = lyricHistory(null, 'line one', 'T', 1000)
    assert.equal(h.previous, '')
    h = lyricHistory(h, 'line two', 'T', 3500)
    assert.equal(h.previous, 'line one')
    assert.equal(h.lineMs, 2500)
  })
  it('the same line is no change', () => {
    const h = lyricHistory(null, 'line one', 'T', 1000)
    assert.equal(lyricHistory(h, 'line one', 'T', 2000), h)
  })
  it('across a break keeps the last sung line as previous', () => {
    let h = lyricHistory(null, 'line one', 'T', 1000)
    h = lyricHistory(h, '', 'T', 3000)
    h = lyricHistory(h, 'line two', 'T', 9000)
    assert.equal(h.previous, 'line one')
  })
  it('never remembers the current line as the previous one', () => {
    // The popup opens: the bridge is read again and the same line comes back.
    let h = lyricHistory(null, 'line one', 'T', 1000)
    h = lyricHistory(h, '', 'T', 2000)
    h = lyricHistory(h, 'line one', 'T', 2100)
    assert.equal(h.line, 'line one')
    assert.notEqual(h.previous, h.line)
    assert.equal(h.previous, '')
    h = lyricHistory(h, 'line two', 'T', 4000)
    assert.equal(h.previous, 'line one')
  })
  it('ignores durations from seeks or pauses, starts over on a new track', () => {
    let h = lyricHistory(null, 'a', 'T', 1000)
    h = lyricHistory(h, 'b', 'T', 3000)
    h = lyricHistory(h, 'c', 'T', 60000)
    assert.equal(h.lineMs, 2000)
    h = lyricHistory(h, 'x', 'U', 61000)
    assert.equal(h.previous, '')
    assert.equal(h.lineMs, 0)
  })
})

describe('neighborLines', () => {
  it('keeps distinct lines', () => {
    assert.deepEqual(neighborLines('b', 'a', 'c'), { previous: 'a', next: 'c' })
  })
  it('drops a neighbor that repeats the current line', () => {
    assert.deepEqual(neighborLines('Same line', ' same  line ', 'next'), { previous: '', next: 'next' })
    assert.deepEqual(neighborLines('x', 'a', 'X'), { previous: 'a', next: '' })
  })
  it('during a break (no current line) shows both', () => {
    assert.deepEqual(neighborLines('', 'a', 'b'), { previous: 'a', next: 'b' })
  })
})

describe('progressFraction', () => {
  it('maps position to 0..1 and survives a missing length', () => {
    assert.equal(progressFraction(50, 200), 0.25)
    assert.equal(progressFraction(500, 200), 1)
    assert.equal(progressFraction(-5, 200), 0)
    assert.equal(progressFraction(50, 0), 0)
  })
})

describe('Visual Bridge', () => {
  const mockText = readFileSync(join(root, 'dev', 'mock', 'state.json'), 'utf8')

  it('reads the mock frame', () => {
    const f = parseBridge(mockText)
    assert.equal(f.active, true)
    assert.equal(f.title, 'Paper Lanterns')
    assert.ok(f.lyric.length > 0)
    assert.ok(f.updatedAt > 0)
  })
  it('reads the lines around the current one when Canto sends them', () => {
    const f = parseBridge(mockText)
    assert.equal(f.hasNeighbors, true)
    assert.ok(f.previous.length > 0)
    assert.ok(f.next.length > 0)
    assert.ok(f.endsInMs > 0)
    const nulls = parseBridge('{"app":"canto","active":true,"lyric":"x","lyric_previous":null,"lyric_next":null,"lyric_ends_in_ms":null}')
    assert.deepEqual([nulls.hasNeighbors, nulls.previous, nulls.next, nulls.endsInMs], [true, '', '', 0])
  })
  it('an older Canto without those keys says so', () => {
    const f = parseBridge('{"app":"canto","active":true,"lyric":"x"}')
    assert.deepEqual([f.hasNeighbors, f.previous, f.next, f.endsInMs], [false, '', '', 0])
    assert.equal(f.liked, null)
  })
  it('reads liked as true, false or unknown, and the track progress', () => {
    assert.equal(parseBridge(mockText).liked, true)
    assert.equal(parseBridge('{"app":"canto","liked":false}').liked, false)
    assert.equal(parseBridge('{"app":"canto","liked":null}').liked, null)
    assert.equal(parseBridge('{"app":"canto","liked":"yes"}').liked, null)
    const f = parseBridge(mockText)
    assert.ok(f.progressMs > 0 && f.durationMs > f.progressMs)
  })
  it('rejects broken, empty or foreign files so the last frame is kept', () => {
    assert.equal(parseBridge(''), null)
    assert.equal(parseBridge('{"app":"canto","act'), null)
    assert.equal(parseBridge('{"app":"other"}'), null)
    assert.equal(parseBridge('null'), null)
  })
  it('handles a stopped or inactive frame', () => {
    const f = parseBridge('{"app":"canto","version":1,"active":false,"playing":false,"track":null,"lyric":null}')
    assert.equal(f.active, false)
    assert.equal(f.title, '')
    assert.equal(f.lyric, '')
    assert.equal(f.hasNeighbors, false)
    assert.equal(f.endsInMs, 0)
    assert.equal(bridgeLyric(f, 'T', true, 0), '')
  })

  const frame = { active: true, playing: true, title: 'Paper Lanterns', lyric: 'a line', updatedAt: 1000 }
  it('gives the line for the same track', () => {
    assert.equal(bridgeLyric(frame, 'paper  lanterns ', true, 0), 'a line')
    assert.equal(bridgeLyric(frame, '', true, 0), 'a line')
  })
  it('drops a line from another track', () => {
    assert.equal(bridgeLyric(frame, 'Night Ferry', true, 0), '')
  })
  it('drops a frame that stopped updating while MPRIS plays', () => {
    assert.equal(bridgeLyric(frame, 'Paper Lanterns', true, 1000 + STALE_MS + 1), '')
    assert.equal(bridgeLyric(frame, 'Paper Lanterns', true, 1000 + STALE_MS - 1), 'a line')
    // Paused: Canto only writes on changes, so an old frame is still right.
    assert.equal(bridgeLyric(frame, 'Paper Lanterns', false, 1000 + STALE_MS * 10), 'a line')
  })
  it('gives nothing without a frame or a line', () => {
    assert.equal(bridgeLyric(null, 'T', true, 0), '')
    assert.equal(bridgeLyric({ ...frame, lyric: '' }, 'Paper Lanterns', true, 0), '')
    assert.equal(bridgeLyric({ ...frame, active: false }, 'Paper Lanterns', true, 0), '')
  })
})

describe('wheelStep', () => {
  it('a mouse notch skips once, up is previous, down is next', () => {
    assert.equal(wheelStep({}, 120, 1000).action, 'previous')
    assert.equal(wheelStep({}, -120, 1000).action, 'next')
  })
  it('touchpad deltas add up to one notch', () => {
    let s = { acc: 0, last: 0 }
    const actions = []
    for (let i = 0; i < 5; i++) { s = wheelStep(s, -30, 1000 + i); actions.push(s.action) }
    assert.deepEqual(actions, ['', '', '', 'next', ''])
  })
  it('ignores the wheel for a moment after a skip', () => {
    let s = wheelStep({}, -120, 1000)
    s = wheelStep(s, -120, 1100)
    assert.equal(s.action, '')
    s = wheelStep(s, -120, 1500)
    assert.equal(s.action, 'next')
  })
})

describe('i18n catalogs', () => {
  it('pt-BR carries every English key and nothing else', () => {
    assert.deepEqual(Object.keys(catalog('pt-BR')).sort(), Object.keys(catalog('en')).sort())
  })
  it('every key is used by the plugin and every value is a non-empty string', () => {
    const source = readdirSync(root).filter(f => f.endsWith('.qml'))
      .map(f => readFileSync(join(root, f), 'utf8')).join('\n')
    for (const file of readdirSync(join(root, 'i18n'))) {
      const strings = catalog(file.replace(/\.json$/, ''))
      for (const [k, v] of Object.entries(strings)) {
        assert.ok(source.includes('"' + k + '"'), `${file}: ${k} is not used`)
        assert.ok(typeof v === 'string' && v.length > 0, `${file}: ${k} is empty`)
      }
    }
  })
  it('no em dash in user-facing strings', () => {
    for (const file of readdirSync(join(root, 'i18n')))
      assert.ok(!readFileSync(join(root, 'i18n', file), 'utf8').includes('\u2014'), file)
  })
})
