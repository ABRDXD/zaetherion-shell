// A neutral icon name, degrees Celsius, and the time of the cached reading.
HostDomain {
    property var current: null
    property var forecast: []
    property double cachedAt: 0
    function refresh(): void { record("refresh", []); }
}
