// config.h — Generated for GONODES gn_ext_hap Snappy build.
// Minimal platform-specific feature detection.

#ifndef SNAPPY_CONFIG_H
#define SNAPPY_CONFIG_H

#define HAVE_CONFIG_H 1

#if defined(_MSC_VER)
  // Windows / MSVC
  #define HAVE_SYS_MMAN_H 0
  #define HAVE_UNISTD_H 0
  #define HAVE_SYS_UIO_H 0
  #define HAVE_BYTESWAP_H 0
  #define HAVE_SYS_ENDIAN_H 0
  #define HAVE_BUILTIN_EXPECT 0
  #define HAVE_BUILTIN_PREFETCH 0
  #define HAVE_BUILTIN_CTZ 0
  #define HAVE_ATTRIBUTE_ALWAYS_INLINE 0
#elif defined(__GNUC__) || defined(__clang__)
  // GCC / Clang (Linux, macOS)
  #define HAVE_BUILTIN_EXPECT 1
  #define HAVE_BUILTIN_PREFETCH 1
  #define HAVE_BUILTIN_CTZ 1
  #define HAVE_ATTRIBUTE_ALWAYS_INLINE 1
  #if defined(__linux__)
    #define HAVE_SYS_MMAN_H 1
    #define HAVE_UNISTD_H 1
    #define HAVE_SYS_UIO_H 1
    #define HAVE_BYTESWAP_H 1
    #define HAVE_SYS_ENDIAN_H 0
  #elif defined(__APPLE__)
    #define HAVE_SYS_MMAN_H 1
    #define HAVE_UNISTD_H 1
    #define HAVE_SYS_UIO_H 1
    #define HAVE_BYTESWAP_H 0
    #define HAVE_SYS_ENDIAN_H 1
  #endif
#endif

#endif // SNAPPY_CONFIG_H
