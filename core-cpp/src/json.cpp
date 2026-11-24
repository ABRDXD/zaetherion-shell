// Ordered JSON with Python's semantics; see json.h.
#include "json.h"

#include "pystr.h"

#include <algorithm>
#include <charconv>
#include <clocale>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <locale.h>
#include <stdexcept>
#include <unordered_map>

namespace fart::json {

// --- Value -----------------------------------------------------------------------------------------------------

Value::Value(Array a) : v_(std::move(a)) {}
Value::Value(Object o) : v_(std::move(o)) {}

const Array& Value::as_array() const { return std::get<Array>(v_); }
Array& Value::as_array() { return std::get<Array>(v_); }
const Object& Value::as_object() const { return std::get<Object>(v_); }
Object& Value::as_object() { return std::get<Object>(v_); }

const Value* Value::find(std::string_view key) const {
    if (!is_object()) return nullptr;
    for (const auto& m : as_object())
        if (m.key == key) return &m.value;
    return nullptr;
}

Value* Value::find(std::string_view key) {
    return const_cast<Value*>(static_cast<const Value*>(this)->find(key));
}

Value& Value::set(std::string_view key, Value value) {
    if (Value* existing = find(key)) return *existing = std::move(value);
    auto& members = as_object();
    members.push_back(Member{std::string(key), std::move(value)});
    return members.back().value;
}

Value& Value::operator[](std::string_view key) {
    if (Value* existing = find(key)) return *existing;
    return set(key, Value());
}

bool Value::operator==(const Value& other) const { return v_ == other.v_; }

namespace {
// Python's numeric tower for ==: bool and int are ints, floats compare by value.
std::optional<long double> number(const Value& v) {
    switch (v.type()) {
    case Value::Type::Bool: return v.as_bool() ? 1.0L : 0.0L;
    case Value::Type::Int: return static_cast<long double>(v.as_int());
    case Value::Type::Float: return static_cast<long double>(v.as_float());
    default: return std::nullopt;
    }
}
}  // namespace

bool Value::py_equals(const Value& other) const {
    if (type() == Type::Int && other.type() == Type::Int) return as_int() == other.as_int();  // exact past 2^53
    auto a = number(*this), b = number(other);
    if (a && b) return *a == *b;
    if (type() != other.type()) return false;
    switch (type()) {
    case Type::Null: return true;
    case Type::BigInt: return as_bigint() == other.as_bigint();
    case Type::String: return as_string() == other.as_string();
    case Type::Array: {
        const auto &x = as_array(), &y = other.as_array();
        if (x.size() != y.size()) return false;
        for (size_t i = 0; i < x.size(); ++i)
            if (!x[i].py_equals(y[i])) return false;
        return true;
    }
    case Type::Object: {
        const auto &x = as_object(), &y = other.as_object();
        if (x.size() != y.size()) return false;
        for (const auto& m : x) {
            const Value* theirs = other.find(m.key);
            if (!theirs || !m.value.py_equals(*theirs)) return false;
        }
        return true;
    }
    default: return false;
    }
}

// --- Numbers ---------------------------------------------------------------------------------------------------

namespace {
locale_t c_locale() {
    static locale_t loc = newlocale(LC_ALL_MASK, "C", nullptr);
    return loc;
}
}  // namespace

std::optional<double> parse_double(std::string_view text) {
    while (!text.empty() && std::isspace(static_cast<unsigned char>(text.front()))) text.remove_prefix(1);
    while (!text.empty() && std::isspace(static_cast<unsigned char>(text.back()))) text.remove_suffix(1);
    if (text.empty()) return std::nullopt;
    std::string s(text);
    char* end = nullptr;
    double d = strtod_l(s.c_str(), &end, c_locale());  // correctly rounded; overflow gives ±inf, underflow ±0
    if (end != s.c_str() + s.size()) return std::nullopt;
    return d;
}

std::string py_repr(double x) {
    if (std::isnan(x)) return "nan";
    if (std::isinf(x)) return x > 0 ? "inf" : "-inf";
    char buf[64];
    auto r = std::to_chars(buf, buf + sizeof buf, x, std::chars_format::scientific);  // shortest round-trip
    std::string_view sci(buf, r.ptr - buf);
    bool negative = sci.front() == '-';
    if (negative) sci.remove_prefix(1);
    size_t e = sci.find('e');
    std::string digits;
    for (char c : sci.substr(0, e))
        if (c != '.') digits += c;
    int exp10 = std::atoi(std::string(sci.substr(e + 1)).c_str());
    int decpt = exp10 + 1;  // value = 0.DIGITS × 10^decpt, as Python's float_repr_style 'short' counts it
    int n = static_cast<int>(digits.size());
    std::string out = negative ? "-" : "";
    if (decpt <= -4 || decpt > 16) {
        out += digits[0];
        if (n > 1) out += "." + digits.substr(1);
        int shown = decpt - 1;
        char tail[16];
        std::snprintf(tail, sizeof tail, "e%c%02d", shown < 0 ? '-' : '+', std::abs(shown));
        out += tail;
    } else if (decpt <= 0) {
        out += "0." + std::string(-decpt, '0') + digits;
    } else if (decpt >= n) {
        out += digits + std::string(decpt - n, '0') + ".0";
    } else {
        out += digits.substr(0, decpt) + "." + digits.substr(decpt);
    }
    return out;
}

double py_round(double x, int ndigits) {
    // CPython's float.__round__: NDIGITS_MAX/MIN from the double's range; 0, nan and inf come back unchanged.
    constexpr int kMax = static_cast<int>((53 - (-1021)) * 0.30103);
    constexpr int kMin = -static_cast<int>((1024 + 1) * 0.30103);
    if (ndigits > kMax) return x;
    if (ndigits < kMin) return 0.0 * x;
    if (x == 0.0 || !std::isfinite(x)) return x;
    // The exact decimal value (glibc prints every digit of a double exactly), rounded half to even by hand.
    // to_chars, not printf: QCoreApplication sets the user's locale, and a comma locale would change "%f".
    static thread_local char buf[1500];
    auto printed = std::to_chars(buf, buf + sizeof buf, std::fabs(x), std::chars_format::fixed, 1100);
    std::string whole(buf, printed.ptr);
    size_t point = whole.find('.');
    std::string digits = whole.substr(0, point) + whole.substr(point + 1);
    long keep = static_cast<long>(point) + ndigits;  // how many leading digits survive
    std::string kept;
    if (keep >= 0) {
        kept = digits.substr(0, static_cast<size_t>(keep));
        char next = static_cast<size_t>(keep) < digits.size() ? digits[keep] : '0';
        bool rest = static_cast<size_t>(keep) + 1 < digits.size() &&
                    digits.find_first_not_of('0', keep + 1) != std::string::npos;
        bool odd = !kept.empty() && (kept.back() - '0') % 2 == 1;
        if (next > '5' || (next == '5' && (rest || odd))) {
            int i = static_cast<int>(kept.size()) - 1;
            while (i >= 0 && kept[i] == '9') kept[i--] = '0';
            if (i >= 0) ++kept[i];
            else kept.insert(kept.begin(), '1');
        }
    }
    if (kept.empty()) kept = "0";
    std::string text = (x < 0 ? "-" : "") + kept + "e" + std::to_string(-ndigits);
    return strtod_l(text.c_str(), nullptr, c_locale());
}

Value py_round_int(double x) {
    if (std::isnan(x)) throw std::domain_error("cannot convert float NaN to integer");
    if (std::isinf(x)) throw std::domain_error("cannot convert float infinity to integer");
    double r = std::nearbyint(x);  // the default rounding mode: to nearest, ties to even, as round() does
    if (std::fabs(r) < 9.2e18) return Value(static_cast<int64_t>(r));
    char buf[400];
    auto printed = std::to_chars(buf, buf + sizeof buf, r, std::chars_format::fixed, 0);  // integral, so exact
    return Value(BigInt{std::string(buf, printed.ptr)});
}

// --- Parser ----------------------------------------------------------------------------------------------------

namespace {

constexpr size_t kMaxIntDigits = 4300;  // sys.get_int_max_str_digits(): int() refuses longer text

// Length of one strictly valid UTF-8 sequence at s[i] (Python's strict decoder: no overlongs, no encoded
// surrogates, nothing past U+10FFFF), or 0.
size_t utf8_length(std::string_view s, size_t i) {
    auto at = [&](size_t k) { return i + k < s.size() ? static_cast<unsigned char>(s[i + k]) : 0u; };
    unsigned c = at(0);
    auto cont = [&](size_t k) { return (at(k) & 0xC0) == 0x80; };
    if (c < 0x80) return 1;
    if (c >= 0xC2 && c <= 0xDF) return cont(1) ? 2 : 0;
    if (c >= 0xE0 && c <= 0xEF) {
        unsigned c1 = at(1);
        if (c == 0xE0 && c1 < 0xA0) return 0;
        if (c == 0xED && c1 >= 0xA0) return 0;  // surrogates
        return cont(1) && cont(2) ? 3 : 0;
    }
    if (c >= 0xF0 && c <= 0xF4) {
        unsigned c1 = at(1);
        if (c == 0xF0 && c1 < 0x90) return 0;
        if (c == 0xF4 && c1 >= 0x90) return 0;
        return cont(1) && cont(2) && cont(3) ? 4 : 0;
    }
    return 0;
}

class Parser {
public:
    Parser(std::string_view s, int max_depth) : s_(s), max_depth_(max_depth) {}

