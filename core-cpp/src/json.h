// Ordered JSON with Python's semantics (Z226 stage 0, docs/CPP_CORE.md "The JSON writer").
//
// The Python core reads with json.loads and writes with json.dumps; state files, socket lines and DMS's settings
// must come out byte for byte the same. So, unlike QJsonDocument: object keys keep insertion order (a repeated key
// keeps its first place and its last value, as a Python dict does), ints and floats stay apart (1 vs 1.0), ints
// beyond 64 bits are kept as their digits, floats are written as Python's repr, and strings are escaped as
// json.dumps escapes them. Text is UTF-8; a lone surrogate from a \uD800 escape is carried as WTF-8 (the three
// bytes a surrogate code point would have), which is how the protocol notices and refuses it.
#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

namespace fart::json {

class Value;
struct Member;
using Array = std::vector<Value>;
using Object = std::vector<Member>;

// An int that doesn't fit in 64 bits: its decimal digits (with a leading '-' when negative), exactly as read.
struct BigInt {
    std::string digits;
    bool operator==(const BigInt&) const = default;
};

class Value {
public:
    enum class Type { Null, Bool, Int, BigInt, Float, String, Array, Object };

    Value() = default;
    Value(std::nullptr_t) {}
    Value(bool b) : v_(b) {}
    template <typename T>
        requires(std::is_integral_v<T> && !std::is_same_v<T, bool>)
    Value(T i) : v_(static_cast<int64_t>(i)) {}
    Value(double d) : v_(d) {}
    Value(BigInt b) : v_(std::move(b)) {}
    Value(const char* s) : v_(std::string(s)) {}
    Value(std::string s) : v_(std::move(s)) {}
    Value(std::string_view s) : v_(std::string(s)) {}
    Value(Array a);
    Value(Object o);

    Type type() const { return static_cast<Type>(v_.index()); }
    bool is_null() const { return type() == Type::Null; }
    bool is_bool() const { return type() == Type::Bool; }
    bool is_int() const { return type() == Type::Int; }
    bool is_float() const { return type() == Type::Float; }
    bool is_string() const { return type() == Type::String; }
    bool is_array() const { return type() == Type::Array; }
    bool is_object() const { return type() == Type::Object; }

    bool as_bool() const { return std::get<bool>(v_); }
    int64_t as_int() const { return std::get<int64_t>(v_); }
    double as_float() const { return std::get<double>(v_); }
    const BigInt& as_bigint() const { return std::get<BigInt>(v_); }
    const std::string& as_string() const { return std::get<std::string>(v_); }
    const Array& as_array() const;
    Array& as_array();
    const Object& as_object() const;
    Object& as_object();

    // Objects: the member's value or nullptr; set() replaces in place or appends, as a Python dict assignment does.
    const Value* find(std::string_view key) const;
    Value* find(std::string_view key);
    Value& set(std::string_view key, Value value);
    Value& operator[](std::string_view key);  // inserts null when missing

    // Python's ==: 1 == 1.0 == True, containers element-wise, objects ignoring order.
    bool py_equals(const Value& other) const;
    // Exact structural equality (types, order): what a byte comparison of two writes would say.
    bool operator==(const Value& other) const;

private:
    // std::vector allows an incomplete element type, so Array and Object can be held directly.
    std::variant<std::nullptr_t, bool, int64_t, BigInt, double, std::string, Array, Object> v_;
};

struct Member {
    std::string key;
    Value value;
    bool operator==(const Member&) const = default;
};

// json.loads, strict (Python's defaults): NaN, Infinity and -Infinity are read; literal control characters in
// strings, invalid UTF-8 (including encoded surrogates), trailing data, a BOM and ints over 4300 digits are not.
struct ParseResult {
    std::optional<Value> value;
    std::string error;            // empty on success
    bool lone_surrogate = false;  // a \uD800-style escape left unpaired somewhere in the text
};
ParseResult parse(std::string_view text, int max_depth = 1000);

// The json.dumps styles the runtime writes (tools/json_corpus.py STYLES).
enum class Style {
    Store,     // separators=(",", ":"): state files and append_line
    Protocol,  // separators=(",", ":"), ensure_ascii=False: socket lines (protocol.encode)
    Dms,       // indent=2, ensure_ascii=False: DMS's settings.json (dms_bar.py), no trailing newline
    Exhibit,   // sort_keys=True, separators=(",", ":"): exhibit's score seed
    Default,   // json.dumps(value): fixture log lines, capture's spec
};
std::string dump(const Value& value, Style style);

// One protocol frame: dump(Protocol) as UTF-8 with errors="backslashreplace" (a lone surrogate becomes the six
// characters \udXXX), plus "\n".
std::string encode_line(const Value& value);

// Python's repr(float): shortest round-trip digits, exponent form when the decimal point is before -4 or after 16
// digits ("1e-05", "1e+16", "1000000000000000.0"), "nan", "inf", "-inf".
std::string py_repr(double x);
// float(text) for the forms JSON and the corpus use; nullopt if text isn't a whole number.
std::optional<double> parse_double(std::string_view text);
// round(x, n) for a float (half to even on the exact binary value) and round(x) to an int (Int, or BigInt when
// it doesn't fit). round(x) throws std::domain_error for nan and inf, as Python raises.
double py_round(double x, int ndigits);
Value py_round_int(double x);

}  // namespace fart::json
