import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Settings.qml — DI.FM plugin settings
// Configures: Listen Key, stream quality, default volume.
ColumnLayout {
    id: root

    // ── Plugin API ─────────────────────────────────────────────────────────
    property var pluginApi: null

    // ── Local state (not written until Save is clicked) ───────────────────
    property string editListenKey: pluginApi?.pluginSettings?.listenKey
        || pluginApi?.manifest?.metadata?.defaultSettings?.listenKey
        || ""

    property string editQuality:   pluginApi?.pluginSettings?.quality
        || pluginApi?.manifest?.metadata?.defaultSettings?.quality
        || "premium_high"

    property int editVolume:       pluginApi?.pluginSettings?.volume
        ?? (pluginApi?.manifest?.metadata?.defaultSettings?.volume ?? 80)

    spacing: Style.marginM

    // ── Listen Key ─────────────────────────────────────────────────────────
    NTextInput {
        Layout.fillWidth: true
        label:           "Listen Key"
        description:     "Your personal DI.FM Listen Key (from di.fm/settings). Required for premium streams."
        placeholderText: "e.g. abc123def456abc123"
        text:            root.editListenKey
        echoMode:        TextInput.Password
        onTextChanged:   root.editListenKey = text
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
            text:      "Find your key at "
            color:     Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        NText {
            text:      "di.fm/settings"
            color:     Color.mPrimary
            pointSize: Style.fontSizeS
            font.underline: true

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    Qt.openUrlExternally("https://www.di.fm/settings")
            }
        }
    }

    NDivider {
        Layout.fillWidth:    true
        Layout.topMargin:    Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Stream quality ──────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label:       "Stream Quality"
            description: "Higher quality requires a DI.FM Premium account."
        }

        NComboBox {
            Layout.fillWidth: true
            model: ["Free (40 kbps AAC)", "Premium (128 kbps AAC)", "Premium High (320 kbps AAC)"]
            currentIndex: {
                if (root.editQuality === "public3")      return 0
                if (root.editQuality === "premium")      return 1
                if (root.editQuality === "premium_high") return 2
                return 2
            }
            onCurrentIndexChanged: {
                var qualities = ["public3", "premium", "premium_high"]
                root.editQuality = qualities[currentIndex]
            }
        }
    }

    NDivider {
        Layout.fillWidth:    true
        Layout.topMargin:    Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Default volume ─────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label:       "Default Volume"
            description: "Starting volume for new streams: " + root.editVolume + "%"
        }

        NSlider {
            Layout.fillWidth: true
            from:      0
            to:        100
            stepSize:  5
            value:     root.editVolume
            onValueChanged: root.editVolume = value
        }
    }

    NDivider {
        Layout.fillWidth:    true
        Layout.topMargin:    Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Info section ───────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        height: infoColumn.implicitHeight + Style.marginM * 2
        color:  Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
            id: infoColumn
            anchors { fill: parent; margins: Style.marginM }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS
                NIcon { icon: "info-circle"; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeM }
                NText { text: "Requirements"; color: Color.mOnSurface; pointSize: Style.fontSizeS; font.weight: Font.Medium }
            }

            NText {
                Layout.fillWidth: true
                text:      "• mpv must be installed (pacman -S mpv)"
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                wrapMode:  Text.WordWrap
            }

            NText {
                Layout.fillWidth: true
                text:      "• A DI.FM account is required. Free accounts access 40 kbps streams only."
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                wrapMode:  Text.WordWrap
            }

            NText {
                Layout.fillWidth: true
                text:      "• Volume changes restart the current stream briefly."
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                wrapMode:  Text.WordWrap
            }
        }
    }

    // ── saveSettings — called by Noctalia when the user clicks Save ────────
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("DIFM", "saveSettings: pluginApi is null")
            return
        }
        pluginApi.pluginSettings.listenKey = root.editListenKey.trim()
        pluginApi.pluginSettings.quality   = root.editQuality
        pluginApi.pluginSettings.volume    = root.editVolume
        pluginApi.saveSettings()
        Logger.i("DIFM", "Settings saved. quality:", root.editQuality,
                 "hasKey:", root.editListenKey.trim() !== "")
    }

    Component.onCompleted: Logger.i("DIFM", "Settings UI loaded")
}
