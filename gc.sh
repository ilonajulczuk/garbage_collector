#!/usr/bin/env bash


### Configuration
################################################

# Comandline options

read -r -d '' usage <<-'EOF'
Possible arguments:

-f [arg] --file [arg] --file=[arg] Filename to redirect output.
-v --verbose                       Verbose mode
-h --help                          Help page
EOF

read -r -d '' examples <<-'EOF'
Examples:

./gc.sh myfile
./gc.sh -v myfile
./gc.sh mydirectory
./gc.sh -f redirect_output_to_this_filename myfile_to_remove
echo "file.txt" | ./gc.sh
EOF

# set magic variables for current FILE & DIR
__DIR__="$(cd "$(dirname "${0}")"; echo $(pwd))"
__FILE__="${__DIR__}/$(basename "${0}")"


# Functions

function _fmt () {
    local color_ok="\x1b[32m"
    local color_bad="\x1b[31m"

    local color="${color_bad}"
    if [ "${1}" = "debug"  ]|| [ "${1}" = "info" ] || [ "${1}" = "notice" ]; then
        color="${color_ok}"
    fi

    local color_reset="\x1b[0m"
    if [ "${TERM}" != "xterm" ] || [ -t 1 ]; then
        # Don't use colors on pipes or non-recognized terminals
        color=""; color_reset=""
    fi
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") ${color}$(printf "[%s]" ${1})${color_reset}";
}


function print_log() {
    if [ -n "$file" ]; then
        echo ${@} > "$file"
    else
        echo ${@}
    fi
}

function error () { [ "${verbose}" -ge 0 ] && print_log "$(_fmt error) ${@}" || true; }
function warning () { [ "${verbose}" -ge 1 ] && print_log "$(_fmt warning) ${@}"|| true; }
function info () { [ "${verbose}" -ge 1 ] && print_log "$(_fmt info) ${@}"|| true; }
function debug () { [ "${verbose}" -ge 2 ] && print_log "$(_fmt debug) ${@}" || true; }

function help() {
    echo "Garbage collector is a simple bash script which can be used to delete files in a safe and simple way." 1>&2
    echo ""
    echo "${usage}" 1>&2
    echo "" 1>&2
    echo "${examples}" 1>&2
    echo "" 1>&2
    exit 1
}

function cleanup_before_exit () {
info "Cleaning up."

find "${TRASHBIN}" -mtime +1 -exec rm {} \;

info "Done"
}


TRASHBIN="/tmp/crap"
# Processing function
################################################################


function process_file() {
    name="${1}"

    if [ -f "$name" ] ; then
        filename="$name"
        info "Moving filename '${filename}' to trashbin"   
        if [[ filename = *.tar.gz ]] ; then
            info "File already compressed"
            mv "${filename}" "${TRASHBIN}"
        else
            info "Compressing file"
            tar czvf "${filename}.tar.gz" "${filename}" 
            mv "${filename}.tar.gz" "${TRASHBIN}"
            rm "${filename}"
        fi
        info "File ${filename} moved!"
    elif [ -d "$name" ] ; then
        dirname="$name"
        info "Moving directory '${dirname}' to trashbin"   
        info "Compressing directory"
        tar czvf "${dirname}.tar.gz" "${dirname}" 
        mv "${dirname}.tar.gz" "${TRASHBIN}"
        rm -r "${dirname}"
        info "Directory ${dirname} moved!"
    else
        error "Can't find file '${filename}' on disk"
    fi
}

trap cleanup_before_exit EXIT

# Parse commandline options
####################################################

file=""
verbose=0

while :
do
    case $1 in
        -h | --help | -\?)
            help
            exit 0
            ;;
        -f | --file)
            file=$2
            shift 2
            ;;
        --file=*)
            file=${1#*=}        # Delete everything up till "="
            shift
            ;;
        -v | --verbose)
            # Each instance of -v adds 1 to verbosity
            verbose=$((verbose+1))
            shift
            ;;
        --) # End of all options
            shift
            break
            ;;
        -*)
            printf >&2 'WARN: Unknown option (ignored): %s\n' "$1"
            shift
            ;;
        *)  # no more options. Stop while loop
            break
            ;;
    esac
done

# debug mode
if [ "${arg_v}" = "1" ]; then
    # turn on tracing
    set -x
    # output debug messages
    LOG_LEVEL="7"
fi


mkdir -p ${TRASHBIN}       

if [ "${arg_h}" = 1 ]; then
    help
fi

if [ $# -gt 0 ] ; then
    for filename in  "$@" ; do
        process_file "$filename"
    done
else
    IFS=$'\n' read -t 1 -d '' -r -a filenames
    if [ "${#filenames}" -eq 0 ]; then
        help
    fi

    for filename in "${filenames[@]}"; do
        process_file "$filename"
    done
fi
