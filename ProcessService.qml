import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var processes: []
  property bool initialized: false
  property bool busy: false
  property bool active: false
  property string message: ""
  property bool lastActionOk: true
  property var pendingAction: null
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.chavez62.process-manager/processctl"

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function setActive(value) {
    active = value
    if (active) refresh()
  }

  function action(kind, pid, startTime, value) {
    if (actionProc.running) return
    busy = true
    message = ""
    pendingAction = { kind: kind, pid: pid, value: value }
    var args = [helper, kind, String(pid), String(startTime)]
    if (kind === "renice") args.push(String(value))
    actionProc.command = args
    actionProc.running = true
  }

  function applySnapshot(raw) {
    try {
      var result = JSON.parse(raw)
      if (result.ok) {
        processes = result.processes || []
        initialized = true
      }
    } catch (error) {
      message = "Could not read process list"
      lastActionOk = false
    }
  }

  function applyAction(raw) {
    try {
      var result = JSON.parse(raw)
      lastActionOk = result.ok === true
      message = result.message || (lastActionOk ? "Action completed" : "Action failed")
    } catch (error) {
      lastActionOk = false
      message = "Action failed"
    }
    busy = false
    pendingAction = null
    refresh()
  }

  Component.onCompleted: refresh()

  Process {
    id: listProc
    command: [root.helper, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      id: actionOutput
      waitForEnd: true
      onStreamFinished: root.applyAction(text)
    }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onRunningChanged: if (!running && root.busy && actionOutput.text === "") {
      root.lastActionOk = false
      root.message = actionError.text.trim() || "Action failed"
      root.busy = false
      root.pendingAction = null
      root.refresh()
    }
  }

  Timer {
    interval: 2500
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }
}
