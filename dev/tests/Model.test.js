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
  cantoRank, pickCantoPlayer, artistLine, trackLabel, pillText, labelWidth,
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
  it('shows the lyric only when it is on and there is one', () => {
    assert.equal(pillText(true, 'a line', 'T', 'A'), 'a line')
    assert.equal(pillText(false, 'a line', 'T', 'A'), 'T · A')
    assert.equal(pillText(true, '   ', 'T', 'A'), 'T · A')
    assert.equal(pillText(true, null, 'T', 'A'), 'T · A')
  })
  it('clamps the width setting', () => {
    assert.equal(labelWidth(undefined), 240)
    assert.equal(labelWidth('300'), 300)
    assert.equal(labelWidth(20), 120)
    assert.equal(labelWidth(5000), 600)
    assert.equal(labelWidth('abc', 200), 200)
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
  it('rejects broken, empty or foreign files so the last frame is kept', () => {
    assert.equal(parseBridge(''), null)
    assert.equal(parseBridge('{"app":"canto","act'), null)
    assert.equal(parseBridge('{"app":"other"}'), null)
    assert.equal(parseBridge('null'), null)
  })
  it('handles a stopped or inactive frame', () => {
    const f = parseBridge('{"app":"canto","version":1,"active":false,"playing":false,"track":null,"lyric":null}')
    assert.deepEqual(f, { active: false, playing: false, title: '', artists: '', lyric: '', updatedAt: 0 })
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
      assert.ok(!readFileSync(join(root, 'i18n', file), 'utf8').includes('—'), file)
  })
})
