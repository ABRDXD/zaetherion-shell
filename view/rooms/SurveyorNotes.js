.pragma library
// The field archive's fiction (FArchive): notes on Mote, the surveyor, a small four-legged instrument
// issued no instructions. Gentle, but for one unsigned note (`wrong`) set between two sweet ones, for
// contrast. The archive's promise still holds for all of them: text only, no jump scares, no sound, no fake
// faults, nothing about the user's system. A note unlocks once `at` rooms have been surveyed (ViewState.visited, counted
// only while the archive is open), or, past the rooms, on the `day`th day the archive is opened (ViewState.surveyDays):
// the survey log goes on a little each day. A `record` is the survey team's own record, clinical and wrong, set
// between the surveyor's notes; field notes and records are numbered separately. Notes in display order.
const NOTES = [
    { at: 0, text: "The surveyor was issued four legs and no instructions.\nIt has been measuring the same doorway for several days." },
    { at: 1, text: "The doorway has been measured again.\nIt is still one doorway wide. The surveyor seemed relieved." },
    { at: 2, text: "Asked to survey the northern ridge, the surveyor surveyed its own tail.\nResult: one tail, slightly behind schedule." },
    { at: 3, text: "The surveyor has filed its first report.\nThe report is a leaf. The leaf has been accepted." },
    { at: 4, text: "The atlas contains no empty spaces.\nOnly places we have not assigned a name.\nThe surveyor has assigned all of them the name \"spot\"." },
    { at: 5, text: "It has learned the word \"orbit\".\nIt now walks in small circles around anything it likes.\nToday that was a cup. Yesterday, also the cup." },
    { at: 6, wrong: true, text: "Measured the doorway at 03:12. One doorway wide. One doorway deep.\nThere is only one doorway. We have counted twice. We have counted from the inside.\nThe surveyor has stopped measuring it. It sits facing it now, very still, tail going,\nthe way it sits when someone it loves is about to come home.\nNobody is due home.\nIf you hear it barking at the doorway, do not open the doorway to check its measurements." },
    { at: 6, text: "Spirit level: the surveyor tilts its head instead of the bubble.\nField opinion: everything is level if you lean." },
    { at: 7, text: "It tried to measure the fabric under the orbit and fell into the first well.\nIt is fine. It has named the well Gerald.\nIt visits Gerald most mornings." },
    { at: 8, text: "The instrument reports a small gravitational discrepancy.\nThe surveyor is sitting on the scale.\nIt will not get off the scale. It is very proud of the number." },
    { at: 9, text: "The tenth room is all keys.\nThe surveyor pressed one. Nothing opened. It pressed it again to be sure.\nIt has filed the room under \"doors, many, small\"." },
    { at: 10, text: "Full survey complete. Findings: ten rooms, one Home, and a very good stick.\nThe stick has been entered into the atlas under \"landmarks\"." },
    // The survey log: one or two entries a day, from the second day the archive is opened.
    { day: 2, text: "The surveyor found the end of the atlas.\nIt sniffed it, decided it was fine, and lay down on it.\nThe edge of the known world is now slightly warm." },
    { day: 2, record: true, text: "Headcount at the start of the survey: four.\nHeadcount this morning: four.\nNobody has left. Nobody has joined. The tents are pitched for five." },
    { day: 3, text: "The surveyor has been issued a hat.\nIt measures the hat every morning to make sure it is still hat-sized.\nThe hat is fine." },
    { day: 3, text: "It barked at Gerald. Gerald did not bark back.\nThe surveyor is counting this as a win." },
    { day: 4, record: true, text: "The north wall of Home measured 4.20 m on arrival.\nDaily since: 4.20, 4.20, 4.20, 4.21, 4.20.\nThe 4.21 was taken by a member of the team who was asleep in camp at the time." },
    { day: 4, text: "The surveyor tried to triangulate the moon.\nThere is no moon here. It used the clock instead, and is extremely proud." },
    { day: 5, text: "Lunch. The surveyor ate a pencil.\nAll measurements this afternoon are approximate and slightly chewed." },
    { day: 5, record: true, text: "Readings from the far side of the orbit arrive before the camera does.\nWe have stopped sending the camera.\nThe readings have not stopped arriving." },
    { day: 6, text: "It has started following the cursor around.\nWhen the cursor stops, it sits.\nWhen the cursor leaves, it waits at the edge of the screen until it comes back." },
    { day: 6, text: "Field opinion, recorded verbatim at its request: \"woof\".\nFiled under geology." },
    { day: 7, record: true, text: "There is a room between 09 and 00.\nYou pass through it every time the list wraps around.\nIt is very small. It is always the last place the surveyor looks before it lies down." },
    { day: 7, text: "The surveyor measured a sunbeam. The sunbeam moved. The surveyor moved with it.\nWe have lost the afternoon and gained a very warm surveyor." },
    { day: 8, text: "It brought back a stick from beyond the doorway.\nNone of us saw it go through the doorway.\nIt is a very good stick." },
    { day: 8, record: true, text: "Previous survey teams are listed in the margins of the atlas, each in a different hand.\nEach hand is a little closer to ours than the one before.\nThe last entry is not finished." },
    { day: 9, text: "The surveyor has learned to count to three.\nIt counts the team every evening: one, two, three.\nThen it looks at the doorway, and stops counting." },
    { day: 9, record: true, text: "We asked the surveyor how long it has been measuring the doorway.\nIt fetched the first note in this archive and dropped it at our feet.\nThe note is in our handwriting. None of us has written it yet." },
    { day: 10, text: "Day ten. The surveyor has been promoted to Senior Surveyor.\nIt has not noticed. It is asleep on the scale again.\nThe scale reads exactly what it read on day one. We are choosing to find this comforting." },
    { day: 10, record: true, text: "Final record. The atlas has a name for every place now.\nIt has started on the team.\nIt has the surveyor down as \"good\". We have not looked at what it has us down as." },
    // After the final record: the rooms have started to keep their own history (docs/OVERDRIVE.md §35–42).
    { day: 11, text: "The surveyor found a crease across Home and lay down in it.\nIt fits exactly. It has decided the crease was made for it.\nNobody folded Home. The crease is where the afternoon was." },
    { day: 12, text: "It barked at the processor plates for most of the morning.\nPlate 3 moved. The surveyor is taking full credit." },
    { day: 12, record: true, text: "The rooms' titles have begun to bear weight.\nThe T of TASKS is carrying more than it was drawn to carry.\nWe have measured it. We have not told it." },
    { day: 13, text: "It measured the dog-ear on the corner of Tasks.\nThen it folded one of its own ears to match.\nField opinion: matching." },
    { day: 14, record: true, text: "Final record, second page.\nThere is a day on the week strip inked darker than any we spent here.\nThe number in its corner is a room we have not opened yet." },
    { day: 14, text: "Two weeks. The surveyor has been issued a rubber stamp. It says GOOD.\nIt has stamped the atlas, the doorway, Gerald and the cup.\nIt has not stamped the second page. It walks around it." }
];
// Shown at night only (22:00–05:59), whatever has been surveyed. Not a fragment; not counted.
const NIGHT = "The surveyor is asleep on the theodolite.\nReadings taken tonight will be slightly warm.";
// In its own hand, once the whole survey is done.
const OWN = "TODAY I MESURED:\nDOOR (1)\nFLOR (A LOT)\nGERALD (DEEP)\nYOU (GOOD)\n— M.";
// What it says on the Tasks plate when poked, in turn.
const POKES = [
    "it has classified your work as terrain.",
    "it measured this list. it is list-sized.",
    "it would like to help. it cannot hold a pen.",
    "surveyor reports: list long. surveyor short.",
    "it has planted a very small flag on the top task.",
    "it is counting the done ones again. it likes those best.",
    "it sat on the late one. the late one is now warm.",
    "it is guarding the checkbox. from what, it will not say.",
    "it sniffed the deadline. the deadline smells like tuesday.",
    "it has dug a small hole in the margin. it is keeping a task in it for later.",
    "it measured you. you are you-sized. well done.",
    "it stared at the empty line under the list for a long time. then it wagged."
];
// What it says when poked while it wanders the panel in Overdrive (view/overdrive/Wanderer). The first is for a
// poke in the middle of a reading.
const STRAY = [
    "reading lost. it is fine. it will measure that again.",
    "it was not lost. it was surveying the long way round.",
    "everything here has been measured. some of it twice.",
    "it has found an edge. it is standing on it on purpose.",
    "it would like it noted that the floor is level if you lean.",
    "it is keeping out of your way. it is very good at that.",
    "the buttons are all button-sized. it checked.",
    "it planted a flag. the flag is also measuring.",
    "it hopped. it would like that measured."
];

