import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

// BarWidget.qml — DI.FM bar widget
// Shows the DI.FM radio icon, current channel, and now-playing track.
// Click opens the DI.FM panel.  Right-click shows a context menu.
Item {
    id: root

    // ── Required plugin properties ─────────────────────────────────────────
    property var         pluginApi: null
    property ShellScreen screen
    property string      widgetId: ""
    property string      section:  ""

    // ── Per-screen sizing ──────────────────────────────────────────────────
    readonly property string screenName:   screen?.name ?? ""
    readonly property string barPosition:  Settings.getBarPositionForScreen(screenName)
    readonly property bool   isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real   capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real   barFontSize:   Style.getBarFontSizeForScreen(screenName)

    // ── State from Main.qml ───────────────────────────────────────────────
    readonly property var    main:            pluginApi?.mainInstance
    readonly property bool   isPlaying:       main?.isPlaying        ?? false
    readonly property string channelName:     main?.currentChannelName || "DI.FM"
    readonly property string nowPlaying:      main?.nowPlayingText    || ""
    readonly property bool   notConfigured:   !(pluginApi?.pluginSettings?.listenKey)

    // ── Content sizing ────────────────────────────────────────────────────
    readonly property real contentWidth: {
        var base = rowContent.implicitWidth + Style.marginM * 2
        // Cap width so it doesn't eat up too much bar space
        return Math.min(base, 340)
    }
    readonly property real contentHeight: capsuleHeight

    implicitWidth:  contentWidth
    implicitHeight: contentHeight

    // ── Visual capsule ────────────────────────────────────────────────────
    Rectangle {
        id: visualCapsule

        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)

        width:  root.contentWidth
        height: root.contentHeight

        color:        mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius:       Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        clip: true

        RowLayout {
            id: rowContent
            anchors.centerIn: parent
            spacing: Style.marginS

            // Radio icon — pulses accent color while playing
            NIcon {
                id:        radioIcon
                icon:      "radio"
                pointSize: root.barFontSize + 1
                color:     root.isPlaying ? Color.mPrimary : Color.mOnSurfaceVariant

                // Subtle pulse animation when playing
                SequentialAnimation on opacity {
                    running:  root.isPlaying
                    loops:    Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) radioIcon.opacity = 1.0
                }
            }

            // Channel name
            NText {
                id: channelLabel
                text:       root.channelName
                color:      root.isPlaying ? Color.mOnSurface : Color.mOnSurfaceVariant
                pointSize:  root.barFontSize
                font.weight: root.isPlaying ? Font.Medium : Font.Normal
                elide:      Text.ElideRight
                maximumLineCount: 1
                Layout.maximumWidth: 120
            }

            // Separator dot + track info (only when playing with metadata)
            NText {
                visible:   root.isPlaying && root.nowPlaying !== ""
                text:      "·"
                color:     Color.mOnSurfaceVariant
                pointSize: root.barFontSize
            }

            NText {
                visible:    root.isPlaying && root.nowPlaying !== ""
                text:       root.nowPlaying
                color:      Color.mOnSurfaceVariant
                pointSize:  root.barFontSize - 0.5
                elide:      Text.ElideRight
                maximumLineCount: 1
                Layout.maximumWidth: 180
            }

            // "Not configured" hint
            NText {
                visible:   root.notConfigured
                text:      "· set listen key"
                color:     Color.mError
                pointSize: root.barFontSize - 0.5
                font.italic: true
            }
        }
    }

    // ── Context menu ───────────────────────────────────────────────────────
    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": root.isPlaying ? "Stop" : "Open Player",
                "action": root.isPlaying ? "stop" : "open",
                "icon":   root.isPlaying ? "player-stop" : "player-play"
            },
            {
                "label": "Settings",
                "action": "settings",
                "icon":   "settings"
            },
            {
                "label": "Open DI.FM",
                "action": "website",
                "icon":   "external-link"
            }
        ]
        onTriggered: function(action) {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "stop") {
                root.main?.stop()
            } else if (action === "open") {
                pluginApi?.openPanel(root.screen, root)
            } else if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest)
            } else if (action === "website") {
                Qt.openUrlExternally("https://www.di.fm")
            }
        }
    }

    // ── Mouse area ─────────────────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill:    parent
        hoverEnabled:    true
        cursorShape:     Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                pluginApi?.openPanel(root.screen, root)
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            }
        }

        onEntered: {
            TooltipService.show(
                root,
                root.isPlaying
                    ? "DI.FM — " + root.channelName + (root.nowPlaying ? "\n" + root.nowPlaying : "")
                    : "DI.FM — Click to open player",
                BarService.getTooltipDirection()
            )
        }
        onExited: TooltipService.hide()
    }

    Component.onCompleted: Logger.i("DIFM", "BarWidget loaded on screen:", root.screenName)
}
