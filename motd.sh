#!/usr/bin/env bash

###########################################################################################
# Name:             motd                                                                  #                                 
# Description:      Custom motd login banner for Debian systems                           #
# Requirements:     wget and timeout command. Generally installed or in coreutils.        #
###########################################################################################

set -o errexit
set -o pipefail

# Set colors for use in task terminal output functions
term_colors() {
    if [[ -t 1 ]]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        CYAN=$(printf '\033[36m')
        YELLOW=$(printf '\033[33m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[0m')
    else
        RED=""
        GREEN=""
        CYAN=""
        YELLOW=""
        BOLD=""
        RESET=""
    fi
}
# Init terminal colours
term_colors

# output_result function
# Usage 1: output_result "result text" "result title"
# Usage 2: output_result "result text"
# No dots will be printed in Usage 2, can used for additional lines etc.
output_result() {
    max_title_len=17
    max_len="18"
    result=${1}
    title=${2:0:${max_title_len}}
    print_line(){
        if [[ -z ${1} ]]; then
            char=" "
        else
            char="${1}"
        fi
	    for ((i=1; i<=${max_len}; i++)); do echo -ne "${char}"; done
        echo -n ": ${result}"
    }
    if [[ ! -z ${result} ]]; then
        if [[ ! -z ${title} ]]; then
            print_line "."
            echo -e "\r${title}"
        else
            print_line
        fi
    fi
}

function get_ip_info(){
    json_data=$(timeout 3s wget -qO- ipinfo.io)

    # Sub-function to get JSON value
    function get_json_value() {
        json_key=${1}
        result=$(echo "${json_data}" \
                | awk -F=":" -v RS="," '$1~/"'${json_key}'"/ {print}' \
                | sed 's/\"//g; s/'${json_key}'://; s/[\{\}]//' \
                | awk '{$1=$1};1' \
                | awk NF)

        if [ "${result}" = "" ]; then
            echo ""
        else
            echo "${result}"
        fi
    }

    # Assign variables based on JSON value returned.
    ip=$(get_json_value ip)
    hostname=$(get_json_value hostname)
    city=$(get_json_value city)
    region=$(get_json_value region)
    country=$(get_json_value country)

    # Display variables use xargs to strip variable whitespace
    output_result "${CYAN}${ip}${RESET} ${hostname}" "External IP Info"
    output_result "${city} ${region} ${country}" 
}


function percentage_color() {
    input_percent="${1//%}"
    if [ "${input_percent}" -lt "50" ]; then
        echo -ne "${GREEN}${input_percent}%${RESET}"
    elif [ "${input_percent}" -le "85" ]; then
        echo -ne "${YELLOW}${input_percent}%${RESET}"
    else
        echo -ne "${RED}${input_percent}%${RESET}"
    fi
}


function show_mem() {
    if [[ $(command -v free -t) ]] >/dev/null 2>&1; then
        mem_perc=$(free -t | awk 'FNR == 2 { printf "%d", $3/$2*100 }')
        result=$(percentage_color ${mem_perc})
        output_result "${result}" "Memory Usage"
    fi
}


function show_storage() {
    if [[ $(command -v lsblk) ]] >/dev/null 2>&1; then
        raw_storage="$(lsblk -f -r -n | grep % | grep -v "loop" | sort | awk 'FNR { printf "%s Used: %s Free: %sB\n\t\t    ", $1,$(NF-1),$(NF-2); }')"
        IFS=', ' read -r -a array <<< $(lsblk -f -r -n | tr ' ' '\n' | grep '%$' | xargs)
        for element in "${array[@]}"
            do
                colored_val=$(percentage_color ${element})
                raw_storage=${raw_storage/${element}/$colored_val}
            done
        echo "${raw_storage}" | while read -r line; do output_result "${line}" "Storage"; done
    fi
}


function show_running() {
    if [[ $(ps ax | wc -l | tr -d " ") -gt "0" ]] >/dev/null 2>&1; then
        result=$(ps ax | wc -l | tr -d " ")
        echo -e "Running Processes.: ${result}"
    fi    
}


function show_cpu() {
    if [[ $(cat /proc/cpuinfo) ]] >/dev/null 2>&1; then
        check_cpu=$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs) || true
        check_model=$(cat /proc/cpuinfo | grep Model | head -1 | cut -d':' -f2 | xargs) || true
        if [[ -z "${check_cpu}" ]]; then
            result="${check_model}"
        else
            result="${check_cpu}"
        fi
        if ! [[ -z "${result}" ]]; then
            output_result "${result}" "System Proc"
        fi
    fi
}


function show_date() {
    result=$(date +"%A, %e %B %Y, %r")
    output_result "${result}" "System Date/Time"
}


function show_uptime() {
    result=$(uptime -p | cut -c 4-)
    output_result "${result}" "System Uptime"
}


function show_hostname() {
    result=$(hostname)
    output_result "${CYAN}${result}${RESET}" "System Hostname"
}


function show_hostip() {
    result=$(hostname --all-ip-addresses | awk '{print $1}')
    output_result "${CYAN}${result}${RESET}" "System Host IP"
}


function show_os_info() {
    if [[ $(command -v lsb_release) ]] >/dev/null 2>&1; then
        local codename=$(lsb_release -c --short)
        local release=$(lsb_release -r --short)
        local dist=$(lsb_release -d --short)
        local distid=$(lsb_release -i --short)
        local arch=$(uname -m)
        local kernel=$(uname -r)
        local dpkg_arch=$(dpkg --print-architecture)
        output_result "${dist}" "System OS"
        output_result "${kernel}" "System Kernel"
        output_result "${arch}" "System Arch"       
    fi
}


function show_ipinfo() {
    get_ip_info || \
    output_result "${RED}Offline - Unable to get IP information. ${RESET}" "External IP Info"
}


function sys_warning() {
    clear
    echo -ne "${RED}
╔═════════════════════════════════════════════╗
║     YOU HAVE ACCESSED A PRIVATE SYSTEM      ║
║         AUTHORISED USER ACCESS ONLY         ║
║                                             ║
║ Unauthorised use of this system is strictly ║
║ prohibited and may be subject to criminal   ║
║ prosecution.                                ║
║                                             ║
║  ALL ACTIVITIES ON THIS SYSTEM ARE LOGGED.  ║
╚═════════════════════════════════════════════╝
${RESET}"
}


function sys_info() {
    echo
    show_date
    show_uptime
    show_hostname
    show_hostip
    show_os_info
    show_cpu
    show_running
    show_mem
    show_storage
    # Comment out show_ipinfo to speed up script if IP info not required
    show_ipinfo
    echo -e "\n"
}


function main() {
    sys_warning
    sys_info
}

main