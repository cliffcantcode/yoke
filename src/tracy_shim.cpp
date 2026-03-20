#include "tracy/TracyC.h"
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#  define YOKE_TRACY_API extern "C" __declspec(dllexport)
#else
#  define YOKE_TRACY_API extern "C" __attribute__((visibility("default")))
#endif

YOKE_TRACY_API TracyCZoneCtx yoke_tracy_zone_begin(const ___tracy_source_location_data* srcloc, int32_t depth, int32_t active) {
    if (depth > 0) {
        return ___tracy_emit_zone_begin_callstack(srcloc, depth, active);
    }
    return ___tracy_emit_zone_begin(srcloc, active);
}

YOKE_TRACY_API void yoke_tracy_zone_end(TracyCZoneCtx ctx) {
    ___tracy_emit_zone_end(ctx);
}

YOKE_TRACY_API void yoke_tracy_zone_text(TracyCZoneCtx ctx, const char* txt, size_t size) {
    ___tracy_emit_zone_text(ctx, txt, size);
}

YOKE_TRACY_API void yoke_tracy_zone_name(TracyCZoneCtx ctx, const char* txt, size_t size) {
    ___tracy_emit_zone_name(ctx, txt, size);
}

YOKE_TRACY_API void yoke_tracy_zone_color(TracyCZoneCtx ctx, uint32_t color) {
    ___tracy_emit_zone_color(ctx, color);
}

YOKE_TRACY_API void yoke_tracy_zone_value(TracyCZoneCtx ctx, uint64_t value) {
    ___tracy_emit_zone_value(ctx, value);
}

YOKE_TRACY_API void yoke_tracy_frame_mark(const char* name) {
    ___tracy_emit_frame_mark(name);
}

YOKE_TRACY_API void yoke_tracy_set_thread_name(const char* name) {
    TracyCSetThreadName(name);
}

YOKE_TRACY_API void yoke_tracy_message(const char* txt, size_t size, uint32_t color) {
    if (color != 0) {
        TracyCMessageC(txt, size, color);
    } else {
        TracyCMessage(txt, size);
    }
}

YOKE_TRACY_API void yoke_tracy_alloc(const void* ptr, size_t size) {
    if (TRACY_CALLSTACK > 0) {
        ___tracy_emit_memory_alloc_callstack(ptr, size, TRACY_CALLSTACK, 0);
    } else {
        ___tracy_emit_memory_alloc(ptr, size, 0);
    }
}

YOKE_TRACY_API void yoke_tracy_free(const void* ptr) {
    if (TRACY_CALLSTACK > 0) {
        ___tracy_emit_memory_free_callstack(ptr, TRACY_CALLSTACK, 0);
    } else {
        ___tracy_emit_memory_free(ptr, 0);
    }
}

YOKE_TRACY_API void yoke_tracy_startup(void) {
#ifdef TRACY_MANUAL_LIFETIME
    ___tracy_startup_profiler();
#endif
}

YOKE_TRACY_API void yoke_tracy_shutdown(void) {
#ifdef TRACY_MANUAL_LIFETIME
    ___tracy_shutdown_profiler();
#endif
}

