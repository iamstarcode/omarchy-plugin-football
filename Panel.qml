import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// iamstarcode.football — livescore-style popover. One day at a time, grouped
// by competition in card blocks, with ‹ › arrows and a day strip to move
// between dates. Refreshes every 60s from ESPN via football.py.
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
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

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
    contentWidth: panel.fittedContentWidth(Style.space(460))
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
        spacing: Style.space(10)

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
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              text: root.updatedAt !== "" ? "ESPN · updated " + root.updatedAt : "ESPN"
              color: Util.alpha(root.barForeground, 0.5)
              font.family: root.fontFamily
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
            spacing: Style.space(2)

            Repeater {
              model: 5

              delegate: Button {
                required property int index
                readonly property string chipDate: Model.addDays(root.selectedDate, index - 2)

                text: Model.chipLabel(chipDate, new Date())
                fontSize: Style.font.caption
                selected: index === 2
                active: index === 2
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

        // Competition blocks
        Repeater {
          model: root.displayRows

          delegate: Item {
            required property var modelData
            width: contentColumn.width
            height: modelData.type === "league" ? leagueHeader.height
                  : modelData.type === "match" ? matchRow.height : 0

            // ---- competition header card ----
            Rectangle {
              id: leagueHeader
              visible: modelData.type === "league"
              width: parent.width
              height: 30
              radius: Style.cornerRadius
              color: Util.alpha(root.barForeground, 0.09)

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height
                radius: 2
                color: modelData.live ? Color.accent : Util.alpha(Color.accent, 0.35)
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label.toUpperCase()
                color: root.barForeground
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
                width: parent.width - Style.space(8) - liveBadge.width - liveBadgeDot.width
              }

              Rectangle {
                id: liveBadgeDot
                visible: modelData.live
                anchors.right: liveBadge.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Color.accent
              }

              Text {
                id: liveBadge
                visible: modelData.live
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                text: "LIVE"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
              }
            }

            // ---- match row ----
            Rectangle {
              id: matchRow
              visible: modelData.type === "match"
              width: parent.width
              height: 36
              radius: Style.cornerRadius
              color: matchArea.containsMouse ? Util.alpha(root.barForeground, 0.07)
                   : modelData.alt ? Util.alpha(root.barForeground, 0.03) : "transparent"

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(4)

                // status: kick-off time / live detail / FT
                Text {
                  width: 48
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.status === "NS" ? modelData.row.time : modelData.row.statusDetail
                  color: modelData.row.status === "LIVE" ? Color.accent
                       : modelData.row.status === "FT" ? Util.alpha(root.barForeground, 0.4)
                       : Util.alpha(root.barForeground, 0.55)
                  font.family: root.fontFamily
                  font.pixelSize: 10
                  font.bold: modelData.row.status === "LIVE"
                  horizontalAlignment: Text.AlignLeft
                  elide: Text.ElideRight
                }

                Text {
                  width: (parent.width - 48 - 72 - parent.spacing * 3) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.home
                  color: modelData.row.status === "FT" ? Util.alpha(root.barForeground, 0.65) : root.barForeground
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  font.bold: modelData.row.status === "LIVE"
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                }

                // score chip
                Rectangle {
                  width: 72
                  height: 24
                  anchors.verticalCenter: parent.verticalCenter
                  radius: Style.cornerRadius
                  color: modelData.row.status === "NS" ? "transparent"
                       : modelData.row.status === "LIVE" ? Util.alpha(Color.accent, 0.14)
                       : Util.alpha(root.barForeground, 0.06)

                  border.width: 1
                  border.color: modelData.row.status === "LIVE" ? Util.alpha(Color.accent, 0.5) : "transparent"

                  Text {
                    anchors.fill: parent
                    text: modelData.row.status === "NS" ? "vs" : modelData.row.homeScore + " - " + modelData.row.awayScore
                    color: modelData.row.status === "LIVE" ? Color.accent
                         : modelData.row.status === "FT" ? Util.alpha(root.barForeground, 0.65)
                         : Util.alpha(root.barForeground, 0.5)
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: modelData.row.status === "LIVE"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                }

                Text {
                  width: (parent.width - 48 - 72 - parent.spacing * 3) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.row.away
                  color: modelData.row.status === "FT" ? Util.alpha(root.barForeground, 0.65) : root.barForeground
                  font.family: root.fontFamily
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
          font.family: root.fontFamily
          font.pixelSize: 11
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }
      }
    }
  }
}
