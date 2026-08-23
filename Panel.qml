import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// iamstarcode.football — scores popover. Anchored to the bar chip by
// KeyboardPanel; lists today's matches plus the week ahead for the selected
// league, refreshing every 60s from ESPN via football.py.
Panel {
  id: root
  moduleName: "iamstarcode.football"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // ---- data ----------------------------------------------------------------
  property var rows: []
  property var displayRows: []
  property string errorMessage: ""
  property string updatedAt: ""
  property string leagueCode: "eng.1"
  property int leagueIndex: 0

  readonly property bool liveNow: Model.liveRow(rows) !== null
  readonly property string tooltipLabel: Model.tooltipLabel(rows)
  readonly property string helperPath: Qt.resolvedUrl("football.py").toString().replace("file://", "")

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
    root.rows = Model.sortRows(Model.parseEvents(payload))
    root.displayRows = Model.buildDisplayRows(root.rows, new Date())
    root.updatedAt = String(payload.updated || "").substring(11, 16)
  }

  function selectLeague(index) {
    if (index < 0 || index >= Model.LEAGUES.length || index === root.leagueIndex) return
    root.leagueIndex = index
    root.leagueCode = Model.LEAGUES[index].code
    writeConfig()
    root.refresh()
  }

  function writeConfig() {
    configFile.setText(JSON.stringify({ league: root.leagueCode }, null, 2) + "\n")
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
    command: ["python3", root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPayload(text)
    }
  }

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/iamstarcode.football.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || "{}"))
        var code = parsed && parsed.league ? String(parsed.league) : "eng.1"
        if (code === root.leagueCode) return
        var index = -1
        for (var i = 0; i < Model.LEAGUES.length; i++)
          if (Model.LEAGUES[i].code === code) { index = i; break }
        root.leagueIndex = index >= 0 ? index : 0
        root.leagueCode = Model.LEAGUES[root.leagueIndex].code
        root.refresh()
      } catch (e) {}
    }
    onLoadFailed: {
      root.leagueIndex = 0
      root.leagueCode = "eng.1"
      writeConfig()
      root.refresh()
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
              text: "FOOTBALL · " + Model.leagueLabel(root.leagueCode).toUpperCase()
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

        Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.accent, 0.4) }

        // League picker
        Flow {
          width: parent.width
          spacing: Style.space(3)
          Repeater {
            model: Model.LEAGUES
            delegate: Button {
              required property var modelData
              required property int index
              text: modelData.label
              fontSize: Style.font.caption
              selected: root.leagueIndex === index
              active: root.leagueIndex === index
              bordered: true
              foreground: root.barForeground
              accent: Color.accent
              onClicked: root.selectLeague(index)
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.barForeground, 0.18) }

        // Matches
        Repeater {
          model: root.displayRows

          delegate: Item {
            required property var modelData
            width: contentColumn.width
            height: modelData.type === "day" ? dayLabel.implicitHeight : matchRow.height

            Text {
              id: dayLabel
              visible: modelData.type === "day"
              text: modelData.label
              color: Util.alpha(root.barForeground, 0.55)
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
          visible: root.rows.length === 0
          text: root.errorMessage !== "" ? root.errorMessage : "No matches in the next 7 days."
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
