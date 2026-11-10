//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
// FART against the inert fixture host: no host commands, playback or system changes.
import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
ShellRoot {
    // Connects to a core only when FART_CORE_SOCKET names one; otherwise the core-backed rooms show it offline.
    CoreClient { id: core; host: host }
    FixtureAdapter { id: host }
    Overlay { host: host; core: core }
}
