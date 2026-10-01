.pragma library

var FRIENDLY_APPS = {
  "google-chrome": "Chrome",
  "chromium": "Chromium",
  "firefox": "Firefox",
  "com.mitchellh.ghostty": "Ghostty",
  "org.wezfurlong.wezterm": "WezTerm",
  "alacritty": "Alacritty",
  "kitty": "Kitty",
  "foot": "Foot",
  "code": "VS Code",
  "code-oss": "VS Code",
  "org.gnome.nautilus": "Files",
  "nautilus": "Files",
  "spotify": "Spotify",
  "discord": "Discord",
  "slack": "Slack",
  "obsidian": "Obsidian",
  "org.signal.Signal": "Signal",
  "signal-desktop": "Signal",
  "thunderbird": "Thunderbird",
  "vlc": "VLC",
  "mpv": "mpv",
  "zoom": "Zoom"
}

function titleCase(text) {
  return String(text || "").replace(/\b\w/g, function (ch) { return ch.toUpperCase() })
}

function toplevelClass(toplevel) {
  var obj = (toplevel && toplevel.lastIpcObject) || {}
  return String(obj.initialClass || obj.class || "")
}

function friendlyAppName(className) {
  var raw = String(className || "").trim()
  if (!raw) return "Unknown"
  if (FRIENDLY_APPS[raw]) return FRIENDLY_APPS[raw]
  if (/^chrome[-.]/.test(raw) || raw === "chrome") return "Chrome"
  if (/^firefox/.test(raw)) return "Firefox"
  if (/^code(-oss)?$/i.test(raw)) return "VS Code"

  var parts = raw.split(".")
  var last = parts[parts.length - 1]
  if (!last) last = raw
  last = last.replace(/[-_]+/g, " ").trim()
  return titleCase(last)
}

function toplevelsForWorkspace(toplevels, workspaceId) {
  var out = []
  for (var i = 0; i < toplevels.length; i++) {
    var toplevel = toplevels[i]
    var workspace = toplevel ? toplevel.workspace : null
    if (workspace && workspace.id === workspaceId) out.push(toplevel)
  }
  out.sort(function (left, right) {
    var leftId = Number((left.lastIpcObject || {}).focusHistoryID)
    var rightId = Number((right.lastIpcObject || {}).focusHistoryID)
    if (isNaN(leftId)) leftId = 9999
    if (isNaN(rightId)) rightId = 9999
    return rightId - leftId
  })
  return out
}

function toplevelTitle(toplevel) {
  var obj = (toplevel && toplevel.lastIpcObject) || {}
  return String((toplevel && toplevel.title) || obj.title || "")
}

function summarize(names) {
  var counts = {}
  var order = []
  for (var i = 0; i < names.length; i++) {
    var name = names[i]
    if (!name) continue
    if (counts[name] === undefined) {
      counts[name] = 1
      order.push(name)
    } else {
      counts[name] += 1
    }
  }

  var parts = []
  for (var j = 0; j < order.length; j++) {
    var label = order[j]
    if (counts[label] > 1) label += " \u00d7" + counts[label]
    parts.push(label)
  }
  return parts.join(" \u00b7 ")
}

function appSummary(toplevels) {
  var names = []
  for (var i = 0; i < toplevels.length; i++) {
    names.push(friendlyAppName(toplevelClass(toplevels[i])))
  }
  return summarize(names)
}

function labelSummary(toplevels, mode) {
  if (mode === "none") return ""
  var names = []
  for (var i = 0; i < toplevels.length; i++) {
    var toplevel = toplevels[i]
    var app = friendlyAppName(toplevelClass(toplevel))
    var title = toplevelTitle(toplevel)
    if (mode === "titles") names.push(title || app)
    else if (mode === "both") names.push(app + ": " + (title || "untitled"))
    else names.push(app)
  }
  return summarize(names)
}

function swapMapping(a, b) {
  var mapping = {}
  if (a !== b) {
    mapping[a] = b
    mapping[b] = a
  }
  return mapping
}

// Fixed numbered slots: dragging a workspace between two others rewrites which
// numbered slot each group of windows lives in. Returns { oldSlot: newSlot }.
function insertionOrder(count, sourceId, targetId, before) {
  var list = []
  for (var i = 1; i <= count; i++) list.push(i)

  var without = []
  for (var j = 0; j < list.length; j++) {
    if (list[j] !== sourceId) without.push(list[j])
  }

  var targetIndex = without.indexOf(targetId)
  if (targetIndex === -1) return null

  var position = before ? targetIndex : targetIndex + 1
  without.splice(position, 0, sourceId)

  var mapping = {}
  for (var k = 0; k < without.length; k++) {
    if (without[k] !== k + 1) mapping[without[k]] = k + 1
  }
  return mapping
}

function numberPair(value, fallback) {
  if (Array.isArray(value) && value.length >= 2) {
    return [Number(value[0]) || 0, Number(value[1]) || 0]
  }
  if (value && typeof value === "object") return [Number(value.x) || 0, Number(value.y) || 0]
  return fallback
}

function windowGeometry(toplevel, monitor) {
  var obj = (toplevel && toplevel.lastIpcObject) || {}
  var at = numberPair(obj.at, [0, 0])
  var size = numberPair(obj.size, [0, 0])
  var monitorX = monitor ? Number(monitor.x) || 0 : 0
  var monitorY = monitor ? Number(monitor.y) || 0 : 0
  var monitorWidth = monitor ? Number(monitor.width) || 0 : 0
  var monitorHeight = monitor ? Number(monitor.height) || 0 : 0

  var fullscreen = Number(obj.fullscreen)
  if (fullscreen === 2 || fullscreen === 3) {
    at = [monitorX, monitorY]
    size = [monitorWidth, monitorHeight]
  }

  if (!(size[0] > 0) || !(size[1] > 0)) return null

  return {
    x: at[0] - monitorX,
    y: at[1] - monitorY,
    width: size[0],
    height: size[1]
  }
}
