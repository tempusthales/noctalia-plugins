import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    readonly property string listenKey:       pluginApi?.pluginSettings?.listenKey       || ""
    readonly property string quality:         pluginApi?.pluginSettings?.quality         || "premium_high"
    readonly property int    savedVolume:     pluginApi?.pluginSettings?.volume          ?? 80
    readonly property string lastChannel:     pluginApi?.pluginSettings?.lastChannel     || ""
    readonly property string lastChannelName: pluginApi?.pluginSettings?.lastChannelName || ""

    property var    channels:           []
    property bool   channelsLoaded:     false
    property bool   channelsLoading:    false

    property string currentChannelKey:  ""
    property string currentChannelName: ""
    property int    currentChannelId:   -1

    property string currentTrackTitle:  ""
    property string currentArtist:      ""
    property string nowPlayingText:     ""

    property bool   isPlaying:          false
    property int    volume:             80

    property string _streamUrl: ""

    Process {
        id: mpvProcess
        running: false
        onRunningChanged: {
            if (!running && root.isPlaying) {
                root.isPlaying = false
                Logger.w("DIFM", "mpv process stopped unexpectedly")
            }
        }
    }

    Timer {
        id: nowPlayingTimer
        interval: 45000
        repeat:   true
        running:  root.isPlaying && root.currentChannelId >= 0
        onTriggered: root.fetchNowPlaying()
    }

    Timer {
        id: nowPlayingDelayTimer
        interval: 3000
        repeat:   false
        running:  false
        onTriggered: root.fetchNowPlaying()
    }

    Component.onCompleted: {
        root.volume = root.savedVolume
        root.currentChannelKey  = root.lastChannel
        root.currentChannelName = root.lastChannelName
        Logger.i("DIFM", "Plugin loaded. quality:", root.quality,
                 "hasKey:", root.listenKey !== "")
        root.loadChannels()
    }

    onListenKeyChanged: {
        if (root.listenKey) root.loadChannels()
    }
    onQualityChanged: {
        root.loadChannels()
    }

    function loadChannels() {
        if (root.channelsLoading) return

        var qualityPath = root.quality
        if (!root.listenKey) qualityPath = "public3"

        var url = "https://listen.di.fm/" + qualityPath + ".json"
        Logger.i("DIFM", "Loading channels from:", url)

        root.channelsLoading = true
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.channelsLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    root.channels = data
                    root.channelsLoaded = true
                    Logger.i("DIFM", "Loaded", data.length, "channels")
                } catch (e) {
                    Logger.e("DIFM", "Failed to parse channels JSON:", e)
                }
            } else {
                Logger.w("DIFM", "Channel fetch failed, status:", xhr.status)
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function playChannel(channelKey, channelName) {
        var ch = null
        for (var i = 0; i < root.channels.length; i++) {
            if (root.channels[i].key === channelKey) {
                ch = root.channels[i]
                break
            }
        }
        if (!ch) {
            Logger.w("DIFM", "Channel not found:", channelKey)
            return
        }
        if (!ch.playlist) {
            Logger.w("DIFM", "No playlist URL for channel:", channelKey)
            return
        }

        var streamUrl = ch.playlist
        if (root.listenKey) streamUrl += "?listen_key=" + root.listenKey

        if (mpvProcess.running) {
            mpvProcess.running = false
        }

        root.currentChannelKey  = channelKey
        root.currentChannelName = channelName
        root.currentChannelId   = ch.id || -1
        root.currentTrackTitle  = ""
        root.currentArtist      = ""
        root.nowPlayingText     = ""
        root._streamUrl         = streamUrl

        // Debug: capture mpv output to log file
        mpvProcess.command = [
            "bash", "-c",
            "mpv --no-video --ao=pipewire --quiet --really-quiet --volume=" + root.volume + " '" + streamUrl + "' > /tmp/mpv-difm.log 2>&1"
        ]
        mpvProcess.running = true
        root.isPlaying = true

        pluginApi.pluginSettings.lastChannel     = channelKey
        pluginApi.pluginSettings.lastChannelName = channelName
        pluginApi.saveSettings()

        Logger.i("DIFM", "Playing:", channelName, "→", streamUrl)
        nowPlayingDelayTimer.restart()
    }

    function stop() {
        if (mpvProcess.running) {
            mpvProcess.running = false
        }
        root.isPlaying = false
        root.currentTrackTitle = ""
        root.currentArtist     = ""
        root.nowPlayingText    = ""
        Logger.i("DIFM", "Stopped")
    }

    function setVolume(newVolume) {
        root.volume = newVolume
        pluginApi.pluginSettings.volume = newVolume
        pluginApi.saveSettings()
        if (root.isPlaying && root._streamUrl !== "") {
            root.playChannel(root.currentChannelKey, root.currentChannelName)
        }
    }

    function fetchNowPlaying() {
        if (root.currentChannelId < 0) return
        var url = "https://api.audioaddict.com/v1/di/track_history/channel/" + root.currentChannelId
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data && data.length > 0 && data[0].track) {
                        var track = data[0].track
                        root.currentTrackTitle = track.title        || ""
                        root.currentArtist     = track.artist_title || ""
                        root.nowPlayingText    = root.currentArtist
                            ? root.currentArtist + " — " + root.currentTrackTitle
                            : root.currentTrackTitle
                        Logger.i("DIFM", "Now playing:", root.nowPlayingText)
                    }
                } catch (e) {
                    Logger.w("DIFM", "Failed to parse track history:", e)
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }
}