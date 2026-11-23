// Python's str semantics on UTF-8 text, where the core's behaviour depends on them: lengths and slices count code
// points, strip() removes Unicode whitespace, re's \d is any Unicode decimal digit, repr() quotes values in error
// messages, and truthiness decides `x or default`. Tables are Python 3.14's (Unicode 16.0.0).
#pragma once

#include "json.h"

#include <cstdint>
#include <string>
#include <string_view>

namespace fart::py {

// One code point from (W)UTF-8 at s[i], advancing i; a byte that starts no sequence reads as U+FFFD.
uint32_t next_code_point(std::string_view s, size_t& i);
void append_utf8(std::string& out, uint32_t cp);

// Strict UTF-8 as Python's decoder takes it: no overlongs, no encoded surrogates, nothing past U+10FFFF.
bool utf8_valid(std::string_view s);

bool is_space(uint32_t cp);    // str.isspace()
int decimal(uint32_t cp);      // unicodedata.decimal(c), or -1: what re's \d matches
size_t length(std::string_view s);                 // len(s)
std::string strip(std::string_view s);             // s.strip()
std::string prefix(std::string_view s, size_t n);  // s[:n]

std::string repr(std::string_view s);    // repr(str)
std::string repr_of(const json::Value& v);
std::string str_of(const json::Value& v);   // str(v): a string as itself, anything else as repr()  // repr() of a parsed JSON value: None, True, 1.0, 'x', [1, 2], {'k': v}
bool truthy(const json::Value& v);       // bool(v)

// int(v) and float(v) of a parsed value, as the loaders call them on whatever a file holds. They throw
// std::runtime_error where Python raises (a string that isn't a number, a list, nan or inf to int, an int beyond
// 64 bits to int here: the core never meets one). int() of a string allows whitespace, a sign, Unicode digits and
// single underscores between digits; float() of a string allows what float() does.
int64_t int_of(const json::Value& v);
double float_of(const json::Value& v);
double number(const json::Value& v);  // an int, float or bool as a double, for arithmetic (Python's promotion)

}  // namespace fart::py
