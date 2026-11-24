# Builds libarchive.so for Android, so CBR/CB7/CBT open without a system
# library. Linux/macOS load libarchive from the system instead.
#
# Sources are fetched from pinned release tarballs, verified by SHA-256
# (matching the digests published on the GitHub releases).
#
# Enabled: ZIP, RAR/RAR5, 7z, tar formats; zlib (from the NDK) and LZMA/XZ
# (liblzma built statically from xz). Everything a comic reader doesn't need
# (crypto, ACLs, xattrs, iconv, XML formats, CLI tools) is off.

cmake_minimum_required(VERSION 3.22)
project(panelist_native C)

include(FetchContent)

FetchContent_Declare(xz
  URL https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.gz
  URL_HASH SHA256=0014c7886930454fe8bd4228665b51af55eeae560ea135c9c4cd33f55b2591d9
)
FetchContent_Declare(libarchive
  URL https://github.com/libarchive/libarchive/releases/download/v3.8.11/libarchive-3.8.11.tar.xz
  URL_HASH SHA256=a3dc0872b1b39da34dc18ef1b944f0f11ffd37425d70ae04be679279f1cf43d2
)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW) # let plain variables set option()s

# --- liblzma (static, linked into libarchive.so) ---------------------------
set(BUILD_SHARED_LIBS OFF)
set(XZ_NLS OFF)
set(XZ_DOC OFF)
set(XZ_TOOL_XZ OFF)
set(XZ_TOOL_XZDEC OFF)
set(XZ_TOOL_LZMADEC OFF)
set(XZ_TOOL_LZMAINFO OFF)
set(XZ_TOOL_SCRIPTS OFF)
set(XZ_TOOL_SYMLINKS OFF)
set(XZ_TOOL_SYMLINKS_LZMA OFF)
FetchContent_GetProperties(xz)
if(NOT xz_POPULATED)
  FetchContent_Populate(xz)
  add_subdirectory(${xz_SOURCE_DIR} ${xz_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

# Hand the in-tree liblzma target to libarchive's FIND_PACKAGE(LibLZMA).
# The library checks FindLibLZMA would run can't link a target that isn't
# built yet, so their results are preset.
set(LIBLZMA_INCLUDE_DIR ${xz_SOURCE_DIR}/src/liblzma/api CACHE PATH "" FORCE)
set(LIBLZMA_LIBRARY liblzma CACHE STRING "" FORCE)
set(LIBLZMA_HAS_AUTO_DECODER TRUE CACHE BOOL "" FORCE)
set(LIBLZMA_HAS_EASY_ENCODER TRUE CACHE BOOL "" FORCE)
set(LIBLZMA_HAS_LZMA_PRESET TRUE CACHE BOOL "" FORCE)

# --- libarchive (shared) ---------------------------------------------------
set(BUILD_SHARED_LIBS ON)
foreach(opt
    OPENSSL MBEDTLS NETTLE MD LIBB2 LZ4 LZO ZSTD BZip2 LIBXML2 BSDXML EXPAT
    WIN32_XMLLITE PCREPOSIX PCRE2POSIX LIBGCC CNG TAR CPIO CAT UNZIP XATTR ACL
    ICONV TEST INSTALL WERROR)
  set(ENABLE_${opt} OFF)
endforeach()
set(ENABLE_LZMA ON)
set(ENABLE_ZLIB ON)
FetchContent_GetProperties(libarchive)
if(NOT libarchive_POPULATED)
  FetchContent_Populate(libarchive)
  add_subdirectory(${libarchive_SOURCE_DIR} ${libarchive_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

# Give the library its usual soname-free file name: libarchive.so.
set_target_properties(archive PROPERTIES OUTPUT_NAME archive SOVERSION "" VERSION "")
