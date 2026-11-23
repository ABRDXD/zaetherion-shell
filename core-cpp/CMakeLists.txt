# fartd-cpp: the core in C++ (Z226, docs/CPP_CORE.md). Python stays the default core until stage 6.
#     cmake -S core-cpp -B core-cpp/build -G Ninja && cmake --build core-cpp/build && ctest --test-dir core-cpp/build
cmake_minimum_required(VERSION 3.24)
project(fartd-cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# The plan's whole dependency list (AGENTS.md: nothing beyond it). Network and DBus are looked for now so a
# machine without them fails here, but each is linked only by the stage that uses it (DBus: 3b), since every
# linked Qt library maps into the core's memory.
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Network DBus)

add_compile_options(-Wall -Wextra -Wpedantic)

add_library(fart-json STATIC src/json.cpp src/pystr.cpp)
target_include_directories(fart-json PUBLIC src)

add_executable(fartd-cpp
  src/main.cpp
  src/clock.cpp
  src/log.cpp
  src/protocol.cpp
  src/core.cpp
  src/store.cpp
  src/tasks.cpp
  src/settings.cpp
  src/host.cpp
  src/timers.cpp
  src/sessions.cpp
  src/command.cpp
)
target_link_libraries(fartd-cpp PRIVATE fart-json Qt6::Core)
# Qt's own signal/slot keywords stay off: the code uses Q_SIGNALS-free lambdas only.
target_compile_definitions(fartd-cpp PRIVATE QT_NO_KEYWORDS)

enable_testing()
add_executable(json-check tests/json_check.cpp)
target_link_libraries(json-check PRIVATE fart-json Qt6::Core)
add_test(NAME json-corpus COMMAND json-check ${CMAKE_CURRENT_SOURCE_DIR}/../tests/parity/json_corpus.json)
