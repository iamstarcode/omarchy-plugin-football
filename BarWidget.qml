import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// iamstarcode.football — bar entry point. Shows a soccer-ball glyph chip that lights up while a
// match is live, and loads Panel.qml (the scores popover) internally.
BarWidget {
  id: root
  moduleName: "iamstarcode.football"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property bool liveNow: panelLoader.item
    ? panelLoader.item.liveNow === true
    : false
  readonly property string panelTooltip: panelLoader.item && panelLoader.item.tooltipLabel
    ? panelLoader.item.tooltipLabel
    : "Football Scores"

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    if ("bar" in panelLoader.item) panelLoader.item.bar = root.bar
    if ("settings" in panelLoader.item) panelLoader.item.settings = root.settings
    if ("anchorItem" in panelLoader.item) panelLoader.item.anchorItem = button
    if ("hostWidget" in panelLoader.item) panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: true

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f16ff}"
    fontSize: Style.bar.iconFont
    fixedWidth: Style.bar.iconSlot
    fixedHeight: Style.bar.iconSlot
    labelVisible: true
    tooltipText: root.panelTooltip
    active: root.opened || root.liveNow
    useActiveColor: false

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }
}
