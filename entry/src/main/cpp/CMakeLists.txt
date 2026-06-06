cmake_minimum_required(VERSION 3.14.0)
project(CalculatorX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

include(FetchContent)

# ================= 引入 Boost =================
FetchContent_Declare(
    boost
    URL ${CMAKE_CURRENT_SOURCE_DIR}/boost_1_82_0.tar.gz
)

FetchContent_GetProperties(boost)
if(NOT boost_POPULATED)
    FetchContent_Populate(boost)
endif()

# 把本地解压的路径传给 CMake 的 find_package
set(BOOST_ROOT ${boost_SOURCE_DIR} CACHE PATH "Boost root" FORCE)
set(Boost_INCLUDE_DIR ${boost_SOURCE_DIR} CACHE PATH "Boost include" FORCE)

include_directories(${boost_SOURCE_DIR})

# ================= 引入 SymEngine (CAS 核心) =================
FetchContent_Declare(
    symengine
    GIT_REPOSITORY https://github.com/symengine/symengine.git
    GIT_TAG        v0.11.2
)

# 关闭所有导致移动端交叉编译失败的依赖，切换大数引擎为 BoostMP
set(WITH_GMP OFF CACHE BOOL "Disable GMP" FORCE)
set(WITH_MPFR OFF CACHE BOOL "Disable MPFR" FORCE)
set(WITH_MPC OFF CACHE BOOL "Disable MPC" FORCE)
set(INTEGER_CLASS "boostmp" CACHE STRING "Use Boost Multiprecision instead of GMP" FORCE)

# 关闭不必要的测试和冗余构建，加快速度
set(BUILD_TESTS OFF CACHE BOOL "Disable tests" FORCE)
set(BUILD_BENCHMARKS OFF CACHE BOOL "Disable benchmarks" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build as static library" FORCE)

FetchContent_MakeAvailable(symengine)

# ================= 强制把 SymEngine 的头文件路径传给 IDE 编辑器 =================
include_directories(
    ${symengine_SOURCE_DIR}       # 源码头文件路径
    ${symengine_BINARY_DIR}       # 动态生成的配置头文件路径
    ${symengine_BINARY_DIR}/symengine/utilities/teuchos  # Teuchos_config.h 的生成目录
)

add_library(entry SHARED engine.cpp ErrorHandler.cpp)

# 将 N-API 和 symengine 静态链接到 entry 库中
target_link_libraries(entry PUBLIC libace_napi.z.so symengine)