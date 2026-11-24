// The JSON writer against Python's corpus (tests/parity/json_corpus.json, tools/json_corpus.py):
//     json-check path/to/json_corpus.json
// Every case's input is read, written in each of the five styles and compared byte for byte with what Python
// wrote; each output must also read back to the same value. Then Python's round() cases and the SHA-256 case.
// Prints each mismatch and a summary; exits 1 on any.
#include "json.h"

#include <QCryptographicHash>
#include <QByteArray>

#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>

using namespace fart::json;

namespace {

int failures = 0;

void fail(const std::string& what) {
    ++failures;
    if (failures <= 40) std::cout << "FAIL " << what << "\n";
}

const Value& member(const Value& v, const char* key) {
    const Value* m = v.find(key);
    if (!m) {
        std::cerr << "corpus has no " << key << "\n";
        std::exit(2);
    }
    return *m;
}

Style style_named(const std::string& name) {
    if (name == "store") return Style::Store;
    if (name == "protocol") return Style::Protocol;
    if (name == "dms") return Style::Dms;
    if (name == "exhibit") return Style::Exhibit;
    if (name == "default") return Style::Default;
    std::cerr << "unknown style " << name << "\n";
    std::exit(2);
}

// Same value, same types, same key order; NaN equal to NaN (none in the corpus today, but repr allows it).
bool same(const Value& a, const Value& b) { return dump(a, Style::Store) == dump(b, Style::Store); }

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "usage: json-check path/to/json_corpus.json\n";
        return 2;
    }
    std::ifstream in(argv[1], std::ios::binary);
    std::stringstream text;
    text << in.rdbuf();
    auto parsed = parse(text.str());
    if (!parsed.value) {
        std::cerr << "corpus unreadable: " << parsed.error << "\n";
        return 2;
    }
    const Value& corpus = *parsed.value;

    int cases = 0, outputs = 0;
    for (const Value& c : member(corpus, "cases").as_array()) {
        ++cases;
        const std::string& input = member(c, "input").as_string();
        auto value = parse(input);
        if (!value.value) {
            fail("input unreadable: " + input + " (" + value.error + ")");
            continue;
        }
        for (const Member& out : member(c, "out").as_object()) {
            ++outputs;
            std::string got = dump(*value.value, style_named(out.key));
            const std::string& want = out.value.as_string();
            if (got != want) fail(out.key + " " + input + "\n  want " + want + "\n  got  " + got);
            // Read back: the same value (exhibit's keys come back sorted, so it is compared by writing it again).
            auto back = parse(want);
            bool sorted = out.key == "exhibit";
            if (!back.value || (sorted ? dump(*back.value, Style::Exhibit) != want : !same(*back.value, *value.value)))
                fail(out.key + " doesn't read back: " + want);
        }
    }

    int rounds = 0;
    for (const Value& r : member(corpus, "round").as_array()) {
        ++rounds;
        const std::string& x_text = member(r, "x").as_string();
        auto x = parse_double(x_text);
        if (!x) {
            fail("round x unreadable: " + x_text);
            continue;
        }
        if (py_repr(*x) != x_text) fail("repr(" + x_text + ") gives " + py_repr(*x));
        const Value& n = member(r, "n");
        std::string got = n.is_null() ? dump(py_round_int(*x), Style::Store) : py_repr(py_round(*x, static_cast<int>(n.as_int())));
        const std::string& want = member(r, "out").as_string();
        if (got != want) fail("round(" + x_text + ", " + dump(n, Style::Store) + ") want " + want + " got " + got);
    }

    const Value& sha = member(corpus, "sha256");
    auto seed = parse(member(sha, "value").as_string());
    std::string exhibit = dump(*seed.value, Style::Exhibit);
    QByteArray digest = QCryptographicHash::hash(QByteArray::fromStdString(exhibit), QCryptographicHash::Sha256).toHex();
    if (digest.toStdString() != member(sha, "digest").as_string()) fail("sha256 of " + exhibit + " is " + digest.toStdString());

    std::cout << cases << " values x " << (cases ? outputs / cases : 0) << " styles (" << outputs << " outputs), " << rounds
              << " round cases, 1 sha256: " << (failures ? std::to_string(failures) + " failed" : std::string("all equal"))
              << "\n";
    return failures ? 1 : 0;
}
