.pragma library

// The periodic table: 118 elements as facts, one place. Pure: no QML, tested under Node (tests/test_elements.py).

var NAMES = "H Hydrogen 1.01|He Helium 4|Li Lithium 6.94|Be Beryllium 9.01|B Boron 10.81|C Carbon 12.01|N Nitrogen 14.01|O Oxygen 16|F Fluorine 19|Ne Neon 20.18|Na Sodium 22.99|Mg Magnesium 24.31|Al Aluminum 26.98|Si Silicon 28.09|P Phosphorus 30.97|S Sulfur 32.07|Cl Chlorine 35.45|Ar Argon 39.95|K Potassium 39.098|Ca Calcium 40.078|Sc Scandium 44.956|Ti Titanium 47.87|V Vanadium 50.94|Cr Chromium 52|Mn Manganese 54.94|Fe Iron 55.85|Co Cobalt 58.93|Ni Nickel 58.69|Cu Copper 63.55|Zn Zinc 65.38|Ga Gallium 69.72|Ge Germanium 72.63|As Arsenic 74.92|Se Selenium 78.96|Br Bromine 79.904|Kr Krypton 83.8|Rb Rubidium 85.47|Sr Strontium 87.62|Y Yttrium 88.91|Zr Zirconium 91.22|Nb Niobium 92.91|Mo Molybdenum 95.94|Tc Technetium 98|Ru Ruthenium 101.07|Rh Rhodium 102.91|Pd Palladium 106.42|Ag Silver 107.87|Cd Cadmium 112.41|In Indium 114.82|Sn Tin 118.71|Sb Antimony 121.76|Te Tellurium 127.6|I Iodine 126.9|Xe Xenon 131.29|Cs Cesium 132.91|Ba Barium 137.33|La Lanthanum 138.91|Ce Cerium 140.12|Pr Praseodymium 140.91|Nd Neodymium 144.24|Pm Promethium 145|Sm Samarium 150.36|Eu Europium 151.96|Gd Gadolinium 157.25|Tb Terbium 158.93|Dy Dysprosium 162.5|Ho Holmium 164.93|Er Erbium 167.26|Tm Thulium 168.93|Yb Ytterbium 173.04|Lu Lutetium 174.97|Hf Hafnium 178.49|Ta Tantalum 180.95|W Tungsten 183.84|Re Rhenium 186.21|Os Osmium 190.23|Ir Iridium 192.22|Pt Platinum 195.09|Au Gold 196.97|Hg Mercury 200.59|Tl Thallium 204.38|Pb Lead 207.2|Bi Bismuth 208.98|Po Polonium 209|At Astatine 210|Rn Radon 222|Fr Francium 223|Ra Radium 226|Ac Actinium 227|Th Thorium 232.04|Pa Protactinium 231.04|U Uranium 238.03|Np Neptunium 237|Pu Plutonium 244|Am Americium 243|Cm Curium 247|Bk Berkelium 247|Cf Californium 251|Es Einsteinium 252|Fm Fermium 257|Md Mendelevium 258|No Nobelium 259|Lr Lawrencium 262|Rf Rutherfordium 267|Db Dubnium 268|Sg Seaborgium 271|Bh Bohrium 272|Hs Hassium 277|Mt Meitnerium 278|Ds Darmstadtium 281|Rg Roentgenium 280|Cn Copernicium 285|Nh Nihonium 286|Fl Flerovium 289|Mc Moscovium 290|Lv Livermorium 293|Ts Tennessine 294|Og Oganesson 294".split("|");

var GROUPS = { alkali: "Li Na K Rb Cs Fr", alkaline: "Be Mg Ca Sr Ba Ra", nonmetal: "H C N O P S Se", halogen: "F Cl Br I At Ts",
               noble: "He Ne Ar Kr Xe Rn Og", metalloid: "B Si Ge As Sb Te", post: "Al Ga In Sn Tl Pb Bi Po Nh Fl Mc Lv" };
