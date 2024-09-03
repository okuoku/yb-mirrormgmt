file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/mirrorlist.txt" mir)
set(root "${CMAKE_CURRENT_LIST_DIR}/_mirrors")

file(MAKE_DIRECTORY "${root}")

foreach(e ${mir})
    if("${e}" MATCHES "([^ ]*) (.*)")
        set(sym "${CMAKE_MATCH_1}")
        set(dir "${root}/${CMAKE_MATCH_1}")
        set(url "${CMAKE_MATCH_2}")
        if(EXISTS "${dir}")
            # Just fetch dir
            execute_process(COMMAND
                git fetch --prune
                RESULT_VARIABLE rr
                WORKING_DIRECTORY "${dir}")
            if(rr)
                # FIXME: Retry this
                message(STATUS "${sym}: Failed to fetch ${url}")
                # message(FATAL_ERROR "Error on fetch [${rr}]")
            endif()
        else()
            # Do fresh clone
            execute_process(COMMAND
                git clone 
                -c http.postBuffer=20000000
                --mirror ${url} ${dir}
                RESULT_VARIABLE rr)
            if(rr)
                message(STATUS "${sym}: Failed to clone ${url}")
                # message(FATAL_ERROR "Error on clone [${rr}]")
            endif()
        endif()
    else()
        message(FATAL_ERROR "Invalid mirror list line [${e}]")
    endif()
endforeach()

