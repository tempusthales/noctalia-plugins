import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Main.qml — Background component
// Manages the mpv player process, channel list, and now-playing metadata.
// All other components access state via pluginApi.mainInstance.
Item {
    id: root

    // ── Plugin API ─────────────────────────────────────────────────────────
    property var pluginApi: null

    // ── Settings helpers ───────────────────────────────────────────────────
    readonly property string listenKey:       pluginApi?.pluginSettings?.listenKey       || ""
    readonly property string quality:         pluginApi?.pluginSettings?.quality         || "premium_high"
    readonly property int    savedVolume:     pluginApi?.pluginSettings?.volume          ?? 80
    readonly property string lastChannel:     pluginApi?.pluginSettings?.lastChannel     || ""
    readonly property string lastChannelName: pluginApi?.pluginSettings?.lastChannelName || ""

    // ── Public state (read by BarWidget + Panel) ───────────────────────────
    property var    channels:           []          // JS array of channel objects
    property bool   channelsLoaded:     false
    property bool   channelsLoading:    false

    property string currentChannelKey:  ""
    property string currentChannelName: ""
    property int    currentChannelId:   -1

    property string currentTrackTitle:  ""
    property string currentArtist:      ""
    property string nowPlayingText:     ""          // "Artist — Title" combined

    property bool   isPlaying:          false
    property int    volume:             80

    // ── Internal: stream URL being played ─────────────────────────────────
    property string _streamUrl: ""

    // ── mpv process ────────────────────────────────────────────────────────
    Process {
        id: mpvProcess
        running: false

        // mpv exits on stream error; mark as not playing
        onRunningChanged: {
            if (!running && root.isPlaying) {
                root.isPlaying = false
                Logger.w("DIFM", "mpv process stopped unexpectedly")
            }
        }
    }

    // ── Now-playing poll (every 45 s while playing) ────────────────────────
    Timer {
        id: nowPlayingTimer
        interval: 45000
        repeat:   true
        running:  root.isPlaying && root.currentChannelId >= 0
        onTriggered: root.fetchNowPlaying()
    }

    // ── Initialization ─────────────────────────────────────────────────────
    Component.onCompleted: {
        root.volume = root.savedVolume
        root.currentChannelKey  = root.lastChannel
        root.currentChannelName = root.lastChannelName
        Logger.i("DIFM", "Plugin loaded. quality:", root.quality,
                 "hasKey:", root.listenKey !== "")
        root.loadChannels()
    }

    // ── Reload channels when settings change ──────────────────────────────
    onListenKeyChanged: {
        if (root.listenKey) root.loadChannels()
    }
    onQualityChanged: {
        root.loadChannels()
    }

    // ── Channel loading ────────────────────────────────────────────────────
    function loadChannels() {
        if (root.channelsLoading) return

        var qualityPath = root.quality
        // Free listeners get public3 (40 kbps), no listen key required
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

    // ── Playback ───────────────────────────────────────────────────────────

    // Play a channel by its key (slug).  channelName is display name.
    function playChannel(channelKey, channelName) {
        // Find the channel object to get stream URL + ID
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

        var streams = ch.streams
        if (!streams || streams.length === 0) {
            Logger.w("DIFM", "No streams for channel:", channelKey)
            return
        }

        var streamUrl = streams[0].url
        if (root.listenKey) {
            streamUrl += "?listen_key=" + root.listenKey
        }

        // Stop any current playback
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

        // Launch mpv
        mpvProcess.command = [
            "mpv",
            "--no-video",
            "--quiet",
            "--really-quiet",
            "--volume=" + root.volume,
            "--title=DI.FM: " + channelName,
            streamUrl
        ]
        mpvProcess.running = true
        root.isPlaying = true

        // Persist last channel
        pluginApi.pluginSettings.lastChannel     = channelKey
        pluginApi.pluginSettings.lastChannelName = channelName
        pluginApi.saveSettings()

        Logger.i("DIFM", "Playing:", channelName, "→", streamUrl)

        // Fetch track info after a short delay (stream needs to negotiate)
        Qt.callLater(function() {
            Qt.createQmlObject('import QtQuick; Timer { interval: 3000; running: true; repeat: false; onTriggered: { root.fetchNowPlaying(); destroy() } }', root)
        })
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

    // Change volume — restarts the stream to apply (mpv limitation via Process)
    function setVolume(newVolume) {
        root.volume = newVolume
        pluginApi.pluginSettings.volume = newVolume
        pluginApi.saveSettings()

        // Restart stream with new volume if currently playing
        if (root.isPlaying && root._streamUrl !== "") {
            var key  = root.currentChannelKey
            var name = root.currentChannelName
            root.playChannel(key, name)
        }
    }

    // ── Now-playing fetch ─────────────────────────────────────────────────
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
                        root.currentTrackTitle = track.title       || ""
                        root.currentArtist     = track.artist_title || ""
                        root.nowPlayingText    = root.currentArtist
                            ? root.currentArtist + " — " + root.currentTrackTitle
                            : root.currentTrackTitle
                        Logger.d("DIFM", "Now playing:", root.nowPlayingText)
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
