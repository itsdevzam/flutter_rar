#ifndef FLUTTER_RAR_H
#define FLUTTER_RAR_H

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* mode: 0 list, 1 extract all, 2 extract one entry, 3 test checksums.
   Returns a malloc'd JSON string. Caller frees it with flutter_rar_free. */
FFI_PLUGIN_EXPORT char* flutter_rar_run(
    const char* path,
    const char* dest,
    const char* password,
    const char* entry,
    int mode);

FFI_PLUGIN_EXPORT void flutter_rar_free(char* ptr);

#ifdef __cplusplus
}
#endif

#endif
