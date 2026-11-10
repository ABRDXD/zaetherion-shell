//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import qs.adapters.serpantinum
import qs.core.client
import qs.view.shell
ShellRoot {
    CoreClient { id: core; host: host }
    SerpantinumAdapter { id: host; core: core }
    Overlay { host: host; core: core }
}
