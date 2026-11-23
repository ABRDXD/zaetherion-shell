// ClockRect: { x, y, width, height, edge ("top" | "bottom"), exact (true when reported by the hook) }.
HostDomain {
    function rectFor(screen: string): var { return { x: 0, y: 0, width: 0, height: 0, edge: "top", exact: false }; }
    function setHookRect(screen: string, x: int, y: int, width: int, height: int) { record("setHookRect", [screen, x, y, width, height]); }
}
