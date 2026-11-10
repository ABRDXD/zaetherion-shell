import QtQuick
import qs.view.contract

// Serpantinum 2.4.1 has no motion tokens. These are the values its popups and controls use
// inline (read-only survey of 186 QML files, docs/CUES.md §15.1). Static: no files or processes.
MotionDomain {
    available: true
    roles: ({
        feedback: { duration: 150, easing: Easing.OutCubic },
        navigate: { duration: 400, easing: Easing.OutQuart, travel: 15, axis: "y", fromOpacity: 0 },
        swap: { duration: 400, easing: Easing.OutQuart },
        settle: { duration: 250, easing: Easing.OutCubic },
        tint: { duration: 150, easing: Easing.Linear },
        emphasis: { duration: 250, easing: Easing.OutQuint },
        // Popup intro: body 800 ms, header +100 ms, room +200 ms, in a 1000 ms driver.
        unfold: { duration: 1000,
            body: { start: 0, end: 0.8, easing: Easing.OutQuart, rise: 20, scale: 0.95 },
            header: { start: 0.1, end: 0.9, easing: Easing.OutBack, overshoot: 1.2, rise: 15 },
            room: { start: 0.2, end: 1, easing: Easing.OutExpo, rise: 20 } },
        // Popup close: 150–160 ms with accelerating curves; retracing the Out curves gives them.
        fold: { duration: 160 }
    })
}
