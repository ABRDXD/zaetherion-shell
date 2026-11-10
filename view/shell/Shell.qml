import qs.core.client
import qs.view.contract
import qs.view.cues
import qs.view.overdrive
import qs.view.rooms
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import "../ui/FocusMap.js" as FocusMap
import "../overdrive/FalseRoom.js" as FalseRoomRules

Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    // Rooms that read core state; the rest never see it.
    readonly property var coreRooms: ["home", "tasks", "timers"]
    property string page: "home"
    property string currentPage: "home"
    property bool preferencesOpen: false
    property bool archiveOpen: false
    // Overdrive (docs/OVERDRIVE.md): the core's lease, the lease manager's popover and the ignition over the panel.
    readonly property OverdriveLease lease: OverdriveLease { core: root.core }
    property bool leaseOpen: false
    property bool igniteKeyHeld: false
    readonly property Ignition ignition: ignitionLayer
    readonly property LeaseChip headerChip: leaseChip
    // The heat: the view's measured CPU in Overdrive, shown as haze over the header (docs/OVERDRIVE.md §8).
    readonly property Heat heat: Heat {}
    // The bass, from the host's spectrum while someone holds its lease (Media in Overdrive, the orbit, the lyrics).
    readonly property real musicBass: {
        const bins = root.host.media?.spectrum ?? [];
        if (!Motion.engaged || bins.length === 0)
            return 0;
        let sum = 0;
        for (let i = 0; i < Math.min(6, bins.length); i++) sum += bins[i];
        return sum / Math.min(6, bins.length);
    }
    property bool profileOpen: false
    // The orbit (docs/ORBIT.md): every room as a system around Home, on Ctrl+M. It replaced the lattice
    // canvas and its map: rooms are reached by flying through it.
    property bool orbitOpen: false
    readonly property var orbit: orbitLoader.item
    // The orbit camera's cue, for tests and review frames.
    readonly property Cue orbitTransfer: transfer
    // The panel's unfold reveals the header and index, then the room (Overlay's Unfold, §15).
    property real headerReveal: 1
    property real headerRise: 0
    property real roomReveal: 1
    property real roomRise: 0
    readonly property bool compact: width < 920
    // The index keeps its names (a narrower column) down to 640 px; only below that it shows numerals only.
    readonly property bool indexCompact: width < 640
    readonly property string displayedPage: currentPage
    readonly property bool editingText: profileOpen || (shownSlot.item?.editing ?? false)

    readonly property bool searchOpen: false
    readonly property bool externalDialogOpen: profileDialog.item?.externalDialogOpen ?? false
    // The room shown is the one requested; while its replacement incubates, `pendingPage` names it.
    property bool frontIsA: true
    readonly property RoomSlot shownSlot: frontIsA ? slotA : slotB
    readonly property RoomSlot nextSlot: frontIsA ? slotB : slotA
    readonly property string loadedPage: shownSlot.item && shownSlot.page === currentPage ? currentPage : ""
    readonly property string pendingPage: nextSlot.page
    readonly property var layoutMetrics: ({
        viewportHeight: pageViewport.height,
        contentHeight: pageViewport.contentHeight,
        pageImplicitHeight: shownSlot.item?.implicitHeight ?? 0
    })
    readonly property var pages: [
        {
            id: "media",
            name: "Media",
            symbol: "music_note",
            voice: "Signal, received.",
            about: "Now playing · lyrics · output"
        },
        {
            id: "performance",
            name: "Performance",
            symbol: "monitor_heart",
            voice: "Anatomy of a machine.",
            about: "Telemetry · live readings"
        },
        {
            id: "workspaces",
            name: "Workspaces",
            symbol: "view_quilt",
            voice: "Parallel lives.",
            about: "Workspace atlas · Hyprland"
        },
        {
            id: "devices",
            name: "Devices",
            symbol: "tune",
            voice: "Everything, in reach.",
            about: "Device systems · manual control"
        },
        {
            id: "tasks",
            name: "Tasks",
            symbol: "checklist",
            voice: "One thing, then another.",
            about: "A field guide to unfinished business"
        },
        {
            id: "timers",
            name: "Timers",
            symbol: "timer",
            voice: "Give time a shape.",
            about: "Temporal instruments"
        },
        {
            id: "clipboard",
            name: "Clips",
            symbol: "content_paste",
            voice: "Fragments, retained.",
            about: "Clipboard · working archive"
        },
        {
            id: "notifications",
            name: "Inbox",
            symbol: "notifications",
            voice: "Messages from outside.",
            about: "Inbox · this FART session"
        },
        {
            id: "codex",
            name: "Codex",
            symbol: "menu_book",
            voice: "What everything is called.",
            about: "Your keys · the elements"
        }
    ]
    // Room shortcuts are Ctrl+1–9; Home gets its own explicit 00 entry. `voice` is the room's line on
    // its title band (it was the room's FHeading title), `about` the band's accessible description.
    readonly property var navigationPages: [{ id: "home", name: "Home", symbol: "home", voice: "Where the day starts.", about: "Resident · the week · the signal" }, ...root.pages]
    readonly property var pageFiles: ({
                                          home: "../rooms/Home.qml",
                                          media: "../rooms/Media.qml",
                                          performance: "../rooms/Performance.qml",
                                          workspaces: "../rooms/Workspaces.qml",
                                          devices: "../rooms/Devices.qml",
                                          tasks: "../rooms/Tasks.qml",
                                          timers: "../rooms/Timers.qml",
                                          clipboard: "../rooms/Clips.qml",
                                          notifications: "../rooms/Inbox.qml",
                                          codex: "../rooms/Codex.qml"
                                      })
    // Each room's editorial cut (MONTAGE.md §4): side, the edge the cut wedge stands on (the ribbon takes the
    // other); span and align, how much of the height the wedge covers and from which end.
    readonly property var cuts: ({
        home: { side: "left", span: 1, align: "top" },
        media: { side: "right", span: 0.74, align: "bottom" },
        performance: { side: "left", span: 0.6, align: "top" },
        workspaces: { side: "right", span: 1, align: "top" },
        devices: { side: "left", span: 0.68, align: "bottom" },
        tasks: { side: "right", span: 0.64, align: "top" },
        timers: { side: "left", span: 1, align: "top" },
        clipboard: { side: "right", span: 0.72, align: "bottom" },
        notifications: { side: "left", span: 0.58, align: "top" },
        codex: { side: "right", span: 0.7, align: "bottom" }
    })
    function sideOf(id) {
        return cuts[id]?.side ?? "left";
    }
    // The room laid over its cluster (the shown one; the requested one while nothing is shown yet).
    readonly property string shownPageId: shownSlot.page || currentPage
    // The ribbon stands on the edge the current room's wedge leaves free.
    readonly property string ribbonSide: sideOf(currentPage) === "left" ? "right" : "left"
    implicitWidth: 1120
    implicitHeight: 760
    readonly property CommandLine commandLine: cmdline
    // The index bands (IndexBand), for tests.
    readonly property Repeater bands: indexBands
    // Every open focuses the command line (DAILY_DRIVER §11 Q3).
    function focusCommandLine() {
        cmdline.focusInput();
    }
    // A kept Shell (PanelBody.keepShell) drops its room when the panel folds.
    function releaseRoom() {
        slotA.cancel();
        slotB.cancel();
    }
    function focusRoom() {
        const room = shownSlot.item;
        if (room)
            room.nextItemInFocusChain(true)?.forceActiveFocus(Qt.TabFocusReason);
    }
    // The key table (MONTAGE.md §3.3). The reticle shows after keyboard navigation, hides on a pointer
    // press or on a typed letter. hjkl move only while it is shown (Q2); otherwise they type.
    property bool keyboardNav: false
    readonly property Reticle focusReticle: reticle
    readonly property var arrowDirections: ({ [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up",
        [Qt.Key_Down]: "down" })
    readonly property var letterDirections: ({ h: "left", j: "down", k: "up", l: "right" })
    // Handles a key pressed with no text field focused; returns true when it was consumed.
    function navigationKey(event) {
        const direction = arrowDirections[event.key] ?? (keyboardNav ? letterDirections[event.text] : undefined);
        if (direction) {
            keyboardNav = true;
            moveFocus(direction);
            reticle.place();
            return true;
        }
        if (event.text === "[" || event.text === "]") {
            stepRoom(event.text === "]" ? 1 : -1);
            return true;
        }
        if (event.text === "/") {
            keyboardNav = false;
            cmdline.focusInput();
            return true;
        }
        return false;
    }
    // The visible, enabled tab stops under `item`, collected on demand (never per frame).
    function focusables(item, out) {
        if (item.activeFocusOnTab && item.visible && item.enabled)
            out.push(item);
        for (const child of item.children)
            if (child.visible)
                focusables(child, out);
        return out;
    }
    function rectIn(item) {
        const origin = item.mapToItem(root, 0, 0);
        return { x: origin.x, y: origin.y, width: item.width, height: item.height };
    }
    // Which part of the panel `item` is in: "room", "index", "command", "header", or "" (an overlay).
    function zoneOf(item) {
        for (let at = item; at; at = at.parent) {
            if (at === shownSlot.item)
                return "room";
            if (at === navigation)
                return "index";
            if (at === cmdline)
                return "command";
            if (at === header)
                return "header";
        }
        return "";
    }
    function zoneItems(zone) {
        if (zone === "room")
            return shownSlot.item ? focusables(shownSlot.item, []) : [];
        if (zone === "index")
            return focusables(navigation, []);
        if (zone === "header")
            return focusables(header, []).filter(item => zoneOf(item) === "header");
        return [];
    }
    // The nearest list or grid view around `item` inside the room, or null.
    function listOf(item) {
        const room = shownSlot.item;
        for (let at = item?.parent; at && at !== room; at = at.parent)
            if (typeof at.positionViewAtIndex === "function" && typeof at.indexAt === "function" && at.contentItem)
                return at;
        return null;
    }
    // The model row of `item` inside `list`, or -1.
    function rowOf(list, item) {
        const c = item.mapToItem(list.contentItem, item.width / 2, item.height / 2);
        return list.indexAt(c.x, c.y);
    }
    // Scrolls the room (and the list holding `item`) so that `item` is fully in view.
    function reveal(item) {
        if (!item || zoneOf(item) !== "room")
            return;
        const list = listOf(item);
        if (list) {
            const row = rowOf(list, item);
            if (row >= 0)
                list.positionViewAtIndex(row, ListView.Contain);
        }
        const top = item.mapToItem(pageViewport.contentItem, 0, 0).y;
        const bottom = top + item.height;
        const maxY = Math.max(0, pageViewport.contentHeight - pageViewport.height);
        if (top < pageViewport.contentY)
            pageViewport.contentY = Math.max(0, top - 8);
        else if (bottom > pageViewport.contentY + pageViewport.height)
            pageViewport.contentY = Math.min(maxY, bottom - pageViewport.height + 8);
    }
    function focusedItem() {
        return Window.activeFocusItem;
    }
    function focusItem(item) {
        item.forceActiveFocus(Qt.TabFocusReason);
        reveal(item);
        return true;
    }
    // The nearest of `items` from `current` in `direction`; focuses it and returns true when found.
    function pickIn(items, current, direction) {
        const rects = items.map(rectIn);
        const from = items.indexOf(current);
        const next = FocusMap.pick(from >= 0 ? rects[from] : rectIn(current), rects, direction);
        return next >= 0 && focusItem(items[next]);
    }
    // A vertical move past the delegates a list has created: scroll one row, then pick again.
    function scrollList(list, current, direction) {
        if (direction !== "up" && direction !== "down")
            return false;
        const row = rowOf(list, current);
        const target = row + (direction === "down" ? 1 : -1);
        if (row < 0 || target < 0 || target >= list.count)
            return false;
        list.positionViewAtIndex(target, ListView.Contain);
        list.forceLayout?.();
        return pickIn(focusables(list, []), current, direction);
    }
    // Enters `zone` after a move with no candidate. Into the room it picks from `current`'s rect, else
    // the first control; into the index, the selected band.
    function enterZone(zone, current, direction) {
        if (zone === "command") {
            cmdline.focusInput();
            return true;
        }
        if (zone === "index") {
            const band = indexBands.itemAt(navigationPages.findIndex(entry => entry.id === currentPage));
            return !!band && focusItem(band);
        }
        if (zone === "room") {
            const items = zoneItems("room");
            if (items.length === 0)
                return false;
            return (current && pickIn(items, current, direction)) || focusItem(items[0]);
        }
        return false;
    }
    // Spatial move (MONTAGE.md §3.3): inside the focused list first, then its zone, then the zone's fallback.
    function moveFocus(direction) {
        if (archiveOpen || profileOpen)
            return false;
        const current = Window.activeFocusItem;
        if (!current || current === root)
            return enterZone("room", null, direction);
        const zone = zoneOf(current);
        if (zone !== "room" && zone !== "index" && zone !== "header")
            return false;
        const list = zone === "room" ? listOf(current) : null;
        if (list && (pickIn(focusables(list, []), current, direction) || scrollList(list, current, direction)))
            return true;
        if (pickIn(zoneItems(zone), current, direction))
            return true;
        return enterZone(FocusMap.fallback(zone, direction, root.ribbonSide), current, direction);
    }
    // Dragging through space (docs/ORBIT.md §4): from a room, pull it out into the orbit; in the orbit,
    // pan. Release with the pointer's velocity (px/s) glides on. For the pointer handlers and tests.
    function orbitPan(dx, dy) { field.orbitPan(dx, dy); }
    function orbitZoom(px, py, factor) { field.orbitZoom(px, py, factor); }
    function orbitRelease(vx, vy) { field.orbitRelease(vx ?? 0, vy ?? 0); }
    readonly property bool orbitDragging: field.orbitFree
    // Escape from anything but the command line goes back to it; a second Escape folds (M5).
    // The contact sheet (M14, view/overdrive/ContactSheet.qml): W on the orbit, Ctrl+W anywhere in the panel.
    property bool sheetOpen: false
    // The heavy layer is drawing the sky under the panel (view/shell/HeavyLayer.qml).
    property bool spaceBelow: false
    readonly property var sheet: sheetLoader.item
    function closeSheet() {
        sheetOpen = false;
        if (orbitOpen && orbit)
            orbit.forceActiveFocus();
        else
            root.forceActiveFocus();
    }
    function escapeKey() {
        if (exhibitScore !== null) { exhibitScore = null; return true; }
        if (falseRoomOpen) { falseRoomOpen = false; return true; }
        if (sheetOpen) {
            closeSheet();
            return true;
        }
        if (leaseOpen) {
            leaseOpen = false;
            return true;
        }
        if (orbitOpen) {
            orbitOpen = false;
            field.fly("close", currentPage);
            return true;
        }
        if (cmdline.inputFocused || archiveOpen || profileOpen)
            return false;
        keyboardNav = false;
        cmdline.focusInput();
        return true;
    }
    // Type to fly (`go <moon>`): open the orbit, and once its systems are built, step into the system holding a
    // moon of that name and key it. "" opens the orbit alone.
    function flyTo(target) {
        // Set before opening: the orbit's Loader may finish (onLoaded, which takes it) inside toggleOrbit.
        pendingFly = target;
        if (!orbitOpen)
            toggleOrbit();
        if (pendingFly !== "" && orbit) {
            orbit.seek(pendingFly);
            pendingFly = "";
        }
    }
    property string pendingFly: ""
    // Open or close the orbit. Closing hands the keyboard back to the command line.
    function toggleOrbit() {
        orbitOpen = !orbitOpen;
        field.fly(orbitOpen ? "open" : "close", currentPage);
    }
    onOrbitOpenChanged: {
        if (orbitOpen && orbit)
            orbit.forceActiveFocus();
        else if (!orbitOpen)
            cmdline.focusInput();
    }
    // Previous or next room in index order, wrapping.
    function stepRoom(delta) {
        const ids = navigationPages.map(entry => entry.id);
        const at = Math.max(0, ids.indexOf(currentPage));
        navigate(ids[(at + delta + ids.length) % ids.length]);
    }
    // A printable key with no text field focused moves to the command line (§4.1). Text fields
    // accept their own keys, so only unhandled keys propagate up to here.
    function noteModifiers(event) {
        const held = [[Qt.MetaModifier, "SUPER"], [Qt.ShiftModifier, "SHIFT"], [Qt.ControlModifier, "CTRL"], [Qt.AltModifier, "ALT"]].filter(m => event.modifiers & m[0]).map(m => m[1]);
        if (held.join() !== ViewState.heldModifiers.join())
            ViewState.heldModifiers = held;
    }
    Keys.onPressed: event => {
        noteModifiers(event);
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        // Ctrl+O held is the ignite plate's key (docs/OVERDRIVE.md §2): the press starts the core's hold, the
        // release ends it; auto-repeats are ignored.
        if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
            // A second edge while held is ignored by the core, so a release lost with the focus can't wedge this.
            if (!event.isAutoRepeat) {
                root.igniteKeyHeld = true;
                root.lease.holdDown();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
            sheetOpen = !sheetOpen;
            if (!sheetOpen)
                closeSheet();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            // Not accepted: the window's focus chain still moves; this only shows the reticle.
            root.keyboardNav = true;
            return;
        }
        if (event.key === Qt.Key_Escape && root.escapeKey()) {
            event.accepted = true;
            return;
        }
        if (plain && !root.editingText && root.navigationKey(event)) {
            event.accepted = true;
            return;
        }
        // Any other printable key goes to the command line and hides the reticle.
        if (plain && event.text.length > 0)
            root.keyboardNav = false;
        if (plain && event.text.length > 0 && event.text >= " " && event.text !== "\x7f" && !root.editingText) {
            cmdline.typeIn(event.text);
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        noteModifiers(event);
        if (event.key === Qt.Key_O && !event.isAutoRepeat && root.igniteKeyHeld) {
            root.igniteKeyHeld = false;
            root.lease.holdUp();
            event.accepted = true;
        }
    }
    onPageChanged: navigate(page)
    Component.onCompleted: { navigate(page); syncEigenDevices(true); }
    function navigate(requested) {
        const name = requested === "controls" ? "devices" : requested;
        if (!pageFiles[name])
            return;
        const previous = currentPage, fromOrbit = orbitOpen;
        currentPage = name;
        if (name !== previous) Eigenmode.strike("room");
        orbitOpen = false;
        // Every switch flies through the orbit (docs/ORBIT.md §4): from a room, out and across; from the
        // orbit, straight in.
        if (fromOrbit || name !== previous)
            field.fly(fromOrbit ? "land" : "switch", name);
        archiveOpen = false;
        preferencesOpen = false;
        ViewState.visit(name);
        // Back to the room still shown: drop the pending one.
        if (shownSlot.page === name && shownSlot.item) {
            nextSlot.cancel();
            shownSlot.leaving = false;
            return;
        }
        if (nextSlot.page === name)
            return;
        // The shown room stays until its replacement is ready, then is released. There is no
        // queue, outgoing screenshot, or hidden retained page tree.
        shownSlot.leaving = !!shownSlot.item;
        nextSlot.staging = false;
        const properties = { host: root.host, shell: root.shell };
        if (coreRooms.includes(name))
            properties.core = root.core;
        nextSlot.page = name;
        nextSlot.setSource(Qt.resolvedUrl(pageFiles[name]), properties);
    }
    // A ready room is laid out invisibly for one frame, then swapped in on the next.
    function stage(slot) {
        if (slot !== nextSlot)
            return;
        if (slot.status === Loader.Error) {
            swap(slot);
            return;
        }
        slot.staging = true;
        stageFrames.seen = 0;
    }
    FrameAnimation {
        id: stageFrames
        property int seen: 0
        running: root.nextSlot.staging
        // The first tick is the frame that lays the room out; the second swaps it in.
        onTriggered: if (++seen >= 2 && field.swapReady) root.swap(root.nextSlot)
    }
    function swap(slot) {
        if (slot !== nextSlot)
            return;
        const outgoing = shownSlot;
        slot.staging = false;
        frontIsA = !frontIsA;
        outgoing.cancel();
        outgoing.leaving = false;
        pageViewport.contentY = 0;
        entrance.replay();
    }
    Connections {
        target: root.shownSlot.item
        ignoreUnknownSignals: true
        function onNavigate(page) {
            root.navigate(page);
        }
        function onEditProfile() {
            root.profileOpen = true;
        }
        // Connection dialogs belong to the host.
        function onOpenDialog(kind) {
            root.shell.openHost(kind);
        }
    }
    ColumnLayout {
        id: panelContent
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18
        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 12
            opacity: Math.min(1, root.headerReveal)
            // The ignition's montage break (docs/OVERDRIVE.md §2): the header jumps up along 78°, the field down.
            transform: [
                Translate { x: .2079 * Eigenmode.offset("header"); y: -.9781 * Eigenmode.offset("header") },
                Translate { y: root.headerRise },
                Translate { x: 14 * 0.2079 * ignitionLayer.jolt; y: -14 * 0.9781 * ignitionLayer.jolt }
            ]
            // FART's logo is the ignition key: hold it to ignite Overdrive, hold it again to cut.
            IgnitePlate {
                id: plate
                lease: root.lease
                fuseNow: fuse.now
            }
            FText {
                text: "FART"
                technical: true
                font.pixelSize: Design.caption
                font.letterSpacing: 4
                color: Design.muted
            }
            LeaseChip {
                id: leaseChip
                lease: root.lease
                open: root.leaseOpen
                onToggled: root.leaseOpen = !root.leaseOpen
            }
            // The command line takes the Search button's place; the host launcher is its fallthrough.
            CommandLine {
                id: cmdline
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                core: root.core
                panelOpen: root.shell.panelOpen
                roomIndexOf: id => root.roomIndex(id)
                onEscapeEmpty: root.shell.close()
                onTabOut: root.focusRoom()
            }
            FButton {
                symbol: "hub"
                hint: "The orbit: every room (Ctrl+M)"
                selected: root.orbitOpen
                implicitHeight: 30
                onClicked: root.toggleOrbit()
            }
            FButton {
                symbol: ViewState.fullscreen ? "fullscreen_exit" : "fullscreen"
                hint: ViewState.fullscreen ? "Back to the panel (F11)" : "Fullscreen (F11)"
                selected: ViewState.fullscreen
                implicitHeight: 30
                onClicked: ViewState.fullscreen = !ViewState.fullscreen
            }
            FButton {
                symbol: "adjust"
                hint: "Motion and appearance"
                implicitHeight: 30
                onClicked: root.preferencesOpen = !root.preferencesOpen
            }
            FButton {
                symbol: "folder_special"
                hint: "Optional field archive"
                implicitHeight: 30
                onClicked: root.archiveOpen = true
            }
            FButton {
                symbol: "power_settings_new"
                danger: true
                hint: "Open session menu; choose and confirm a power action"
                implicitHeight: 30
                onClicked: root.shell.openHost("power")
            }
            BatteryMark {
                battery: root.host.power.battery
            }
            // The clock (atlas #51): in Overdrive, events cross it by their weight (view/overdrive/ClockOccultation.qml).
            ClockOccultation {
                id: clockOccultation
                hours: Clock.hourStr
                minutes: Clock.minuteStr
            }
            Rectangle {
                implicitWidth: 1
                implicitHeight: 18
                color: Design.line
            }
            FButton {
                symbol: "close"
                label: "Close"
                hint: "Close"
                implicitHeight: 30
                onClicked: root.shell.close()
            }
        }
        FRule {
            Layout.fillWidth: true
            color: Qt.tint(Design.line, Qt.alpha(Design.accent, 0.6 * Motion.drive))
            transform: Translate { x: 14 * 0.2079 * ignitionLayer.jolt; y: -14 * 0.9781 * ignitionLayer.jolt }
            // The ignite hold burns along the rule, from the plate (D16).
            Fuse {
                id: fuse
                lease: root.lease
                width: parent.width
                height: parent.height
            }
        }
        // The field (MONTAGE.md §4): the shown room on its sheet, seen through the orbit camera. At rest the room
        // fills the field but for a thin margin; every switch flies out through the orbit and into the next room.
        Item {
            id: field
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            clip: true
            opacity: Math.min(1, root.roomReveal)
            transform: [
                Translate { x: .2079 * Eigenmode.offset("room"); y: -.9781 * Eigenmode.offset("room") },
                Translate { y: root.roomRise },
                Translate { x: -14 * 0.2079 * ignitionLayer.jolt; y: 14 * 0.9781 * ignitionLayer.jolt }
            ]
            readonly property real peekX: root.compact ? 10 : 16
            readonly property real peekY: root.compact ? 8 : 12
            readonly property real cw: Math.max(0, width - 2 * peekX)
            readonly property real ch: Math.max(0, height - 2 * peekY)
            // The cut wedge's width, the ribbon's, and the clear gutter beside each.
            readonly property real cut: root.compact ? 104 : 150
            readonly property real ribbon: root.indexCompact ? 40 : 60
            readonly property real gutter: 18
            readonly property real boxWidth: Math.max(0, cw - cut - ribbon - 2 * gutter)
            // Where a room's content starts on its sheet: clear of the wedge, or of the ribbon.
            function boxX(id) {
                return root.sideOf(id) === "left" ? cut + gutter : ribbon + gutter;
            }
            // The index ribbon stands on the edge the current room's wedge leaves free.
            readonly property real ribbonX: root.ribbonSide === "right" ? peekX + cw - ribbon : peekX
            // The orbit camera (docs/ORBIT.md §4). A switch zooms the room out into its tile until the whole
            // orbit shows (0 → a), drifts while a streak crosses to the chosen room (a → b), then dives into its
            // tile until it fills the field (b → 1). Opening the orbit is the first part alone, closing it and
            // landing from it the last. A key frame is "overview", "room:<id>" or, when a new flight starts
            // mid-way, the camera where it was, so a burst retargets and never jumps.
            property bool flying: false
            property var flight: null
            readonly property real ft: transfer.value
            readonly property var overviewCam: ({ x: width / 2, y: height / 2, s: 1 })
            function roomCam(id) {
                const r = root.orbit ? root.orbit.rectOf(id) : null;
                return r && r.w > 0 ? { x: r.x + r.w / 2, y: r.y + r.h / 2, s: width / r.w } : overviewCam;
            }
            function resolve(k) {
                return typeof k !== "string" ? k : k === "overview" ? overviewCam : roomCam(k.slice(5));
            }
            // Between two cameras: the scale moves geometrically, and the anchor point `a` (a room's tile)
            // slides on screen in a straight line, so a zoom shrinks the room in place instead of throwing it
            // off the field.
            function lerpCam(p, q, u, a) {
                const s = Math.exp(Math.log(p.s) + (Math.log(q.s) - Math.log(p.s)) * u);
                if (!a)
                    return { x: p.x + (q.x - p.x) * u, y: p.y + (q.y - p.y) * u, s: s };
                const sx = (a.x - p.x) * p.s + ((a.x - q.x) * q.s - (a.x - p.x) * p.s) * u;
                const sy = (a.y - p.y) * p.s + ((a.y - q.y) * q.s - (a.y - p.y) * p.s) * u;
                return { x: a.x - sx / s, y: a.y - sy / s, s: s };
            }
            function centreOf(id) {
                const r = root.orbit ? root.orbit.rectOf(id) : null;
                return r ? { x: r.x + r.w / 2, y: r.y + r.h / 2 } : null;
            }
            function inOut(u) { return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; }
            function span(a, b) { return Math.max(0, Math.min(1, (ft - a) / (b - a))); }
            readonly property var orbitCam: {
                if (orbitFree)
                    return spaceCam;
                const f = flight;
                if (!flying || !f)
                    return root.orbitOpen ? overviewCam : roomCam(root.shownPageId);
                const k0 = resolve(f.k0), k2 = resolve(f.k2);
                const k1 = f.kind === "switch" || f.kind === "open" ? overviewCam : k0;
                // Mid-switch the camera leans a little towards the room chosen.
                const k1d = f.kind === "switch" ? { x: k1.x + (k2.x - k1.x) * 0.12, y: k1.y + (k2.y - k1.y) * 0.12, s: 1.06 } : k1;
                const t = ft;
                // Out: anchored on the room being left (its tile shrinks in place); in: on the room arrived at.
                const leaving = typeof f.k0 === "string" && f.k0 !== "overview" ? centreOf(f.k0.slice(5)) : centreOf(f.to);
                if (f.a > 0 && t <= f.a) return lerpCam(k0, k1, inOut(t / f.a), leaving);
                if (f.b > f.a && t <= f.b) return lerpCam(k1, k1d, Math.sin((t - f.a) / (f.b - f.a) * Math.PI / 2), null);
                if (f.b >= 1) return k1d;
                const anchor = f.kind === "frame" ? null : typeof f.k2 === "string" && f.k2 !== "overview" ? centreOf(f.k2.slice(5)) : leaving;
                return lerpCam(k1d, k2, inOut((t - f.b) / (1 - f.b)), anchor);
            }
            // The shown room's tile through the camera, in field coordinates, at the field's aspect.
            readonly property var lensRect: {
                if (!root.orbit)
                    return { x: 0, y: 0, w: width, h: height };
                const r = root.orbit.rectOf(root.shownPageId), c = orbitCam;
                const w = r.w * c.s, h = w * height / Math.max(1, width);
                return { x: width / 2 + (r.x + r.w / 2 - c.x) * c.s - w / 2, y: height / 2 + (r.y + r.h / 2 - c.y) * c.s - h / 2, w: w, h: h };
            }
            // The room fades into its tile as it shrinks below about half the field, and is gone at tile size
            // (a tile is at most ~0.14 of the field), so its loops stop and the orbit is never drawn over.
            readonly property real roomOpacity: !root.orbit ? 1 : root.orbitOpen && !flying ? 0
                : Math.max(0, Math.min(1, (lensRect.w / Math.max(1, width) - 0.16) / 0.3))
            // The plane swings in flight, for depth: a switch flattens it to 31° at the middle of the crossing and
            // back; opening swoops down from 62° to 45°, closing rises again. At rest it is 45°.
            readonly property real orbitElevation: {
                const f = flight;
                if (!flying || !f) return 45;
                if (f.kind === "switch") return 45 - 14 * Math.sin(Math.PI * ft);
                if (f.kind === "open" && typeof f.k0 === "string") return 62 - 17 * inOut(ft);
                if (f.kind === "close") return 45 + 17 * inOut(ft);
                return 45;
            }
            // The tiles rise out of the plane as the orbit opens, one orbit after another.
            readonly property real orbitRise: flying && flight?.kind === "open" && typeof flight.k0 === "string" ? ft : 1
            // The dive's sound, as a switch turns into its dive.
            readonly property bool diving: flying && flight?.kind === "switch" && ft >= flight.b
            onDivingChanged: {
                if (!diving)
                    return;
                Feedback.play("orbit.land");
                // Overdrive: the room you arrive at sounds its chord, from where its tile stands (OVERDRIVE_IDEAS #46, #49).
                if (Motion.driving && flight) {
                    const n = root.navigationPages.findIndex(p => p.id === flight.to);
                    const at = fieldPoint(flight.to).x / Math.max(1, width);
                    if (n >= 0)
                        Feedback.play("chord." + n + "." + (at < 0.38 ? "l" : at > 0.62 ? "r" : "c"));
                }
            }
            // The room left stays live until it has shrunk away (B's finding: an early swap reads as a page change).
            readonly property bool swapReady: !flying || !flight || flight.kind !== "switch" || ft >= flight.a
            // A switch's length, as a share of Motion.transfer, by how far apart the two tiles stand at rest:
            // neighbours take 0.55 (550 ms), and tiles 1.6 orbit radii apart or more (Home to the far side)
            // the whole second. The orbit is loaded by then (flying makes it).
            function hop(from, to) {
                const o = root.orbit;
                if (!o || !o.outer)
                    return 1;
                const a = o.rectOf(from), b = o.rectOf(to);
                const d = Math.hypot(a.x + a.w / 2 - b.x - b.w / 2, a.y + a.h / 2 - b.y - b.h / 2);
                return 0.55 + 0.45 * Math.min(1, d / (1.6 * o.outer));
            }
            // kind: "switch", "open", "close", "land", or "return" (a pulled room springing back, silent).
            // `quiet` skips the sound.
            // kind "frame" glides to the camera `target` and stays free there.
            function fly(kind, to, quiet, target) {
                // Sound: the pull-back whooshes (not again while a switch is still pulling back, so a burst of
                // rooms is one whoosh); a dive straight in whooshes down at once.
                if (quiet || kind === "return") {
                } else if ((kind === "switch" || kind === "open") && !(flying && flight && ft < (flight.a || 1) * 0.9))
                    Feedback.play("orbit.out");
                else if (kind === "close" || kind === "land")
                    Feedback.play("orbit.land");
                fling.stop();
                const k0 = orbitFree || (flying && flight) ? { x: orbitCam.x, y: orbitCam.y, s: orbitCam.s }
                    : kind === "open" || kind === "switch" ? "room:" + root.shownPageId : "overview";
                const k2 = kind === "frame" ? target : kind === "open" ? "overview" : kind === "close" || kind === "return" ? "room:" + root.shownPageId : "room:" + to;
                const phases = kind === "switch" ? [0.34, 0.6] : kind === "open" ? [1, 1] : [0, 0];
                flight = { kind: kind, from: root.shownPageId, to: to, k0: k0, k2: k2, a: phases[0], b: phases[1] };
                flying = true;
                orbitFree = false;
                pullBase = null;
                transfer.enter = kind === "switch" ? Math.round(Motion.transfer * hop(flight.from, to)) : kind === "return" ? Motion.settle * 2 : Motion.zoom;
                transfer.value = 0;
                transfer.retarget();
            }
            // The free camera: while the user drags, pinches or wheels through space, the camera is theirs.
            // From a room, a drag pulls the room out of the field: it follows the pointer and shrinks into its
            // tile as the pull grows, revealing the orbit around it; letting go springs it back, or, past a
            // third of the way, opens the orbit there. In the orbit, a drag pans and the wheel zooms about the
            // pointer; letting go glides on and stays where it stops.
            property bool orbitFree: false
            property var spaceCam: ({ x: 0, y: 0, s: 1 })
            // A room being pulled: { id, s (its camera scale), tx, ty (the pull so far) }.
            property var pullBase: null
            property real pull: 0
            function grabOrbit() {
                if (orbitFree)
                    return;
                const loaded = root.orbit !== null;
                const snap = { x: orbitCam.x, y: orbitCam.y, s: orbitCam.s };
                if (flying) {
                    transfer.animation.stop();
                    flying = false;
                    flight = null;
                }
                fling.stop();
                orbitFree = true;
                spaceCam = loaded ? snap : roomCam(root.shownPageId);
                pullBase = root.orbitOpen ? null : { id: root.shownPageId, s: spaceCam.s, tx: 0, ty: 0 };
                pull = 0;
            }
            function orbitPan(dx, dy) {
                grabOrbit();
                const b = pullBase;
                if (!b) {
                    spaceCam = { x: spaceCam.x - dx / spaceCam.s, y: spaceCam.y - dy / spaceCam.s, s: spaceCam.s };
                    return;
                }
                b.tx += dx;
                b.ty += dy;
                pull = Math.min(1, Math.hypot(b.tx, b.ty) / (Math.min(width, height) * 0.6));
                const u = 1 - Math.pow(1 - pull, 2);
                const s = Math.exp(Math.log(b.s) * (1 - u));
                const r = root.orbit.rectOf(b.id);
                // The room's tile stays under the pointer: its centre sits at the field's centre plus the pull.
                spaceCam = { x: r.x + r.w / 2 - b.tx / s, y: r.y + r.h / 2 - b.ty / s, s: s };
            }
            // Zoom about a field point: the scene point under it stays under it. From far enough out to see
            // every system to close enough to read a moon; `glide` (the wheel, the keys) eases to the new
            // level over ~0.1 s instead of jumping, and further steps add to where it is heading.
            readonly property real zoomMin: 0.2
            readonly property real zoomMax: 10
            function orbitZoom(px, py, factor, glide) {
                grabOrbit();
                const b = pullBase;
                if (glide && !b && Motion.live(field)) {
                    zoomGlide.goal = Math.max(zoomMin, Math.min(zoomMax, (zoomGlide.running ? zoomGlide.goal : spaceCam.s) * factor));
                    zoomGlide.px = px;
                    zoomGlide.py = py;
                    zoomGlide.running = true;
                    return;
                }
                zoomTo(px, py, Math.max(zoomMin, Math.min(b ? b.s : zoomMax, spaceCam.s * factor)));
                if (b)
                    pull = Math.max(pull, 1 - Math.log(spaceCam.s) / Math.log(b.s));
                letGoOrbit.restart();
            }
            function zoomTo(px, py, s1) {
                const s0 = spaceCam.s;
                const ax = spaceCam.x + (px - width / 2) / s0, ay = spaceCam.y + (py - height / 2) / s0;
                spaceCam = { x: ax - (px - width / 2) / s1, y: ay - (py - height / 2) / s1, s: s1 };
                if (!root.orbit || pullBase)
                    return;
                // Zoomed far enough into a tile: dive into its room.
                root.orbit.zoomPoint = Qt.point(px, py);
                const enter = root.orbit.enterCandidate;
                if (root.orbitOpen && enter && enter.progress >= 1) {
                    zoomGlide.running = false;
                    root.navigate(enter.id);
                }
            }
            FrameAnimation {
                id: zoomGlide
                property real goal: 1
                property real px: 0
                property real py: 0
                running: false
                onTriggered: {
                    if (!field.orbitFree) { running = false; return; }
                    const s = field.spaceCam.s, k = 1 - Math.exp(-Math.min(0.05, frameTime) / 0.07);
                    const next = Math.exp(Math.log(s) + (Math.log(goal) - Math.log(s)) * k);
                    const done = Math.abs(Math.log(goal / next)) < 0.003;
                    field.zoomTo(px, py, done ? goal : next);
                    if (done)
                        running = false;
                }
            }
            Activity { name: "orbit.zoom"; running: zoomGlide.running }
            function orbitRelease(vx, vy) {
                letGoOrbit.stop();
                if (!orbitFree)
                    return;
                const b = pullBase;
                if (b) {
                    if (pull > 0.3) {
                        // The whoosh belongs to the commit, not to the pull: a pull let go early springs back silently.
                        root.orbitOpen = true;
                        fly("open", root.currentPage);
                    } else {
                        fly("return", root.currentPage);
                    }
                    return;
                }
                // In the orbit: glide on with the pointer's velocity, and stay where it stops.
                if (Motion.live(field) && Math.hypot(vx, vy) > 120)
                    fling.start(vx, vy);
            }
            Timer { id: letGoOrbit; interval: 260; onTriggered: field.orbitRelease(0, 0) }
            // Back to the whole main system from wherever the camera wandered (the compass, ".", a double-click).
            function recentre() {
                if (root.orbitOpen && orbitFree)
                    fly("open", root.currentPage, true);
            }
            // Every system in view at once: a glide to a camera that frames them all, which then stays free.
            function showGalaxy() {
                if (root.orbitOpen && root.orbit)
                    frameBox(root.orbit.galaxyBounds(), 1);
            }
            // A glide until the box { x0, y0, x1, y1 } fills the field right of the readout (which stays put
            // on the left), no closer than `most`; the camera stays free there.
            function frameBox(b, most) {
                if (!root.orbitOpen || !root.orbit)
                    return;
                const left = root.orbit.systemLeft, bottom = root.orbit.systemBottom;
                const s = Math.max(zoomMin, Math.min(most, Math.min((width - left) / (b.x1 - b.x0 + 60), (height - bottom) / (b.y1 - b.y0 + 60))));
                fly("frame", root.currentPage, true, { x: (b.x0 + b.x1) / 2 - left / 2 / s, y: (b.y0 + b.y1) / 2 + bottom / 2 / s, s: s });
            }
            // Keyboard zoom in the orbit, about the field's centre; it settles like a wheel.
            function zoomStep(factor) {
                if (root.orbitOpen)
                    orbitZoom(width / 2, height / 2, factor, true);
            }
            FrameAnimation {
                id: fling
                property real vx: 0
                property real vy: 0
                function start(x, y) { vx = x; vy = y; running = true; }
                running: false
                onTriggered: {
                    const dt = Math.min(0.05, frameTime);
                    if (!field.orbitFree) { running = false; return; }
                    const s = field.spaceCam.s;
                    field.spaceCam = { x: field.spaceCam.x - vx * dt / s, y: field.spaceCam.y - vy * dt / s, s: s };
                    const decay = Math.exp(-dt / 0.28);
                    vx *= decay;
                    vy *= decay;
                    if (Math.hypot(vx, vy) < 12)
                        running = false;
                }
            }
            Activity { name: "orbit.fling"; running: fling.running }
            Cue {
                id: transfer
                name: "orbit.transfer"
                on: true
                scope: root
                enter: Motion.transfer
                easing: Motion.linear
                onSettled: {
                    // A framed view stays where it was framed, the camera the user's again.
                    if (field.flight?.kind === "frame") {
                        field.spaceCam = field.flight.k2;
                        field.pullBase = null;
                        field.orbitFree = true;
                    }
                    field.flying = false;
                    field.flight = null;
                }
            }
            // The orbit, under the room: shown while open and while the camera flies through it; not created
            // otherwise (it costs nothing then).
            Loader {
                id: orbitLoader
                anchors.fill: parent
                active: root.orbitOpen || field.flying || field.orbitFree
                focus: root.orbitOpen
                sourceComponent: Component {
                    OrbitSystem {
                        pages: root.navigationPages
                        current: root.currentPage
                        angles: ViewState.orbitAngles
                        interactive: root.orbitOpen && !field.flying
                        camX: field.orbitCam.x
                        camY: field.orbitCam.y
                        camS: field.orbitCam.s
                        elevation: field.orbitElevation
                        rise: field.orbitRise
                        streakFrom: field.flight?.kind === "switch" ? field.flight.from : ""
                        streakTo: field.flight?.kind === "switch" ? field.flight.to : ""
                        streak: field.flight?.kind === "switch" ? field.span(field.flight.a - 0.06, field.flight.b + 0.14) : 0
                        host: root.host
                        core: root.core
                        shell: root.shell
                        spacious: (root.orbitOpen && !field.flying) || field.orbitFree
                        onChosen: id => root.navigate(id)
                        onRecentre: field.recentre()
                        onGalaxy: field.showGalaxy()
                        onSheet: root.sheetOpen = true
                        onFalseRoom: signature => root.enterFalseRoom(signature)
                        spaceBelow: root.spaceBelow
                        onFrameBox: box => field.frameBox(box, 1.8)
                        onZoomStep: factor => field.zoomStep(factor)
                    }
                }
                onLoaded: {
                    if (root.orbitOpen)
                        item.forceActiveFocus();
                    if (root.pendingFly !== "") {
                        item.seek(root.pendingFly);
                        root.pendingFly = "";
                    }
                }
            }
            // The lens: the room as seen by the orbit camera. At rest it is the whole field; in flight it is
            // the shown room's tile, zoomed, so the room shrinks into its tile and grows out of the next one.
            Item {
                id: lens
                x: field.lensRect.x
                y: field.lensRect.y
                width: field.lensRect.w
                height: field.lensRect.h
                clip: root.orbit !== null
                opacity: field.roomOpacity
                visible: opacity > 0
            Item {
                id: stage
                width: field.width
                height: field.height
                scale: lens.width / Math.max(1, field.width)
                transformOrigin: Item.TopLeft
                RoomSheet {
                    x: field.peekX
                    y: field.peekY
                    width: field.cw
                    height: field.ch
                    readonly property int index: root.navigationPages.findIndex(entry => entry.id === root.shownPageId)
                    entry: root.navigationPages[Math.max(0, index)]
                    plan: root.cuts[root.shownPageId] ?? ({})
                    number: String(Math.max(0, index)).padStart(2, "0")
                    cut: field.cut
                    sharedMask: sheetStratum.item?.mask ?? null
                }
                // The sheet alive (docs/OVERDRIVE.md §4): a drifting moiré on the room's sheet, under the room and kept
                // clear of its content by the keep-out mask, off the title wedge; it pulses with the bass and lights
                // up round the pointer. Not while the orbit is open.
                Stratum {
                    id: sheetStratum
                    name: "sheet"
                    scope: field
                    wanted: !root.orbitOpen
                    x: field.peekX
                    y: field.peekY
                    width: field.cw
                    height: field.ch
                    sourceComponent: SheetField {
                        content: pageViewport
                        contentRect: Qt.rect(field.boxX(root.shownPageId), 0, field.boxWidth, field.ch)
                        wedgeRect: Qt.rect(root.sideOf(root.shownPageId) === "left" ? 0 : field.cw - field.cut, 0, field.cut, field.ch)
                        phaseValue: sheetLoop.phase
                        bassLevel: root.musicBass
                        pointerAt: Qt.point(fieldHover.point.position.x - field.peekX, fieldHover.point.position.y - field.peekY)
                        lightLevel: fieldHover.hovered ? 1 : 0
                    }
                }
                // Kinetic lyrics (M9, docs/OVERDRIVE.md §6): in Overdrive, while something plays, the Media room's
                // title wedge sings. Under the room, over its sheet.
                Stratum {
                    name: "lyrics"
                    gpu: false
                    scope: field
                    x: field.peekX
                    y: field.peekY
                    width: field.cw
                    height: field.ch
                    wanted: root.shownPageId === "media" && (root.host.media?.active?.playing ?? false)
                    sourceComponent: KineticLyrics {
                        host: root.host
                        side: root.cuts.media.side
                        span: root.cuts.media.span
                        align: root.cuts.media.align
                        cut: field.cut
                    }
                }
                // The live room, laid over its sheet.
                Flickable {
                    id: pageViewport
                    x: field.peekX + field.boxX(root.shownPageId)
                    y: field.peekY
                    width: field.boxWidth
                    height: field.ch
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, root.shownSlot.item?.implicitHeight ?? 0)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    RoomSlot {
                        id: slotA
                        width: pageViewport.width
                        height: pageViewport.contentHeight
                        shown: root.frontIsA
                        entrance: entrance.value
                        onLoaded: root.stage(slotA)
                        onStatusChanged: if (status === Loader.Error) root.swap(slotA)
                    }
                    RoomSlot {
                        id: slotB
                        width: pageViewport.width
                        height: pageViewport.contentHeight
                        shown: !root.frontIsA
                        entrance: entrance.value
                        onLoaded: root.stage(slotB)
                        onStatusChanged: if (status === Loader.Error) root.swap(slotB)
                    }
                }
            }
            }
            // Overdrive's room switch: the room you leave seen through a gravitational lens at the room you chose
            // (M13), and at the end the destination's double image and the cut from where you asked (OVERDRIVE_IDEAS #38, #39).
            function fieldPoint(id) {
                const c = centreOf(id), cam = orbitCam;
                return c ? Qt.point(width / 2 + (c.x - cam.x) * cam.s, height / 2 + (c.y - cam.y) * cam.s) : Qt.point(width / 2, height / 2);
            }
            property real causeX: width / 2
            readonly property bool switching: flying && flight?.kind === "switch"
            onSwitchingChanged: if (switching) causeX = fieldHover.hovered ? fieldHover.point.position.x : width / 2
            Stratum {
                name: "lens"
                scope: field
                x: lens.x
                y: lens.y
                width: lens.width
                height: lens.height
                sourceComponent: LensPass {
                    target: lens
                    active: field.switching && field.ft < field.flight.a
                    strength: active ? Math.sin(Math.PI * Math.max(0, field.ft / field.flight.a)) : 0
                    lensAt: { const p = field.fieldPoint(field.flight?.to ?? root.shownPageId); return Qt.point(p.x - lens.x, p.y - lens.y); }
                    opacity: lens.opacity
                }
            }
            Stratum {
                name: "flightcuts"
                gpu: false
                scope: field
                z: 3
                anchors.fill: parent
                sourceComponent: FlightCuts {
                    t: field.ft
                    diveAt: field.flight?.b ?? 0.6
                    switching: field.switching
                    hop: field.flight ? field.hop(field.flight.from, field.flight.to) : 0.55
                    name: root.navigationPages.find(p => p.id === field.flight?.to)?.name ?? ""
                    causeX: field.causeX
                }
            }
            Stratum {
                name: "exchange"
                gpu: false
                scope: field
                z: 2.5
                anchors.fill: parent
                wanted: Motion.driving
                sourceComponent: CoordinateExchange {
                    t: field.ft
                    switching: field.switching
                    fromIndex: Math.max(0, root.navigationPages.findIndex(p => p.id === field.flight?.from))
                    toIndex: Math.max(0, root.navigationPages.findIndex(p => p.id === field.flight?.to))
                }
            }
            Stratum {
                name: "teleport"
                gpu: false
                scope: field
                z: 4
                anchors.fill: parent
                wanted: Motion.driving
                sourceComponent: Teleport {
                    t: field.ft
                    switching: field.switching
                    clock: Clock.hourStr + ":" + Clock.minuteStr
                    load: root.host.system?.cpu?.available ? root.host.system.cpu.usage : -1
                    unread: root.host.notifications?.items?.length ?? 0
                }
            }
            // Idle life on the sheet (MONTAGE.md §4.5): a faint scan line sweeping down the field and a few
            // motes rising through it. Transforms and opacity only; stopped when the panel folds, in the orbit
            // and with ambient detail off.
            IdleLoop { id: scanLoop; scope: field; name: "field.scan"; enabled: !root.orbitOpen; period: 9000 }
            IdleLoop { id: sheetLoop; scope: field; name: "sheet"; enabled: !root.orbitOpen; period: 16000 }
            HoverHandler { id: fieldHover; enabled: Motion.engaged }
            IdleLoop { id: moteLoop; scope: field; name: "field.motes"; enabled: !root.orbitOpen; period: 40000 }
            Binding { target: Motion; property: "ambient"; value: ViewState.ambientEnabled }
            Item {
                id: scan
                // 6.4 s down the field, then a 2.6 s rest out of sight.
                readonly property real p: Math.min(1, scanLoop.phase * 9000 / 6400)
                visible: scanLoop.running && p < 1
                width: field.width
                height: 44
                y: -height + (field.height + height) * (0.5 - 0.5 * Math.cos(Math.PI * p))
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.alpha(Design.accent, 0.07) }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(Design.accent, 0.28) }
            }
            Repeater {
                model: moteLoop.running ? 12 : 0
                Rectangle {
                    required property int index
                    readonly property real seed: (index * 0.61803398875) % 1
                    readonly property real rise: (moteLoop.phase * (3 + index % 3) + seed) % 1
                    x: field.width * (0.08 + 0.84 * seed)
                    y: field.height - (field.height + 10) * rise
                    width: 3 + (index % 3)
                    height: width
                    color: index % 4 === 0 ? Design.accent : Design.ink
                    opacity: 0.32 * Math.sin(Math.PI * rise)
                    rotation: 45 * (index % 2)
                }
            }
            // The sheet's darkened edges, as on a convex screen. Static, over everything in the field.
            Rectangle {
                width: field.width * 0.12
                height: field.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha("black", 0.16) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Rectangle {
                x: field.width - width
                width: field.width * 0.12
                height: field.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha("black", 0.16) }
                }
            }
            // The index ribbon, on the edge the current room leaves free; it crosses with the camera.
            Item {
                id: navigation
                x: field.ribbonX
                y: field.peekY + 8
                width: field.ribbon
                height: field.ch - 16
                opacity: root.orbitOpen || field.flying || field.orbitFree ? 0 : Math.min(1, root.headerReveal)
                visible: opacity > 0
                Column {
                    width: parent.width
                    spacing: 9
                    Repeater {
                        id: indexBands
                        model: root.navigationPages
                        IndexBand {
                            width: navigation.width
                            selected: root.currentPage === modelData.id
                            compact: root.indexCompact
                            // The flight's whoosh is the switch's sound.
                            onClicked: root.navigate(modelData.id)
                        }
                    }
                }
            }
            // Spatial input (docs/ORBIT.md §4): from a room, a drag (anywhere a control does not take the press; the
            // middle button anywhere), Ctrl+wheel or a pinch pulls the room out into the orbit; in the orbit, a drag
            // pans and the wheel zooms about the pointer.
            DragHandler {
                id: panDrag
                target: null
                enabled: !root.archiveOpen && !root.profileOpen
                acceptedButtons: Qt.LeftButton
                grabPermissions: root.orbitOpen ? PointerHandler.CanTakeOverFromAnything : PointerHandler.CanTakeOverFromHandlersOfDifferentType
                property point last: Qt.point(0, 0)
                onActiveChanged: {
                    last = Qt.point(0, 0);
                    if (!active)
                        field.orbitRelease(centroid.velocity.x, centroid.velocity.y);
                }
                onTranslationChanged: {
                    const dx = translation.x - last.x, dy = translation.y - last.y;
                    field.orbitPan(dx, dy);
                    last = translation;
                }
            }
            DragHandler {
                target: null
                enabled: !root.archiveOpen && !root.profileOpen
                acceptedButtons: Qt.MiddleButton
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                property point last: Qt.point(0, 0)
                onActiveChanged: {
                    last = Qt.point(0, 0);
                    if (!active)
                        field.orbitRelease(centroid.velocity.x, centroid.velocity.y);
                }
                onTranslationChanged: {
                    const dx = translation.x - last.x, dy = translation.y - last.y;
                    field.orbitPan(dx, dy);
                    last = translation;
                }
            }
            WheelHandler {
                target: null
                enabled: !root.archiveOpen && !root.profileOpen
                acceptedModifiers: Qt.ControlModifier
                onWheel: event => {
                    const f = Math.pow(1.0018, event.angleDelta.y);
                    field.orbitZoom(point.position.x, point.position.y, f, root.orbitOpen);
                }
            }
            WheelHandler {
                target: null
                enabled: root.orbitOpen
                acceptedModifiers: Qt.NoModifier
                onWheel: event => {
                    const f = Math.pow(1.0018, event.angleDelta.y);
                    field.orbitZoom(point.position.x, point.position.y, f, true);
                }
            }
            PinchHandler {
                target: null
                enabled: !root.archiveOpen && !root.profileOpen
                property real last: 1
                onActiveChanged: {
                    last = 1;
                    if (!active)
                        field.orbitRelease(0, 0);
                }
                onActiveScaleChanged: {
                    const f = activeScale / last;
                    field.orbitZoom(centroid.position.x, centroid.position.y, f);
                    last = activeScale;
                }
            }
        }
        FRule {
            id: footerRule
            transform: Translate { x: .2079 * Eigenmode.offset("footer"); y: -.9781 * Eigenmode.offset("footer") }
            Layout.fillWidth: true
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            FText {
                anchors.left: parent.left
                width: parent.width * 0.29
                text: (root.host.network.name || (root.host.network.kind === "ethernet" ? "ETHERNET" : "OFFLINE")).toUpperCase()
                technical: true
                font.pixelSize: Design.caption
                color: Design.faint
            }
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.width > 850
                text: "CTRL + 0—9   NAVIGATE   ·   CTRL + M   THE ORBIT   ·   CTRL + W   THE DESKS"
                technical: true
                font.pixelSize: Design.caption
                color: Design.faint
            }
            FText {
                anchors.right: parent.right
                width: parent.width * 0.32
                horizontalAlignment: Text.AlignRight
                readonly property var battery: root.host.power.battery
                readonly property bool draining: battery.available && !battery.pluggedIn
                text: battery.available ? Math.round(battery.level * 100) + "%   " + (battery.pluggedIn ? "EXTERNAL POWER" : "UNTETHERED") : "EXTERNAL POWER"
                technical: true
                font.pixelSize: Design.caption
                color: draining && battery.level <= 0.1 ? Design.danger : draining && battery.level <= 0.2 ? Design.warning : Design.muted
            }
        }
    }
    RoomPrecompiler {
        urls: Object.values(root.pageFiles).map(file => Qt.resolvedUrl(file))
        idle: root.shell.panelOpen && Motion.active === 0 && root.loadedPage === root.currentPage
    }
    Cue {
        id: entrance
        name: "shell.entrance"
        on: true
        scope: root
        enter: Motion.navigate
        easing: Motion.roles.navigate.easing
        overshoot: Motion.roles.navigate.overshoot
    }
    Shortcut {
        sequence: "F11"
        enabled: root.visible
        onActivated: ViewState.fullscreen = !ViewState.fullscreen
    }
    Shortcut {
        sequence: "Ctrl+M"
        enabled: root.visible && !root.archiveOpen && !root.profileOpen
        onActivated: root.toggleOrbit()
    }
    Shortcut {
        sequence: "Ctrl+0"
        enabled: root.visible && !root.archiveOpen
        onActivated: root.navigate("home")
    }
    // Ctrl+1 to Ctrl+9: one per room after Home, as many as there are (the Codex is 09).
    Instantiator {
        model: Math.min(9, root.pages.length)
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            enabled: root.visible && !root.archiveOpen
            onActivated: root.navigate(root.pages[index].id)
        }
    }
    // The ignition over the panel: its flash, the spin-down's sweep and the shockwave through the content.
    Ignition {
        id: ignitionLayer
        anchors.fill: parent
        z: 9
        target: panelContent
        origin: plate.mapToItem(root, plate.width / 2, plate.height / 2)
    }
    Loader {
        id: sheetLoader
        parent: field
        anchors.fill: parent
        z: 50
        active: root.sheetOpen
        sourceComponent: ContactSheet {
            host: root.host
            shell: root.shell
            onClosed: root.closeSheet()
        }
    }
    // Undeformed layout geometry, never transformed mapToItem feedback.
    Binding {
        target: Eigenmode; property: "elements"
        value: [
            {name:"header",x:panelContent.x+header.x,y:panelContent.y+header.y,width:header.width,height:header.height},
            {name:"room",x:panelContent.x+field.x,y:panelContent.y+field.y,width:field.width,height:field.height},
            {name:"footer",x:panelContent.x+footerRule.x,y:panelContent.y+footerRule.y,width:footerRule.width,height:Math.max(1,footerRule.height)}]
    }
    Stratum {
        anchors.fill: parent; name:"eigenmode"; gpu:false; wanted:Motion.overdrive
        sourceComponent: EigenImpulse {}
    }
    Stratum {
        anchors.fill: parent; name:"eigenmode.diagram"; gpu:false; wanted:Motion.overdrive
        sourceComponent: EigenDiagram { origin:Eigenmode.origin }
    }
    Loader {
        anchors.fill: parent
        active: Motion.overdrive && Motion.reduced && Eigenmode.still
        sourceComponent: EigenDiagram { origin:Eigenmode.origin; still:true }
    }
    Connections {
        target:root.core
        function onCue(data) { if(data.cue === "timer.done" || data.cue === "pomodoro.phase") Eigenmode.strike("timer");
            else if(data.cue === "quiet.device") Eigenmode.strike("device"); }
    }
    // The clock occultation's events (atlas #51): a countdown's end splits the clock with Timers' number; a device
    // crosses in front with Devices'; a new track passes behind with Media's. Only the change is noticed: no title is kept.
    // The False Room (W1): inside, until Esc, a click or a release.
    property bool falseRoomOpen: false
    property string falseRoomSignature: ""
    function enterFalseRoom(signature) {
        ViewState.falseRoomSpent = FalseRoomRules.spend(ViewState.falseRoomSpent, signature);
        root.falseRoomSignature = signature;
        root.falseRoomOpen = true;
    }
    Connections {
        target: Motion
        function onDrivingChanged() {
            if (!Motion.driving) {
                root.falseRoomOpen = false;
                root.matchCutRunning = false;
            }
        }
    }
    Stratum {
        name: "falseroom.inside"
        gpu: false
        wanted: root.falseRoomOpen
        z: 19
        x: panelContent.x + field.x
        y: panelContent.y + field.y
        width: field.width
        height: field.height
        sourceComponent: FalseRoomSheet {
            rooms: root.navigationPages.map(p => p.id)
            names: root.navigationPages.reduce((m, p) => { m[p.id] = p.name; return m; }, {})
            journey: root.core.journeyData
            devices: root.host.bluetooth.devices.filter(d => d.connected).length
            pressure: FalseRoomRules.pressure(root.host.system?.cpu?.available ? root.host.system.cpu.usage : NaN)
            signature: root.falseRoomSignature
            onExited: root.falseRoomOpen = false
        }
    }
    // Discovery (M15): a found fragment's whisper, one faint line low in the current room for about a second.
    Whisper {
        id: whisper
        z: 18
        // Centred in the quiet strip under the room, clear of the room's own wedge and index.
        x: panelContent.x + field.x + (field.width - width) / 2
        y: panelContent.y + field.y + field.height + 2
        open: root.shell.panelOpen
        pending: root.core?.discoveryData?.whisper ?? null
        onSeen: id => root.core.request("discovery.seen", { id: id })
    }
    readonly property Item discoveryWhisper: whisper
    // For tests and tools: the header's clock.
    readonly property Item headerClock: clockOccultation
    function roomIndex(id) { return Math.max(0, root.navigationPages.findIndex(p => p.id === id)); }
    Connections {
        target: root.core
        function onCue(data) {
            if (data.cue === "timer.done" || data.cue === "pomodoro.phase") clockOccultation.occult("timer", root.roomIndex("timers"));
            else if (data.cue === "quiet.device") clockOccultation.occult("device", root.roomIndex("devices"));
        }
    }
    readonly property string trackKey: { const a = root.host.media?.active; return a ? (a.id ?? "") + "\u0001" + (a.title ?? "") + "\u0001" + (a.artist ?? "") : ""; }
    property string lastTrackKey: ""
    onTrackKeyChanged: {
        if (root.lastTrackKey !== "" && root.trackKey !== "" && root.trackKey !== root.lastTrackKey)
            clockOccultation.occult("media", root.roomIndex("media"));
        root.lastTrackKey = root.trackKey;
    }
    property var eigenDevices: []
    property bool eigenDevicesReady: false
    function syncEigenDevices(initial) {
        const current=[];
        for(let i=0;i<root.host.bluetooth.devices.length;i++) {
            const d=root.host.bluetooth.devices[i];if(d.connected)current.push(d.id);
        }
        let added=false;
        for(let i=0;i<current.length;i++)if(root.eigenDevices.indexOf(current[i])<0)added=true;
        if(!initial && root.eigenDevicesReady && added){Eigenmode.strike("device");clockOccultation.occult("device", root.roomIndex("devices"));}
        root.eigenDevices=current;root.eigenDevicesReady=true;
    }
    Connections {
        target:root.host.bluetooth
        function onDevicesChanged() { root.syncEigenDevices(false); }
    }
    property var exhibitScore: null
    Connections {
        target: root.core
        function onCommand(action, page, from, extra) {
            if (action !== "exhibit") return;
            const geometry = [];
            for (const screen of Quickshell.screens) geometry.push(screen.x, screen.y, screen.width, screen.height);
            for (const w of (root.host.workspaces.windows ?? []).slice(0,12)) geometry.push(w.x ?? 0,w.y ?? 0,w.width ?? 0,w.height ?? 0);
            root.core.request("exhibit.prepare", {reduced: Motion.reduced || !Motion.overdrive || !root.visible,
                metadata: {geometry: geometry.concat((root.host.workspaces.windows ?? []).slice(0,12).reduce((all, w) => all.concat([w.x ?? 0,w.y ?? 0,w.width ?? 0,w.height ?? 0]), [])), devices: [root.host.bluetooth.devices.length, root.host.workspaces.workspaces.length],
                           spectrum: root.host.media.active?.playing ? (root.host.media.spectrum ?? []) : []}}, (ok, score) => {
                if (ok && score && Motion.overdrive && !Motion.reduced) root.exhibitScore = score;
            });
        }
    }
    Connections {
        target: Motion
        function onOverdriveChanged() { if (!Motion.overdrive) root.exhibitScore = null; }
        function onReducedChanged() { if (Motion.reduced) root.exhibitScore = null; }
    }
    Stratum {
        id: exhibitLayer
        anchors.fill: parent
        z: 1000
        name: "exhibit"
        gpu: false
        wanted: root.exhibitScore !== null && Motion.overdrive
        sourceComponent: Exhibit {
            score: root.exhibitScore
            core: root.core
            onClosed: { root.exhibitScore = null; root.focusCommandLine(); }
        }
    }
    // The heat haze over the header: as hard as the view is really working (a GPU stratum, Overdrive only).
    IdleLoop { id: shimmer; scope: header; name: "heat"; period: 2600 }
    Stratum {
        name: "heat"
        scope: header
        z: 1
        x: panelContent.x + header.x + 14 * 0.2079 * ignitionLayer.jolt
        y: panelContent.y + header.y + root.headerRise - 14 * 0.9781 * ignitionLayer.jolt
        width: header.width
        height: header.height
        opacity: header.opacity
        sourceComponent: HeatHaze {
            target: header
            heatLevel: root.heat.heat
            phaseValue: shimmer.phase
        }
    }
    // The ruler and the ballistic command line, in Overdrive (OVERDRIVE_IDEAS.md #61, #59).
    Stratum {
        name: "ruler"
        gpu: false
        scope: footerRule
        z: 8
        x: panelContent.x
        y: panelContent.y + footerRule.y - 40
        width: panelContent.width
        height: 56
        sourceComponent: RulerGesture {
            ruleY: 44
            rooms: root.navigationPages.map(p => p.id)
            onChosen: id => {
                Feedback.play("foley.ruler");
                root.navigate(id);
            }
        }
    }
    Stratum {
        name: "ballistic"
        gpu: false
        scope: header
        z: 12
        wanted: cmdline.inputFocused && (cmdline.hint?.candidates?.length ?? 0) > 1
        anchors.fill: parent
        sourceComponent: BallisticHints {
            line: cmdline
            originX: cmdline.mapToItem(root, Math.min(cmdline.width - 60, 12 + cmdline.text.length * 8), 0).x
            originY: cmdline.mapToItem(root, 0, cmdline.height).y + 8
        }
    }
    // The surveyor wanders the footer rule in Overdrive (docs/OVERDRIVE.md §7).
    Stratum {
        name: "surveyor"
        gpu: false
        scope: footerRule
        z: 8
        x: panelContent.x
        y: panelContent.y + footerRule.y + 4 - 60
        width: panelContent.width
        height: 60
        sourceComponent: Wanderer {
            room: root.shownSlot.item
            viewport: pageViewport
            roomId: root.shownPageId
            journey: root.core.journeyData
            rooms: root.navigationPages.map(p => p.id)
        }
    }
    // The lease manager, under the header's lease chip.
    Loader {
        active: root.leaseOpen
        z: 11
        x: Math.min(root.width - 24 - (item?.width ?? 0), leaseChip.mapToItem(root, 0, 0).x)
        y: leaseChip.mapToItem(root, 0, leaseChip.height).y + 12
        sourceComponent: LeasePanel {
            lease: root.lease
            heat: root.heat
            onClosed: root.leaseOpen = false
        }
    }
    Rectangle {
        visible: root.preferencesOpen
        x: 40
        y: Math.max(20, root.height - height - 80)
        width: 290
        height: prefs.implicitHeight + 32
        color: Design.surface
        radius: Design.radiusCard
        border.width: 1
        border.color: Design.line
        z: 10
        ColumnLayout {
            id: prefs
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 10
            RowLayout {
                FText {
                    text: "INSTRUMENT SETTINGS"
                    technical: true
                    color: Design.accent
                    Layout.fillWidth: true
                }
                FButton {
                    symbol: "close"
                    implicitHeight: 26
                    hint: "Close preferences"
                    onClicked: root.preferencesOpen = false
                }
            }
            FButton {
                Layout.fillWidth: true
                label: "CURVED SHELL · HARD INTERIOR"
                enabled: false
            }
            FButton {
                Layout.fillWidth: true
                label: Design.italic ? "Shell asides: italic" : "Shell asides: upright"
                selected: Design.italic
                onClicked: Config.options.appearance.fonts.italicMain = !Design.italic
            }
            FButton {
                Layout.fillWidth: true
                label: ViewState.motionEnabled ? "Motion: full" : "Motion: reduced"
                selected: ViewState.motionEnabled
                onClicked: ViewState.motionEnabled = !ViewState.motionEnabled
            }
            FButton {
                Layout.fillWidth: true
                label: ViewState.fullscreen ? "Size: fullscreen" : "Size: panel"
                selected: ViewState.fullscreen
                onClicked: ViewState.fullscreen = !ViewState.fullscreen
            }
            FButton {
                Layout.fillWidth: true
                label: ViewState.visualiserEnabled ? "Visualiser: on" : "Visualiser: off"
                selected: ViewState.visualiserEnabled
                onClicked: ViewState.visualiserEnabled = !ViewState.visualiserEnabled
            }
            FButton {
                Layout.fillWidth: true
                visible: Motion.overdrive
                label: ViewState.ambientEnabled ? "Ambient detail: on" : "Ambient detail: off"
                selected: ViewState.ambientEnabled
                onClicked: ViewState.ambientEnabled = !ViewState.ambientEnabled
            }
            FButton {
                Layout.fillWidth: true
                label: "Optional field archive"
                symbol: "folder_special"
                onClicked: {
                    root.preferencesOpen = false;
                    root.archiveOpen = true;
                }
            }
            FButton {
                Layout.fillWidth: true
                label: root.shell.wideLayout ? "Exterior: wide → clock" : "Exterior: clock → wide"
                onClicked: root.shell.toggleLayout()
            }
        }
    }
    // The archive and profile dialogs load by URL, so they compile when first opened instead of
    // with Shell on every cold start (branch coldstart).
    Loader {
        id: archiveDialog
        anchors.fill: parent
        active: root.archiveOpen
        z: 20
        source: "../rooms/FArchive.qml"
    }
    Connections {
        target: archiveDialog.item
        function onCloseRequested() { root.closeArchive(); }
    }
    Binding {
        target: archiveDialog.item
        when: archiveDialog.item !== null
        property: "discovery"
        value: root.core?.discoveryData ?? null
    }
    // Leaving the archive for the room still shown (atlas #40, view/overdrive/MatchCut.qml): in Overdrive, the room's
    // number, if an archive label on screen holds it, survives the cut and glides into the room's own.
    property bool matchCutRunning: false
    function closeArchive() {
        const cut = matchCut.item;
        if (cut && archiveDialog.item && !field.switching) {
            const number = String(root.roomIndex(root.shownPageId)).padStart(2, "0");
            const from = cut.pivotIn(archiveDialog.item, number), to = from ? cut.targetIn(field, number) : null;
            if (from && to) {
                root.matchCutRunning = true;
                cut.start(from, to);
            }
        }
        root.archiveOpen = false;
    }
    Stratum {
        id: matchCut
        name: "archive.matchcut"
        gpu: false
        // Kept while the cut runs past the archive's close; a flag, not item.running, so the loader doesn't feed itself.
        wanted: root.archiveOpen || root.matchCutRunning
        anchors.fill: parent
        z: 22
        sourceComponent: MatchCut { onFinished: root.matchCutRunning = false }
    }
    // In Overdrive the archive plays back from a worn tape (docs/OVERDRIVE.md §7): a GPU stratum draws it rolling
    // and tearing, with a harder tracking glitch every few seconds.
    IdleLoop { id: tapeRoll; scope: archiveDialog; name: "archive.tape"; enabled: root.archiveOpen; period: 7000 }
    Pulse {
        id: tapeGlitch
        name: "archive.glitch"
        scope: archiveDialog
        attack: Motion.scaled(40)
        release: Motion.scaled(520)
    }
    property int tapeTurn: tapeRoll.turns
    onTapeTurnChanged: if (tapeTurn % 2 === 1) tapeGlitch.trigger()
    Stratum {
        name: "tape"
        scope: archiveDialog
        wanted: root.archiveOpen && archiveDialog.status === Loader.Ready
        anchors.fill: archiveDialog
        z: 21
        sourceComponent: Tape {
            target: archiveDialog.item
            phaseValue: tapeRoll.phase
            glitchValue: tapeGlitch.value
        }
    }
    Loader {
        id: profileDialog
        anchors.fill: parent
        active: root.profileOpen
        z: 25
        source: "../rooms/FProfile.qml"
    }
    Binding { target: profileDialog.item; property: "username"; value: root.host.system.user; when: profileDialog.item !== null }
    Connections {
        target: profileDialog.item
        function onCloseRequested() { root.profileOpen = false; }
    }
    // Pointer presses hide the reticle; the press itself passes through to whatever is under it.
    MouseArea {
        anchors.fill: parent
        z: 30
        acceptedButtons: Qt.AllButtons
        propagateComposedEvents: true
        onPressed: mouse => {
            root.keyboardNav = false;
            mouse.accepted = false;
        }
    }
    // Tab and arrow moves keep the focused control in view; the reticle re-measures after the scroll.
    Connections {
        target: root.Window.window
        enabled: root.keyboardNav
        function onActiveFocusItemChanged() {
            root.reveal(root.Window.activeFocusItem);
            reticle.place();
        }
    }
    Reticle {
        id: reticle
        z: 31
        frame: root
        target: root.keyboardNav ? root.Window.activeFocusItem : null
        shown: root.keyboardNav && !root.archiveOpen && !root.profileOpen
    }
}
