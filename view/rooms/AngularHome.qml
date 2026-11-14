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

// Original Angular Home visual tree; shared state belongs to HomeSession.
ColumnLayout {
    id: root
    required property HomeSession session
    readonly property bool active: session.active && visible
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
                    objectName: "home.profile"
                    symbol: "edit"
                    hint: "Edit profile"
                    baseColor: Qt.alpha(Design.background, 0.94)
                    outlineColor: Qt.alpha(Design.ink, 0.42)
                    onClicked: root.session.editProfile()
                }
                FButton {
                    x: portrait.offset + portrait.side + portrait.run - width - 14
                    y: 8
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSize: 18
                    objectName: "home.lock"
                    symbol: "lock"
                    hint: "Lock session"
                    baseColor: Qt.alpha(Design.background, 0.94)
                    outlineColor: Qt.alpha(Design.ink, 0.42)
                    onClicked: {
                        root.session.lock();
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
                        text: Config.options.profile.displayName || root.session.host.system.user
                        headline: true
                        font.pixelSize: Design.readout
                        font.weight: Font.Black
                        color: Design.onInk ?? Design.background
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: root.session.host.system.user + "@" + root.session.host.system.hostname
                    technical: true
                    color: Design.muted
                }
                FText {
                    text: "UP FOR " + Math.floor(root.session.uptimeMinutes / 60) + "H " + root.session.uptimeMinutes % 60 + "M"
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
                    sky: root.session.sky
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
                journey: root.session.core?.journeyData ?? null
                lapse: homeSky.lapse
                active: root.active
            }
            FWeek {
                objectName: "home.week"
                Layout.fillWidth: true
                journey: root.session.core?.journeyData ?? null
                week: root.session.calendarWeek
                selectedDate: root.session.calendarSelection
                onWeekChanged: root.session.calendarWeek = week
                onSelectedDateChanged: root.session.calendarSelection = selectedDate
            }
        }
    }
    // The signal: what is playing, as an open band between two rules, not a card. A hatched edge marks it;
    // the cover is round inside a thin ring that carries the track's position (sampled, so it moves only when
    // a new position arrives).
    Item {
        id: signal
        readonly property real progress: (root.session.player?.length ?? 0) > 0 ? Math.max(0, Math.min(1, root.session.host.media.position / root.session.player.length)) : 0
        Layout.fillWidth: true
        Layout.preferredHeight: root.width < 740 ? 92 : 104
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
                source: root.session.player?.artUrl ?? ""
                progress: signal.progress
                spinning: root.session.player?.playing ?? false
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 0
                spacing: 4
                RowLayout {
                    spacing: 8
                    FStatusDot {
                        pulse: root.session.player?.playing ?? false
                        color: pulse ? Design.accent : Design.faint
                    }
                    FText {
                        text: root.session.player?.playing ? "ON AIR" : root.session.player ? "SIGNAL HELD" : "NO CARRIER"
                        technical: true
                        color: Design.accent
                    }
                    FText {
                        visible: !!root.session.player
                        text: "VIA " + (root.session.player?.identity ?? "")
                        technical: true
                        color: Design.faint
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: root.session.player?.title || "The room is quiet."
                    headline: true
                    font.pixelSize: root.width < 740 ? Design.readout : Design.figure // scale: narrow-room breakpoint
                    font.weight: Font.Black
                    font.capitalization: Font.MixedCase
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                FText {
                    Layout.fillWidth: true
                    text: root.session.player?.artist || "Nothing needs to fill the silence."
                    font.pixelSize: Design.control
                    font.capitalization: Font.MixedCase
                    color: Design.muted
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                FButton {
                    objectName: "home.previous"
                    symbol: "skip_previous"
                    hint: "Previous"
                    enabled: root.session.player?.canPrevious ?? false
                    onClicked: root.session.previous()
                }
                FButton {
                    objectName: "home.play"
                    symbol: root.session.player?.playing ? "pause" : "play_arrow"
                    hint: "Play / pause"
                    primary: true
                    enabled: root.session.player?.canToggle ?? false
                    onClicked: root.session.togglePlaying()
                }
                FButton {
                    objectName: "home.next"
                    symbol: "skip_next"
                    hint: "Next"
                    enabled: root.session.player?.canNext ?? false
                    onClicked: root.session.next()
                }
                FButton {
                    objectName: "home.media"
                    symbol: "arrow_forward"
                    hint: "Open signal room"
                    onClicked: root.session.navigate("media")
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
        Component { id: tasksFace; TasksFace { core: root.session.core } }
        Component { id: timersFace; TimersFace { core: root.session.core } }
        Component { id: inboxFace; NotificationsFace { host: root.session.host } }
        Component { id: deskFace; WorkspacesFace { host: root.session.host } }
        // The cards as set: in Overdrive, the edition's front page.
        readonly property var set: root.session.overdrive && root.session.frontPage.length === cards.length
            ? root.session.frontPage.map(r => cards.find(c => c.room === r)) : cards
        // The sheet folded by the day, laid over the whole of Home (it is Home's sibling so it can cover it).
        Stratum {
            parent: root.session.surface
            x: 0
            y: 0
            z: 10
            width: root.width
            height: root.height
            name: "home.fold"
            gpu: false
            scope: root
            wanted: root.active
            sourceComponent: DayFoldSheet {
                rise: root.session.sunrise
                set: root.session.sunset
                autonomous: false
                Component.onCompleted: {
                    const at = dayRuler.mapToItem(root, 0, 0);
                    from = root.width > 0 ? at.x / root.width : 0;
                    span = root.width > 0 ? dayRuler.width / root.width : 1;
                    if (root.session.foldSnapshot) {
                        sheet = root.session.foldSnapshot;
                        opened = root.session.foldOpened;
                    } else {
                        open();
                        root.session.foldSnapshot = sheet;
                        root.session.foldOpened = opened;
                        root.session.printing = Fold.printing(sheet);
                    }
                }
            }
        }
        ColumnLayout {
            visible: today.fits && !!root.session.core
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                FText {
                    text: root.session.overdrive && root.session.edition !== "" ? root.session.edition + (root.session.printing !== "" ? " · " + root.session.printing : "") : "TODAY"
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
                        Layout.fillWidth: !root.session.overdrive
                        Layout.preferredWidth: root.session.overdrive ? (index === 0 ? 0.4 : 0.2) * (today.width - 36) : -1
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
                            active: today.fits && !!root.session.core
                            asynchronous: true
                            sourceComponent: card.modelData.face
                        }
                        Binding { target: faceLoader.item; property: "live"; value: root.active; when: faceLoader.item !== null }
                        Binding { target: faceLoader.item; property: "tone"; value: cardPlane.textColor; when: faceLoader.item !== null }
                        Binding { target: faceLoader.item; property: "ground"; value: cardPlane.fillColor; when: faceLoader.item !== null }
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.session.navigate(card.modelData.room) }
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
            readonly property var updates: root.session.host.hostActions.updates
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
                objectName: "home.checkUpdates"
                label: upkeep.updates.checking ? "Checking…" : "Check updates"
                detail: upkeep.updates.checking ? "" : upkeep.updates.available ? upkeep.updates.count + " WAITING" : "UNAVAILABLE"
                enabled: !upkeep.updates.checking
                onClicked: root.session.checkUpdates()
            }
            FMenuItem {
                Layout.fillWidth: true
                objectName: "home.updates"
                label: "Host updates…"
                onClicked: root.session.openHost("updates")
            }
            FMenuItem {
                Layout.fillWidth: true
                objectName: "home.updateFart"
                label: "Update FART"
                detail: "GIT"
                onClicked: root.session.updateFart()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 0
            FText { Layout.bottomMargin: 4; text: "DESK"; technical: true; color: Design.faint }
            FMenuItem {
                Layout.fillWidth: true
                objectName: "home.wallpapers"
                label: "Wallpaper"
                onClicked: root.session.openHost("wallpapers")
            }
            FMenuItem {
                Layout.fillWidth: true
                objectName: "home.themes"
                label: "Presets"
                onClicked: root.session.openHost("themes")
            }
            FMenuItem {
                Layout.fillWidth: true
                objectName: "home.settings"
                label: "Settings"
                onClicked: root.session.openHost("settings")
            }
        }
    }
}
