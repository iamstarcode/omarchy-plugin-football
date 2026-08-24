import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// iamstarcode.football — livescore-style popover. One day at a time, grouped
// by competition, with ‹ › arrows and a day strip to move between dates.
// Refreshes every 60s from ESPN via football.py.
Panel {
  id: root
  moduleName: "iamstarcode.football"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // ---- data ----------------------------------------------------------------
  property var groups: []
  property var displayRows: []
  property string errorMessage: ""
  property string updatedAt: ""
  property string selectedDate: Model.todayIso()

  readonly property bool liveNow: Model.liveRow(groups) !== null
  readonly property string tooltipLabel: Model.tooltipLabel(groups)
  readonly property string helperPath: Qt.resolvedUrl("football.py").toString().replace("file://", "")
  readonly property bool viewingToday: selectedDate === Model.todayIso()

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  function applyPayload(raw) {
    var payload = {}
    try { payload = JSON.parse(String(raw || "{}")) } catch (e) { payload = {} }
    if (payload.error) {
      root.errorMessage = String(payload.error)
      return
    }
    root.errorMessage = ""
    root.groups = Model.parseGroups(payload)
    root.displayRows = Model.buildDisplayRows(root.groups)
    root.updatedAt = String(payload.updated || "").substring(11, 16)
  }

  function selectDate(iso) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(iso) || iso === root.selectedDate) return
    root.selectedDate = iso
    root.refresh()
  }

  function shiftDate(days) {
    root.selectDate(Model.addDays(root.selectedDate, days))
  }

  function openMatch(row) {
    if (row && row.url) Quickshell.execDetached(["xdg-open", row.url])
  }

  Component.onCompleted: Qt.callLater(root.refresh)

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProc
    command: ["python3", root.helperPath, root.selectedDate]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPayload(text)
    }
  }

  // ---- UI --------------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(scroll.contentHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    Flickable {
      id: scroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: contentColumn
        width: scroll.width
        spacing: Style.space(8)

        // Header
        Row {
          width: parent.width
          spacing: Style.space(6)

          Column {
            width: parent.width - panelActions.width - parent.spacing
            spacing: 1
            Text {
              text: "FOOTBALL · " + Model.dayLabel(root.selectedDate, new Date()).toUpperCase()
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              text: root.updatedAt !== "" ? "ESPN · updated " + root.updatedAt : "ESPN"
              color: Util.alpha(root.barForeground, 0.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: 9
            }
          }

          Row {
            id: panelActions
            spacing: Style.space(3)
            Button {
              iconText: "↻"
              foreground: root.barForeground
              tooltipText: "Refresh now"
              onClicked: root.refresh()
            }
            Button {
              iconText: "×"
              foreground: root.barForeground
              tooltipText: "Close"
              onClicked: root.close()
            }
          }
        }

        // Date navigation: ‹ [strip] › Today
        Row {
          width: parent.width
          spacing: Style.space(3)

          Button {
            iconText: "‹"
            foreground: root.barForeground
            tooltipText: "Previous day"
            onClicked: root.shiftDate(-1)
          }

          Row {
            id: strip
            spacing: Style.space(2)

            Repeater {
              model: 7

              delegate: Button {
                required property int index
                readonly property string chipDate: Model.addDays(root.selectedDate, index - 3)

                text: Model.chipLabel(chipDate, new Date())
                fontSize: Style.font.caption
                selected: index === 3
                active: index === 3
                bordered: true
                foreground: root.barForeground
                accent: Color.accent
                onClicked: root.selectDate(chipDate)
              }
            }
          }

          Button {
            iconText: "›"
            foreground: root.barForeground
            tooltipText: "Next day"
            onClicked: root.shiftDate(1)
          }

          Button {
            text: "Today"
            fontSize: Style.font.caption
            selected: root.viewingToday
            active: root.viewingToday
            bordered: true
            foreground: root.barForeground
            accent: Color.accent
            visible: !root.viewingToday
            onClicked: root.selectDate(Model.todayIso())
          }
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.accent, 0.4) }

        // Matches grouped by competition
        Repeater {
          model: root.displayRows

          delegate: Item {
            required property var modelData
            width: contentColumn.width
            height: modelData.type === "league" ? leagueLabel.implicitHeight
                  : modelData.type === "match" ? matchRow.height : 0

            Text {
              id: leagueLabel
              visible: modelData.type === "league"
              text: modelData.label.toUpperCase()
              color: modelData.live ? Color.accent : Util.alpha(root.barForeground, 0.55)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: 10
              font.bold: true
              font.letterSpacing: 0.8
            }

            Rectangle {
              id: matchRow
              visible: modelData.type === "match"
              width: parent.width
              height: 34
              radius: Style.cornerRadius
              color: matchArea.containsMouse ? Util.alpha(root.barForeground, 0.07) : "transparent"

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(4)

                Text {
                  width: 52
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.status === "NS" ? modelData.row.time : modelData.row.statusDetail
                  color: modelData.row.status === "LIVE" ? Color.accent : Util.alpha(root.barForeground, 0.55)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 10
                  font.bold: modelData.row.status === "LIVE"
                  horizontalAlignment: Text.AlignLeft
                  elide: Text.ElideRight
                }

                Text {
                  width: (parent.width - 52 - 64 - parent.spacing * 3) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.home
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 12
                  font.bold: modelData.row.status === "LIVE"
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                }

                Text {
                  width: 64
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.status === "NS" ? "vs" : modelData.row.homeScore + " - " + modelData.row.awayScore
                  color: modelData.row.status === "NS" ? Util.alpha(root.barForeground, 0.5) : Color.accent
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 13
                  font.bold: modelData.row.status !== "NS"
                  horizontalAlignment: Text.AlignHCenter
                }

                Text {
                  width: (parent.width - 52 - 64 - parent.spacing * 3) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.away
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 12
                  font.bold: modelData.row.status === "LIVE"
                  horizontalAlignment: Text.AlignLeft
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: matchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: modelData.type === "match" && modelData.row.url !== ""
                onClicked: root.openMatch(modelData.row)
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.groups.length === 0
          text: root.errorMessage !== "" ? root.errorMessage : "No matches on this day."
          color: Util.alpha(root.barForeground, 0.65)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 11
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }
      }
    }
  }
}
