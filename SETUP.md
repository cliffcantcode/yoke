# Yoke setup (Windows)

## Requirements

- Windows
- Git
- Zig 0.15.2

## Clone

Fresh clone:

```bat
git clone --recurse-submodules <YOUR_YOKE_REPO_URL>
cd yoke
```

If you already cloned without submodules:

```bat
git submodule update --init --recursive
```

## Tracy submodule

Yoke expects Tracy here:

```text
third_party\tracy
```

Quick check:

```bat
dir third_party\tracy\public\TracyClient.cpp
```

## Pin Tracy to the GUI version

If your profiler GUI is `windows-0.13.1`, pin the submodule to `v0.13.1`:

```bat
git -C third_party\tracy fetch --tags
git -C third_party\tracy checkout v0.13.1
git add .gitmodules third_party\tracy
git commit -m "Pin Tracy to v0.13.1"
```

Verify:

```bat
git -C third_party\tracy describe --tags --exact-match
git -C third_party\tracy rev-parse --short HEAD
```

Expected:

```text
v0.13.1
05cceee
```

## Normal run

Build:

```bat
zig build
```

Run:

```bat
zig-out\bin\yoke_win32.exe
```

## Normal hot-reload loop

Terminal 1:

```bat
zig-out\bin\yoke_win32.exe
```

Terminal 2:

```bat
zig build hot --watch -fincremental
```

If you change host/runtime/build files, stop the hot loop, rebuild fully, and restart the host:

```bat
zig build
zig-out\bin\yoke_win32.exe
```

## Tracy mode

Build:

```bat
zig build -Dtracy=true
```

Run:

```bat
zig-out\bin\yoke_win32.exe
```

For now, treat Tracy mode as a **full rebuild / full restart** workflow.
Do not use the hot-reload loop while you are trying to get the profiler path working.

## Tracy GUI

1. Start `yoke_win32.exe` built with `-Dtracy=true`.
2. Start the Tracy profiler GUI.
3. Connect to:

```text
127.0.0.1:8086
```

## If Tracy does not connect

First try the simplest bring-up config:
- Tracy enabled
- full rebuild
- no hot-reload loop
- connect to `127.0.0.1:8086`

Then check whether the Tracy client is listening:

```bat
netstat -ano | findstr 8086
```

If you do **not** see a listener on port 8086 while `yoke_win32.exe` is running, the client runtime is not actually active in the process.

After changing Tracy source, build flags, or the Tracy submodule, do a clean rebuild:

```bat
rmdir /s /q .zig-cache
rmdir /s /q zig-out
zig build -Dtracy=true -fno-incremental
```

## Notes

Normal mode is currently the hot-reload workflow.

The long-term clean profiling mode is:
- compile the project side directly into `yoke_win32.exe`
- disable hot reload
- profile one simpler process image
