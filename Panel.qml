import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.chavez62.process-manager"
  ipcTarget: "io.github.chavez62.process-manager"

  property var anchorItem: null
  property var hostWidget: null
  property var processService: null
  property int selectedPid: 0
  property var selectedProcess: null
  property int niceValue: selectedProcess ? selectedProcess.nice : 0
  property int armedKillPid: 0
  property string query: ""
  property string sortKey: "cpu"
  property bool sortDescending: true
  readonly property var visibleProcesses: Model.filtered(processService ? processService.processes : [], query, sortKey, sortDescending)
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { controller.show(); if (processService) processService.setActive(true) }
  function close() { armedKillPid = 0; if (processService) processService.setActive(false); controller.hide() }
  function toggle() { if (opened) close(); else open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function choose(process) {
    selectedPid = process.pid
    selectedProcess = process
    niceValue = process.nice
    armedKillPid = 0
  }
  function act(kind) {
    if (!processService || !selectedProcess) return
    if (kind === "kill" && armedKillPid !== selectedPid) {
      armedKillPid = selectedPid
      killArmTimer.restart()
      return
    }
    processService.action(kind, selectedPid, selectedProcess.startTime, niceValue)
    armedKillPid = 0
  }

  function syncSelection() {
    if (!processService || selectedPid === 0) return
    var rows = processService.processes || []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].pid === selectedPid) {
        selectedProcess = rows[i]
        niceValue = rows[i].nice
        return
      }
    }
    selectedPid = 0
    selectedProcess = null
    armedKillPid = 0
  }

  Connections {
    target: root.processService
    function onProcessesChanged() { root.syncSelection() }
  }

  Timer { id: killArmTimer; interval: 3500; onTriggered: root.armedKillPid = 0 }

  function setSort(key) {
    if (sortKey === key) sortDescending = !sortDescending
    else { sortKey = key; sortDescending = key !== "name" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(Style.space(610))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        anchors.fill: parent
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: title.implicitHeight
          Text { id: title; text: "Process Manager"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
          Text { anchors.right: parent.right; anchors.verticalCenter: title.verticalCenter; text: processService ? processService.processes.length + " shown" : "loading"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        }

        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.13), 1)

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            verticalAlignment: TextInput.AlignVCenter
            color: root.foreground
            selectionColor: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            clip: true
            onTextChanged: root.query = text

            Text {
              visible: searchInput.text === "" && !searchInput.activeFocus
              anchors.verticalCenter: parent.verticalCenter
              text: "Search name, command, or PID…"
              color: root.dim
              font: searchInput.font
            }
          }
        }

        Row {
          spacing: Style.space(7)
          Repeater {
            model: [{ key: "cpu", label: "CPU" }, { key: "memory", label: "Memory" }, { key: "name", label: "Name" }, { key: "pid", label: "PID" }]
            delegate: BorderSurface {
              required property var modelData
              height: Style.space(26)
              width: sortLabel.implicitWidth + Style.space(18)
              radius: Style.cornerRadius
              color: root.sortKey === modelData.key ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.16) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              borderSpec: Border.none()
              Text { id: sortLabel; anchors.centerIn: parent; text: modelData.label + (root.sortKey === modelData.key ? (root.sortDescending ? " ↓" : " ↑") : ""); color: root.sortKey === modelData.key ? root.urgent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              TapHandler { onTapped: root.setSort(parent.modelData.key) }
            }
          }
        }

        ListView {
          id: processList
          width: parent.width
          height: Style.space(390)
          clip: true
          spacing: Style.space(2)
          model: root.visibleProcesses

          delegate: Rectangle {
            id: row
            required property var modelData
            width: processList.width
            height: Style.space(42)
            radius: Style.space(6)
            color: root.selectedPid === modelData.pid
              ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18)
              : (hover.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")

            Text { anchors.left: parent.left; anchors.leftMargin: Style.space(8); anchors.top: parent.top; anchors.topMargin: Style.space(5); width: parent.width - Style.space(155); text: modelData.name; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: root.selectedPid === modelData.pid }
            Text { anchors.left: parent.left; anchors.leftMargin: Style.space(8); anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(4); width: parent.width - Style.space(155); text: modelData.pid + "  ·  " + modelData.rssMiB.toFixed(1) + " MiB  ·  nice " + modelData.nice + (modelData.stopped ? "  ·  PAUSED" : ""); elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text { anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter; text: modelData.cpu.toFixed(1) + "% CPU   " + modelData.memory.toFixed(1) + "% MEM"; color: modelData.stopped ? root.urgent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            HoverHandler { id: hover }
            TapHandler { onTapped: root.choose(row.modelData) }
          }

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }

        Text {
          width: parent.width
          text: root.selectedProcess ? root.selectedProcess.command : "Select a process to manage it"
          textFormat: Text.PlainText
          elide: Text.ElideMiddle
          color: root.selectedProcess ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          spacing: Style.space(9)
          enabled: !!root.selectedProcess && !(processService && processService.busy)
          opacity: enabled ? 1 : 0.45

          PanelActionButton { iconText: root.selectedProcess && root.selectedProcess.stopped ? "󰐊" : "󰏤"; tooltipText: root.selectedProcess && root.selectedProcess.stopped ? "Resume process" : "Pause process"; foreground: root.foreground; fontFamily: root.fontFamily; focusable: true; onClicked: root.act(root.selectedProcess.stopped ? "resume" : "pause") }
          PanelActionButton { iconText: "󰩹"; tooltipText: "Terminate gracefully"; foreground: root.foreground; hoverColor: root.urgent; fontFamily: root.fontFamily; focusable: true; onClicked: root.act("terminate") }
          PanelActionButton { iconText: root.armedKillPid === root.selectedPid ? "󰄬" : "󰅖"; tooltipText: root.armedKillPid === root.selectedPid ? "Click again to confirm hard kill" : "Hard kill"; foreground: root.foreground; hoverColor: root.urgent; fontFamily: root.fontFamily; focusable: true; onClicked: root.act("kill") }
          Rectangle { width: 1; height: Style.space(24); color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18) }
          PanelActionButton { iconText: "−"; tooltipText: "Lower priority"; foreground: root.foreground; fontFamily: root.fontFamily; focusable: true; onClicked: root.niceValue = Math.min(19, root.niceValue + 1) }
          Text { text: "nice " + root.niceValue; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
          PanelActionButton { iconText: "󰄬"; tooltipText: "Apply nice value"; foreground: root.foreground; fontFamily: root.fontFamily; focusable: true; enabled: !!root.selectedProcess && root.niceValue !== root.selectedProcess.nice; onClicked: root.act("renice") }
        }

        Text {
          width: parent.width
          visible: processService && processService.message !== ""
          text: processService ? processService.message : ""
          textFormat: Text.PlainText
          color: processService && processService.lastActionOk ? root.dim : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "TERM ASKS A PROCESS TO EXIT · KILL REQUIRES A SECOND CLICK · ONLY YOUR PROCESSES ARE LISTED"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.7
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
