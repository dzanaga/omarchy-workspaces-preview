import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "WorkspacesPreviewModel.js" as OverviewModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property bool opened: false
  property bool opening: false

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.dzanaga.workspaces-preview"

  readonly property int workspaceCount: 10
  readonly property int gridColumns: 5

  // Bumped on structural compositor events so derived bindings recompute.
  property int revision: 0
  // Bumped whenever fresh workspace snapshots land on disk.
  property int snapshotRevision: 0
  // Callbacks queued behind the in-flight grim capture.
  property var captureCallbacks: []
  // Workspace ids whose snapshot file exists on disk.
  property var snapshotIds: ({})
  property var lastCaptureIds: []

  readonly property string cacheDir: {
    var base = Quickshell.env("XDG_CACHE_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.cache"
    return base + "/omarchy/workspaces-preview"
  }

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omarchy/workspaces-preview"
  readonly property string settingsPath: configDir + "/settings.json"
  readonly property string shortcutFilePath: Quickshell.env("HOME") + "/.config/hypr/workspaces-preview.lua"

  // ---- settings -----------------------------------------------------------
  property string labelMode: "apps"          // apps | titles | both | none
  property bool refreshOnOpen: true
  property bool showEmptyWorkspaces: true
  property bool reorderEnabled: true
  property bool showOnAllMonitors: true
  property string shortcut: "SUPER + ESCAPE"

  property bool settingsOpen: false
  property string settingsScreen: ""
  property bool recordingShortcut: false
  property string shortcutError: ""
  property string pendingShortcut: ""

  readonly property var structuralEvents: [
    "openwindow", "closewindow", "movewindow", "movewindowv2", "resizewindow",
    "workspace", "workspacev2", "createworkspace", "createworkspacev2",
    "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2",
    "renameworkspace", "focusedmon", "focusedmonv2",
    "monitoradded", "monitoraddedv2", "monitorremoved", "fullscreen"
  ]

  // Snapshot the currently visible workspaces *before* mapping the overlay so
  // the captures never include the overlay itself.
  function open(payloadJson) {
    if (root.opened || root.opening) return
    if (!root.refreshOnOpen) {
      root.showOverview()
      return
    }
    root.opening = true
    root.requestSnapshot(function () {
      root.opening = false
      root.showOverview()
    })
  }

  function showOverview() {
    root.opened = true
    root.revision++
    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
  }

  // ---- settings plumbing --------------------------------------------------

  function defaultSettings() {
    return {
      labelMode: "apps",
      refreshOnOpen: true,
      showEmptyWorkspaces: true,
      reorderEnabled: true,
      showOnAllMonitors: true,
      shortcut: "SUPER + ESCAPE"
    }
  }

  function applySettingsText(text) {
    var parsed = null
    try { parsed = JSON.parse(String(text || "")) } catch (e) { parsed = null }
    if (!parsed) return
    if (typeof parsed.labelMode === "string") root.labelMode = parsed.labelMode
    if (typeof parsed.refreshOnOpen === "boolean") root.refreshOnOpen = parsed.refreshOnOpen
    if (typeof parsed.showEmptyWorkspaces === "boolean") root.showEmptyWorkspaces = parsed.showEmptyWorkspaces
    if (typeof parsed.reorderEnabled === "boolean") root.reorderEnabled = parsed.reorderEnabled
    if (typeof parsed.showOnAllMonitors === "boolean") root.showOnAllMonitors = parsed.showOnAllMonitors
    if (typeof parsed.shortcut === "string" && parsed.shortcut) root.shortcut = parsed.shortcut
  }

  function persistSettings() {
    settingsFile.setText(JSON.stringify({
      labelMode: root.labelMode,
      refreshOnOpen: root.refreshOnOpen,
      showEmptyWorkspaces: root.showEmptyWorkspaces,
      reorderEnabled: root.reorderEnabled,
      showOnAllMonitors: root.showOnAllMonitors,
      shortcut: root.shortcut
    }, null, 2) + "\n")
  }

  function setLabelMode(mode) { root.labelMode = mode; root.persistSettings() }
  function setRefreshOnOpen(value) { root.refreshOnOpen = value; root.persistSettings() }
  function setShowEmptyWorkspaces(value) { root.showEmptyWorkspaces = value; root.persistSettings() }
  function setReorderEnabled(value) { root.reorderEnabled = value; root.persistSettings() }
  function setShowOnAllMonitors(value) { root.showOnAllMonitors = value; root.persistSettings() }

  function resetSettings() {
    var defaults = root.defaultSettings()
    root.labelMode = defaults.labelMode
    root.refreshOnOpen = defaults.refreshOnOpen
    root.showEmptyWorkspaces = defaults.showEmptyWorkspaces
    root.reorderEnabled = defaults.reorderEnabled
    root.showOnAllMonitors = defaults.showOnAllMonitors
    root.persistSettings()
    root.shortcutError = ""
  }

  function openSettings(screenName) {
    root.settingsScreen = String(screenName || "")
    root.settingsOpen = true
  }

  function closeSettings() {
    root.settingsOpen = false
    root.recordingShortcut = false
  }

  // ---- shortcut editing ---------------------------------------------------

  function beginShortcutRecording() {
    root.recordingShortcut = true
    root.shortcutError = ""
  }

  function keyName(event) {
    var key = event.key
    if (key === Qt.Key_Escape) return "ESCAPE"
    if (key === Qt.Key_Tab) return "TAB"
    if (key === Qt.Key_Return || key === Qt.Key_Enter) return "RETURN"
    if (key === Qt.Key_Space) return "SPACE"
    if (key === Qt.Key_Backspace) return "BACKSPACE"
    if (key === Qt.Key_Left) return "LEFT"
    if (key === Qt.Key_Right) return "RIGHT"
    if (key === Qt.Key_Up) return "UP"
    if (key === Qt.Key_Down) return "DOWN"
    if (key === Qt.Key_PageUp) return "PAGEUP"
    if (key === Qt.Key_PageDown) return "PAGEDOWN"
    if (key === Qt.Key_Home) return "HOME"
    if (key === Qt.Key_End) return "END"
    if (key === Qt.Key_Insert) return "INSERT"
    if (key === Qt.Key_Delete) return "DELETE"
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(65 + (key - Qt.Key_A))
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String(key - Qt.Key_0)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (1 + key - Qt.Key_F1)
    var text = String(event.text || "").toUpperCase()
    return text.length === 1 ? text : ""
  }

  function comboFromEvent(event) {
    var key = root.keyName(event)
    if (!key) return ""
    var mods = []
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    if (mods.length === 0) return ""
    return mods.join(" + ") + " + " + key
  }

  function captureShortcutKey(event) {
    var combo = root.comboFromEvent(event)
    if (!combo) {
      if (event.key === Qt.Key_Escape) {
        root.recordingShortcut = false
        return true
      }
      return false
    }
    root.recordingShortcut = false
    root.tryShortcut(combo)
    return true
  }

  function tryShortcut(combo) {
    root.pendingShortcut = combo
    root.shortcutError = ""
    bindsProcess.running = true
  }

  function modmaskFor(combo) {
    var mask = 0
    var parts = combo.split(" + ")
    for (var i = 0; i < parts.length - 1; i++) {
      if (parts[i] === "SHIFT") mask |= 1
      else if (parts[i] === "CTRL") mask |= 4
      else if (parts[i] === "ALT") mask |= 8
      else if (parts[i] === "SUPER") mask |= 64
    }
    return mask
  }

  function applyBindsResult(text) {
    var combo = root.pendingShortcut
    root.pendingShortcut = ""
    if (!combo) return

    var parts = combo.split(" + ")
    var key = String(parts[parts.length - 1] || "").toUpperCase()
    var mask = root.modmaskFor(combo)
    var conflict = ""

    try {
      var binds = JSON.parse(String(text || "[]"))
      for (var i = 0; i < binds.length; i++) {
        var bind = binds[i]
        var bindKey = String(bind.key || "").toUpperCase()
        if (!bindKey || bindKey !== key) continue
        if ((Number(bind.modmask) & 77) !== mask) continue
        var description = String(bind.description || bind.dispatcher || "an existing binding")
        if (description === "Workspace overview") continue
        conflict = description
        break
      }
    } catch (e) {
      conflict = ""
    }

    if (conflict) {
      root.shortcutError = "Already used by: " + conflict
      return
    }

    root.shortcut = combo
    root.persistSettings()
    root.writeShortcutFile()
    reloadProcess.running = true
  }

  function writeShortcutFile() {
    var text = "-- Managed by the Workspaces Preview plugin. Do not edit by hand.\n"
      + "-- Change the shortcut from the overview's settings panel.\n\n"
      + "hl.unbind(\"SUPER + ESCAPE\")\n"
      + "hl.unbind(\"" + root.shortcut + "\")\n"
      + "o.bind(\"" + root.shortcut + "\", \"Workspace overview\",\n"
      + "  \"omarchy-shell shell toggle " + root.pluginId + "\")\n"
    shortcutFile.setText(text)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function buildCaptureScript() {
    var monitors = Hyprland.monitors.values
    var commands = ["mkdir -p " + root.shellQuote(root.cacheDir)]
    root.lastCaptureIds = []
    for (var i = 0; i < monitors.length; i++) {
      var workspace = monitors[i].activeWorkspace
      if (!workspace || !(workspace.id > 0)) continue
      root.lastCaptureIds.push(workspace.id)
      commands.push("grim -o " + root.shellQuote(String(monitors[i].name))
        + " " + root.shellQuote(root.cacheDir + "/ws-" + workspace.id + ".png")
        + " 2>/dev/null")
    }
    return commands.join("; ")
  }

  function requestSnapshot(callback) {
    if (typeof callback === "function") root.captureCallbacks.push(callback)
    if (captureProcess.running) return
    var script = root.buildCaptureScript()
    if (!script) {
      root.finishSnapshot()
      return
    }
    captureProcess.command = ["bash", "-c", script]
    captureProcess.running = true
  }

  function finishSnapshot() {
    var next = {}
    for (var key in root.snapshotIds) next[key] = root.snapshotIds[key]
    for (var i = 0; i < root.lastCaptureIds.length; i++) {
      next[String(root.lastCaptureIds[i])] = true
    }
    root.snapshotIds = next
    root.snapshotRevision++

    var callbacks = root.captureCallbacks
    root.captureCallbacks = []
    for (var j = 0; j < callbacks.length; j++) callbacks[j]()
  }

  function registerSnapshotFiles(text) {
    var lines = String(text || "").split("\n")
    var next = {}
    for (var key in root.snapshotIds) next[key] = root.snapshotIds[key]
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/ws-(\d+)\.png\s*$/)
      if (match) next[match[1]] = true
    }
    root.snapshotIds = next
    root.snapshotRevision++
  }

  function hasSnapshot(id) {
    return root.snapshotIds[String(id)] === true
  }

  function snapshotPath(id) {
    return "file://" + root.cacheDir + "/ws-" + id + ".png"
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    root.closeSettings()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function toplevelsForWorkspace(id) {
    return OverviewModel.toplevelsForWorkspace(Hyprland.toplevels.values, id)
  }

  function activeWorkspaceIds() {
    var ids = []
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var workspace = monitors[i].activeWorkspace
      if (workspace && ids.indexOf(workspace.id) === -1) ids.push(workspace.id)
    }
    return ids
  }

  function monitorName(id) {
    var workspace = root.workspaceById(id)
    return workspace && workspace.monitor ? String(workspace.monitor.name || "") : ""
  }

  function focusWorkspace(id) {
    if (!(id > 0)) return
    root.dismiss()
    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }

  function cycleWorkspaceMonitor(id, direction) {
    var monitors = Hyprland.monitors.values
    if (monitors.length < 2) return
    var workspace = root.workspaceById(id)
    if (!workspace || !workspace.monitor) return

    var index = -1
    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].name === workspace.monitor.name) index = i
    }
    if (index === -1) return

    var step = direction < 0 ? -1 : 1
    var next = monitors[(index + step + monitors.length) % monitors.length]
    Hyprland.dispatch("moveworkspacetomonitor " + id + " " + next.name)
    root.revision++
  }

  // ---- reorder (fixed slots: windows move between numbered workspaces) ----

  function swapWorkspaces(a, b) {
    if (!root.reorderEnabled || !(a > 0) || !(b > 0) || a === b) return
    root.applyWorkspaceMapping(OverviewModel.swapMapping(a, b))
  }

  function insertWorkspace(sourceId, targetId, before) {
    if (!root.reorderEnabled || !(sourceId > 0) || !(targetId > 0)) return
    if (sourceId === targetId) return
    var mapping = OverviewModel.insertionOrder(root.workspaceCount, sourceId, targetId, before)
    if (!mapping) return
    root.applyWorkspaceMapping(mapping)
  }

  function applyWorkspaceMapping(mapping) {
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (!toplevel.workspace) continue
      var target = mapping[toplevel.workspace.id]
      if (!target) continue
      Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + target
        + "\", window = \"address:" + toplevel.address + "\", follow = false })")
    }
    root.moveSnapshotFiles(mapping)
    root.revision++
  }

  function moveSnapshotFiles(mapping) {
    var commands = ["mkdir -p " + root.shellQuote(root.cacheDir)]
    var pairs = []
    for (var oldId in mapping) pairs.push([String(oldId), String(mapping[oldId])])
    for (var i = 0; i < pairs.length; i++) {
      commands.push("mv " + root.shellQuote(root.cacheDir + "/ws-" + pairs[i][0] + ".png")
        + " " + root.shellQuote(root.cacheDir + "/.reorder-" + pairs[i][0] + ".png")
        + " 2>/dev/null")
    }
    for (var j = 0; j < pairs.length; j++) {
      commands.push("mv " + root.shellQuote(root.cacheDir + "/.reorder-" + pairs[j][0] + ".png")
        + " " + root.shellQuote(root.cacheDir + "/ws-" + pairs[j][1] + ".png")
        + " 2>/dev/null")
    }
    reorderProcess.command = ["bash", "-c", commands.join("; ")]
    reorderProcess.running = true
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = String(event && event.name || "")
      if (root.structuralEvents.indexOf(name) === -1) return
      root.revision++
      snapshotDebounce.restart()
    }
  }

  Process {
    id: captureProcess
    onExited: root.finishSnapshot()
  }

  Process {
    id: reorderProcess
    onExited: {
      root.snapshotRevision++
      listProcess.running = true
    }
  }

  Process {
    id: listProcess
    command: ["bash", "-c",
      "ls " + root.shellQuote(root.cacheDir) + "/ws-*.png 2>/dev/null"]
    stdout: StdioCollector {
      id: listStdout
      waitForEnd: true
    }
    onExited: root.registerSnapshotFiles(listStdout.text)
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    onLoaded: root.applySettingsText(settingsFile.text())
    onFileChanged: settingsFile.reload()
  }

  FileView {
    id: shortcutFile
    path: root.shortcutFilePath
    atomicWrites: true
  }

  Process {
    id: bindsProcess
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      id: bindsStdout
      waitForEnd: true
    }
    onExited: root.applyBindsResult(bindsStdout.text)
  }

  Process {
    id: reloadProcess
    command: ["hyprctl", "reload", "config-only"]
    onExited: root.revision++
  }

  Timer {
    id: startupSnapshot
    interval: 2200
    onTriggered: root.requestSnapshot(null)
  }

  Timer {
    id: snapshotDebounce
    interval: 700
    onTriggered: {
      if (!root.opened && !root.opening) root.requestSnapshot(null)
    }
  }

  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", root.configDir])
    listProcess.running = true
    startupSnapshot.start()
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      OverviewSurface {
        overview: root
        screen: modelData
      }
    }
  }
}
