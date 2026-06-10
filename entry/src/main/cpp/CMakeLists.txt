cmake_minimum_required(VERSION 3.14.0)
project(CalculatorX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

# 包含当前的 include 目录（确保能找到 gmp.h）
include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

include(FetchContent)

# ================= 引入 Boost (本地) =================
FetchContent_Declare(
    boost
    URL ${CMAKE_CURRENT_SOURCE_DIR}/boost_1_82_0.tar.gz
)
FetchContent_GetProperties(boost)
if(NOT boost_POPULATED)
    FetchContent_Populate(boost)
endif()
set(BOOST_ROOT ${boost_SOURCE_DIR} CACHE PATH "Boost root" FORCE)
set(Boost_INCLUDE_DIR ${boost_SOURCE_DIR} CACHE PATH "Boost include" FORCE)
include_directories(${boost_SOURCE_DIR})


# ================= 引入 GMP (你辛苦编译的 arm64 满血版静态库) =================
add_library(gmp STATIC IMPORTED)
set_target_properties(gmp PROPERTIES IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libgmp.a)


# ================= 引入 SymEngine (CAS 核心) =================
FetchContent_Declare(
    symengine
    GIT_REPOSITORY https://github.com/symengine/symengine.git
    GIT_TAG        v0.11.2
)
set(WITH_GMP OFF CACHE BOOL "Disable GMP" FORCE)
set(WITH_MPFR OFF CACHE BOOL "Disable MPFR" FORCE)
set(WITH_MPC OFF CACHE BOOL "Disable MPC" FORCE)
set(INTEGER_CLASS "boostmp" CACHE STRING "Use Boost Multiprecision instead of GMP" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "Disable tests" FORCE)
set(BUILD_BENCHMARKS OFF CACHE BOOL "Disable benchmarks" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build as static library" FORCE)

FetchContent_MakeAvailable(symengine)
include_directories(
    ${symengine_SOURCE_DIR}
    ${symengine_BINARY_DIR}
    ${symengine_BINARY_DIR}/symengine/utilities/teuchos
)


# ================= 引入 Giac =================
FetchContent_Declare(
    giac
    URL ${CMAKE_CURRENT_SOURCE_DIR}/giac-1.9.0.tar.gz
)
FetchContent_GetProperties(giac)
if(NOT giac_POPULATED)
    FetchContent_Populate(giac)
endif()

# 伪造系统环境，同时在此注入 musl libc 缺少的 glibc 运行时符号
# 编译时动态生成一个 glibc_stub.c，抹平 Linux 和鸿蒙底层的运行时差异
set(GLIBC_STUB_FILE "${CMAKE_CURRENT_BINARY_DIR}/glibc_stub.c")
file(WRITE "${GLIBC_STUB_FILE}" "
#include <stdio.h>
#include <stdarg.h>

/* 1. 完美平替 Linux 的安全打印符号 __fprintf_chk */
int __fprintf_chk(FILE *stream, int flag, const char *format, ...) {
    va_list ap;
    int ret;
    va_start(ap, format);
    ret = vfprintf(stream, format, ap);
    va_end(ap);
    return ret;
}

/* 2. 完美平替 Linux 的本地化字符表符号 __ctype_b_loc */
#include <ctype.h>
const unsigned short **__ctype_b_loc(void) {
    /* musl libc 内部有自己的字符映射，这里直接桥接或返回符合标准的通用本地化位置 */
    static const unsigned short table[384] = { 0 };
    static const unsigned short *p_table = &table[128];
    return &p_table;
}
")

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/giac)
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/config.h "/* Auto-generated dummy */\n#define HAVE_UNISTD_H 1\n#define HAVE_SYS_PARAM_H 1\n#include <fcntl.h>\n#include <sys/stat.h>\n")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/giac/config.h "/* Auto-generated dummy */\n")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/os.h "/* Auto-generated dummy */\n")

# 收集 Giac 源码
file(GLOB GIAC_SRC "${giac_SOURCE_DIR}/src/*.cc" "${giac_SOURCE_DIR}/src/*.c" "${giac_SOURCE_DIR}/src/*.cpp")

# 剔除纯桌面 GUI 和控制台测试程序外壳
list(FILTER GIAC_SRC EXCLUDE REGEX "(FLTK|fltk|Graph|Graph3d|xcas|qcas|Editeur|History|/cas2.*\\.cc|/casce\\.cc|/casctrl\\.cc|/find_global_var\\.cc|freeglut|Help|aide|Xcas|Python|/giac_oo\\.cpp|/gl2ps\\.c|/giacnspire\\.cc|/hevea2mml\\.cc|/icas\\.cc|/graphic\\.c|/factor\\.cc|/integrate\\.cc|/normalize\\.cc|/partfrac\\.cc|/renee\\.cc|/opengl\\.cc|/lua.*)")

# 把动态生成的 glibc 补丁文件也放进 giac 的编译列表
add_library(giac STATIC ${GIAC_SRC} "${GLIBC_STUB_FILE}")

target_compile_definitions(giac PRIVATE
    WITHOUT_GUI NO_READLINE NO_EZPRINT
    HAVE_CONFIG_H GIAC_GENERIC_CONSTANTS
    HAVE_UNISTD_H NO_STDEXCEPT HAVE_NO_HOME_DIRECTORY HAVE_NO_PWD TIMEOUT
    VERSION=\"1.9.0\"
    gammaf=tgammaf
)

target_include_directories(giac PUBLIC
    ${giac_SOURCE_DIR}/src
    ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies
)

target_link_libraries(giac PUBLIC gmp)


# ================= 构建入口 ==================
add_library(entry SHARED engine.cpp FastMath.cpp)

# 将 N-API、SymEngine、Giac 和 arm64 版 GMP 一并链接
target_link_libraries(entry PUBLIC
    libace_napi.z.so
    symengine
    giac
    gmp
)