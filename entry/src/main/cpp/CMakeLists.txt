cmake_minimum_required(VERSION 3.14.0)
project(CalculatorX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

# 包含当前的 include 目录（确保能找到我们放进来的 gmp.h）
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

# ================= 引入 GMP (预编译静态库) =================
# 直接挂载从 Alpine Linux 提取的 aarch64 静态库
add_library(gmp STATIC IMPORTED)
set_target_properties(gmp PROPERTIES IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libgmp.a)

# ================= 引入 SymEngine (CAS 核心) =================
FetchContent_Declare(
    symengine
    GIT_REPOSITORY https://github.com/symengine/symengine.git
    GIT_TAG        v0.11.2
)
# 暂时保持 BoostMP 方案，以保证你原有的逻辑不被破坏
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

# ================= 引入 Giac (手动接管源码编译) =================
FetchContent_Declare(
    giac
    URL ${CMAKE_CURRENT_SOURCE_DIR}/giac-1.9.0.tar.gz
)
FetchContent_GetProperties(giac)
if(NOT giac_POPULATED)
    FetchContent_Populate(giac)
endif()

# 【神级造假 2.0】：动态生成假的配置头文件，强行注入 Linux 底层文件控制宏！
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/giac)
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/config.h "/* Auto-generated dummy */\n#define HAVE_UNISTD_H 1\n#define HAVE_SYS_PARAM_H 1\n#include <fcntl.h>\n#include <sys/stat.h>\n")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/giac/config.h "/* Auto-generated dummy */\n")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies/os.h "/* Auto-generated dummy */\n")

# 1. 收集 Giac 核心源码
file(GLOB GIAC_SRC "${giac_SOURCE_DIR}/src/*.cc" "${giac_SOURCE_DIR}/src/*.c" "${giac_SOURCE_DIR}/src/*.cpp")

# 2. 【精准狙杀 4.0】：追加剔除 normalize.cc 命令行测试外壳！
list(FILTER GIAC_SRC EXCLUDE REGEX "(FLTK|fltk|Graph|Graph3d|xcas|qcas|Editeur|History|cas2.*\\.cc|casce\\.cc|casctrl\\.cc|cocoa\\.cc|find_global_var\\.cc|freeglut|Help|aide|Xcas|Python|giac_oo\\.cpp|gl2ps\\.c|giacnspire\\.cc|hevea2mml\\.cc|icas\\.cc|graphic\\.c|factor\\.cc|integrate\\.cc|derive\\.cc|desolve\\.cc|lua.*|opengl\\.cc|partfrac\\.cc|renee\\.cc|normalize\\.cc)")







# 3. 手动定义 Giac 静态库
add_library(giac STATIC ${GIAC_SRC})

# 4. 注入宏定义，切断 GUI 依赖，声明 POSIX 环境，并打上跨平台语法补丁！
target_compile_definitions(giac PRIVATE
    WITHOUT_GUI NO_READLINE NO_EZPRINT
    HAVE_CONFIG_H GIAC_GENERIC_CONSTANTS
    HAVE_UNISTD_H NO_STDEXCEPT HAVE_NO_HOME_DIRECTORY HAVE_NO_PWD TIMEOUT
    VERSION=\"1.9.0\"   # 【补丁 1】：强行注入版本号，修复 VERSION 未定义
    gammaf=tgammaf      # 【补丁 2】：强行将非标准的 gammaf 替换为鸿蒙标准的 tgammaf
)

# 5. 包含头文件（包括原码目录和我们的造假目录）
target_include_directories(giac PUBLIC
    ${giac_SOURCE_DIR}/src
    ${CMAKE_CURRENT_BINARY_DIR}/giac_dummies
)

# 6. 【极其关键】：把我们提取的 Linux 满血版 GMP 喂给 Giac！
target_link_libraries(giac PUBLIC gmp)

# ================= 构建入口 ==================
# 注意：整个文件里 add_library(entry ...) 只能出现一次
add_library(entry SHARED engine.cpp FastMath.cpp)

# 打通全链路：将 N-API、SymEngine、以及新增的 Giac 和 GMP 一并链接
target_link_libraries(entry PUBLIC
    libace_napi.z.so
    symengine
    giac
    gmp
)