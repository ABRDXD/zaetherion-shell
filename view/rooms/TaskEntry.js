.pragma library

// The Tasks room's entry line, read the same way as the `task` verb (core/verbs/tasks.py):
// words starting with @ name a list, one ! word is a due date, the rest is the text. Pure; `today`
// is passed in as a local Date so tests can fix it.

const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const SHORT_DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

function pad(n) {
    return String(n).padStart(2, "0");
}

function isoDate(day) {
    return day.getFullYear() + "-" + pad(day.getMonth() + 1) + "-" + pad(day.getDate());
}

function addDays(day, count) {
    return new Date(day.getFullYear(), day.getMonth(), day.getDate() + count);
}

// Monday is 0, as in Python's date.weekday().
function weekday(day) {
    return (day.getDay() + 6) % 7;
}

// The due word without its "!", resolved against `today`; null when it is not a date.
function resolveDue(word, today) {
    word = word.toLowerCase();
    if (word === "today" || word === "tod")
        return isoDate(today);
    if (word === "tomorrow" || word === "tom" || word === "tmr")
        return isoDate(addDays(today, 1));
    if (word.length >= 3) {
        for (let index = 0; index < WEEKDAYS.length; index++) {
            if (WEEKDAYS[index].startsWith(word)) {
                // The next one: !fri on a Friday is a week away (!today is today).
                return isoDate(addDays(today, ((index - weekday(today) - 1) % 7 + 7) % 7 + 1));
            }
        }
    }
    const relative = /^\+(\d{1,3})([dw])$/.exec(word);
    if (relative)
        return isoDate(addDays(today, Number(relative[1]) * (relative[2] === "w" ? 7 : 1)));
    if (/^\d{4}-\d{2}-\d{2}(t\d{2}:\d{2})?$/.test(word))
        return word.toUpperCase();
    return null;
}

// {text, list, due, error}: list is the name as typed (or null), due an ISO date (or null).
function parse(line, today) {
    const text = [];
    let list = null;
    let due = null;
    let error = "";
    for (const word of line.trim().split(/\s+/)) {
        if (!word)
            continue;
        if (word.length > 1 && word[0] === "@") {
            if (list !== null)
                error = error || "one @list per task";
            list = word.slice(1);
        } else if (word.length > 1 && word[0] === "!") {
            const resolved = resolveDue(word.slice(1), today);
            if (resolved === null)
                error = error || "not a due date: " + word;
            else if (due !== null)
                error = error || "one !due per task";
            else
                due = resolved;
        } else {
            text.push(word);
        }
    }
    return { text: text.join(" "), list, due, error };
}

// Whole days from today to the due date (negative when overdue).
function daysUntil(due, today) {
    const parts = /^(\d{4})-(\d{2})-(\d{2})/.exec(due);
    if (!parts)
        return null;
    const day = new Date(Number(parts[1]), Number(parts[2]) - 1, Number(parts[3]));
    const base = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    return Math.round((day - base) / 86400000);
}

// "overdue", "today", "soon" (within a week), "later", or "" without a date.
function state(due, today) {
    const days = due ? daysUntil(due, today) : null;
    if (days === null)
        return "";
    return days < 0 ? "overdue" : days === 0 ? "today" : days < 7 ? "soon" : "later";
}

// The due date as the room prints it: TODAY, TOMORROW, a weekday within the week, else "13 NOV".
// Overdue dates read as they are, with how late beside them ("2 D LATE"): stated, not scolded.
function label(due, today) {
    const days = due ? daysUntil(due, today) : null;
    if (days === null)
        return "";
    const time = due.length > 10 ? " " + due.slice(11, 16) : "";
    if (days === 0)
        return "TODAY" + time;
    if (days === 1)
        return "TOMORROW" + time;
    const day = addDays(new Date(today.getFullYear(), today.getMonth(), today.getDate()), days);
    if (days < 0)
        return pad(day.getDate()) + " " + MONTHS[day.getMonth()] + " · " + (-days) + " D LATE";
    if (days < 7)
        return SHORT_DAYS[day.getDay()] + time;
    return pad(day.getDate()) + " " + MONTHS[day.getMonth()] + time;
}

// Neglect patina (atlas #25): how recopied a task looks. Not an alarm colour: degradation, as if the line had been
// copied out again each day it was left. 0 is clean. An overdue task's patina is its days late; an undated open task
// starts to weather after two weeks, at half the rate. Done tasks are clean.
function patina(task, today) {
    if (!task || task.done)
        return 0;
    const days = task.due ? daysUntil(task.due, today) : null;
    if (days !== null && days < 0)
        return -days;
    if (days === null && Number.isFinite(task.created)) {
        const age = (new Date(today.getFullYear(), today.getMonth(), today.getDate()) - task.created) / 86400000;
        return Math.max(0, Math.floor((age - 14) / 2));
    }
    return 0;
}
// Which way a task's copies slip, fixed by its id: 1 or -1.
function patinaSide(id) {
    let h = 7;
    for (let i = 0; i < String(id).length; i++)
        h = (h * 31 + String(id).charCodeAt(i)) % 104729;
    return h % 2 ? 1 : -1;
}
// How far, in px: at least half a pixel from the first day, never more than 2.2.
function patinaShift(level) {
    return level <= 0 ? 0 : Math.min(2.2, 0.5 + 0.35 * Math.sqrt(level));
}

// Completion negative space (atlas #26): a task finished today keeps its place in the open list as an empty cut-out,
// until the day turns over.
function vanishedToday(task, today) {
    if (!task || !task.done || !Number.isFinite(task.doneAt))
        return false;
    const d = new Date(task.doneAt);
    return d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate();
}
