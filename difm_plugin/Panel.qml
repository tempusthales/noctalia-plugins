import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "." as Local

Item {
    id: root

    property var pluginApi: null

    readonly property var  geometryPlaceholder: panelContainer
    readonly property bool allowAttach:         true

    property real contentPreferredWidth:  500 * Style.uiScaleRatio
    property real contentPreferredHeight: 620 * Style.uiScaleRatio

    anchors.fill: parent

    readonly property var    main:          pluginApi?.mainInstance
    readonly property bool   isPlaying:     main?.isPlaying         ?? false
    readonly property string channelName:   main?.currentChannelName || ""
    readonly property string nowPlaying:    main?.nowPlayingText     || ""
    readonly property var    channels:      main?.channels           ?? []
    readonly property bool   notConfigured: !(pluginApi?.pluginSettings?.listenKey)

    property string searchText:       ""
    property int    localVolume:      main?.volume ?? (pluginApi?.pluginSettings?.volume ?? 80)
    property var    filteredChannels: []

    onChannelsChanged:   updateFiltered()
    onSearchTextChanged: updateFiltered()

    function updateFiltered() {
        var q = root.searchText.toLowerCase().trim()
        if (!q || !root.channels || root.channels.length === 0) {
            root.filteredChannels = root.channels || []
            return
        }
        root.filteredChannels = root.channels.filter(function(ch) {
            return ch.name.toLowerCase().indexOf(q) >= 0 ||
                   ch.key.toLowerCase().indexOf(q) >= 0
        })
    }

    onMainChanged: {
        Logger.i("DIFM", "main changed, channels=" + (main?.channels?.length ?? -1))
        if (main) {
            root.localVolume = main.volume
            updateFiltered()
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            // ── Header ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                Rectangle {
                    width:  36
                    height: 36
                    radius: Style.radiusM
                    color:  Color.mPrimary

                    NText {
                        anchors.centerIn: parent
                        text:        "DI"
                        color:       Color.mOnSurface
                        pointSize:   Style.fontSizeM
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    NText {
                        text: root.isPlaying ? root.channelName
                            : root.channels.length > 0 ? "DI.FM"
                            : "Loading channels…"
                        color:       Color.mOnSurface
                        pointSize:   Style.fontSizeM
                        font.weight: Font.Bold
                        elide:       Text.ElideRight
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
                        visible:   !root.isPlaying && root.channels.length === 0
                        text:      root.notConfigured ? "Set your Listen Key in plugin settings" : "No channels loaded"
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        wrapMode:  Text.WordWrap
                        Layout.fillWidth: true
                    }

                    NText {
                        visible:   !root.isPlaying && root.channels.length > 0 && root.channelName !== ""
                        text:      "Last: " + root.channelName
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        elide:     Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

            // ── Playback controls ───────────────────────────────────────
                RowLayout {
                    spacing: Style.marginXS

                    NButton {
                        implicitWidth:  36
                        implicitHeight: 36
                        enabled:        root.channels.length > 0
                        onClicked:      root.main?.playPrev()

                        NIcon {
                            anchors.centerIn: parent
                            icon:      "player-skip-back"
                            color:     Color.mOnSurface
                            pointSize: Style.fontSizeM
                        }
                    }

                    NButton {
                        implicitWidth:  44
                        implicitHeight: 44
                        enabled: root.isPlaying || (root.channels.length > 0 && (root.main?.currentChannelKey || "") !== "")
                        onClicked: {
                            if (root.isPlaying) {
                                root.main?.stop()
                            } else {
                                root.main?.playChannel(
                                    root.main?.currentChannelKey  || pluginApi.pluginSettings.lastChannel,
                                    root.main?.currentChannelName || pluginApi.pluginSettings.lastChannelName
                                )
                            }
                        }

                        NIcon {
                            anchors.centerIn: parent
                            icon:      root.isPlaying ? "player-stop" : "player-play"
                            color:     Color.mOnSurface
                            pointSize: Style.fontSizeL
                        }
                    }

                    NButton {
                        implicitWidth:  36
                        implicitHeight: 36
                        enabled:        root.channels.length > 0
                        onClicked:      root.main?.playNext()

                        NIcon {
                            anchors.centerIn: parent
                            icon:      "player-skip-forward"
                            color:     Color.mOnSurface
                            pointSize: Style.fontSizeM
                        }
                    }
                }

            // ── Volume ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon:      root.localVolume === 0 ? "volume-off" : "volume"
                    color:     Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeM
                }

                NSlider {
                    Layout.fillWidth: true
                    from:      0
                    to:        100
                    stepSize:  5
                    value:     root.localVolume
                    onValueChanged: root.localVolume = value
                    onPressedChanged: {
                        if (!pressed) root.main?.setVolume(root.localVolume)
                    }
                }

                NText {
                    text:                root.localVolume + "%"
                    color:               Color.mOnSurfaceVariant
                    pointSize:           Style.fontSizeS
                    Layout.minimumWidth: 34
                }
            }

            NDivider { Layout.fillWidth: true }

            // ── Not-configured banner ──────────────────────────────────────
            Rectangle {
                visible:          root.notConfigured
                Layout.fillWidth: true
                height:           52
                color:            Color.mSurfaceVariant
                radius:           Style.radiusM

                RowLayout {
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginS

                    NIcon { icon: "alert-circle"; color: Color.mOnSurface; pointSize: Style.fontSizeM }

                    NText {
                        text:             "Add your DI.FM Listen Key in Settings to stream."
                        color:            Color.mOnSurface
                        pointSize:        Style.fontSizeS
                        wrapMode:         Text.WordWrap
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
                Layout.fillWidth: true
                placeholderText:  "Search channels…"
                text:             root.searchText
                onTextChanged:    root.searchText = text
                visible:          root.channels.length > 0
            }

            // ── Channel list ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                color:  Color.mSurfaceVariant
                radius: Style.radiusL
                clip:   true

                ColumnLayout {
                    visible:          root.channels.length === 0
                    anchors.centerIn: parent
                    spacing:          Style.marginM

                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon:      "loader"
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXL

                        RotationAnimation on rotation {
                            running:  root.channels.length === 0
                            from: 0; to: 360
                            duration: 1200
                            loops:    Animation.Infinite
                        }
                    }

                    NText {
                        Layout.alignment:    Qt.AlignHCenter
                        text:      root.notConfigured ? "Enter your Listen Key in Settings\nto load channels." : "Loading channels…"
                        color:     Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode:  Text.WordWrap
                    }
                }

                NText {
                    visible:          root.channels.length > 0 && root.filteredChannels.length === 0
                    anchors.centerIn: parent
                    text:             "No channels match \"" + root.searchText + "\""
                    color:            Color.mOnSurfaceVariant
                    pointSize:        Style.fontSizeS
                }

                ListView {
                    anchors.fill:    parent
                    anchors.margins: Style.marginS
                    visible:         root.filteredChannels.length > 0
                    model:           root.filteredChannels
                    spacing:         2
                    clip:            true

                    delegate: Local.ChannelDelegate {
                        width:         ListView.view.width
                        channelData:   modelData
                        isActive:      modelData.key === (root.main?.currentChannelKey || "")
                        isPlayingThis: root.isPlaying && isActive
                        nowPlaying:    isPlayingThis ? root.nowPlaying : ""
                        onPlayRequested: function(key, name) {
                            root.main?.playChannel(key, name)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: Logger.i("DIFM", "Panel opened, channels=" + root.channels.length)
}