import qs.core.client
import qs.view.contract
import qs.view.faces
import qs.view.cues
import qs.view.shell
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "DayFold.js" as Fold

ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    // The core (tasks, timers), for the today strip's faces.
    property CoreClient core: null
    signal navigate(string page)
    signal editProfile
    readonly property var player: host.media.active
    readonly property bool active: root.visible && (root.QsWindow.window?.visible ?? false) && root.shell.panelOpen
    readonly property int uptimeMinutes: Math.floor(host.system.uptime / 60)
    // Overdrive's edition of Home (docs/OVERDRIVE.md §36; atlas #9, #11): set when Home is opened, not live. Which
    // edition from the sun, the printing from the sheet's creases (DayFoldSheet), the front page's order from the
    // edition and the rooms used today; the lead card is set wide.
    readonly property bool overdrive: Motion.engaged && !Motion.reduced
    function localHour(iso) {
        if (!iso) return NaN;
        const d = new Date(iso);
        return d.getHours() + d.getMinutes() / 60;
    }
    readonly property real sunrise: localHour(homeSky.sky?.sun?.rise)
    readonly property real sunset: localHour(homeSky.sky?.sun?.set)
    property string edition: ""
    property string printing: ""
    property var frontPage: []
    function setEdition() {
        const d = new Date(), h = d.getHours() + d.getMinutes() / 60;
        const noon = Number.isFinite(sunrise) && Number.isFinite(sunset) ? (sunrise + sunset) / 2 : NaN;
        edition = Fold.edition(h, sunrise, noon, sunset);
        const day = root.core?.journeyData?.days?.[Qt.formatDate(d, "yyyy-MM-dd")] ?? {};
        frontPage = Fold.front(today.cards.map(c => c.room), edition, day);
    }
    onActiveChanged: if (active && overdrive) setEdition()
    onOverdriveChanged: if (overdrive && active) setEdition()
    spacing: 14
    // Top: the resident (a square portrait with an offset signal frame) beside the clock and the week.
    RowLayout {
        Layout.fillWidth: true
        spacing: 26
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 10
            Item {
                id: portrait
                // A 78° parallelogram (Plane slant 3): the top edge sits `run` right of the bottom one.
                readonly property real side: root.width < 740 ? 160 : 200
                readonly property real run: side * -Design.shear
                readonly property real offset: 12
                // The shear about the top-left that Plane uses: x' = x - shear·y + run.
                readonly property matrix4x4 lean: Qt.matrix4x4(1, Design.shear, 0, run, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                Layout.preferredWidth: side + run + offset
                Layout.preferredHeight: side + offset
                // The frame is the same parallelogram, down and left of the picture, like the Media cover.
                Rectangle {
                    x: 0
                    y: portrait.offset
                    width: portrait.side
                    height: portrait.side
                    transformOrigin: Item.TopLeft
                    transform: Matrix4x4 { matrix: portrait.lean }
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Design.accent, pointer.containsMouse ? 1 : 0.7)
                    antialiasing: true
                }
                // The picture is clipped to the parallelogram; the image inside is sheared back so it stays upright.
                Item {
                    id: picture
                    x: portrait.offset
                    y: 0
                    width: portrait.side
                    height: portrait.side
                    clip: true
                    transform: Matrix4x4 { matrix: portrait.lean }
                    Item {
                        width: portrait.side + portrait.run
                        height: portrait.side
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -Design.shear, 0, -portrait.run, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        FHalftone {
                            anchors.fill: parent
                            visible: profileImage.status !== Image.Ready
                        }
                        Image {
                            id: profileImage
                            anchors.fill: parent
                            anchors.margins: -5
                            source: Config.options.profile.avatarPicture || Quickshell.env("HOME") + "/.face"
                            sourceSize: Qt.size(Math.ceil(width * (root.QsWindow.window?.screen?.devicePixelRatio ?? 1)), Math.ceil(height * (root.QsWindow.window?.screen?.devicePixelRatio ?? 1)))
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            transform: Translate {
                                x: !Motion.reduced && pointer.containsMouse ? (pointer.mouseX / pointer.width - .5) * -7 : 0
                                y: !Motion.reduced && pointer.containsMouse ? (pointer.mouseY / pointer.height - .5) * -7 : 0
                                Tween on x {
                                    scope: root
                                    NumberAnimation {
                                        duration: Motion.settle
                                        easing.type: Motion.roles.settle.easing
                                    }
                                }
                                Tween on y {
                                    scope: root
                                    NumberAnimation {
                                        duration: Motion.settle
                                        easing.type: Motion.roles.settle.easing
                                    }
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: pointer
                    x: portrait.offset
                    width: portrait.side + portrait.run
                    height: portrait.side
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                // Edit and lock sit on the top corners, upright, inside the slanted edges.
                FButton {
                    x: portrait.offset + portrait.run + 6
                    y: 8
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSize: 18
                    symbol: "edit"
                    hint: "Edit profile"
                    baseColor: Qt.alpha(Design.background, 0.94)
                    outlineColor: Qt.alpha(Design.ink, 0.42)
                    onClicked: root.editProfile()
                }
                FButton {
                    x: portrait.offset + portrait.side + portrait.run - width - 14
                    y: 8
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSize: 18
                    symbol: "lock"
                    hint: "Lock session"
                    baseColor: Qt.alpha(Design.background, 0.94)
                    outlineColor: Qt.alpha(Design.ink, 0.42)
                    onClicked: {
                        root.shell.close();
                        root.host.power.lock();
                    }
                }
            }
            ColumnLayout {
                Layout.leftMargin: portrait.offset
                Layout.maximumWidth: portrait.side + portrait.run
                spacing: 3
                FText {
                    text: "RESIDENT 01"
                    technical: true
                    color: Design.accent
                }
                Item {
                    Layout.preferredWidth: Math.min(portrait.side + portrait.run, resident.implicitWidth + 30)
                    Layout.preferredHeight: 32
                    Plane { anchors.fill: parent; role: "ink"; slant: 3; backing: true }
                    FText {
                        id: resident
                        x: 13
                        width: parent.width - 26
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.options.profile.displayName || root.host.system.user
                        headline: true
                        font.pixelSize: Design.readout
                        font.weight: Font.Black
                        color: Design.onInk ?? Design.background
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: root.host.system.user + "@" + root.host.system.hostname
                    technical: true
                    color: Design.muted
                }
                FText {
                    text: "UP FOR " + Math.floor(root.uptimeMinutes / 60) + "H " + root.uptimeMinutes % 60 + "M"
                    technical: true
                    color: Design.muted
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.minimumWidth: 0
            spacing: 10
            // The clock over the sky it keeps (HomeSky: the astronomical clock, M10).
            Item {
                Layout.fillWidth: true
                implicitWidth: clockRow.implicitWidth
                implicitHeight: clockRow.implicitHeight
                HomeSky {
                    id: homeSky
                    anchors.fill: parent
                    core: root.core
                    active: root.active
                    quietTo: clockFace.x + clockFace.width
                }
                RowLayout {
                    id: clockRow
                    anchors.fill: parent
                    FText {
                        id: clockFace
                        text: Clock.hourStr + ":" + Clock.minuteStr
                        headline: true
                        font.pixelSize: root.width < 740 ? Design.headline : Design.display // scale: narrow-room breakpoint
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        // Idle: the clock breathes in the accent, once every two seconds (MONTAGE.md §4.5).
                        color: Qt.tint(Design.ink, Qt.alpha(Design.accent, 0.55 * (0.5 - 0.5 * Math.cos(2 * Math.PI * breath.phase))))
                        IdleLoop { id: breath; scope: clockFace; name: "home.clock"; period: 2400 }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 14
                        spacing: 2
                        FText {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatDate(Clock.date, "d MMM")
                            headline: true
                            font.pixelSize: Design.figure
                            font.weight: Font.Black
                            color: Design.accent
                        }
                        FText {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatDate(Clock.date, "dddd")
                            technical: true
                            color: Design.muted
                        }
                        // The sky's next word: sunrise or sunset, and the moon's light.
                        FText {
                            readonly property var sun: homeSky.sky?.sun ?? ({})
                            readonly property var next: (homeSky.sky?.next ?? []).find(e => e.kind === "sun.rise" || e.kind === "sun.set")
                            Layout.alignment: Qt.AlignRight
                            visible: !!homeSky.sky
                            text: (next ? (next.kind === "sun.rise" ? "SUNRISE " : "SUNSET ") + Qt.formatTime(new Date(next.at), "HH:mm") + " · " : "")
                                  + "MOON " + Math.round(100 * (homeSky.sky?.moon?.illumination ?? 0)) + "%"
                            technical: true
                            font.pixelSize: Design.caption
                            color: Design.faint
                        }
                    }
                }
            }
            // The day's ruler (DayRuler: daylight's share, the sidereal margin, the moment in three frames).
            DayRuler {
                id: dayRuler
                Layout.fillWidth: true
                sky: homeSky.sky
                journey: root.core?.journeyData ?? null
                lapse: homeSky.lapse
                active: root.active
            }
            FWeek {
                Layout.fillWidth: true
                journey: root.core?.journeyData ?? null
            }
        }
    }
    // The signal: what is playing, as an open band between two rules, not a card. A hatched edge marks it;
    // the cover is round inside a thin ring that carries the track's position (sampled, so it moves only when
    // a new position arrives).
    Item {
        id: signal
        readonly property real progress: (root.player?.length ?? 0) > 0 ? Math.max(0, Math.min(1, root.host.media.position / root.player.length)) : 0
        Layout.fillWidth: true
        Layout.preferredHeight: root.width < 740 ? 92 : 104
        HostLease { domain: root.host.media; feature: "position"; active: root.active && !!root.player }
        Hairline { anchors.top: parent.top; width: parent.width; startNode: true; color: Design.line }
        Hairline { anchors.bottom: parent.bottom; width: parent.width; startNode: true; color: Design.line }
        Hatch {
            x: 0
            y: 10
            width: 22
            height: parent.height - 20
            color: Design.accent
            strength: 0.6
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 36
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 18
            CoverDisc {
                Layout.preferredWidth: signal.height - 16
                Layout.preferredHeight: signal.height - 16
                Layout.alignment: Qt.AlignVCenter
                source: root.player?.artUrl ?? ""
                progress: signal.progress
                spinning: root.player?.playing ?? false
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 0
                spacing: 4
                RowLayout {
                    spacing: 8
                    FStatusDot {
                        pulse: root.player?.playing ?? false
                        color: pulse ? Design.accent : Design.faint
                    }
                    FText {
                        text: root.player?.playing ? "ON AIR" : root.player ? "SIGNAL HELD" : "NO CARRIER"
                        technical: true
                        color: Design.accent
                    }
                    FText {
                        visible: !!root.player
                        text: "VIA " + (root.player?.identity ?? "")
                        technical: true
                        color: Design.faint
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: root.player?.title || "The room is quiet."
                    headline: true
                    font.pixelSize: root.width < 740 ? Design.readout : Design.figure // scale: narrow-room breakpoint
                    font.weight: Font.Black
                    font.capitalization: Font.MixedCase
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                FText {
                    Layout.fillWidth: true
                    text: root.player?.artist || "Nothing needs to fill the silence."
                    font.pixelSize: Design.control
                    font.capitalization: Font.MixedCase
                    color: Design.muted
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                FButton {
                    symbol: "skip_previous"
                    hint: "Previous"
                    enabled: root.player?.canPrevious ?? false
                    onClicked: root.host.media.previous()
                }
                FButton {
                    symbol: root.player?.playing ? "pause" : "play_arrow"
                    hint: "Play / pause"
                    primary: true
                    enabled: root.player?.canToggle ?? false
                    onClicked: root.host.media.togglePlaying()
                }
                FButton {
                    symbol: "skip_next"
                    hint: "Next"
                    enabled: root.player?.canNext ?? false
                    onClicked: root.host.media.next()
                }
                FButton {
                    symbol: "arrow_forward"
                    hint: "Open signal room"
                    onClicked: root.navigate("media")
                }
            }
        }
    }
    // Today: the rooms' live facts as cards (the planet faces at their readout size), in the space between
    // the signal and the menus. Shown only when that space holds a card; a click goes to the room. The
    // faces are live only while Home is shown, and none of them takes a lease of its own here.
    Item {
        id: today
        Layout.fillWidth: true
        Layout.fillHeight: true
        readonly property bool fits: height >= 84 && width >= 600
        readonly property var cards: [
            { room: "tasks", number: "05", name: "TASKS", face: tasksFace },
            { room: "timers", number: "06", name: "TIMERS", face: timersFace },
            { room: "notifications", number: "08", name: "INBOX", face: inboxFace },
            { room: "workspaces", number: "03", name: "DESK", face: deskFace }
        ]
        Component { id: tasksFace; TasksFace { core: root.core } }
        Component { id: timersFace; TimersFace { core: root.core } }
        Component { id: inboxFace; NotificationsFace { host: root.host } }
        Component { id: deskFace; WorkspacesFace { host: root.host } }
        // The cards as set: in Overdrive, the edition's front page.
        readonly property var set: root.overdrive && root.frontPage.length === cards.length
            ? root.frontPage.map(r => cards.find(c => c.room === r)) : cards
        // The sheet folded by the day, laid over the whole of Home (it is Home's sibling so it can cover it).
        Stratum {
            parent: root.parent
            x: root.x
            y: root.y
            z: 10
            width: root.width
            height: root.height
            name: "home.fold"
            gpu: false
            scope: root
            wanted: root.active
            sourceComponent: DayFoldSheet {
                rise: root.sunrise
                set: root.sunset
                autonomous: false
                Component.onCompleted: {
                    const at = dayRuler.mapToItem(root, 0, 0);
                    from = root.width > 0 ? at.x / root.width : 0;
                    span = root.width > 0 ? dayRuler.width / root.width : 1;
                    open();
                    root.printing = Fold.printing(Fold.kept.sheet);
                }
            }
        }
        ColumnLayout {
            visible: today.fits && !!root.core
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                FText {
                    text: root.overdrive && root.edition !== "" ? root.edition + (root.printing !== "" ? " · " + root.printing : "") : "TODAY"
                    technical: true
                    color: Design.faint
                }
                Hairline { Layout.fillWidth: true; color: Design.line }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: today.set
                    Item {
                        id: card
                        required property var modelData
                        required property int index
                        // In an edition the lead story is set wide: two fifths of the row, the rest a fifth each.
                        Layout.fillWidth: !root.overdrive
                        Layout.preferredWidth: root.overdrive ? (index === 0 ? 0.4 : 0.2) * (today.width - 36) : -1
                        Layout.preferredHeight: Math.min(190, today.height - 30)
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name
                        Plane {
                            id: cardPlane
                            anchors.fill: parent
                            role: hover.hovered ? "signal" : "clear"
                            slant: 3
                            backing: true
                        }
                        FText {
                            x: cardPlane.run + 10
                            y: 7
                            text: card.modelData.number + "  " + card.modelData.name
                            technical: true
                            font.weight: Font.Bold
                            color: cardPlane.textColor
                        }
                        Loader {
                            id: faceLoader
                            x: cardPlane.run * 0.5 + 8
                            y: 24
                            width: parent.width - x - cardPlane.run * 0.5 - 8
                            height: parent.height - y - 6
                            active: today.fits && !!root.core
                            asynchronous: true
                            sourceComponent: card.modelData.face
                        }
                        Binding { target: faceLoader.item; property: "live"; value: root.active; when: faceLoader.item !== null }
                        Binding { target: faceLoader.item; property: "tone"; value: cardPlane.textColor; when: faceLoader.item !== null }
                        Binding { target: faceLoader.item; property: "ground"; value: cardPlane.fillColor; when: faceLoader.item !== null }
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.navigate(card.modelData.room) }
                    }
                }
            }
        }
    }
    // The sheet's menus: the host and FART's upkeep on the left, the desk on the right.
    RowLayout {
        Layout.fillWidth: true
        spacing: 28
        ColumnLayout {
            id: upkeep
            readonly property var updates: root.host.hostActions.updates
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                FText { text: "UPKEEP"; technical: true; color: Design.faint }
                FText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    visible: upkeep.updates.available && upkeep.updates.count > 0
                    text: "the host has news."
                    aside: true
                    color: Design.muted
                }
            }
            FMenuItem {
                Layout.fillWidth: true
                label: upkeep.updates.checking ? "Checking…" : "Check updates"
                detail: upkeep.updates.checking ? "" : upkeep.updates.available ? upkeep.updates.count + " WAITING" : "UNAVAILABLE"
                enabled: !upkeep.updates.checking
                onClicked: root.host.hostActions.checkUpdates()
            }
            FMenuItem {
                Layout.fillWidth: true
                label: "Host updates…"
                onClicked: root.shell.openHost("updates")
            }
            FMenuItem {
                Layout.fillWidth: true
                label: "Update FART"
                detail: "GIT"
                onClicked: FartCommands.updateReport()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 0
            FText { Layout.bottomMargin: 4; text: "DESK"; technical: true; color: Design.faint }
            FMenuItem {
                Layout.fillWidth: true
                label: "Wallpaper"
                onClicked: root.shell.openHost("wallpapers")
            }
            FMenuItem {
                Layout.fillWidth: true
                label: "Presets"
                onClicked: root.shell.openHost("themes")
            }
            FMenuItem {
                Layout.fillWidth: true
                label: "Settings"
                onClicked: root.shell.openHost("settings")
            }
        }
    }
}
