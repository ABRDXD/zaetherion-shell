#include "pystr.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <optional>
#include <stdexcept>

namespace fart::py {

uint32_t next_code_point(std::string_view s, size_t& i) {
    unsigned char c = static_cast<unsigned char>(s[i]);
    auto cont = [&](size_t k) { return i + k < s.size() && (static_cast<unsigned char>(s[i + k]) & 0xC0) == 0x80; };
    auto bits = [&](size_t k) { return static_cast<uint32_t>(static_cast<unsigned char>(s[i + k]) & 0x3F); };
    uint32_t cp;
    if (c < 0x80) {
        cp = c;
        i += 1;
    } else if (c >= 0xC0 && c < 0xE0 && cont(1)) {
        cp = ((c & 0x1Fu) << 6) | bits(1);
        i += 2;
    } else if (c >= 0xE0 && c < 0xF0 && cont(1) && cont(2)) {
        cp = ((c & 0x0Fu) << 12) | (bits(1) << 6) | bits(2);
        i += 3;
    } else if (c >= 0xF0 && c < 0xF8 && cont(1) && cont(2) && cont(3)) {
        cp = ((c & 0x07u) << 18) | (bits(1) << 12) | (bits(2) << 6) | bits(3);
        i += 4;
    } else {
        cp = 0xFFFD;
        i += 1;
    }
    return cp;
}

void append_utf8(std::string& out, uint32_t cp) {  // WTF-8: surrogate code points get their three bytes too
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xF0 | (cp >> 18));
        out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
}

bool utf8_valid(std::string_view s) {
    size_t i = 0;
    auto at = [&](size_t k) { return i + k < s.size() ? static_cast<unsigned char>(s[i + k]) : 0u; };
    auto cont = [&](size_t k) { return (at(k) & 0xC0) == 0x80; };
    while (i < s.size()) {
        unsigned c = at(0);
        size_t len = 0;
        if (c < 0x80) len = 1;
        else if (c >= 0xC2 && c <= 0xDF) len = cont(1) ? 2 : 0;
        else if (c >= 0xE0 && c <= 0xEF) {
            unsigned c1 = at(1);
            bool bad = (c == 0xE0 && c1 < 0xA0) || (c == 0xED && c1 >= 0xA0);
            len = !bad && cont(1) && cont(2) ? 3 : 0;
        } else if (c >= 0xF0 && c <= 0xF4) {
            unsigned c1 = at(1);
            bool bad = (c == 0xF0 && c1 < 0x90) || (c == 0xF4 && c1 >= 0x90);
            len = !bad && cont(1) && cont(2) && cont(3) ? 4 : 0;
        }
        if (len == 0) return false;
        i += len;
    }
    return true;
}

bool is_space(uint32_t cp) {
    // [c for c in range(0x110000) if chr(c).isspace()], Python 3.14
    return (cp >= 0x09 && cp <= 0x0D) || (cp >= 0x1C && cp <= 0x20) || cp == 0x85 || cp == 0xA0 || cp == 0x1680 ||
           (cp >= 0x2000 && cp <= 0x200A) || cp == 0x2028 || cp == 0x2029 || cp == 0x202F || cp == 0x205F || cp == 0x3000;
}

int decimal(uint32_t cp) {
    // The code points whose unicodedata.decimal() is 0 (category Nd comes in runs of ten), Unicode 16.0.0.
    static constexpr std::array<uint32_t, 76> zeros = {
        0x30, 0x660, 0x6f0, 0x7c0, 0x966, 0x9e6, 0xa66, 0xae6, 0xb66, 0xbe6, 0xc66, 0xce6, 0xd66, 0xde6, 0xe50, 0xed0,
        0xf20, 0x1040, 0x1090, 0x17e0, 0x1810, 0x1946, 0x19d0, 0x1a80, 0x1a90, 0x1b50, 0x1bb0, 0x1c40, 0x1c50, 0xa620,
        0xa8d0, 0xa900, 0xa9d0, 0xa9f0, 0xaa50, 0xabf0, 0xff10, 0x104a0, 0x10d30, 0x10d40, 0x11066, 0x110f0, 0x11136,
        0x111d0, 0x112f0, 0x11450, 0x114d0, 0x11650, 0x116c0, 0x116d0, 0x116da, 0x11730, 0x118e0, 0x11950, 0x11bf0,
        0x11c50, 0x11d50, 0x11da0, 0x11f50, 0x16130, 0x16a60, 0x16ac0, 0x16b50, 0x16d70, 0x1ccf0, 0x1d7ce, 0x1d7d8,
        0x1d7e2, 0x1d7ec, 0x1d7f6, 0x1e140, 0x1e2f0, 0x1e4f0, 0x1e5f1, 0x1e950, 0x1fbf0};
    auto it = std::upper_bound(zeros.begin(), zeros.end(), cp);
    if (it == zeros.begin()) return -1;
    uint32_t zero = *(it - 1);
    return cp - zero < 10 ? static_cast<int>(cp - zero) : -1;
}

