"""What the launcher shows inline above the apps (S6, Z27, Z28, Z195): a sum, a unit conversion, `>cmd`, `?term`.

Pure functions, no state: `core/launcher.py` turns their answers into rows and actions.

- **Calc.** A small arithmetic language parsed with Python's `ast` (never `eval`): numbers, + − × ÷ % ^ ( ),
  pi/e/tau and a fixed list of functions. A line is a sum only when it has an operator or a function call, so a
  bare number or a word such as "e" is left to the apps.
- **Units.** `<number> <unit> to|in|as|-> <unit>` within one dimension (length, mass, temperature, volume, area,
  speed, time, data). Physical factors, our own table.
- **Search.** `?term` opens the engine's results page; the engines are a setting (Z28: Brave Search by default).
"""
from __future__ import annotations

import ast
import math
import operator
import re
from urllib.parse import quote_plus

MAX_TEXT = 1000  # as long as a command line (core/command.py MAX_LINE)
MAX_EXPONENT = 10_000  # a power past this is not a sum anyone types; it would only burn time
SIGNIFICANT = 12  # digits shown for a sum
UNIT_SIGNIFICANT = 6  # digits shown for a conversion

# Calc

FUNCTIONS = {
    "sqrt": math.sqrt, "cbrt": lambda x: math.copysign(abs(x) ** (1 / 3), x), "abs": abs,
    "sin": math.sin, "cos": math.cos, "tan": math.tan, "asin": math.asin, "acos": math.acos, "atan": math.atan,
    "ln": math.log, "log": math.log, "log10": math.log10, "log2": math.log2, "exp": math.exp,
    "floor": math.floor, "ceil": math.ceil, "round": round, "pow": math.pow,
}
CONSTANTS = {"pi": math.pi, "π": math.pi, "e": math.e, "tau": math.tau}
BINARY = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
          ast.Mod: operator.mod, ast.Pow: operator.pow, ast.FloorDiv: operator.floordiv}
UNARY = {ast.UAdd: operator.pos, ast.USub: operator.neg}
CALC_CHARS = re.compile(r"[0-9a-zπ+\-*/%^×÷·().,\s_]+", re.IGNORECASE)


class _NotASum(Exception):
    pass


def _value(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)) and not isinstance(node.value, bool):
        return float(node.value)
    if isinstance(node, ast.Name) and node.id in CONSTANTS:
        return CONSTANTS[node.id]
    if isinstance(node, ast.UnaryOp) and type(node.op) in UNARY:
        return UNARY[type(node.op)](_value(node.operand))
    if isinstance(node, ast.BinOp) and type(node.op) in BINARY:
        left, right = _value(node.left), _value(node.right)
        if isinstance(node.op, ast.Pow) and abs(right) > MAX_EXPONENT:
            raise _NotASum
        return BINARY[type(node.op)](left, right)
    if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in FUNCTIONS
            and not node.keywords and 1 <= len(node.args) <= 2):
        return float(FUNCTIONS[node.func.id](*(_value(arg) for arg in node.args)))
    raise _NotASum


def _has_work(node) -> bool:
    """An operator or a call somewhere: "2", "-3" and "pi" alone are not sums."""
    return any(isinstance(n, (ast.BinOp, ast.Call)) for n in ast.walk(node))


def number(value: float, digits: int) -> str:
    if value == int(value) and abs(value) < 1e15:
        return str(int(value))
    return f"{value:.{digits}g}"


def calc(text: str) -> str | None:
    """The result of a sum as shown, or None when the text is not one."""
    line = text.strip()
    if not line or len(line) > MAX_TEXT or not CALC_CHARS.fullmatch(line):
        return None
    source = line.lower().replace("×", "*").replace("·", "*").replace("÷", "/").replace("^", "**").replace("π", "pi")
    try:
        tree = ast.parse(source, mode="eval").body
        if not _has_work(tree):
            return None
        value = _value(tree)
    except (SyntaxError, _NotASum, ArithmeticError, ValueError, TypeError, RecursionError, MemoryError):
        return None
    if isinstance(value, complex) or not math.isfinite(value):
        return None
    return number(value, SIGNIFICANT)


# Units: each dimension maps a unit to (factor to the base unit, the names it answers to).

