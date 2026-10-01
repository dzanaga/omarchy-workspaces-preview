import QtQuick
import Quickshell
import qs.Commons

Rectangle {
  id: panel

  required property var overview

  readonly property color foreground: Color.menu.text
  readonly property int rowHeight: Math.max(Style.space(30),
    Style.font.body + Style.spacing.controlPaddingY * 2)
  readonly property int panelWidth: Style.space(320)

  width: panelWidth
  height: column.implicitHeight + Style.spacing.panelPadding * 2
  radius: Style.cornerRadius
  color: Color.menu.background
  border.width: Math.max(1, Style.space(1))
  border.color: Color.menu.border

  // Swallow clicks so the backdrop underneath does not dismiss the overlay.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.spacing.panelPadding
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      text: "Overview settings"
      color: panel.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
      bottomPadding: Style.spacing.xs
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - control.width
        text: "Labels"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: control
        text: panel.labelModeLabel()
        onActivated: panel.overview.setLabelMode(panel.nextLabelMode())
      }
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - control2.width
        text: "Preview on open"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: control2
        text: panel.overview.refreshOnOpen ? "Refresh" : "Cached"
        onActivated: panel.overview.setRefreshOnOpen(!panel.overview.refreshOnOpen)
      }
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - control3.width
        text: "Show empty workspaces"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: control3
        text: panel.overview.showEmptyWorkspaces ? "On" : "Off"
        onActivated: panel.overview.setShowEmptyWorkspaces(!panel.overview.showEmptyWorkspaces)
      }
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - control4.width
        text: "Drag to reorder"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: control4
        text: panel.overview.reorderEnabled ? "On" : "Off"
        onActivated: panel.overview.setReorderEnabled(!panel.overview.reorderEnabled)
      }
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - control5.width
        text: "Show on all monitors"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: control5
        text: panel.overview.showOnAllMonitors ? "On" : "Off"
        onActivated: panel.overview.setShowOnAllMonitors(!panel.overview.showOnAllMonitors)
      }
    }

    Item {
      width: parent.width
      height: Math.max(1, Style.space(1)) + Style.spacing.xs * 2

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(1, Style.space(1))
        color: Color.menu.border
        opacity: 0.5
      }
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - shortcutPill.width
        text: "Shortcut"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Pill {
        id: shortcutPill
        text: panel.overview.recordingShortcut ? "Press keys\u2026" : panel.overview.shortcut
        onActivated: {
          if (panel.overview.recordingShortcut) panel.overview.recordingShortcut = false
          else panel.overview.beginShortcutRecording()
        }
      }
    }

    Text {
      width: parent.width
      visible: panel.overview.recordingShortcut || panel.overview.shortcutError !== ""
      text: panel.overview.recordingShortcut
        ? "Press a modifier + key combination\u2026"
        : panel.overview.shortcutError
      color: Color.urgent
      wrapMode: Text.WordWrap
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Row {
      width: parent.width
      height: panel.rowHeight
      Pill {
        text: "Reset settings"
        onActivated: panel.overview.resetSettings()
      }
    }
  }

  function labelModeLabel() {
    var mode = panel.overview.labelMode
    if (mode === "titles") return "Titles"
    if (mode === "both") return "Both"
    if (mode === "none") return "None"
    return "Apps"
  }

  function nextLabelMode() {
    var mode = panel.overview.labelMode
    if (mode === "apps") return "titles"
    if (mode === "titles") return "both"
    if (mode === "both") return "none"
    return "apps"
  }

  component Pill: Rectangle {
    id: pill

    property string text: ""
    signal activated()

    implicitWidth: pillText.implicitWidth + Style.space(20)
    implicitHeight: pillText.implicitHeight + Style.space(8)
    radius: height / 2
    color: pillArea.pressed
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      : Qt.rgba(panel.foreground.r, panel.foreground.g, panel.foreground.b, 0.08)
    border.width: Math.max(1, Style.space(1))
    border.color: Color.menu.border

    Text {
      id: pillText
      anchors.centerIn: parent
      text: pill.text
      color: panel.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: pillArea
      anchors.fill: parent
      onClicked: pill.activated()
    }
  }
}
