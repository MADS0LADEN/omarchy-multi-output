import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "muj.multi-output"
  ipcTarget: "muj.multi-output"

  readonly property string script:
    Qt.resolvedUrl("bin/combine").toString().replace(/^file:\/\//, "")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var status: Model.emptyStatus()
  readonly property var outputs: status.available || []
  readonly property bool enabled: status.enabled === true
  readonly property int selectedCount: Model.selectedCount(status)
  readonly property string barText: Model.barLabel(status)
  readonly property string barIcon: enabled ? "󰓃" : "󰕾"
  readonly property bool canEnable: selectedCount >= 2
  readonly property string toggleHint: enabled ? "Stop sharing" : "Play on selected outputs"

  property string focusSection: "header"
  property int selectedIndex: 0
  property bool cursorActive: false
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"

  implicitWidth: barRow.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(raw) {
    var next = Model.parseStatus(raw)
    if (!next.ok && outputs.length > 0) return
    status = next
    clampCursor()
  }

  function runAction(args) {
    if (actionProc.running) return
    actionProc.command = ["/usr/bin/python3", root.script].concat(args)
    actionProc.running = true
  }

  function toggleOutput(name) {
    if (!name) return
    runAction(["toggle", name])
  }

  function toggleSharing() {
    if (enabled) runAction(["off"])
    else if (canEnable) runAction(["on"])
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
  }

  function clampCursor() {
    if (focusSection === "header") return
    if (outputs.length === 0) {
      focusSection = "header"
      selectedIndex = 0
      return
    }
    if (selectedIndex >= outputs.length) selectedIndex = outputs.length - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  function moveCursor(delta) {
    if (focusSection === "header") {
      if (delta > 0 && outputs.length > 0) {
        focusSection = "outputs"
        selectedIndex = 0
      }
      return
    }
    if (delta < 0 && selectedIndex === 0) {
      focusSection = "header"
      return
    }
    selectedIndex = Math.max(0, Math.min(outputs.length - 1, selectedIndex + delta))
  }

  function activateCursor() {
    if (focusSection === "header") {
      toggleSharing()
      return
    }
    var row = outputs[selectedIndex]
    if (row) toggleOutput(row.name)
  }

  Process {
    id: statusProc
    command: ["/usr/bin/python3", root.script, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: function() { root.refresh() }
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    focusSection = "header"
    selectedIndex = 0
    root.refresh()
  }

  Row {
    id: barRow
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: 0

    BarIconButton {
      id: button
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      bar: root.bar
      text: root.barIcon
      active: root.enabled
      dimmed: !root.enabled
      tooltipText: Model.tooltip(root.status)
      onPressed: function(b) {
        if (b === Qt.RightButton) root.toggleSharing()
        else root.toggle()
      }
    }

    WidgetButton {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      visible: root.barText !== "" && !(root.bar && root.bar.vertical)
      bar: root.bar
      text: root.barText
      fontSize: Style.font.bodySmall
      horizontalMargin: 2
      active: root.enabled
      tooltipText: button.tooltipText
      onPressed: function(b) {
        if (b === Qt.RightButton) root.toggleSharing()
        else root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Multi-output"
          meta: Model.heroMeta(root.status)
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.enabled ? 1.0 : 0.55
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.barIcon
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              color: root.enabled ? root.foreground : root.dim
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: root.enabled
              hasCursor: root.headerHasCursor
              foreground: root.foreground
              onHovered: function(on) { if (on) root.setHeaderCursor() }
              onToggled: root.toggleSharing()

              PanelToolTip {
                visible: parent.containsMouse
                text: root.toggleHint
                fontFamily: root.fontFamily
              }
            }
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "Audio plays on every ticked output. Connect both AirPods first, then tick them here."
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          color: root.dim
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "OUTPUTS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Repeater {
          model: root.outputs
          Toggle {
            required property var modelData
            required property int index
            width: column.width
            label: modelData.description || modelData.name
            description: modelData.selected && root.enabled ? "Playing" : (modelData.selected ? "Selected" : "")
            checked: modelData.selected === true
            hasCursor: root.cursorActive && root.focusSection === "outputs" && root.selectedIndex === index
            foreground: root.foreground
            fontFamily: root.fontFamily
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "outputs"
              root.selectedIndex = index
            }
            onClicked: root.toggleOutput(modelData.name)
          }
        }

        Text {
          visible: root.outputs.length === 0
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "No audio outputs found."
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          color: root.dim
        }
      }
    }
  }
}