size_t length(std::string_view s) {
    size_t n = 0;
    for (size_t i = 0; i < s.size(); ++n) next_code_point(s, i);
    return n;
}

std::string strip(std::string_view s) {
    size_t i = 0, start = s.size(), end = 0;
    while (i < s.size()) {
        size_t at = i;
        if (!is_space(next_code_point(s, i))) {
            if (start == s.size()) start = at;
            end = i;
        }
    }
    return start == s.size() ? std::string() : std::string(s.substr(start, end - start));
}

std::string prefix(std::string_view s, size_t n) {
    size_t i = 0;
    for (size_t k = 0; k < n && i < s.size(); ++k) next_code_point(s, i);
    return std::string(s.substr(0, i));
}

std::vector<std::string> split(std::string_view s) {
    std::vector<std::string> out;
    std::string word;
    size_t i = 0;
    while (i < s.size()) {
        size_t at = i;
        if (is_space(next_code_point(s, i))) {
            if (!word.empty()) out.push_back(std::move(word));
            word.clear();
        } else {
            word.append(s.substr(at, i - at));
        }
    }
    if (!word.empty()) out.push_back(std::move(word));
    return out;
}

std::string lower(std::string_view s) {
    std::string out;
    size_t i = 0;
    while (i < s.size()) {
        size_t at = i;
        uint32_t cp = next_code_point(s, i);
        if (cp >= 'A' && cp <= 'Z') out += static_cast<char>(cp + 32);
        else if (cp == 0x212A) out += 'k';
        else if (cp == 0x0130) out += "i\xcc\x87";
        else out.append(s.substr(at, i - at));
    }
    return out;
}

std::string upper_ascii(std::string_view s) {
    std::string out(s);
    for (char& c : out)
        if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 32);
    return out;
}

namespace {
// str.isprintable() beyond what repr() escapes by range below: Python's own table also marks unassigned code
// points, which only a Unicode database knows; those print here as themselves.
bool printable(uint32_t cp) {
    if (cp >= 0xD800 && cp <= 0xDFFF) return false;                     // surrogates
    if ((cp >= 0xE000 && cp <= 0xF8FF) || cp >= 0xF0000) return false;  // private use
    if (cp == 0x1680 || (cp >= 0x2000 && cp <= 0x200F) || (cp >= 0x2028 && cp <= 0x202F) ||
        (cp >= 0x205F && cp <= 0x206F) || cp == 0x3000 || cp == 0xFEFF || (cp >= 0xFFF9 && cp <= 0xFFFB))
        return false;  // separators and format characters
    if ((cp >= 0x0600 && cp <= 0x0605) || cp == 0x061C || cp == 0x06DD || cp == 0x070F || cp == 0x180E) return false;
    return cp != 0xFFFE && cp != 0xFFFF;
}
}  // namespace

std::string repr(std::string_view s) {
    bool single = s.find('\'') == std::string_view::npos || s.find('"') != std::string_view::npos;
    char quote = single ? '\'' : '"';
    std::string out(1, quote);
    auto hex = [&](const char* fmt, uint32_t cp) {
        char buf[16];
        std::snprintf(buf, sizeof buf, fmt, cp);
        out += buf;
    };
    size_t i = 0;
    while (i < s.size()) {
        size_t start = i;
        uint32_t cp = next_code_point(s, i);
        if (cp == static_cast<uint32_t>(quote) || cp == '\\') {
            out += '\\';
            out += static_cast<char>(cp);
        } else if (cp == '\t') {
            out += "\\t";
        } else if (cp == '\n') {
            out += "\\n";
        } else if (cp == '\r') {
            out += "\\r";
        } else if (cp < 0x20 || (cp >= 0x7F && cp <= 0xA0) || cp == 0xAD) {
            hex("\\x%02x", cp);
        } else if (!printable(cp)) {
            hex(cp > 0xFFFF ? "\\U%08x" : "\\u%04x", cp);
        } else {
            out.append(s.substr(start, i - start));
        }
    }
    out += quote;
    return out;
}

