#!/usr/bin/env bash

###################################################################
# Script Name   : transfer.sh
# Description   : A script to manage file transfers using Transfer.sh service.
#                 It supports operations like send, receive, delete,
#                 and get information about files and directories.
# Args          : [OPTIONS] <command>
# Author        : GPT-3.5 and GPT-4, assisted by obeone
# Version       : 1.1
# Date          : 2024-02-15
# License       : MIT License
# Usage         : ./transfer.sh [OPTIONS] <command>
# Notes         : Ensure you have the necessary permissions to execute
#                 and that your terminal supports ANSI color codes for
#                 the best experience.
###################################################################

# Fail on any error
set -e

# Environment defaults
: ${TRANSFERSH_URL:="https://transfer.obeone.cloud"}
: ${TRANSFERSH_MAX_DAYS:=}
: ${TRANSFERSH_MAX_DOWNLOADS:=}
: ${LOG_LEVEL:="INFO"}
: ${DEBUG:=}
: ${AUTH_USER:=""}
: ${AUTH_PASS:=""}

COMMAND="$(basename "$0")"

# Color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'
BOLD='\e[1m'
UNDERLINE='\e[4m'
ITALIC='\e[3m'
INVERTED='\e[7m'

log() {
    local level="$1"
    shift
    local message="$*"
    local levels=("ERROR" "WARN" "INFO" "DEBUG")
    local current_level=""

    exec 3>&1

    for i in "${!levels[@]}"; do
        if [[ "${levels[$i]}" == "$LOG_LEVEL" ]]; then
            current_level="${i}"
            break
        fi
    done

    for i in "${!levels[@]}"; do
        if [[ "$level" == "${levels[$i]}" ]] && [[ $i -le $current_level ]]; then
            case "$level" in
                DEBUG)
                    echo -e "${YELLOW}[DEBUG] ${message}${RESET}" >&3
                    ;;
                INFO)
                    echo -e "${GREEN}[INFO] ${message}${RESET}" >&3
                    ;;
                WARN)
                    echo -e "${YELLOW}[WARN] ${message}${RESET}" >&3
                    ;;
                ERROR)
                    echo -e "${RED}[ERROR] ${message}${RESET}" >&3
                    ;;
            esac
            return
        fi
    done
}

check_requirements() {
    for cmd in curl openssl zip; do
        if ! command -v $cmd &> /dev/null; then
            log ERROR "$cmd is not installed."
            exit 1
        fi
    done
}

curl_call() {
    log DEBUG "Calling curl with the following command: curl $*"
    command curl "$@"
    return_code=$?
    if [ $return_code -ne 0 ]; then
        log ERROR "Curl command failed with return code: $return_code"
    fi

    return $return_code
}

display_help() {
    case $1 in
        send)
            echo -e "${GREEN}Usage: $0 send [OPTIONS] <file|directory> [<file|directory>...]${RESET}"
            echo -e "Options:"
            echo -e "  ${CYAN}-h, --help${RESET}                  Display help message"
            echo -e "  ${CYAN}-d, --max-downloads <value>${RESET} Set the maximum number of downloads (optional)"
            echo -e "  ${CYAN}-D, --max-days <value>${RESET}      Set the maximum number of days the file is stored (optional)"
            echo -e "  ${CYAN}-k, --key <value>${RESET}           Encryption key (optional)"
            echo -e "  ${CYAN}-u, --user <value>${RESET}          Username for basic auth (optional)"
            echo -e "  ${CYAN}-p, --password <value>${RESET}      Password for basic auth (optional)"
            echo -e "  ${CYAN}-y${RESET}                          Bypass confirmation"
            echo -e "  ${CYAN}TRANSFERSH_ENCRYPTION_KEY${RESET}   Encryption key can also be set in environment variable TRANSFERSH_ENCRYPTION_KEY"
            echo -e "  ${CYAN}TRANSFERSH_MAX_DAYS${RESET}         Set the maximum number of days the file is stored"
            echo -e "  ${CYAN}TRANSFERSH_MAX_DOWNLOADS${RESET}    Set the maximum number of downloads"
            echo -e "  ${CYAN}TRANSFERSH_URL${RESET}              In case of self-hosted installation, URL can be set in environment variable TRANSFERSH_URL"
            ;;
        receive)
            echo -e "${GREEN}Usage: $0 receive <URL> [destination]${RESET}"
            echo -e "  ${CYAN}-k, --key <value>${RESET}         Decryption key (optional)"
            echo -e "  ${CYAN}-u, --unzip${RESET}               Offer to unzip file on receive (optional)"
            echo -e "  ${CYAN}TRANSFERSH_ENCRYPTION_KEY${RESET} Decryption key can also be set in environment variable TRANSFERSH_ENCRYPTION_KEY"
            ;;
        delete)
            echo -e "${GREEN}Usage: $0 delete <X-URL-Delete>${RESET}"
            ;;
        info)
            echo -e "${GREEN}Usage: $0 info <URL>${RESET}"
            ;;
        *)
            echo -e "${GREEN}Usage: $0 [OPTIONS] <command>${RESET}"
            echo -e "Options:"
            echo -e "  ${CYAN}-h, --help${RESET}          Display help"
            echo -e "  ${CYAN}-y${RESET}                  Bypass confirmation"
            echo -e "  ${CYAN}--log-level <level>${RESET} Set the logging level (ERROR, WARN, INFO, DEBUG) (default: INFO)"
            echo -e "Commands:"
            echo -e "  ${CYAN}send${RESET}                Send a file or directory"
            echo -e "  ${CYAN}receive${RESET}             Receive a file or directory"
            echo -e "  ${CYAN}delete${RESET}              Delete a file or directory"
            echo -e "  ${CYAN}info${RESET}                Get information about a file or directory"
            ;;
    esac
}