function open(n, surveyed, days) {
    return n.day !== undefined ? days >= n.day : surveyed >= n.at;
}
// The notes out so far, each with its label's number: field notes (the unsigned one included) count
// from 000, the team's records from Ø-01.
function unlocked(surveyed, days) {
    let note = 0, record = 0;
    return NOTES.filter(n => open(n, surveyed, days ?? 0))
        .map(n => Object.assign({}, n, n.record ? { label: "SURVEY RECORD / Ø-" + String(++record).padStart(2, "0") }
                                              : { label: "FIELD NOTE / " + String(note++).padStart(3, "0") }));
}
// The next room threshold, or -1 when every room note is out.
function next(surveyed) {
    const n = NOTES.find(n => n.day === undefined && surveyed < n.at);
    return n ? n.at : -1;
}
// The next day with an entry, or -1 when the log is complete.
function nextDay(days) {
    const n = NOTES.find(n => n.day !== undefined && days < n.day);
    return n ? n.day : -1;
}
function night(hour) {
    return hour >= 22 || hour < 6;
}

// Revision history (atlas #58): each note's metadata line, from the day it was first filed (first seen in the
// archive, ViewState.noteFiled) and how long it has been read (the tape's seconds): "FILED 2026-11-09 · REV 3", a
// revision for every two minutes of reading. Once the survey has gone on IMPOSSIBLE_AFTER days, one note (fixed by the
// survey's seed) has a revision dated before it was filed. Nothing remarks on it.
const IMPOSSIBLE_AFTER = 21;
function dayOffset(day, days) {
    const p = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day || "");
    if (!p) return "";
    const d = new Date(Number(p[1]), Number(p[2]) - 1, Number(p[3]) + days);
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}
function labelHash(label) {
    let h = 17;
    for (let i = 0; i < label.length; i++) h = (h * 31 + label.charCodeAt(i)) % 100003;
    return h;
}
// The metadata line for a note, or "" before it is filed.
function revision(label, filed, seconds, surveyDays, seed, labels) {
    if (!filed) return "";
    const rev = 1 + Math.floor((seconds || 0) / 120);
    let line = "FILED " + filed + " · REV " + rev;
    if (surveyDays >= IMPOSSIBLE_AFTER && labels && labels.length > 0) {
        const chosen = labels[(seed >>> 0) % labels.length];
        if (chosen === label)
            line += " · REV " + (rev + 1) + " " + dayOffset(filed, -(3 + labelHash(label) % 20));
    }
    return line;
}
