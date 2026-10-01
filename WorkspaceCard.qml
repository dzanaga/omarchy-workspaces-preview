import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import "WorkspacesPreviewModel.js" as OverviewModel

Rectangle {
  id: card

  required property int workspaceId
  required property var overview

  property bool dragEnabled: true
  property string dropState: ""
  property bool dropBefore: false

  signal dragBegin(int id, real sceneX, real sceneY)
  signal dragUpdate(int id, real sceneX, real sceneY)
  signal dragEnd(int id, real sceneX, real sceneY)

  readonly property var workspace: {
    overview.revision
    return overview.workspaceById(card.workspaceId)
  }

  readonly property var toplevels: {
    overview.revision
    return overview.toplevelsForWorkspace(card.workspaceId)
  }

  readonly property var monitor: workspace && workspace.monitor ? workspace.monitor : null
  readonly property bool monitorAssigned: monitor !== null
  readonly property string monitorName: {
    if (monitor) return String(monitor.name || "")
    return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  }

  readonly property bool occupied: toplevels.length > 0

  readonly property bool displayed: {
    overview.revision
    return overview.activeWorkspaceIds().indexOf(card.workspaceId) !== -1
  }

  readonly property bool focused: Hyprland.focusedWorkspace !== null
    && Hyprland.focusedWorkspace.id === card.workspaceId

  readonly property bool onThisScreen: {
    if (!monitor) return false
    var window = card.QsWindow ? card.QsWindow.window : null
    var screen = window ? window.screen : null
    return screen !== null && surfaceName(screen) === monitorName
  }

  function surfaceName(screen) {
    return screen && screen.name ? String(screen.name) : ""
  }

  readonly property string summary: OverviewModel.labelSummary(toplevels, overview.labelMode)
  readonly property color foreground: Color.menu.text
  readonly property color accent: Color.accent
  readonly property int footerHeight: Math.max(Style.space(30),
    Style.font.title + Style.spacing.controlPaddingY * 2)

  radius: Style.cornerRadius
  color: Color.menu.background
  border.width: (focused || dropState === "swap")
    ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
  border.color: (focused || dropState === "swap") ? accent : Color.menu.border
  opacity: occupied || displayed ? 1 : 0.72
  clip: true

  Rectangle {
    id: previewArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: footer.top
    anchors.margins: Style.space(6)
    color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.05)
    radius: Math.max(0, Style.cornerRadius - Style.space(2))
    clip: true

    WorkspacePreview {
      anchors.fill: parent
      overview: card.overview
      workspaceId: card.workspaceId
      toplevels: card.toplevels
      monitor: card.monitor
      active: card.displayed
    }

    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      text: card.workspaceId === 10 ? "0" : String(card.workspaceId)
      color: card.foreground
      opacity: 0.85
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
      font.bold: true
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.55)
    }

    Text {
      anchors.centerIn: parent
      visible: !card.occupied
      text: "Empty"
      color: card.foreground
      opacity: 0.4
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
    }
  }

  MouseArea {
    id: cardArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    property real pressX: 0
    property real pressY: 0
    property bool dragging: false
    property bool suppressClick: false

    onPressed: function (mouse) {
      pressX = mouse.x
      pressY = mouse.y
      dragging = false
      suppressClick = false
    }

    onPositionChanged: function (mouse) {
      if (!pressed) return
      var dx = mouse.x - pressX
      var dy = mouse.y - pressY
      if (!dragging && card.dragEnabled && Math.sqrt(dx * dx + dy * dy) > 8) {
        dragging = true
        var start = card.mapToItem(null, mouse.x, mouse.y)
        card.dragBegin(card.workspaceId, start.x, start.y)
      }
      if (dragging) {
        var point = card.mapToItem(null, mouse.x, mouse.y)
        card.dragUpdate(card.workspaceId, point.x, point.y)
      }
    }

    onReleased: function (mouse) {
      if (!dragging) return
      var point = card.mapToItem(null, mouse.x, mouse.y)
      card.dragEnd(card.workspaceId, point.x, point.y)
      dragging = false
      suppressClick = true
    }

    onClicked: function (mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.RightButton)
        card.overview.cycleWorkspaceMonitor(card.workspaceId, 1)
      else
        card.overview.focusWorkspace(card.workspaceId)
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: card.dropState === "swap"
    color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.12)
    radius: card.radius
    border.width: Math.max(3, Style.space(3))
    border.color: card.accent
    z: 5
  }

  Rectangle {
    visible: card.dropState === "insert"
    width: Math.max(3, Style.space(3))
    height: Math.max(0, card.height - Style.space(14))
    anchors.verticalCenter: parent.verticalCenter
    x: card.dropBefore ? Style.space(8) : card.width - width - Style.space(8)
    radius: width / 2
    color: card.accent
    z: 5
  }

  RowLayout {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: card.footerHeight
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(8)

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: card.workspaceId === 10 ? "0" : String(card.workspaceId)
      color: card.focused ? card.accent : card.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: card.occupied ? card.summary : "no windows"
      color: card.foreground
      opacity: card.occupied ? 0.9 : 0.4
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    Rectangle {
      id: monitorBadge
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: badgeText.implicitWidth + Style.space(14)
      implicitHeight: badgeText.implicitHeight + Style.space(6)
      radius: height / 2
      color: badgeArea.pressed
        ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.28)
        : Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b,
          card.onThisScreen ? 0.16 : 0.07)
      border.width: Math.max(1, Style.space(1))
      border.color: card.onThisScreen ? card.accent : Color.menu.border

      Text {
        id: badgeText
        anchors.centerIn: parent
        text: card.monitorName
          ? (card.monitorAssigned ? card.monitorName : "~" + card.monitorName)
          : "\u2014"
        color: card.onThisScreen ? card.accent : card.foreground
        opacity: card.monitorAssigned ? (card.onThisScreen ? 1 : 0.85) : 0.45
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: badgeArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
          card.overview.cycleWorkspaceMonitor(card.workspaceId,
            mouse.button === Qt.RightButton ? -1 : 1)
        }
      }
    }
  }
}