encrypt_file() {
    local file="$1"
    local key="$2"
    local outfile="$(mktemp)"

    if openssl enc -aes-256-cbc -salt -pbkdf2 -in "$file" -out "$outfile" -pass pass:"$key"; then
        echo "$outfile"
    else
        rm -f "$outfile"
        return 1
    fi
}

decrypt_file() {
    local file="$1"
    local key="$2"
    local outfile="$3"

    openssl enc -d -aes-256-cbc -pbkdf2 -in "$file" -out "$outfile" -pass pass:"$key"
    return $?
}

send_file_or_directory() {
    local max_downloads="${TRANSFERSH_MAX_DOWNLOADS}"
    local max_days="${TRANSFERSH_MAX_DAYS}"
    local headers=()
    local encryption_key="${TRANSFERSH_ENCRYPTION_KEY:-}"
    local request_confirmation=true
    local should_zip=false
    local temp_file=""
    local file_name=""
    local auth=""
    local auth=""
    local should_zip=false
    local temp_file=""
    local file_name=""


    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--max-downloads)
                max_downloads="$2"
                log DEBUG "Max downloads set to: $max_downloads"
                shift 2
                ;;
            -D|--max-days)
                max_days="$2"
                log DEBUG "Max days set to: $max_days"
                shift 2
                ;;
            -k|--key)
                encryption_key="$2"
                log DEBUG "Encryption key provided."
                shift 2
                ;;
            -u|--user)
                AUTH_USER="$2"
                auth=1
                log DEBUG "Basic auth username provided."
                shift 2
                ;;
            -p|--password)
                AUTH_PASS="$2"
                auth=1
                log DEBUG "Basic auth password provided."
                shift 2
                ;;
            -h|--help)
                display_help send
                return 0
                ;;
            -y)
                log DEBUG "Bypassing confirmation."
                request_confirmation=false
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    create_zip() {
        temp_file="$(mktemp -u).zip"
        log DEBUG "Creating ZIP file: $temp_file"
        zip -r "$temp_file" "$@"
        file_name="transfer.zip"
    }

    extract_url() {
            local content="$1"

        # Capture the delete URL
        local url_delete=$(echo "$content" | grep -i 'x-url-delete:' | awk '{print $2}')

        # Capture the final URL (last line of the content)
        local url_end=$(echo "$content" | tail -n 1 | sed 's/^.*[0-9.]*%//')

        # Return both URLs separated by a semicolon
        echo "$url_delete;$url_end"
    }

    if [ -z "$encryption_key" ]; then
        echo -ne "${CYAN}Enter encryption key (leave empty for no encryption): ${RESET}"
        read -rs encryption_key
        echo
    fi

    if [[ request_confirmation ]]; then
        echo -e "${CYAN}You are about to send the following files/directories:${RESET}"
        for file in "$@"; do
            echo -e "${BLUE}$(basename "$file")${RESET}"
        done
        read -p $'\e[1;35mAre you sure you want to proceed? (Y/n): \e[0m' confirm
        confirm=${confirm:-y}
        [[ "$confirm" =~ ^[Yy]$ ]] || return 1

        [[ -n "$max_downloads" ]] && headers+=("-H" "Max-Downloads: $max_downloads")
        [[ -n "$max_days" ]] && headers+=("-H" "Max-Days: $max_days")
    fi

    if [[ $# -gt 1 || -d "$1" ]]; then
        should_zip=true
        create_zip "$@"
    else
        temp_file="$1"
        file_name=$(basename "$1")
    fi

    local response
    local return_code
    local auth_options=()

    if [ -n "$auth" ]; then
        auth_options=("--user" "$AUTH_USER:$AUTH_PASS")
    fi

    if [ -n "$encryption_key" ]; then
        file_name="$file_name.enc"
        log DEBUG "Uploading encrypted file: $file_name"

        encrypted_file=$(encrypt_file "$temp_file" "$encryption_key")
        if [[ $? == 1 ]]; then
            log ERROR "Cannot encrypt"
            exit 1
        fi

        response=$(curl_call --dump-header /dev/stdout --progress-bar "${auth_options[@]}" "${headers[@]}" --upload-file "$encrypted_file" "${TRANSFERSH_URL}/$file_name" 2>&1 | grep -v 'HTTP/2')
        rm "$encrypted_file"

        return_code=$?
    else
        log DEBUG "Uploading file: $temp_file"
        response=$(curl_call --dump-header /dev/stdout --progress-bar "${auth_options[@]}" "${headers[@]}" --upload-file "$temp_file" "${TRANSFERSH_URL}/$file_name" 2>&1 | grep -v 'HTTP/2')
        return_code=$?
    fi


    log DEBUG "cURL Reponse :"
    log DEBUG "$response"

    if echo "$response" | grep -q "Not authorized"; then
        log ERROR "Not authorized error occurred."
        exit 1
    fi
    if [ $return_code -ne 0 ]; then
        log ERROR "Failed to upload file."
        exit 1
    fi

    # Call the function and capture the outputs in variables
    IFS=";" read url_delete url <<< "$(extract_url "$response")"

    [ "$should_zip" = true ] && rm "$temp_file" 

    if [ -n "$url" ]; then
        echo -e "\n${GREEN}${BOLD}Upload successful.${RESET}"
        echo ""
        echo -e "${GREEN}${BOLD}Link to the file:${RESET} ${GREEN}${url}${RESET}"
        echo -e "${BLUE}${BOLD}Receive command:${RESET} ${BLUE}${COMMAND} receive ${url}${RESET}"
        echo ""
        echo -e "${RED}${BOLD}Delete command:${RESET} ${RED}${COMMAND} delete ${url_delete}${RESET}"
    fi
}

receive_file_or_directory() {
    local encryption_key="${TRANSFERSH_ENCRYPTION_KEY:-}"
    local offer_unzip="false"
    local encrypted="false"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        display_help receive
        return 0
    elif [ "$1" == "-k" ] || [ "$1" == "--key" ]; then
        encryption_key="$2"
        log DEBUG "Decryption key provided."
        shift 2
    elif [ "$1" == "-u" ] || [ "$1" == "--unzip" ]; then
        offer_unzip="true"
        log DEBUG "Offering to unzip after download."
        shift
    fi

    local url="$1"
    local destination="${2:-.}"
    local file_name=$(basename "$url")
    local response
    local return_code
    local decryption_command

    if [[ "$file_name" == *.enc ]]; then
        encrypted="true"
        if [ -z "$encryption_key" ]; then
            read -sp "Enter decryption key: " encryption_key
            echo
        fi
    fi

    log DEBUG "Downloading file from $url to $destination"
    local temp_download="$(mktemp)"
    response=$(curl_call "$url" -o "$temp_download" -w "%{http_code}" -s)
    return_code=$?

    if [ $return_code -ne 0 ] || [ "$response" -ne 200 ]; then
        log ERROR "Failed to download file."
        log ERROR "cURL response: $response"
        rm "$temp_download"
        exit 1
    fi

    if [ -z "$encryption_key" ]; then
        mv "$temp_download" "$destination/$file_name"
    else
        decrypt_file "$temp_download" "$encryption_key" "$destination/${file_name%.enc}"
        rm "$temp_download"
    fi

    if [ "$offer_unzip" == "true" ] && [[ "$file_name" == *.zip || "$file_name" == *.zip.enc ]]; then
        read -p $'\e[1;35mDo you want to unzip the downloaded file? (Y/n): \e[0m' confirm_unzip
        confirm_unzip=${confirm_unzip:-y}
        if [[ "$confirm_unzip" =~ ^[Yy]$ ]]; then
            unzip "$destination/$file_name" -d "$destination"
            rm "$destination/$file_name"
        fi
    fi

    log INFO "Download successful."
}

delete_file_or_directory() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        display_help delete
        return 0
    fi

    local delete_url="$1"
    log DEBUG "Deleting file at URL: $delete_url"
    curl_call -X DELETE "$delete_url"
    log INFO "File deleted successfully."
}

info_command() {
    local url="$1"
    log INFO "Retrieving information for URL: $url"
    curl_call -I "$url" | awk '/x-remaining-days/ {print "Remaining Days: " $2} /x-remaining-downloads/ {print "Remaining Downloads: " $2} /Content-Length/ {print "File Size: " $2} /Content-Type/ {print "Mime-Type: " $2}'
}

# Main script
check_requirements

if [[ $# -eq 0 ]]; then
    display_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            display_help
            exit 0
            ;;
        --log-level)
            LOG_LEVEL="$2"
            log INFO "Log level set to: $LOG_LEVEL"
            shift 2
            ;;
        send)
            shift
            send_file_or_directory "$@"
            exit 0
            ;;
        receive)
            shift
            receive_file_or_directory "$@"
            exit 0
            ;;
        delete)
            shift
            delete_file_or_directory "$@"
            exit 0
            ;;
        info)
            shift
            info_command "$@"
            exit 0
            ;;
        *)
            log ERROR "Invalid option: $1"
            display_help
            exit 1
            ;;
    esac
done