    ParseResult run() {
        ParseResult result;
        skip_ws();
        Value v;
        if (value(v)) {
            skip_ws();
            if (i_ != s_.size()) fail("Extra data");
        }
        if (!error_.empty()) {
            result.error = error_ + " at byte " + std::to_string(i_);
            return result;
        }
        result.value = std::move(v);
        result.lone_surrogate = lone_;
        return result;
    }

private:
    std::string_view s_;
    size_t i_ = 0;
    int depth_ = 0, max_depth_;
    bool lone_ = false;
    std::string error_;

    bool fail(const char* why) {
        if (error_.empty()) error_ = why;
        return false;
    }
    bool more() const { return i_ < s_.size(); }
    char peek() const { return more() ? s_[i_] : '\0'; }
    void skip_ws() {
        while (more() && (s_[i_] == ' ' || s_[i_] == '\t' || s_[i_] == '\n' || s_[i_] == '\r')) ++i_;
    }
    bool literal(std::string_view word) {
        if (s_.substr(i_, word.size()) != word) return fail("Expecting value");
        i_ += word.size();
        return true;
    }

    bool value(Value& out) {
        switch (peek()) {
        case '"': {
            std::string text;
            if (!string(text)) return false;
            out = Value(std::move(text));
            return true;
        }
        case '{': return object(out);
        case '[': return array(out);
        case 'n': return literal("null") && (out = Value(), true);
        case 't': return literal("true") && (out = Value(true), true);
        case 'f': return literal("false") && (out = Value(false), true);
        case 'N': return literal("NaN") && (out = Value(std::nan("")), true);
        case 'I': return literal("Infinity") && (out = Value(HUGE_VAL), true);
        case '-':
            if (s_.substr(i_, 9) == "-Infinity") {
                i_ += 9;
                out = Value(-HUGE_VAL);
                return true;
            }
            return number(out);
        default:
            if (peek() >= '0' && peek() <= '9') return number(out);
            return fail("Expecting value");
        }
    }

