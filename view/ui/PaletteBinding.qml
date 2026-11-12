import QtQuick
import qs.core.client

// One binding per view process; a lost connection cannot strand a transient preview.
Binding {
    required property CoreClient core
    target: Design
    property: "selection"
    value: core.connected ? core.paletteData?.colors ?? null : core.paletteData?.savedColors ?? null
}
