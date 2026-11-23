# Confluence Home checkpoint

Native Shell, 1360×860 panel on a 1920×1080 nested Hyprland output. Home's
content viewport is 1034×647. All service data is synthetic. These captures
do not establish sustained 144 Hz performance.

- `fluid-home.png`: Silent, Amoled Black.
- `fluid-home-overdrive.png`: Overdrive, same Home design and shared state.
- `fluid-home-calendar.png`: next month, retained by the persistent session.
- `fluid-settings-preview.png`: Ice preview with the native Design Style selector.
- `fluid-settings-overdrive.png`: Settings after preview cancellation.
- `angular.png` / `angular-baseline.png`: current Angular and original Home
  from e6c86ea. Within the panel, zero pixels differ by more than 16/255;
  small rendering differences remain. The initial screenshot includes a
  temporary nested-compositor startup notice outside the panel.

The shell header, tilted room label, navigation and shared Overdrive effects
still use the existing Angular presentation; their Confluence work remains.
Home and the earlier Media presentation use the global persisted style selector.

Reproduce from the repository root:

```sh
python tools/nested_hypr.py start
python tools/fluid_fixture.py --fixture tests/fixtures/fluid/HomeSwitch.qml
python tools/fluid_fixture.py --fixture tests/fixtures/fluid/HomeSwitch.qml --capture docs/captures/fluid-home
python tools/fluid_fixture.py --fixture tests/fixtures/fluid/HomeSwitch.qml --capture docs/captures/fluid-home --baseline
```

The driver focuses only nested ZTEST so floating regression windows receive
rendered frames. Stop the nested compositor afterward only if this run owns
it and no other work is using it. `checks.log` records assertion markers and
validation commands; `fixture.log`, `baseline.log` and `state.json` accompany
the capture. The tested Home checkpoint is committed under the owner's existing approval; no deployment or push is included.