    bool number(Value& out) {
        size_t start = i_;
        if (peek() == '-') ++i_;
        auto digit = [&] { return more() && s_[i_] >= '0' && s_[i_] <= '9'; };
        if (!digit()) return fail("Expecting value");
        if (s_[i_] == '0') ++i_;
        else while (digit()) ++i_;
        bool is_float = false;
        // As Python's scanner: a '.' or 'e' without digits ends the number there (and the caller then fails).
        if (peek() == '.' && i_ + 1 < s_.size() && s_[i_ + 1] >= '0' && s_[i_ + 1] <= '9') {
            is_float = true;
            ++i_;
            while (digit()) ++i_;
        }
        if (peek() == 'e' || peek() == 'E') {
            size_t save = i_++;
            if (peek() == '+' || peek() == '-') ++i_;
            if (digit()) {
                is_float = true;
                while (digit()) ++i_;
            } else {
                i_ = save;
            }
        }
        std::string_view text = s_.substr(start, i_ - start);
        if (is_float) {
            auto d = parse_double(text);
            if (!d) return fail("bad number");
            out = Value(*d);
            return true;
        }
        size_t ndigits = text.size() - (text.front() == '-' ? 1 : 0);
        if (ndigits > kMaxIntDigits) return fail("int too long");
        int64_t n = 0;
        auto r = std::from_chars(text.data(), text.data() + text.size(), n);
        if (r.ec == std::errc()) {
            out = Value(n);
        } else {  // beyond 64 bits: keep the digits, as Python's int does
            out = Value(BigInt{std::string(text)});
        }
        return true;
    }

