.pragma library

function parseStatus(raw) {
    var fans = []
    var mode = "auto"
    var until = 0
    var profile = ""
    var platform = ""
    var temps = {}
    var watts = -1
    var lines = String(raw).split('\n')
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === '') continue
        var eq = line.indexOf('=')
        if (eq < 0) continue
        var key = line.slice(0, eq)
        var value = line.slice(eq + 1)
        if (key === 'MODE') {
            mode = value === 'max' ? 'max' : 'auto'
        } else if (key === 'UNTIL') {
            until = parseInt(value, 10) || 0
        } else if (key === 'PROFILE') {
            profile = value
        } else if (key === 'PLATFORM') {
            platform = value
        } else if (key === 'WATTS') {
            watts = parseInt(value, 10)
        } else if (key === 'TEMP') {
            var t = value.split('|')
            if (t.length >= 3) {
                temps[t[0]] = { source: t[1], celsius: Math.round((parseInt(t[2], 10) || 0) / 1000) }
            }
        } else if (key === 'FAN') {
            var parts = value.split('|')
            if (parts.length >= 5) {
                fans.push({
                    driver: parts[0],
                    index: parseInt(parts[1], 10) || 0,
                    rpm: parseInt(parts[2], 10) || 0,
                    pwm: parseInt(parts[3], 10) || 0,
                    enable: parseInt(parts[4], 10) || 0,
                    maxRpm: parseInt(parts[5], 10) || 0
                })
            }
        }
    }
    return { mode: mode, until: until, fans: fans, temps: temps, watts: watts, profile: profile, platform: platform }
}

function fanLabel(fan) {
    if (!fan) return ""
    return "Fan " + fan.index + " (" + fan.driver + ")"
}

function rpmText(fan) {
    if (!fan || !fan.rpm) return "—"
    return fan.rpm + " rpm"
}

function loadPercent(fan) {
    if (!fan || !fan.maxRpm || !fan.rpm) return 0
    return Math.round((fan.rpm / fan.maxRpm) * 100)
}

function fanDetail(fan) {
    if (!fan) return "—"
    var text = rpmText(fan)
    if (fan.maxRpm > 0 && fan.rpm > 0) text += " (" + loadPercent(fan) + "%)"
    return text
}

function pwmPercent(fan) {
    if (!fan || !fan.pwm) return 0
    return Math.round((fan.pwm / 255) * 100)
}

function wattsText(watts) {
    if (!(watts >= 0)) return "—"
    return watts + " W"
}

function tempText(temps, kind) {
    var entry = temps ? temps[kind] : null
    if (!entry) return "—"
    return entry.celsius + "\u00b0C"
}

function averageRpm(fans) {
    var sum = 0
    var count = 0
    for (var i = 0; i < fans.length; i++) {
        if (fans[i].rpm > 0) { sum += fans[i].rpm; count++ }
    }
    return count > 0 ? Math.round(sum / count) : 0
}

function modeText(mode, until, nowEpoch, profile) {
    if (mode !== 'max') return profile !== '' ? 'Automatic · ' + profile : 'Automatic'
    var tail = profile !== '' ? ' · ' + profile : ''
    if (!until || until <= 0) return 'Boosted, held' + tail
    var left = Math.max(0, Math.floor(until - nowEpoch))
    var minutes = Math.floor(left / 60)
    var seconds = left % 60
    return 'Boosted' + tail + ' · ' + minutes + ':' + (seconds < 10 ? '0' : '') + seconds + ' left'
}

function barText(mode, fans) {
    if (mode === 'max') return "🌬 MAX"
    var rpm = averageRpm(fans)
    if (rpm > 0) return "🌬 " + rpm
    return "🌬"
}
