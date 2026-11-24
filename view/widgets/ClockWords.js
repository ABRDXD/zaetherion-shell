// The desktop clock's words (Day index and Offcut, Astra's studies on codex/widget-study). Pure: a Date in,
// strings out, so tests/test_desktop_clock.py can check them under Node. English, as the studies set them.
.pragma library

var DAYS = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
var MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
var MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
                   "November", "December"];

function weekday(date) { return DAYS[date.getDay()]; }

// Day index sets the weekday on two planes: its own part ("WEDNES") and the shared "DAY".
function weekdayHead(date) {
    var name = weekday(date);
    return name.slice(0, name.length - 3);
}

// Monday to Sunday of the date's week, as day numbers; `today` is today's place in it (0-6).
function week(date) {
    var offset = (date.getDay() + 6) % 7;
    var days = [];
    for (var i = 0; i < 7; ++i) {
        var d = new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset + i, 12);
        days.push(d.getDate());
    }
    return { days: days, today: offset };
}

// Angular: "24 NOV 2026", short "24 NOV". Fluid: "24 November 2026", short "24 Nov".
function dateLabel(date, fluid, brief) {
    var d = String(date.getDate());
    if (fluid)
        return brief ? d + " " + MONTH_NAMES[date.getMonth()].slice(0, 3) : d + " " + MONTH_NAMES[date.getMonth()] + " " + date.getFullYear();
    return brief ? d + " " + MONTHS[date.getMonth()] : d + " " + MONTHS[date.getMonth()] + " " + date.getFullYear();
}

// "– 07:24 –" in 24 h; "– 7:24 AM –" in 12 h.
function timeLabel(date, hours) {
    var h = date.getHours(), m = String(date.getMinutes()).padStart(2, "0");
    if (hours === 12)
        return "– " + ((h + 11) % 12 + 1) + ":" + m + (h < 12 ? " AM" : " PM") + " –";
    return "– " + String(h).padStart(2, "0") + ":" + m + " –";
}

// The face choices, at the study's values (codex/widget-editor-study FaceStrip.qml): day spacing Close / Original /
// Wide as a letter-spacing offset, and the ink (Angular: the backing and Æ stamp; Fluid: the lettering).
function tracking(spacing) { return spacing === "close" ? -8 : spacing === "wide" ? 3 : 0; }
function ink(choice, fluid) {
    var inks = fluid ? { original: "#30294d", copper: "#603329", tide: "#174652" }
                     : { original: "#ffd064", copper: "#ff9d78", tide: "#81dece" };
    return inks[choice] || inks.original;
}