    static int hex(char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    }
    bool hex4(size_t at, uint32_t& out) {
        if (at + 4 > s_.size()) return false;
        out = 0;
        for (size_t k = 0; k < 4; ++k) {
            int h = hex(s_[at + k]);
            if (h < 0) return false;
            out = out * 16 + static_cast<uint32_t>(h);
        }
        return true;
    }

    bool string(std::string& out) {
        ++i_;  // the opening quote
        while (true) {
            if (!more()) return fail("Unterminated string");
            unsigned char c = static_cast<unsigned char>(s_[i_]);
            if (c == '"') {
                ++i_;
                return true;
            }
            if (c < 0x20) return fail("Invalid control character");
            if (c == '\\') {
                if (i_ + 1 >= s_.size()) return fail("Unterminated string");
                char e = s_[i_ + 1];
                i_ += 2;
                switch (e) {
                case '"': out += '"'; break;
                case '\\': out += '\\'; break;
                case '/': out += '/'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'n': out += '\n'; break;
                case 'r': out += '\r'; break;
                case 't': out += '\t'; break;
                case 'u': {
                    uint32_t cp;
                    if (!hex4(i_, cp)) return fail("Invalid \\uXXXX escape");
                    i_ += 4;
                    if (cp >= 0xD800 && cp <= 0xDBFF && s_.substr(i_, 2) == "\\u") {
                        uint32_t low;
                        if (!hex4(i_ + 2, low)) return fail("Invalid \\uXXXX escape");
                        if (low >= 0xDC00 && low <= 0xDFFF) {
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                            i_ += 6;
                        }
                    }
                    if (cp >= 0xD800 && cp <= 0xDFFF) lone_ = true;
                    py::append_utf8(out, cp);
                    break;
                }
                default: return fail("Invalid \\escape");
                }
                continue;
            }
            size_t len = utf8_length(s_, i_);
            if (len == 0) return fail("invalid UTF-8");
            out.append(s_.substr(i_, len));
            i_ += len;
        }
    }

    bool enter() {
        if (++depth_ > max_depth_) return fail("too deep");
        return true;
    }

    bool array(Value& out) {
        if (!enter()) return false;
        ++i_;
        Array items;
        skip_ws();
        if (peek() == ']') {
            ++i_;
        } else {
            while (true) {
                Value item;
                if (!value(item)) return false;
                items.push_back(std::move(item));
                skip_ws();
                if (peek() == ',') {
                    ++i_;
                    skip_ws();
                    continue;
                }
                if (peek() == ']') {
                    ++i_;
                    break;
                }
                return fail("Expecting ',' delimiter");
            }
        }
        --depth_;
        out = Value(std::move(items));
        return true;
    }

