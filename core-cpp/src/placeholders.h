// STAGE-0 PLACEHOLDERS: what the stage-0 parity scenarios lean on before its stage ports it. Each goes when its
// stage lands; nothing here writes a file or reaches the host. The parity diff (tools/parity.py) shows each as a
// difference from the Python core, on purpose.
//
//   task.add + the `tasks` topic   protocol_events uses it to check event order and revs. Kept in memory only.
//                                  Stage 1 replaces it with core/tasks.py's port.
//   status sections                view, timers, tasks, notifications, overdrive, session: {} until ported.
//   every other topic              offered (the Server's table) with a {} snapshot until ported.
#pragma once

#include "json.h"
#include "protocol.h"

#include <string>
#include <vector>

namespace fart {

class Placeholders {
public:
    explicit Placeholders(Server& server);
    json::Value status_part(const std::string& name) const;

private:
    Server& server_;
    std::vector<std::string> texts_;
    json::Value tasks_snapshot() const;
};

}  // namespace fart
