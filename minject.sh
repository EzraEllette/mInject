#!/bin/bash

process_name=""
process_id=0
library_path=""
reload=false
inject=false
unload=false

display_help() {
    echo -e "Usage: $(basename $0) [-p process_id] [-n process_name] { -i | -r | -u } <library_path>\n\t-i\tInject the library into the process\n\t-r\tReload the library in the process\n\t-u\tUnload the library from the process\n\t-p\tProcess id\n\t-n\tProcess name\n\t-h\tDisplay this help message"
}

# if [ "$EUID" -ne 0 ]; then
#     echo "Error: Please run as root"
#     exit 1
# fi

while getopts 'p:n:l:iruh' opt; do
  case "$opt" in
    p)
        process_id="$OPTARG"
      ;;

    n)
        if [ $process_id == 0 ]; then
            process_name="$OPTARG"
            process_id=$(pgrep $process_name)
        else
            echo "Error: Cannot specify both process name and process id"
            exit 1
        fi

        if [ -z $process_id ]; then
            echo "Error: Process name '$process_name' not found"
            exit 1
        elif [ $(echo $process_id | wc -w) -gt 1 ]; then
            echo "Error: Multiple processes with name '$process_name' found"
            exit 1
        else
            process_id=$(echo $process_id | tr -d '\n' | tr -d '\r' | tr -d ' ' | tr -d '\t' | tr -d '\0')
        fi
      echo "Process id: $process_id"
      ;;
    l)
        library_path="$OPTARG"
        ;;
    i)
        inject=true
        ;;
    r)
        reload=true
        ;;
    u)
        unload=true
        ;;
    h)
      display_help
      exit 1
      ;;
  esac
done
if [ -z $library_path ]; then

    if [ -f "${@: -1}" ]; then
        library_path="${@: -1}"
    else
        echo "Error: Library path not specified"
        exit 1
    fi
fi
if [ $OPTIND -eq 1 ]; then display_help && exit 1; fi
shift "$(($OPTIND -1))"

if [ $process_id == 0 ]; then
    echo "Error: Process id not specified"
    exit 1
fi

# make sure 1 and only 1 of -i, -r, -u is specified
if [[ $inject == true && $reload == true ]]; then
    echo "Error: Cannot specify both -i and -r"
    exit 1
elif [[ $inject == true && $unload == true ]]; then
    echo "Error: Cannot specify both -i and -u"
    exit 1
elif [[ $reload == true && $unload == true ]]; then
    echo "Error: Cannot specify both -r and -u"
    exit 1
elif [[ ! $inject == false && ! $reload == false && ! $unload == false ]]; then
    echo "Error: Must specify one of -i, -r, -u"
    exit 1
fi

# Get the absolute path of the library
library_path=$(cd $(dirname "$library_path"); pwd)/$(basename "$library_path")


mktmp() {
    mkdir -p /tmp/minject
}

rmtmp() {
    rm -rf /tmp/minject
}

createlldbLoadScript() {
    echo "expr (void*)dlopen(\"$library_path\", 0x2);" > /tmp/minject/loadscript
}

createlldbUnlaodScript() {
    echo "expr void* \$handle = (void*)dlopen(\"$library_path\", 0x6);" > /tmp/minject/unloadscript
    echo "expr (int)dlclose(\$handle);" >> /tmp/minject/unloadscript
    echo "expr (int)dlclose(\$handle);" >> /tmp/minject/unloadscript
}

library_loaded() {
    linked=$(vmmap $process_id | grep "$library_path")
    if [ -z "$linked" ]; then
        return 0
    else
        return 1
    fi
}

mktmp


if [[ $unload == true || $reload == true ]]; then
    #Decrease library reference count to unload it
    createlldbUnlaodScript
    echo "Unloading library '$library_path' from process '$process_id'"
    lldb -p $process_id --batch -s /tmp/minject/unloadscript > /dev/null 2>&1
    if [ $unload == true ]; then
        rmtmp
        if library_loaded; then
            echo "Error: Library '$library_path' still loaded in process '$process_id'"
            exit 1
        else
            echo "Unloaded library '$library_path' from process '$process_id'"
            exit 0
        fi
    fi
fi

if [[ $inject == true || $reload == true ]]; then
    # Inject the library
    echo "Injecting library '$library_path' into process '$process_id'"
    createlldbLoadScript
    lldb -p $process_id --batch -s /tmp/minject/loadscript > /dev/null 2>&1
    rmtmp
    if [ ! library_loaded ]; then
        echo "Error: Library '$library_path' not loaded in process '$process_id'"
        exit 1
    fi
    echo "Injected library '$library_path' into process '$process_id'"
    exit 0
fi