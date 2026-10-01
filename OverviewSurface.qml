import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: surface

  property var modelData: null
  required property var overview

  readonly property string surfaceName: modelData ? String(modelData.name || "") : ""
  readonly property bool focusedMonitor: Hyprland.focusedMonitor !== null
    && Hyprland.focusedMonitor.name === surfaceName

  screen: modelData
  visible: overview.opened
    && (overview.showOnAllMonitors || surface.focusedMonitor)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "omarchy-workspaces-preview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible && surface.focusedMonitor
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  readonly property real outerMargin: Style.space(30)
  readonly property real headerHeight: Style.space(26)
  readonly property real footerHeight: Style.space(22)
  readonly property real gridSpacing: Style.space(14)
  readonly property int columns: overview.gridColumns
  readonly property int rows: Math.max(1, Math.ceil(overview.workspaceCount / columns))

  readonly property real cellWidth: Math.max(120,
    (width - outerMargin * 2 - gridSpacing * (columns - 1)) / columns)
  readonly property real cellHeight: Math.max(120,
    (height - outerMargin * 2 - headerHeight - footerHeight - gridSpacing * 2
      - gridSpacing * (rows - 1)) / rows)

  function takeFocus() {
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function digitToWorkspace(text) {
    if (!text || text.length !== 1) return 0
    var code = text.charCodeAt(0)
    if (code < 48 || code > 57) return 0
    var id = text === "0" ? 10 : code - 48
    return id <= overview.workspaceCount ? id : 0
  }

  // ---- drag and drop reorder ---------------------------------------------

  property int draggingId: 0
  property real dragX: 0
  property real dragY: 0
  property int dropCardId: 0
  property string dropMode: ""
  property bool insertBefore: false

  function cardAt(sceneX, sceneY) {
    var children = grid.children
    for (var i = 0; i < children.length; i++) {
      var child = children[i]
      if (child.workspaceId === undefined) continue
      var local = child.mapFromItem(null, sceneX, sceneY)
      var inside = local.x >= 0 && local.y >= 0
        && local.x <= child.width && local.y <= child.height
      if (inside) return { item: child, localX: local.x, localY: local.y }
    }
    return null
  }

  function nearestCard(sceneX, sceneY) {
    var children = grid.children
    var best = null
    var bestDistance = Infinity
    var bestX = sceneX
    var bestY = sceneY
    for (var i = 0; i < children.length; i++) {
      var child = children[i]
      if (child.workspaceId === undefined) continue
      if (child.workspaceId === surface.draggingId) continue
      var center = child.mapToItem(null, child.width / 2, child.height / 2)
      var dx = center.x - sceneX
      var dy = center.y - sceneY
      var distance = dx * dx + dy * dy
      if (distance < bestDistance) {
        bestDistance = distance
        best = child
        bestX = center.x
        bestY = sceneY
      }
    }
    return best ? { item: best, centerX: bestX } : null
  }

  function updateDrop(sceneX, sceneY) {
    dropCardId = 0
    dropMode = ""
    if (draggingId === 0) return

    var hit = cardAt(sceneX, sceneY)
    if (hit) {
      if (hit.item.workspaceId === draggingId) return
      var rx = hit.localX / Math.max(1, hit.item.width)
      var ry = hit.localY / Math.max(1, hit.item.height)
      dropCardId = hit.item.workspaceId
      if (rx > 0.32 && rx < 0.68 && ry > 0.25 && ry < 0.85) {
        dropMode = "swap"
      } else {
        dropMode = "insert"
        insertBefore = rx < 0.5
      }
      return
    }

    var nearest = nearestCard(sceneX, sceneY)
    if (!nearest) return
    dropCardId = nearest.item.workspaceId
    dropMode = "insert"
    insertBefore = sceneX < nearest.centerX
  }

  function dragBegin(id, sceneX, sceneY) {
    draggingId = id
    dragX = sceneX
    dragY = sceneY
    updateDrop(sceneX, sceneY)
  }

  function dragMove(sceneX, sceneY) {
    dragX = sceneX
    dragY = sceneY
    updateDrop(sceneX, sceneY)
  }

  function dragDrop(sceneX, sceneY) {
    updateDrop(sceneX, sceneY)
    var sourceId = draggingId
    var targetId = dropCardId
    var mode = dropMode
    var before = insertBefore
    draggingId = 0
    dropCardId = 0
    dropMode = ""
    if (sourceId === 0 || targetId === 0 || sourceId === targetId) return
    if (mode === "swap") overview.swapWorkspaces(sourceId, targetId)
    else if (mode === "insert") overview.insertWorkspace(sourceId, targetId, before)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: overview.dismiss()
  }

  Text {
    id: header
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.leftMargin: surface.outerMargin
    anchors.topMargin: surface.outerMargin
    text: "Workspaces"
    color: Color.menu.text
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    style: Text.Outline
    styleColor: Qt.rgba(0, 0, 0, 0.5)
  }

  Rectangle {
    id: settingsButton
    z: 10
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: surface.outerMargin
    anchors.topMargin: surface.outerMargin - Style.space(4)
    implicitWidth: settingsLabel.implicitWidth + Style.space(24)
    implicitHeight: settingsLabel.implicitHeight + Style.space(12)
    radius: height / 2
    color: settingsArea.pressed
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
      : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.08)
    border.width: Math.max(1, Style.space(1))
    border.color: overview.settingsOpen && overview.settingsScreen === surface.surfaceName
      ? Color.accent : Color.menu.border

    Text {
      id: settingsLabel
      anchors.centerIn: parent
      text: "Settings"
      color: Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: settingsArea
      anchors.fill: parent
      onClicked: {
        if (overview.settingsOpen && overview.settingsScreen === surface.surfaceName)
          overview.closeSettings()
        else
          overview.openSettings(surface.surfaceName)
      }
    }
  }

  SettingsPanel {
    id: settingsPanel
    z: 10
    anchors.right: parent.right
    anchors.top: settingsButton.bottom
    anchors.rightMargin: surface.outerMargin
    anchors.topMargin: Style.space(8)
    visible: overview.settingsOpen && overview.settingsScreen === surface.surfaceName
    overview: surface.overview
  }

  Grid {
    id: grid
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: surface.outerMargin + surface.headerHeight + surface.gridSpacing
    columns: surface.columns
    spacing: surface.gridSpacing

    Repeater {
      model: {
        surface.overview.revision
        var ids = []
        for (var i = 1; i <= surface.overview.workspaceCount; i++) {
          if (!surface.overview.showEmptyWorkspaces) {
            var occupied = surface.overview.toplevelsForWorkspace(i).length > 0
            var displayed = surface.overview.activeWorkspaceIds().indexOf(i) !== -1
            var focused = Hyprland.focusedWorkspace !== null
              && Hyprland.focusedWorkspace.id === i
            if (!occupied && !displayed && !focused) continue
          }
          ids.push(i)
        }
        return ids
      }

      WorkspaceCard {
        required property int modelData

        width: surface.cellWidth
        height: surface.cellHeight
        workspaceId: modelData
        overview: surface.overview
        dragEnabled: surface.overview.reorderEnabled
        dropState: surface.dropCardId === modelData ? surface.dropMode : ""
        dropBefore: surface.insertBefore

        onDragBegin: function (id, sceneX, sceneY) { surface.dragBegin(id, sceneX, sceneY) }
        onDragUpdate: function (id, sceneX, sceneY) { surface.dragMove(sceneX, sceneY) }
        onDragEnd: function (id, sceneX, sceneY) { surface.dragDrop(sceneX, sceneY) }
      }
    }
  }

  Rectangle {
    id: dragGhost
    visible: surface.draggingId !== 0
    x: surface.dragX - width / 2
    y: surface.dragY - height / 2
    width: Style.space(150)
    height: Style.space(44)
    radius: Style.cornerRadius
    color: Color.menu.background
    border.width: Math.max(2, Style.space(2))
    border.color: Color.accent
    opacity: 0.92
    z: 30

    Text {
      anchors.centerIn: parent
      text: "Workspace " + (surface.draggingId === 10 ? "0" : surface.draggingId)
      color: Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  Text {
    id: hint
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: surface.outerMargin
    text: "1\u20130 jump  \u00b7  drag to reorder  \u00b7  S settings  \u00b7  right-click cycles monitor  \u00b7  Esc closes"
    color: Color.menu.text
    opacity: 0.55
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function (event) {
      if (overview.recordingShortcut) {
        if (overview.captureShortcutKey(event)) event.accepted = true
        return
      }

      if (event.key === Qt.Key_Escape) {
        if (overview.settingsOpen) overview.closeSettings()
        else overview.dismiss()
        event.accepted = true
        return
      }

      if (overview.settingsOpen) return

      var text = event.text || ""
      if (text === "s" || text === "S") {
        overview.openSettings(surface.surfaceName)
        event.accepted = true
        return
      }

      var id = surface.digitToWorkspace(text)
      if (id > 0) {
        overview.focusWorkspace(id)
        event.accepted = true
      }
    }
  }

  onVisibleChanged: {
    if (visible) surface.takeFocus()
  }

  Connections {
    target: overview

    function onOpenedChanged() {
      if (overview.opened) surface.takeFocus()
    }
  }
}
