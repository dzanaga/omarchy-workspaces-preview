import QtQuick
import Quickshell
import qs.Commons
import "WorkspacesPreviewModel.js" as OverviewModel

Item {
  id: preview

  required property var overview
  required property int workspaceId
  required property var toplevels
  required property var monitor
  property bool active: false

  clip: true

  readonly property real monitorWidth: monitor ? Number(monitor.width) || 1920 : 1920
  readonly property real monitorHeight: monitor ? Number(monitor.height) || 1080 : 1080

  readonly property real fitScale: monitorWidth > 0 && monitorHeight > 0
    ? Math.min(width / monitorWidth, height / monitorHeight) : 0

  readonly property string snapshotSource: overview.hasSnapshot(workspaceId)
    ? overview.snapshotPath(workspaceId) + "?v=" + overview.snapshotRevision
    : ""

  Item {
    id: desktop
    width: preview.monitorWidth * preview.fitScale
    height: preview.monitorHeight * preview.fitScale
    anchors.centerIn: parent

    Image {
      id: snapshot
      anchors.fill: parent
      visible: status === Image.Ready
      source: preview.snapshotSource
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      cache: false
      smooth: true
    }

    Repeater {
      model: {
        preview.overview.revision
        return snapshot.status === Image.Ready ? [] : preview.toplevels
      }

      WindowGhost {
        required property var modelData

        toplevel: modelData
        monitor: preview.monitor
        scale: preview.fitScale
      }
    }

  }

  component WindowGhost: Item {
    id: ghost

    required property var toplevel
    required property var monitor
    required property real scale

    readonly property var geometry: OverviewModel.windowGeometry(toplevel, monitor)
    readonly property string appName: OverviewModel.friendlyAppName(
      OverviewModel.toplevelClass(toplevel))

    x: geometry ? Math.round(geometry.x * scale) : 0
    y: geometry ? Math.round(geometry.y * scale) : 0
    width: geometry ? Math.max(2, Math.round(geometry.width * scale)) : 0
    height: geometry ? Math.max(2, Math.round(geometry.height * scale)) : 0
    visible: geometry !== null
    clip: true

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1)
      radius: Math.max(0, Style.space(2))
      border.width: Math.max(1, Style.space(1))
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)

      Text {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.space(6))
        text: ghost.appName
        color: Color.menu.text
        opacity: 0.8
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