std::string repr_of(const json::Value& v) {
    using T = json::Value::Type;
    switch (v.type()) {
    case T::Null: return "None";
    case T::Bool: return v.as_bool() ? "True" : "False";
    case T::Int: return std::to_string(v.as_int());
    case T::BigInt: return v.as_bigint().digits;
    case T::Float: return json::py_repr(v.as_float());
    case T::String: return repr(v.as_string());
    case T::Array: {
        std::string out = "[";
        for (size_t k = 0; k < v.as_array().size(); ++k) out += (k ? ", " : "") + repr_of(v.as_array()[k]);
        return out + "]";
    }
    case T::Object: {
        std::string out = "{";
        bool first = true;
        for (const auto& m : v.as_object()) {
            out += (first ? "" : ", ") + repr(m.key) + ": " + repr_of(m.value);
            first = false;
        }
        return out + "}";
    }
    }
    return "?";
}

std::string str_of(const json::Value& v) { return v.is_string() ? v.as_string() : repr_of(v); }

bool truthy(const json::Value& v) {
    using T = json::Value::Type;
    switch (v.type()) {
    case T::Null: return false;
    case T::Bool: return v.as_bool();
    case T::Int: return v.as_int() != 0;
    case T::BigInt: return true;
    case T::Float: return v.as_float() != 0.0;
    case T::String: return !v.as_string().empty();
    case T::Array: return !v.as_array().empty();
    case T::Object: return !v.as_object().empty();
    }
    return false;
}

namespace {
std::optional<std::string> ascii_int_text(std::string_view s) {  // int(str)'s grammar, digits made ASCII
    std::string stripped = strip(s), out;
    size_t i = 0;
    if (i < stripped.size() && (stripped[i] == '+' || stripped[i] == '-')) out += stripped[i++];
    bool digit_before = false;
    while (i < stripped.size()) {
        size_t at = i;
        uint32_t cp = next_code_point(stripped, i);
        if (cp == '_' && digit_before && i < stripped.size()) {
            size_t peek = i;
            if (decimal(next_code_point(stripped, peek)) < 0) return std::nullopt;
            digit_before = false;
            continue;
        }
        int d = decimal(cp);
        if (d < 0) return std::nullopt;
        (void)at;
        out += static_cast<char>('0' + d);
        digit_before = true;
    }
    if (!digit_before) return std::nullopt;
    return out;
}
}  // namespace

int64_t int_of(const json::Value& v) {
    using T = json::Value::Type;
    switch (v.type()) {
    case T::Bool: return v.as_bool() ? 1 : 0;
    case T::Int: return v.as_int();
    case T::Float: {
        double d = v.as_float();
        if (!std::isfinite(d)) throw std::runtime_error("cannot convert float to integer");
        double t = std::trunc(d);
        if (std::fabs(t) >= 9.2e18) throw std::runtime_error("int beyond 64 bits");
        return static_cast<int64_t>(t);
    }
    case T::String: {
        auto text = ascii_int_text(v.as_string());
        if (!text) throw std::runtime_error("invalid literal for int(): " + repr(v.as_string()));
        try {
            return std::stoll(*text);
        } catch (const std::exception&) {
            throw std::runtime_error("int beyond 64 bits");
        }
    }
    default: throw std::runtime_error("int() argument must be a string or a number, not " + repr_of(v));
    }
}

double float_of(const json::Value& v) {
    using T = json::Value::Type;
    switch (v.type()) {
    case T::Bool: return v.as_bool() ? 1.0 : 0.0;
    case T::Int: return static_cast<double>(v.as_int());
    case T::Float: return v.as_float();
    case T::BigInt: {
        auto d = json::parse_double(v.as_bigint().digits);
        if (!d || !std::isfinite(*d)) throw std::runtime_error("int too large to convert to float");
        return *d;
    }
    case T::String: {
        std::string text;
        for (char c : strip(v.as_string()))
            if (c != '_') text += c;  // float("1_000"); a misplaced underscore is refused below only roughly
        auto d = json::parse_double(text);
        if (!d || text.empty() || text.find_first_of("xXpP") != std::string::npos)
            throw std::runtime_error("could not convert string to float: " + repr(v.as_string()));
        return *d;
    }
    default: throw std::runtime_error("float() argument must be a string or a real number, not " + repr_of(v));
    }
}

double number(const json::Value& v) {
    if (v.is_bool()) return v.as_bool() ? 1.0 : 0.0;
    if (v.is_int()) return static_cast<double>(v.as_int());
    if (v.is_float()) return v.as_float();
    throw std::runtime_error("not a number: " + repr_of(v));
}

}  // namespace fart::py
