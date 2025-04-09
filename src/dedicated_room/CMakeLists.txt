# SPDX-FileCopyrightText: 2017 Citra Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(eden-room
    precompiled_headers.h
    eden_room.cpp
    eden_room.rc
)

target_link_libraries(eden-room PRIVATE common network)
if (ENABLE_WEB_SERVICE)
    target_compile_definitions(eden-room PRIVATE -DENABLE_WEB_SERVICE)
    target_link_libraries(eden-room PRIVATE web_service)
endif()

target_link_libraries(eden-room PRIVATE mbedtls mbedcrypto)
if (MSVC)
    target_link_libraries(eden-room PRIVATE getopt)
endif()
target_link_libraries(eden-room PRIVATE ${PLATFORM_LIBRARIES} Threads::Threads)

if(UNIX AND NOT APPLE)
    install(TARGETS eden-room)
endif()

if (EDEN_USE_PRECOMPILED_HEADERS)
    target_precompile_headers(eden-room PRIVATE precompiled_headers.h)
endif()

set_target_properties(eden-room PROPERTIES OUTPUT_NAME "eden-room")

create_target_directory_groups(eden-room)
