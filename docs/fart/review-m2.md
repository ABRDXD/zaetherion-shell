# Review of the M2 core

Reviewed `580521f^..0fa5b7a` against the finalized core design at `d7651b7`. Line numbers refer to `0fa5b7a`. Reproductions used disposable data, fake clocks or the offscreen fixture. The fixes below are proposals.

## High

1. **Removing an app from the privacy list writes its previously private history to disk.** `core/notifications.py:79–82,188–189`. Changing the list overwrites the privacy flag on every retained item. In a synthetic call/return test, the disk record count went from zero to one solely by removing the app from the list. Keep the private flag sticky for the lifetime of each item. Apply a newly added exclusion immediately and purge matching persisted rows before acknowledging the policy change. Test both directions across a flush and restart.

2. **A rejected move can delete a task.** `core/tasks.py:167–171,123–126`. The method removes the task before validating the index. In a private core, moving the only task to index −1 returned `bad-args` and the open count immediately fell to zero. The next successful mutation persists the loss. Validate first, then apply the reorder. Use the same validate-before-mutate rule in `update` at lines 150–160, where a bad due date can leave an earlier text or done change in memory. Test the snapshot and the next disk write after rejection.

3. **A task containing an escaped lone surrogate can prevent the view from subscribing after restart.** `core/protocol.py:21–22,115–116,145`, `core/tasks.py:25–31,144–146`. JSON decoding accepts an escaped lone surrogate. The state writer escapes and persists it, then the wire encoder tries to encode it as literal UTF-8 and raises. Every later subscription containing that task hits the same encoder. Reject invalid Unicode scalar strings before mutation and make the wire encoder able to serve existing stored rows, for example by escaping non-ASCII in the JSON representation. Test a request, reload and subscribe.

## Medium

4. **A core restart can move a timer by the size of a wall-clock adjustment.** `core/timers.py:117–120`. The reboot rebase updates memory and returns before saving its new boot anchor. A fixture stopwatch read 300 s after reboot. Moving the fake wall clock forward one hour and reloading on that same boot made it read 3,900 s with zero additional boottime. Atomically persist when at least one anchor was rebased. Extend the reboot test with a clock adjustment and a second load.

5. **Concurrent cold opens can spawn competing views.** `core/view.py:163–179,191–192`. The first opener yields to the foreign-instance check while state is still absent. A second opener can enter the same spawn path. The calls then replace the shared ready future and process reference. A waiter can time out and reap the other caller's view, and an earlier child's exit can be ignored. Install one shared startup task before the first await and have every opener await it. Test two peers with a barrier inside the foreign-instance check.

6. **A close accepted during cold start is lost.** `core/view.py:146–152`. With two private socket clients, close returned state `starting` while the first open awaited hello. The last command was close, but the eventual state was open. Keep the latest requested visibility and page during startup, deliver them after hello, and preserve ordering across clients. Cover the cold reversal as well as rapid changes after the handshake.

7. **A held lease can suppress idle reaping indefinitely after release.** `core/view.py:249–252`, `core/app.py:49–55,60–65`. If the ten-minute deadline fires while Overdrive is held, the scheduler consumes it and the view manager does nothing. Lease release has no callback to revisit the closed view. Re-evaluate the original closed-since deadline when the last lease ends. Also recheck the lease immediately before terminating in `reap` at line 267, since a lease may have started after the reap task was queued.

8. **A refused handshake can leave a live QML socket permanently offline.** `core/client/CoreClient.qml:56–69`, `core/view.py:160–169,222–224`. Failed hello/subscribe returns with the transport connected, which prevents the retry timer from running. On the server, losing a ready peer clears the client but leaves the completed ready future. A subsequent request can report success while its command is merely queued. Close and retry failed handshakes with backoff, create a fresh readiness future on disconnect, and fail pending callbacks explicitly. Test a failed first handshake followed by recovery.

9. **The outbound buffer limit can retain memory and the socket of a stalled peer.** `core/protocol.py:35–46`. The server enqueues the entire encoded snapshot before checking the limit. Asyncio's transport close attempts to flush the queued bytes. A peer that never reads can retain the backlog, and an idle handler can stay blocked reading until connection loss. Check the pending size plus the encoded frame before enqueueing, abort a peer that exceeds the cap, and test a subscriber that stops reading while another client continues to work.

10. **Notification IDs can collide across session-bus restarts.** `core/notifications.py:89–94,158–160`. The persisted owner is a D-Bus unique name scoped to one bus lifetime. A new bus can assign the same name to a new service. A surviving stored row could then address a different notification with the same numeric ID. Persist the bus ID alongside the owner and invalidate rows before enabling dismissal when either identity changes. Test two synthetic bus IDs with identical owner names and item IDs.

## Lower severity

11. **EOF can execute an unterminated protocol frame.** `core/protocol.py:99–107`. A private client sent a valid hello line, then a task-add object without its newline and half-closed the socket. Both operations returned success. Require the newline before dispatch and drop an incomplete final frame. Keep the exact-limit and oversized-line cases in the same test.

12. **Falsy non-object arguments bypass envelope validation.** `core/protocol.py:123–125`. An explicit empty array, empty string or false becomes an empty object and lets a zero-argument operation execute. Default only an omitted field, then validate the supplied value. Test malformed arguments against a mutating zero-argument operation with a fixture.

### Checks without a separate finding

I compared the reachable requested modes, guard sets, effect ordering and timeout replacement in `core/overdrive.py:37–74` with §6.2. The pure transitions matched the effective-state table. The reaping issue above is in the integration with lease release. The crash counter in `core/view.py:193–195` distinguishes quick unexpected exits from intentional reaps, and the existing test covers three quick exits. The concurrency and reconnect gaps above affect which child that counter observes.

The notification parser pairs a return with the caller's unique name and cookie and checks the current server owner. The real private-bus integration test passed. Ordinary same-boot suspend arithmetic and the oversized inbound-line test also passed.
