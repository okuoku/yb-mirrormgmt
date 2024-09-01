function(calc_repoid var url)
    string(REGEX REPLACE "\\.git$" "" in "${url}")
    string(REGEX REPLACE "/$" "" in "${in}")
    if(${in} MATCHES "(h|s|g)[^:]*://(.*)")
        set(path ${CMAKE_MATCH_2})
        # Replace : / => _
        string(REPLACE : _ path "${path}")
        string(REPLACE / _ path "${path}")
        set(${var} ${path} PARENT_SCOPE)
    else()
        set(${var} OFF PARENT_SCOPE)
    endif()
endfunction()

set(repoids)

function(fetch_repodata id gitrepo)
    calc_repoid(repoid ${gitrepo})
    if(REPODATA_${repoid}_done)
        message(STATUS "Skip: ${gitrepo}")
        set(${id} OFF PARENT_SCOPE)
        return()
    endif()
    set(${id} ${repoid} PARENT_SCOPE)
    set(a ${repoids})
    list(APPEND a ${repoid})
    set(repoids "${a}" PARENT_SCOPE)
    set(REPODATA_${repoid}_url ${gitrepo} PARENT_SCOPE)
    set(repopath "${tmpdir}/${repoid}")
    if(NOT repopath)
        message(FATAL_ERROR "Unknown URL ${gitrepo}")
    endif()
    file(REMOVE_RECURSE "${repopath}")
    file(MAKE_DIRECTORY "${repopath}")
    execute_process(COMMAND git
        clone
        --depth=1
        --bare
        --filter=blob:none
        ${gitrepo}
        ${repopath}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "Failed to fetch ${gitrepo}")
    endif()
    execute_process(COMMAND git
        ls-tree
        HEAD .gitmodules
        WORKING_DIRECTORY ${repopath}
        OUTPUT_VARIABLE out
        RESULT_VARIABLE rr)
    if(rr)
        message(STATUS "Unexpected return from ls-tree [${rr}]")
    else()
        if("${out}" MATCHES "100644 blob ([^\t ]*)")
            set(oid ${CMAKE_MATCH_1})
            execute_process(COMMAND git
                config 
                --blob HEAD:.gitmodules 
                --get-regexp "submodule.*.url"
                WORKING_DIRECTORY ${repopath}
                OUTPUT_VARIABLE out
                RESULT_VARIABLE rr)

            if(rr)
                message(FATAL_ERROR "Unexpected return from config [${rr}]")
            else()
                string(REPLACE "\n" ";" lis "${out}")
                set(mods)
                foreach(e ${lis})
                    if("${e}" MATCHES "[^ ]* (.*)")
                        string(STRIP "${CMAKE_MATCH_1}" modurl)
                        list(APPEND mods "${modurl}")
                    endif()
                    set(REPODATA_${repoid}_mods "${mods}" PARENT_SCOPE)
                endforeach()
            endif()
        else()
            if(out)
                message(FATAL_ERROR "Unexpected return from ls-tree [${out}]")
            else()
                message(STATUS "No .gitmodules")
            endif()
        endif()
    endif()
    set(REPODATA_${repoid}_done ON PARENT_SCOPE)
endfunction()

set(tmpdir "${CMAKE_CURRENT_LIST_DIR}/_tmp")
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/seed.txt" seed)

macro(collect_mods)
    foreach(e ${ARGN})
        fetch_repodata(myid ${e})
        if(myid)
            collect_mods(${REPODATA_${myid}_mods})
        endif()
    endforeach()
endmacro()

collect_mods(${seed})

list(SORT repoids)
file(WRITE mirrorlist.txt)

foreach(mod ${repoids})
    set(url ${REPODATA_${mod}_url})
    message(STATUS "${mod} ${url}")
    file(APPEND mirrorlist.txt "${mod} ${url}\n")
endforeach()
