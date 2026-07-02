# Contributor Notes

Use this page when changing the Lua runtime or public Lua API.

## Where to change what

### Widget API

- `api.lua`
- `easybar_api.base.lua`
- `easybar_api.events.lua`
- `easybar_api.lua`
- `docs/content/lua/*`

`easybar_api.base.lua` is the hand-edited source stub.
`easybar_api.events.lua` is generated from the event catalog.
`easybar_api.lua` is the combined generated artifact that EasyBar installs for LuaLS/editor support.

### Driver events

- `event_tokens.lua`
- `easybar_api.events.lua`
- `easybar_api.lua`
- Swift event sources

### Event payloads

- `EventHub.swift`
- `EventTypes.swift`
- `events.lua`

### Rendering

- `render.lua`
- `WidgetNodeState.swift`

### Process and runtime

- `RuntimeCoordinator.swift`
- `WidgetEngine.swift`
- `LuaProcessController.swift`
- `LuaTransport.swift`

## Generated artifacts

Regenerate every checked-in generated artifact through the Makefile:

```bash
make generate
```

This runs the theme-token generator, event-catalog generator, and generated docs pipeline.
Use this before committing changes that affect generated Swift, Lua, or documentation artifacts.

Verify that generated artifacts are current before opening a pull request:

```bash
make check-generated
```

`make test` intentionally does not regenerate checked-in artifacts. Run `make generate` or
`make check-generated` explicitly when changing generated Swift, Lua, or documentation outputs.

## Generated docs

Regenerate only generated documentation through the Makefile:

```bash
make generate-docs
```

The underlying generator scripts are implementation details. Call them directly only when debugging the generation pipeline.

`make fmt` formats Swift only. Generated Markdown is formatted automatically as part of `make generate-docs`, so generated-doc comparisons stay stable. Run `make fmt-markdown` only when you intentionally want to format all Markdown with Prettier.

## Helper scripts

Reusable automation scripts live under `scripts/` and are grouped by purpose:

- `scripts/build/` contains build helpers used by the Makefile, such as universal product builds, resource copying, plist stamping, and bundle verification.
- `scripts/ci/` contains CI helpers such as dependency setup and long-running Swift test logging.
- `scripts/dev/` contains local-development wrappers such as the shared run and stop flows.
- `scripts/release/` contains release helpers such as signing, notarization, Homebrew formula rendering, release verification, and tap commits.

Keep stable developer commands in the Makefile and delegate large reusable shell blocks into these scripts. This keeps commands like `make run-debug`, `make generate`, `make build-docs`, and `make package` stable while avoiding duplicated or hard-to-review shell logic.

## Notes

- widget directory is executable Lua
- every `*.lua` file is loaded
- reload is a full reset
- protocol:
  - Lua socket JSON in/out via `EasyBarLuaRuntime`
  - stderr logs

## If you change the Lua API

When changing the Lua API:

1. update runtime code
2. update stubs
3. run `make generate-docs`
4. update hand-written guides and examples