    bool object(Value& out) {
        if (!enter()) return false;
        ++i_;
        Object members;
        std::unordered_map<std::string, size_t> index;  // only once an object grows past a handful of keys
        skip_ws();
        if (peek() == '}') {
            ++i_;
        } else {
            while (true) {
                if (peek() != '"') return fail("Expecting property name enclosed in double quotes");
                std::string key;
                if (!string(key)) return false;
                skip_ws();
                if (peek() != ':') return fail("Expecting ':' delimiter");
                ++i_;
                skip_ws();
                Value item;
                if (!value(item)) return false;
                // A repeated key keeps its first place and takes the last value, as dict assignment does.
                size_t found = members.size();
                if (members.size() > 8) {
                    if (index.empty())
                        for (size_t k = 0; k < members.size(); ++k) index.emplace(members[k].key, k);
                    if (auto it = index.find(key); it != index.end()) found = it->second;
                } else {
                    for (size_t k = 0; k < members.size(); ++k)
                        if (members[k].key == key) found = k;
                }
                if (found < members.size()) {
                    members[found].value = std::move(item);
                } else {
                    if (!index.empty()) index.emplace(key, members.size());
                    members.push_back(Member{std::move(key), std::move(item)});
                }
                skip_ws();
                if (peek() == ',') {
                    ++i_;
                    skip_ws();
                    continue;
                }
                if (peek() == '}') {
                    ++i_;
                    break;
                }
                return fail("Expecting ',' delimiter");
            }
        }
        --depth_;
        out = Value(std::move(members));
        return true;
    }
};

}  // namespace

ParseResult parse(std::string_view text, int max_depth) { return Parser(text, max_depth).run(); }

// --- Writer ----------------------------------------------------------------------------------------------------

namespace {

struct Options {
    bool ascii;
    bool sort;
    int indent;  // -1: none
    std::string_view item, key;
};

Options options(Style style) {
    switch (style) {
    case Style::Store: return {true, false, -1, ",", ":"};
    case Style::Protocol: return {false, false, -1, ",", ":"};
    case Style::Dms: return {false, false, 2, ",", ": "};
    case Style::Exhibit: return {true, true, -1, ",", ":"};
    case Style::Default: break;
    }
    return {true, false, -1, ", ", ": "};
}

void put_u(std::string& out, uint32_t unit) {
    char buf[16];
    std::snprintf(buf, sizeof buf, "\\u%04x", unit);
    out += buf;
}

void write_string(std::string& out, std::string_view s, bool ascii) {
    out += '"';
    size_t i = 0;
    while (i < s.size()) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if (c < 0x80) {  // ASCII, the same in both modes except DEL
            ++i;
            switch (c) {
            case '"': out += "\\\""; continue;
            case '\\': out += "\\\\"; continue;
            case '\b': out += "\\b"; continue;
            case '\f': out += "\\f"; continue;
            case '\n': out += "\\n"; continue;
            case '\r': out += "\\r"; continue;
            case '\t': out += "\\t"; continue;
            default: break;
            }
            if (c < 0x20 || (ascii && c == 0x7F)) put_u(out, c);
            else out += static_cast<char>(c);
            continue;
        }
        size_t start = i;
        uint32_t cp = py::next_code_point(s, i);
        bool surrogate = cp >= 0xD800 && cp <= 0xDFFF;
        if (ascii || surrogate) {  // non-ASCII mode: a lone surrogate is what backslashreplace writes
            if (cp >= 0x10000) {
                uint32_t v = cp - 0x10000;
                put_u(out, 0xD800 + (v >> 10));
                put_u(out, 0xDC00 + (v & 0x3FF));
            } else {
                put_u(out, cp);
            }
        } else {
            out.append(s.substr(start, i - start));
        }
    }
    out += '"';
}

void write_float(std::string& out, double d) {
    if (std::isnan(d)) out += "NaN";
    else if (std::isinf(d)) out += d > 0 ? "Infinity" : "-Infinity";
    else out += py_repr(d);
}

void newline(std::string& out, const Options& o, int level) {
    out += '\n';
    out.append(static_cast<size_t>(o.indent * level), ' ');
}

void write_value(std::string& out, const Value& v, const Options& o, int level) {
    switch (v.type()) {
    case Value::Type::Null: out += "null"; return;
    case Value::Type::Bool: out += v.as_bool() ? "true" : "false"; return;
    case Value::Type::Int: out += std::to_string(v.as_int()); return;
    case Value::Type::BigInt: out += v.as_bigint().digits; return;
    case Value::Type::Float: write_float(out, v.as_float()); return;
    case Value::Type::String: write_string(out, v.as_string(), o.ascii); return;
    case Value::Type::Array: {
        const auto& items = v.as_array();
        if (items.empty()) {
            out += "[]";
            return;
        }
        out += '[';
        for (size_t k = 0; k < items.size(); ++k) {
            if (k) out += o.item;
            if (o.indent >= 0) newline(out, o, level + 1);
            write_value(out, items[k], o, level + 1);
        }
        if (o.indent >= 0) newline(out, o, level);
        out += ']';
        return;
    }
    case Value::Type::Object: {
        const auto& members = v.as_object();
        if (members.empty()) {
            out += "{}";
            return;
        }
        std::vector<const Member*> order;
        order.reserve(members.size());
        for (const auto& m : members) order.push_back(&m);
        if (o.sort)  // code-point order: UTF-8 bytes compare the same way (std::string compares unsigned)
            std::sort(order.begin(), order.end(), [](const Member* a, const Member* b) { return a->key < b->key; });
        out += '{';
        for (size_t k = 0; k < order.size(); ++k) {
            if (k) out += o.item;
            if (o.indent >= 0) newline(out, o, level + 1);
            write_string(out, order[k]->key, o.ascii);
            out += o.key;
            write_value(out, order[k]->value, o, level + 1);
        }
        if (o.indent >= 0) newline(out, o, level);
        out += '}';
        return;
    }
    }
}

}  // namespace

std::string dump(const Value& value, Style style) {
    std::string out;
    write_value(out, value, options(style), 0);
    return out;
}

std::string encode_line(const Value& value) {
    std::string out = dump(value, Style::Protocol);
    out += '\n';
    return out;
}

}  // namespace fart::json
