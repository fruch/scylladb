set(disabled_warnings
  c++11-narrowing
  mismatched-tags
  overloaded-virtual
  unsupported-friend)
include(CheckCXXCompilerFlag)
foreach(warning ${disabled_warnings})
  check_cxx_compiler_flag("-Wno-${warning}" _warning_supported_${warning})
  if(_warning_supported_${warning})
    list(APPEND _supported_warnings ${warning})
  endif()
endforeach()
list(TRANSFORM _supported_warnings PREPEND "-Wno-")
string(JOIN " " CMAKE_CXX_FLAGS
  "-Wall"
  "-Werror"
  "-Wno-error=deprecated-declarations"
  "-Wimplicit-fallthrough"
  ${_supported_warnings})

function(default_target_arch arch)
  set(x86_instruction_sets i386 i686 x86_64)
  if(CMAKE_SYSTEM_PROCESSOR IN_LIST x86_instruction_sets)
    set(${arch} "westmere" PARENT_SCOPE)
  elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    # we always use intrinsics like vmull.p64 for speeding up crc32 calculations
    # on the aarch64 architectures, and they require the crypto extension, so
    # we have to add "+crypto" in the architecture flags passed to -march. the
    # same applies to crc32 instructions, which need the ARMv8-A CRC32 extension
    # please note, Seastar also sets -march when compiled with DPDK enabled.
    set(${arch} "armv8-a+crc+crypto" PARENT_SCOPE)
  else()
    set(${arch} "" PARENT_SCOPE)
  endif()
endfunction()

default_target_arch(target_arch)
if(target_arch)
    string(APPEND CMAKE_CXX_FLAGS " -march=${target_arch}")
endif()

math(EXPR _stack_usage_threshold_in_bytes "${stack_usage_threshold_in_KB} * 1024")
set(_stack_usage_threshold_flag "-Wstack-usage=${_stack_usage_threshold_in_bytes}")
check_cxx_compiler_flag(${_stack_usage_threshold_flag} _stack_usage_flag_supported)
if(_stack_usage_flag_supported)
  string(APPEND CMAKE_CXX_FLAGS " ${_stack_usage_threshold_flag}")
endif()

# Force SHA1 build-id generation
set(default_linker_flags "-Wl,--build-id=sha1")
include(CheckLinkerFlag)
set(Scylla_USE_LINKER
    ""
    CACHE
    STRING
    "Use specified linker instead of the default one")
if(Scylla_USE_LINKER)
    set(linkers "${Scylla_USE_LINKER}")
else()
    set(linkers "lld" "gold")
endif()

foreach(linker ${linkers})
    set(linker_flag "-fuse-ld=${linker}")
    check_linker_flag(CXX ${linker_flag} "CXX_LINKER_HAVE_${linker}")
    if(CXX_LINKER_HAVE_${linker})
        string(APPEND default_linker_flags " ${linker_flag}")
        break()
    elseif(Scylla_USE_LINKER)
        message(FATAL_ERROR "${Scylla_USE_LINKER} is not supported.")
    endif()
endforeach()

set(CMAKE_EXE_LINKER_FLAGS "${default_linker_flags}" CACHE INTERNAL "")

# TODO: patch dynamic linker to match configure.py behavior
