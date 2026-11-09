.pragma library

function parseStatus(raw) {
    var fans = []
    var mode = "auto"
    var until = 0
    var profile = ""
    var platform = ""
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
        } else if (key === 'FAN') {
            var parts = value.split('|')
            if (parts.length >= 5) {
                fans.push({
                    driver: parts[0],
                    index: parseInt(parts[1], 10) || 0,
                    rpm: parseInt(parts[2], 10) || 0,
                    pwm: parseInt(parts[3], 10) || 0,
                    enable: parseInt(parts[4], 10) || 0
                })
            }
        }
    }
    return { mode: mode, until: until, fans: fans, profile: profile, platform: platform }
}

function fanLabel(fan) {
    if (!fan) return ""
    return "Fan " + fan.index + " (" + fan.driver + ")"
}

function rpmText(fan) {
    if (!fan || !fan.rpm) return "—"
    return fan.rpm + " rpm"
}

function fanDetail(fan) {
    if (!fan) return "—"
    var text = rpmText(fan)
    if (fan.pwm > 0) text += " (" + pwmPercent(fan) + "%)"
    return text
}

function pwmPercent(fan) {
    if (!fan || !fan.pwm) return 0
    return Math.round((fan.pwm / 255) * 100)
}

function averageRpm(fans) {
    var sum = 0
    var count = 0
    for (var i = 0; i < fans.length; i++) {
        if (fans[i].rpm > 0) { sum += fans[i].rpm; count++ }
    }
    return count > 0 ? Math.round(sum / count) : 0
}

function modeText(mode, until, nowEpoch) {
    if (mode !== 'max') return 'Automatic'
    if (!until || until <= 0) return 'Maximum, held'
    var left = Math.max(0, Math.floor(until - nowEpoch))
    var minutes = Math.floor(left / 60)
    var seconds = left % 60
    return 'Maximum · ' + minutes + ':' + (seconds < 10 ? '0' : '') + seconds + ' left'
}

function barText(mode, fans) {
    if (mode === 'max') return "FAN MAX"
    var rpm = averageRpm(fans)
    if (rpm > 0) return "FAN " + rpm
    return "FAN"
}
