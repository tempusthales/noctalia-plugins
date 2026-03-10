import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property string editListenKey: pluginApi?.pluginSettings?.listenKey || ""
    property string editQuality:   pluginApi?.pluginSettings?.quality   || "premium_high"
    property int    editVolume:    pluginApi?.pluginSettings?.volume     ?? 80

    spacing: Style.marginM

    NTextInput {
        Layout.fillWidth: true
        label:           "Listen Key"
        description:     "Your DI.FM Listen Key from di.fm/settings"
        placeholderText: "e.g. abc123def456abc123"
        text:            root.editListenKey
        onTextChanged:   root.editListenKey = text
    }

    NDivider { Layout.fillWidth: true }

    NText {
        text:        "Stream Quality"
        color:       Color.mOnSurface
        pointSize:   Style.fontSizeS
        font.weight: Font.Medium
    }

    NToggle {
        Layout.fillWidth: true
        label:       "Use Free Streams (40 kbps)"
        description: "Disable to use Premium streams (128/320 kbps)"
        checked:     root.editQuality === "public3"
        onCheckedChanged: root.editQuality = checked ? "public3" : "premium_high"
    }

    NDivider { Layout.fillWidth: true }

    NText {
        text:        "Default Volume: " + root.editVolume + "%"
        color:       Color.mOnSurface
        pointSize:   Style.fontSizeS
        font.weight: Font.Medium
    }

    NSlider {
        Layout.fillWidth: true
        from:      0
        to:        100
        stepSize:  5
        value:     root.editVolume
        onValueChanged: root.editVolume = value
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.listenKey = root.editListenKey.trim()
        pluginApi.pluginSettings.quality   = root.editQuality
        pluginApi.pluginSettings.volume    = root.editVolume
        pluginApi.saveSettings()
        Logger.i("DIFM", "Settings saved")
    }

    Component.onCompleted: Logger.i("DIFM", "Settings UI loaded")
}