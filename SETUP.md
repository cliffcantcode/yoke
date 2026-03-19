# Yoke setup

This README is for getting a fresh clone of **yoke** running on Windows, including the Tracy submodule and the normal hot-reload workflow.

## Requirements

- Windows
- Git
- Zig 0.15.2

## Clone the repo

If you are cloning for the first time, include submodules:

```bat
git clone --recurse-submodules <YOUR_YOKE_REPO_URL>
cd yoke
```

If you already cloned without submodules:

```bat
git submodule update --init --recursive
```

That should populate `third_party/tracy`.

## Verify the Tracy submodule

Check that Tracy exists where the build expects it:

```bat
dir third_party\tracy\public\TracyClient.cpp
```

If you want to see what commit/tag is currently pinned:

```bat
git -C third_party\tracy describe --tags --always
```

## Maintainer note: pinning Tracy to a release tag

If you are the person updating the repo and want to pin Tracy to a specific tag:

```bat
git -C third_party\tracy fetch --tags
git -C third_party\tracy checkout v0.13.1
git add .gitmodules third_party\tracy
git commit -m "Pin Tracy to v0.13.1"
```

The parent repo pins the submodule by commit, so teammates only need normal submodule sync/update commands after that.

## Normal build and run

Build everything:

```bat
zig build
```

Run the host:

```bat
zig-out\bin\yoke_win32.exe
```

## Normal hot-reload workflow

Use two terminals.

Terminal 1:

```bat
zig-out\bin\yoke_win32.exe
```

Terminal 2:

```bat
zig build hot --watch -fincremental
```

### Important rule

Use the `hot` loop only when you are editing the hotloaded project side, typically:

- `src/work_module.zig`
- other files only consumed by `work_module`

Do a full rebuild and restart the host when you change host/runtime/build-side files such as:

- `src/yoke_win32.zig`
- `src/abi.zig`
- `src/hot_reload.zig`
- `src/draw.zig`
- `src/widgets.zig`
- `src/layout.zig`
- `src/text.zig`
- `build.zig`
- `build_support.zig`

That looks like:

```bat
zig build
zig-out\bin\yoke_win32.exe
```

## Build with Tracy enabled

Build the full app with Tracy enabled:

```bat
zig build -Dtracy=true
```

Run the host:

```bat
zig-out\bin\yoke_win32.exe
```

Then, for iterative DLL work with Tracy still on:

```bat
zig build hot -Dtracy=true --watch -fincremental
```

## Tracy profiler GUI

The Yoke build wires in the Tracy client runtime, but the GUI profiler is a separate application.

The easiest way to get it is:

1. Download the official Tracy Windows release zip.
2. Extract it somewhere convenient.
3. Launch the Tracy profiler executable.
4. Start `yoke_win32.exe` with `-Dtracy=true` build output.
5. Connect to the running process from the Tracy UI.

## Current Tracy defaults in Yoke

Yoke currently treats Tracy as opt-in with one build flag:

```bat
-Dtracy=true
```

The other profiler defaults are baked into `build_support.zig`:

- callstack depth = 8
- on-demand = true
- only-localhost = true
- delayed-init = false
- manual-lifetime = false

## First places to add Tracy zones

The current wrapper API is designed so markers can stay in the code and compile away when Tracy is disabled.

Example pattern:

```zig
const tracy = @import("tracy.zig");

fn update(memory: *abi.PlatformMemory, ctx: abi.TickContext) callconv(.c) void {
    var zone = tracy.zoneN("work_module.update");
    defer zone.end();

    // update work...
}
```

Good first instrumentation points:

- `work_module.update`
- `work_module.render`
- the main loop in `yoke_win32.zig`
- render command execution
- backbuffer presentation
- DLL reload checks / reload swap path

A frame mark once per rendered frame is also useful:

```zig
tracy.frameMark();
```

## Memory profiling hooks

The Tracy shim already exposes wrappers for:

- zone begin/end
- frame marks
- messages
- memory alloc/free
- optional manual startup/shutdown

So if you later add custom allocators or arena wrappers, you can route alloc/free events through `tracy.alloc(...)` and `tracy.free(...)` without changing the overall integration shape.

## Troubleshooting

### `third_party/tracy/public/TracyClient.cpp` not found

The Tracy submodule is missing. Run:

```bat
git submodule update --init --recursive
```

### Hot reload works, but host/runtime changes do not show up

You are probably still using the DLL-only watch loop. Stop it, do a full rebuild, and restart the host:

```bat
zig build
zig-out\bin\yoke_win32.exe
```

### Tracy build is enabled but nothing appears in the profiler

Check all of these:

- you built with `-Dtracy=true`
- the Tracy GUI profiler is running
- the process is the Tracy-enabled build output
- localhost connections are allowed on your machine

## Recommended day-to-day commands

Non-profiled normal use:

```bat
zig build
zig-out\bin\yoke_win32.exe
zig build hot --watch
```

Profiled use:

```bat
zig build -Dtracy=true
zig-out\bin\yoke_win32.exe
zig build hot -Dtracy=true --watch
```
