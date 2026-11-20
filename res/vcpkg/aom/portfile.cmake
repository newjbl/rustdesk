# NASM is required to build AOM
vcpkg_find_acquire_program(NASM)
get_filename_component(NASM_EXE_PATH ${NASM} DIRECTORY)
vcpkg_add_to_path(${NASM_EXE_PATH})

# Perl is required to build AOM
vcpkg_find_acquire_program(PERL)
get_filename_component(PERL_PATH ${PERL} DIRECTORY)
vcpkg_add_to_path(${PERL_PATH})

if(DEFINED ENV{USE_AOM_391})
    set(AOM_CONFIG_PATH "lib/cmake/aom")
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF 8ad484f8a18ed1853c094e7d3a4e023b2a92df28 # 3.9.1
        PATCHES
            aom-uninitialized-pointer-3.9.1.diff
            aom-avx2.diff
            aom-install.diff
    )
else()
    set(AOM_CONFIG_PATH "lib/cmake/AOM")
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF 03087864cf4bea6abb0d28f95cf7843511413d8f # 3.14.1
        PATCHES
            aom-uninitialized-pointer.diff
    )
endif()

set(aom_target_cpu "")
if(VCPKG_TARGET_IS_UWP OR (VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE MATCHES "^arm"))
    # UWP + aom's assembler files result in weirdness and build failures
    # Also, disable assembly on ARM and ARM64 Windows to fix compilation issues.
    set(aom_target_cpu "-DAOM_TARGET_CPU=generic")
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" AND VCPKG_TARGET_IS_LINUX)
  set(aom_target_cpu "-DENABLE_NEON=OFF")
endif()

# aom's aom_configure.cmake falls back to the GNU assembler named "as" on every
# platform except Darwin/Windows. The NDK ships no "as", so cross-building from a
# Windows host fails at enable_language(ASM). Point it at the NDK clang instead.
set(aom_android_asm "")
if(VCPKG_TARGET_IS_ANDROID)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(aom_android_triple "aarch64-linux-android")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(aom_android_triple "armv7a-linux-androideabi")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(aom_android_triple "x86_64-linux-android")
    else()
        set(aom_android_triple "i686-linux-android")
    endif()
    file(TO_CMAKE_PATH "$ENV{ANDROID_NDK_HOME}" aom_android_ndk)
    set(aom_android_asm
        "-DCMAKE_ASM_COMPILER=${aom_android_ndk}/toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe"
        "-DCMAKE_ASM_FLAGS=--target=${aom_android_triple}${VCPKG_CMAKE_SYSTEM_VERSION}"
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${aom_target_cpu}
        ${aom_android_asm}
        -DENABLE_DOCS=OFF
        -DENABLE_EXAMPLES=OFF
        -DENABLE_TESTDATA=OFF
        -DENABLE_TESTS=OFF
        -DENABLE_TOOLS=OFF
)

vcpkg_cmake_install()

vcpkg_copy_pdbs()

vcpkg_fixup_pkgconfig()

if(VCPKG_TARGET_IS_WINDOWS)
  vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/lib/pkgconfig/aom.pc" " -lm" "")
  if(NOT VCPKG_BUILD_TYPE)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/aom.pc" " -lm" "")
  endif()
endif()

# Move cmake configs
vcpkg_cmake_config_fixup(CONFIG_PATH ${AOM_CONFIG_PATH})

# Remove duplicate files
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include
                    ${CURRENT_PACKAGES_DIR}/debug/share)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

vcpkg_fixup_pkgconfig()
