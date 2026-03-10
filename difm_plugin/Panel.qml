import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

// Panel.qml — DI.FM player panel
// Header: now-playing info + play/stop + volume slider
// Body: searchable channel list
Item {
    id: root

    // ── Plugin API ─────────────────────────────────────────────────────────
    property var pluginApi: null

    // ── SmartPanel required properties ────────────────────────────────────
    readonly property var  geometryPlaceholder: panelContainer
    readonly property bool allowAttach:         true

    property real contentPreferredWidth:  500 * Style.uiScaleRatio
    property real contentPreferredHeight: 620 * Style.uiScaleRatio

    anchors.fill: parent

    // ── Convenience accessors ──────────────────────────────────────────────
    readonly property var    main:          pluginApi?.mainInstance
    readonly property bool   isPlaying:     main?.isPlaying        ?? false
    readonly property string channelName:   main?.currentChannelName || ""
    readonly property string nowPlaying:    main?.nowPlayingText    || ""
    readonly property var    channels:      main?.channels          ?? []
    readonly property bool   channelsLoaded: main?.channelsLoaded   ?? false
    readonly property bool   notConfigured: !(pluginApi?.pluginSettings?.listenKey)

    // ── Local UI state ────────────────────────────────────────────────────
    property string searchText:  ""
    property int    localVolume: main?.volume ?? (pluginApi?.pluginSettings?.volume ?? 80)

    // Filtered channels based on search query
    readonly property var filteredChannels: {
        var q = root.searchText.toLowerCase().trim()
        if (!q || !root.channels) return root.channels || []
        return root.channels.filter(function(ch) {
            return ch.name.toLowerCase().indexOf(q) >= 0 ||
                   ch.key.toLowerCase().indexOf(q) >= 0
        })
    }

    // Sync local volume when Main changes it externally
    onMainChanged: {
        if (main) root.localVolume = main.volume
    }

    // ── Root panel container ───────────────────────────────────────────────
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill:    parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // ── Header ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                // DI.FM branding
                Rectangle {
                    width:  36
                    height: 36
                    radius: Style.radiusM
                    color:  Color.mPrimary

                    NText {
                        anchors.centerIn: parent
                        text:       "DI"
                        color:      Color.mOnPrimary
                        pointSize:  Style.fontSizeM
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    NText {
                        text: root.isPlaying
                            ? root.channelName
                            : (root.channelsLoaded ? "DI.FM" : "Loading channels…")
                        color:      Color.mOnSurface
                        pointSize:  Style.fontSizeM
                        font.weight: Font.Bold
                        elide:      Text.ElideRight
                        Layout.fillWidth: true
                    }

                    NText {
                        visible:   root.isPlaying && root.nowPlaying !== ""
                        text:      root.nowPlaying
                        color:     Color.mPrimary
                        pointSize: Style.fontSizeS
                        elide:     Text.ElideRight
                        Layout.fillWidth: true
                    }

                    NText {
                        visible:   !root.isPlaying && !root.channelsLoaded && !(main?.channelsLoading ?? false)
                        text:      root.notConfigured
                            ? "Set your Listen Key in plugin settings"
                            : "No channels loaded"
                        color:     root.notConfigured ? Color.mError : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        wrapMode:  Text.WordWrap
                        Layout.fillWidth: true
                    }

                    NText {
                        visible:   !root.isPlaying && root.channelsLoaded && root.channelName !== ""
                        text:      "Last: " + root.channelName
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        elide:     Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Play / Stop button
                NButton {
                    text:        root.isPlaying ? "Stop" : ""
                    highlighted: root.isPlaying

                    NIcon {
                        anchors.centerIn: parent
                        visible:   !root.isPlaying
                        icon:      "player-play"
                        color:     Color.mOnSurface
                        pointSize: Style.fontSizeM
                    }

                    implicitWidth:  44
                    implicitHeight: 36

                    onClicked: {
                        if (root.isPlaying) {
                            root.main?.stop()
                        } else if (root.main?.lastChannel) {
                            root.main?.playChannel(
                                root.main.currentChannelKey  || pluginApi.pluginSettings.lastChannel,
                                root.main.currentChannelName || pluginApi.pluginSettings.lastChannelName
                            )
                        }
                    }

                    enabled: root.isPlaying || (root.channelsLoaded &&
                             (root.main?.currentChannelKey || "") !== "")
                }
            }

            // ── Volume row ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon:      root.localVolume === 0 ? "volume-off" : "volume"
                    color:     Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeM
                }

                NSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from:      0
                    to:        100
                    stepSize:  5
                    value:     root.localVolume

                    onValueChanged: {
                        if (Math.abs(value - root.localVolume) > 0) {
                            root.localVolume = value
                        }
                    }

                    // Apply on release to avoid spamming restarts during drag
                    onPressedChanged: {
                        if (!pressed) {
                            root.main?.setVolume(root.localVolume)
                        }
                    }
                }

                NText {
                    text:      root.localVolume + "%"
                    color:     Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    Layout.minimumWidth: 34
                }
            }

            NDivider { Layout.fillWidth: true }

            // ── Not-configured banner ──────────────────────────────────────
            Rectangle {
                visible:      root.notConfigured
                Layout.fillWidth: true
                height:       52
                color:        Color.mErrorContainer
                radius:       Style.radiusM

                RowLayout {
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginS

                    NIcon { icon: "alert-circle"; color: Color.mOnErrorContainer; pointSize: Style.fontSizeM }

                    NText {
                        text:       "Add your DI.FM Listen Key in Settings to stream premium quality."
                        color:      Color.mOnErrorContainer
                        pointSize:  Style.fontSizeS
                        wrapMode:   Text.WordWrap
                        Layout.fillWidth: true
                    }

                    NButton {
                        text: "Settings"
                        onClicked: {
                            pluginApi?.closePanel(pluginApi.panelOpenScreen)
                            BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest)
                        }
                    }
                }
            }

            // ── Search ─────────────────────────────────────────────────────
            NTextInput {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Search channels…"
                icon:            "search"
                text:            root.searchText
                onTextChanged:   root.searchText = text
                visible:         root.channelsLoaded
            }

            // ── Channel list ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                color:    Color.mSurfaceVariant
                radius:   Style.radiusL
                clip:     true

                // Loading state
                ColumnLayout {
                    visible:  !root.channelsLoaded
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon:      "loader"
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXL

                        RotationAnimation on rotation {
                            running:  !root.channelsLoaded
                            from:     0; to: 360
                            duration: 1200
                            loops:    Animation.Infinite
                        }
                    }

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text:      root.notConfigured
                            ? "Enter your Listen Key in Settings\nto load channels."
                            : "Loading channels…"
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                // Empty search state
                NText {
                    visible:  root.channelsLoaded && root.filteredChannels.length === 0
                    anchors.centerIn: parent
                    text:      "No channels match "" + root.searchText + """
                    color:     Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }

                // Channel list
                NScrollView {
                    anchors.fill:    parent
                    anchors.margins: Style.marginS
                    visible:  root.channelsLoaded && root.filteredChannels.length > 0

                    ListView {
                        id: channelList
                        model:   root.filteredChannels
                        spacing: Style.marginXS

                        delegate: ChannelDelegate {
                            width:         channelList.width
                            channelData:   modelData
                            isActive:      modelData.key === (root.main?.currentChannelKey || "")
                            isPlayingThis: root.isPlaying && isActive
                            onPlayRequested: function(key, name) {
                                root.main?.playChannel(key, name)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Inline channel delegate component ─────────────────────────────────
    component ChannelDelegate: Rectangle {
        id: delegate

        property var    channelData:   ({})
        property bool   isActive:      false
        property bool   isPlayingThis: false
        signal playRequested(string key, string name)

        height: 52
        color: {
            if (isActive)               return Color.mSecondaryContainer
            if (delegateMouse.containsMouse) return Color.mSurface
            return "transparent"
        }
        radius: Style.radiusM

        RowLayout {
            anchors { fill: parent; leftMargin: Style.marginM; rightMargin: Style.marginM }
            spacing: Style.marginM

            // Channel colour swatch (deterministic from channel key)
            Rectangle {
                width:  6
                height: 32
                radius: 3
                color: {
                    // Generate a hue from the channel key string
                    var key = delegate.channelData.key || ""
                    var h = 0
                    for (var i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) & 0xFFFFFF
                    return Qt.hsva((h % 360) / 360, 0.7, 0.85, 1)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                NText {
                    text:       delegate.channelData.name || ""
                    color:      delegate.isActive ? Color.mOnSecondaryContainer : Color.mOnSurface
                    pointSize:  Style.fontSizeS
                    font.weight: delegate.isActive ? Font.Medium : Font.Normal
                    elide:      Text.ElideRight
                    Layout.fillWidth: true
                }

                NText {
                    visible:   !delegate.isPlayingThis && (delegate.channelData.description || "") !== ""
                    text:      delegate.channelData.description || ""
                    color:     delegate.isActive ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    elide:     Text.ElideRight
                    Layout.fillWidth: true
                }

                // Show now-playing for the active channel
                NText {
                    visible:   delegate.isPlayingThis && root.nowPlaying !== ""
                    text:      "▶  " + root.nowPlaying
                    color:     Color.mPrimary
                    pointSize: Style.fontSizeXS
                    elide:     Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Play indicator / play button
            NIcon {
                visible:   delegate.isPlayingThis
                icon:      "player-play"
                color:     Color.mPrimary
                pointSize: Style.fontSizeM
            }

            NIcon {
                visible:   !delegate.isPlayingThis && delegateMouse.containsMouse
                icon:      "player-play"
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeM
            }
        }

        MouseArea {
            id: delegateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                delegate.playRequested(delegate.channelData.key, delegate.channelData.name)
            }
        }
    }

    Component.onCompleted: Logger.i("DIFM", "Panel opened")
}