var LABELS = { alkali: "ALKALI METAL", alkaline: "ALKALINE EARTH", transition: "TRANSITION METAL", post: "POST-TRANSITION METAL", metalloid: "METALLOID",
               nonmetal: "NONMETAL", halogen: "HALOGEN", noble: "NOBLE GAS", lanthanide: "LANTHANIDE", actinide: "ACTINIDE" };

// Ground states that differ from the Madelung filling, as electrons per shell.
var EXCEPTIONS = { 24: [2, 8, 13, 1], 29: [2, 8, 18, 1], 41: [2, 8, 18, 12, 1], 42: [2, 8, 18, 13, 1], 44: [2, 8, 18, 15, 1], 45: [2, 8, 18, 16, 1], 46: [2, 8, 18, 18],
                   47: [2, 8, 18, 18, 1], 57: [2, 8, 18, 18, 9, 2], 58: [2, 8, 18, 19, 9, 2], 64: [2, 8, 18, 25, 9, 2], 78: [2, 8, 18, 32, 17, 1], 79: [2, 8, 18, 32, 18, 1],
                   89: [2, 8, 18, 32, 18, 9, 2], 90: [2, 8, 18, 32, 18, 10, 2], 91: [2, 8, 18, 32, 20, 9, 2], 92: [2, 8, 18, 32, 21, 9, 2], 93: [2, 8, 18, 32, 22, 9, 2],
                   96: [2, 8, 18, 32, 25, 9, 2], 103: [2, 8, 18, 32, 32, 8, 3] };

function shells(z) {
    if (EXCEPTIONS[z])
        return EXCEPTIONS[z].slice();
    // Madelung: subshells by n + l, then n.
    var order = [];
    for (var n = 1; n <= 7; n++)
        for (var l = 0; l < n && l < 4; l++)
            order.push({ n: n, cap: 2 * (2 * l + 1), key: (n + l) * 10 + n });
    order.sort(function (a, b) { return a.key - b.key; });
    var out = [0, 0, 0, 0, 0, 0, 0], left = z;
    for (var i = 0; i < order.length && left > 0; i++) {
        var put = Math.min(left, order[i].cap);
        out[order[i].n - 1] += put;
        left -= put;
    }
    while (out.length && out[out.length - 1] === 0)
        out.pop();
    return out;
}

// Where an element stands: col 1..18, row 1..9, the two f-block rows set apart at 8 and 9, as the table is drawn.
function place(z) {
    if (z === 1) return { col: 1, row: 1 };
    if (z === 2) return { col: 18, row: 1 };
    if (z <= 4) return { col: z - 2, row: 2 };
    if (z <= 10) return { col: z + 8, row: 2 };
    if (z <= 12) return { col: z - 10, row: 3 };
    if (z <= 18) return { col: z, row: 3 };
    if (z <= 36) return { col: z - 18, row: 4 };
    if (z <= 54) return { col: z - 36, row: 5 };
    if (z <= 57) return { col: z - 54, row: 6 };
    if (z <= 71) return { col: z - 54, row: 8 };
    if (z <= 86) return { col: z - 68, row: 6 };
    if (z <= 89) return { col: z - 86, row: 7 };
    if (z <= 103) return { col: z - 86, row: 9 };
    return { col: z - 100, row: 7 };
}

function category(symbol, z) {
    for (var key in GROUPS)
        if ((" " + GROUPS[key] + " ").indexOf(" " + symbol + " ") >= 0)
            return key;
    if (z >= 57 && z <= 71) return "lanthanide";
    if (z >= 89 && z <= 103) return "actinide";
    return "transition";
}

var ELEMENTS = NAMES.map(function (row, i) {
    var parts = row.split(" "), z = i + 1, at = place(z), kind = category(parts[0], z);
    return { z: z, symbol: parts[0], name: parts[1], mass: Number(parts[2]), col: at.col, row: at.row, kind: kind, label: LABELS[kind], shells: shells(z) };
});

// One element a day, the same all day: day number since the epoch, by a step coprime with 118 so neighbours don't follow.
function ofDay(date) {
    var day = Math.floor(date.getTime() / 86400000 - date.getTimezoneOffset() / 1440);
    return ELEMENTS[((day * 47) % 118 + 118) % 118];
}