DIMENSIONS = {
    "length": {"mm": (1e-3, "millimetre millimeter millimetres millimeters"), "cm": (1e-2, "centimetre centimeter centimetres centimeters"),
               "m": (1.0, "metre meter metres meters"), "km": (1e3, "kilometre kilometer kilometres kilometers"),
               "in": (0.0254, "inch inches"), "ft": (0.3048, "foot feet"), "yd": (0.9144, "yard yards"),
               "mi": (1609.344, "mile miles"), "nmi": (1852.0, "nautical")},
    "mass": {"mg": (1e-6, "milligram milligrams"), "g": (1e-3, "gram grams"), "kg": (1.0, "kilogram kilograms kilo kilos"),
             "t": (1e3, "tonne tonnes"), "oz": (0.028349523125, "ounce ounces"), "lb": (0.45359237, "lbs pound pounds"),
             "st": (6.35029318, "stone stones")},
    "volume": {"mL": (1e-3, "millilitre milliliter millilitres milliliters"), "L": (1.0, "litre liter litres liters"),
               "m³": (1e3, "m3"), "tsp": (0.00492892159375, "teaspoon teaspoons"),
               "tbsp": (0.01478676478125, "tablespoon tablespoons"), "fl oz": (0.0295735295625, "floz"),
               "cup": (0.2365882365, "cups"), "pt": (0.473176473, "pint pints"), "qt": (0.946352946, "quart quarts"),
               "gal": (3.785411784, "gallon gallons")},
    "area": {"mm²": (1e-6, "mm2"), "cm²": (1e-4, "cm2"), "m²": (1.0, "m2"), "ha": (1e4, "hectare hectares"),
             "km²": (1e6, "km2"), "in²": (0.00064516, "in2"), "ft²": (0.09290304, "ft2 sqft"),
             "ac": (4046.8564224, "acre acres"), "mi²": (2589988.110336, "mi2")},
    "speed": {"m/s": (1.0, "mps"), "km/h": (1 / 3.6, "kmh kph"), "mph": (0.44704, ""), "kn": (1852 / 3600, "knot knots"),
              "ft/s": (0.3048, "fps")},
    "time": {"ms": (1e-3, "millisecond milliseconds"), "s": (1.0, "sec secs second seconds"), "min": (60.0, "mins minute minutes"),
             "h": (3600.0, "hr hrs hour hours"), "d": (86400.0, "day days"), "wk": (604800.0, "week weeks"),
             "yr": (31556952.0, "year years")},
    "data": {"bit": (0.125, "bits"), "B": (1.0, "byte bytes"), "KB": (1e3, "kilobyte kilobytes"), "MB": (1e6, "megabyte megabytes"),
             "GB": (1e9, "gigabyte gigabytes"), "TB": (1e12, "terabyte terabytes"), "KiB": (1024.0, "kibibyte"),
             "MiB": (1024.0 ** 2, "mebibyte"), "GiB": (1024.0 ** 3, "gibibyte"), "TiB": (1024.0 ** 4, "tebibyte")},
}
TEMPERATURE = {"°C": "c °c celsius centigrade", "°F": "f °f fahrenheit", "K": "k kelvin"}


def _names() -> dict[str, tuple[str, str]]:
    """Every name a unit answers to, lower-cased → (dimension, unit)."""
    names = {}
    for dimension, units in DIMENSIONS.items():
        for unit, (_, aliases) in units.items():
            for name in (unit, *aliases.split()):
                names.setdefault(name.lower().replace(" ", ""), (dimension, unit))
    for unit, aliases in TEMPERATURE.items():
        for name in (unit, *aliases.split()):
            names.setdefault(name.lower(), ("temperature", unit))
    return names


UNIT_NAMES = _names()
CONVERSION = re.compile(r"(?P<amount>[-+]?(?:\d+(?:\.\d*)?|\.\d+))\s*(?P<source>(?:fl\s+)?[^\d\s.]\S*)\s+"
                        r"(?:to|in|as|into|->|→|=)\s+(?P<target>(?:fl\s+)?\S+)", re.IGNORECASE)


def _celsius(value: float, unit: str) -> float:
    return {"°C": value, "°F": (value - 32) * 5 / 9, "K": value - 273.15}[unit]


def _from_celsius(value: float, unit: str) -> float:
    return {"°C": value, "°F": value * 9 / 5 + 32, "K": value + 273.15}[unit]


def _unit(name: str) -> tuple[str, str] | None:
    return UNIT_NAMES.get(name.lower().replace(" ", ""))


def convert(text: str) -> dict | None:
    """{"amount", "source", "value", "target"} as shown, or None when the text is not a conversion."""
    if len(text) > MAX_TEXT:
        return None
    match = CONVERSION.fullmatch(text.strip())
    if not match:
        return None
    source, target = _unit(match["source"]), _unit(match["target"])
    if not source or not target or source[0] != target[0]:
        return None
    amount = float(match["amount"])
    if source[0] == "temperature":
        value = _from_celsius(_celsius(amount, source[1]), target[1])
    else:
        units = DIMENSIONS[source[0]]
        value = amount * units[source[1]][0] / units[target[1]][0]
    if not math.isfinite(value):
        return None
    return {"amount": number(amount, UNIT_SIGNIFICANT), "source": source[1],
            "value": number(value, UNIT_SIGNIFICANT), "target": target[1]}


# Search engines for `?term`: a name to show and the results address the term is appended to.

ENGINES = {
    "brave": ("Brave Search", "https://search.brave.com/search?q="),
    "duckduckgo": ("DuckDuckGo", "https://duckduckgo.com/?q="),
    "google": ("Google", "https://www.google.com/search?q="),
    "startpage": ("Startpage", "https://www.startpage.com/do/search?q="),
    "kagi": ("Kagi", "https://kagi.com/search?q="),
    "wikipedia": ("Wikipedia", "https://en.wikipedia.org/w/index.php?search="),
    "youtube": ("YouTube", "https://www.youtube.com/results?search_query="),
}


def search_url(engine: str, term: str) -> str:
    return ENGINES[engine][1] + quote_plus(term)
