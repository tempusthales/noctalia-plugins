import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: delegate
    property var    channelData:   ({})
    property bool   isActive:      false
    property bool   isPlayingThis: false
    property string nowPlaying:    ""
    signal playRequested(string key, string name)
    height: 52
    color: {
        if (isActive)                    return Color.mSurfaceVariant
        if (delegateMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.05)
        return "transparent"
    }
    radius: Style.radiusM
    RowLayout {
        anchors { fill: parent; leftMargin: Style.marginM; rightMargin: Style.marginM }
        spacing: Style.marginM
        Rectangle {
            width:  6
            height: 32
            radius: 3
            color: {
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
                text:        delegate.channelData.name || ""
                color:       delegate.isActive ? Color.mOnSurfaceVariant : Color.mOnSurfaceVariant
                pointSize:   Style.fontSizeS
                font.weight: delegate.isActive ? Font.Medium : Font.Normal
                elide:       Text.ElideRight
                Layout.fillWidth: true
            }
            NText {
                visible:   !delegate.isPlayingThis && (delegate.channelData.description || "") !== ""
                text:      delegate.channelData.description || ""
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                elide:     Text.ElideRight
                Layout.fillWidth: true
            }
            NText {
                visible:   delegate.isPlayingThis && delegate.nowPlaying !== ""
                text:      "▶  " + delegate.nowPlaying
                color:     Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                elide:     Text.ElideRight
                Layout.fillWidth: true
            }
        }
        NIcon {
            visible:   delegate.isPlayingThis
            icon:      "player-play"
            color:     Color.mOnSurfaceVariant
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
        id:           delegateMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    delegate.playRequested(delegate.channelData.key, delegate.channelData.name)
    }
}