#!/usr/bin/env bash

####################################################################
#
# Script Name:   transfer.sh
# Description:   A command-line tool to interact with the Transfer.sh service
#                for sending, receiving, deleting, and inspecting files.
# Author:        obeone (assisted by GPT-3.5 and GPT-4)
# Version:       1.2
# Date:          2024-02-15
# License:       MIT License
#
# Usage:
#                ./transfer.sh [OPTIONS] <command>
#
# Notes:
#                - Requires curl, openssl, and zip to be installed.
#                - Supports environment variables for configuration.
#                - Best experienced in a terminal that supports ANSI colors.
#
####################################################################

# Exit immediately if a command exits with a non-zero status.
set -e

# ==============================================================================
# Configuration and Environment Variables
# ==============================================================================
: "${TRANSFERSH_URL:="https://transfer.obeone.cloud"}"
: "${TRANSFERSH_MAX_DAYS:=}"
: "${TRANSFERSH_MAX_DOWNLOADS:=}"
: "${TRANSFERSH_ENCRYPTION_KEY:=}"
: "${LOG_LEVEL:="INFO"}"
: "${AUTH_USER:=""}"
: "${AUTH_PASS:=""}"

# ==============================================================================
# Globals
# ==============================================================================
COMMAND="$(basename "$0")"

# Color Codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'
BOLD='\e[1m'

# ==============================================================================
# Logging
# ==============================================================================

# log <level> <message>
#
# Prints a log message with a specified level (ERROR, WARN, INFO, DEBUG).
# The message is only displayed if its level is at or below the global
# LOG_LEVEL.
#
log() {
    local level="$1"
    shift
    local message="$*"
    local levels=("ERROR" "WARN" "INFO" "DEBUG")
    local current_level_idx=-1
    local level_idx=-1

    for i in "${!levels[@]}"; do
        if [[ "${levels[$i]}" == "$LOG_LEVEL" ]]; then
            current_level_idx=$i
        fi
        if [[ "${levels[$i]}" == "$level" ]]; then
            level_idx=$i
        fi
    done

    if [[ $level_idx -le $current_level_idx ]]; then
        case "$level" in
            DEBUG) echo -e "${YELLOW}[DEBUG] ${message}${RESET}" >&2 ;;
            INFO)  echo -e "${GREEN}[INFO] ${message}${RESET}" >&2 ;;
            WARN)  echo -e "${YELLOW}[WARN] ${message}${RESET}" >&2 ;;
            ERROR) echo -e "${RED}[ERROR] ${message}${RESET}" >&2 ;;
        esac
    fi
}

# ==============================================================================
# Prerequisite Checks
# ==============================================================================

# check_requirements
#
# Verifies that all required command-line tools (curl, openssl, zip)
# are installed and available in the system's PATH.
#
check_requirements() {
    for cmd in curl openssl zip; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "$cmd is not installed. Please install it to continue."
            exit 1
        fi
    done
}

# ==============================================================================
# Core Functions
# ==============================================================================

# curl_call <arguments...>
#
# A wrapper around the curl command that adds logging for debugging
# and basic error handling.
#
curl_call() {
    log "DEBUG" "Executing: curl $*"
    command curl "$@"
    local return_code=$?
    if [ $return_code -ne 0 ]; then
        log "ERROR" "curl command failed with exit code: $return_code"
    fi
    return $return_code
}

# display_help [command]
#
# Displays the help message for the script or a specific command.
#
display_help() {
    case $1 in
        send)
            echo -e "${GREEN}Usage: $0 send [OPTIONS] <file|directory>...${RESET}"
            echo "Uploads one or more files or directories."
            echo
            echo "Options:"
            echo -e "  ${CYAN}-d, --max-downloads <count>${RESET}  Set the maximum number of downloads."
            echo -e "  ${CYAN}-D, --max-days <days>${RESET}       Set the retention period in days."
            echo -e "  ${CYAN}-k, --key <key>${RESET}              Encryption key for the files."
            echo -e "  ${CYAN}-u, --user <user>${RESET}           Username for basic authentication."
            echo -e "  ${CYAN}-p, --password <pass>${RESET}       Password for basic authentication."
            echo -e "  ${CYAN}-y${RESET}                           Bypass the confirmation prompt."
            echo -e "  ${CYAN}-h, --help${RESET}                   Display this help message."
            ;;
        receive)
            echo -e "${GREEN}Usage: $0 receive <URL> [destination]${RESET}"
            echo "Downloads a file from a transfer.sh URL."
            echo
            echo "Options:"
            echo -e "  ${CYAN}-k, --key <key>${RESET}              Decryption key for encrypted files."
            echo -e "  ${CYAN}-u, --unzip${RESET}                  Prompt to unzip the file after download."
            echo -e "  ${CYAN}-h, --help${RESET}                   Display this help message."
            ;;
        delete)
            echo -e "${GREEN}Usage: $0 delete <delete-url>${RESET}"
            echo "Deletes a file using its deletion URL."
            ;;
        info)
            echo -e "${GREEN}Usage: $0 info <URL>${RESET}"
            echo "Retrieves metadata for a file from its URL."
            ;;
        *)
            echo -e "${GREEN}Usage: $0 [OPTIONS] <command>${RESET}"
            echo
            echo "A versatile script for file transfers using transfer.sh."
            echo
            echo "Options:"
            echo -e "  ${CYAN}--log-level <level>${RESET}   Set logging level (ERROR, WARN, INFO, DEBUG). Default: INFO."
            echo -e "  ${CYAN}-h, --help${RESET}           Display this help message."
            echo
            echo "Commands:"
            echo -e "  ${CYAN}send${RESET}                 Upload a file or directory."
            echo -e "  ${CYAN}receive${RESET}              Download a file."
            echo -e "  ${CYAN}delete${RESET}               Delete a file."
            echo -e "  ${CYAN}info${RESET}                 Get file information."
            ;;
    esac
}

# encrypt_file <input_file> <key>
#
# Encrypts a file using AES-256-CBC with a provided key.
#
# Returns: The path to the temporary encrypted file.
#
encrypt_file() {
    local file="$1"
    local key="$2"
    local outfile
    outfile="$(mktemp)"

    if openssl enc -aes-256-cbc -salt -pbkdf2 -in "$file" -out "$outfile" -pass pass:"$key"; then
        echo "$outfile"
    else
        rm -f "$outfile"
        return 1
    fi
}

# decrypt_file <input_file> <key> <output_file>
#
# Decrypts a file using AES-256-CBC with a provided key.
#
decrypt_file() {
    local file="$1"
    local key="$2"
    local outfile="$3"

    openssl enc -d -aes-256-cbc -pbkdf2 -in "$file" -out "$outfile" -pass pass:"$key"
}

# send_file_or_directory <arguments...>
#
# Handles the logic for uploading files and directories.
#
send_file_or_directory() {
    local max_downloads="$TRANSFERSH_MAX_DAYS"
    local max_days="$TRANSFERSH_MAX_DOWNLOADS"
    local encryption_key="$TRANSFERSH_ENCRYPTION_KEY"
    local request_confirmation=true
    local auth_provided=false

    # --- Argument Parsing ---
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--max-downloads) max_downloads="$2"; shift 2 ;;
            -D|--max-days) max_days="$2"; shift 2 ;;
            -k|--key) encryption_key="$2"; shift 2 ;;
            -u|--user) AUTH_USER="$2"; auth_provided=true; shift 2 ;;
            -p|--password) AUTH_PASS="$2"; auth_provided=true; shift 2 ;;
            -y) request_confirmation=false; shift ;;
            -h|--help) display_help send; return 0 ;;
            *) break ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        log "ERROR" "No files or directories specified."
        display_help send
        return 1
    fi

    # --- User Confirmation ---
    if [[ "$request_confirmation" == "true" ]]; then
        echo -e "${CYAN}You are about to upload:${RESET}"
        for item in "$@"; do echo -e "  ${BLUE}- $(basename "$item")${RESET}"; done
        read -p $'\e[1;35mProceed? (Y/n): \e[0m' confirm
        [[ "${confirm:-y}" =~ ^[Yy]$ ]] || { log "INFO" "Upload cancelled."; return 0; }
    fi

    # --- Prepare Upload ---
    local temp_file
    local file_name
    local should_zip=false
    if [[ $# -gt 1 || -d "$1" ]]; then
        should_zip=true
        temp_file="$(mktemp -u).zip"
        log "INFO" "Creating zip archive: $temp_file"
        zip -r "$temp_file" "$@" > /dev/null
        file_name="transfer-$(date +%s).zip"
    else
        temp_file="$1"
        file_name=$(basename "$1")
    fi

    # --- Encryption ---
    if [ -z "$encryption_key" ]; then
        echo -ne "${CYAN}Enter encryption key (or press Enter to skip): ${RESET}"
        read -rs encryption_key
        echo
    fi

    local upload_file="$temp_file"
    if [ -n "$encryption_key" ]; then
        log "INFO" "Encrypting file..."
        local encrypted_file
        encrypted_file=$(encrypt_file "$temp_file" "$encryption_key")
        if [[ $? -ne 0 ]]; then
            log "ERROR" "Encryption failed."
            [ "$should_zip" = true ] && rm "$temp_file"
            return 1
        fi
        upload_file="$encrypted_file"
        file_name+=".enc"
    fi

    # --- Build Headers and Auth ---
    local headers=()
    [[ -n "$max_downloads" ]] && headers+=("-H" "Max-Downloads: $max_downloads")
    [[ -n "$max_days" ]] && headers+=("-H" "Max-Days: $max_days")

    local auth_options=()
    if [[ "$auth_provided" == "true" || -n "$AUTH_USER" ]]; then
        auth_options=("--user" "$AUTH_USER:$AUTH_PASS")
    fi

    # --- Upload ---
    log "INFO" "Uploading $file_name..."
    local response
    response=$(curl_call --dump-header /dev/stdout --progress-bar "${auth_options[@]}" "${headers[@]}" --upload-file "$upload_file" "${TRANSFERSH_URL}/$file_name" 2>&1 | grep -v 'HTTP/2')
    local return_code=$?

    # --- Cleanup ---
    if [ "$should_zip" = true ]; then rm "$temp_file"; fi
    if [ -n "$encryption_key" ]; then rm "$upload_file"; fi

    # --- Process Response ---
    if [[ $return_code -ne 0 ]] || echo "$response" | grep -q "Not authorized"; then
        log "ERROR" "Upload failed. Please check credentials and URL."
        log "DEBUG" "Server response:\n$response"
        return 1
    fi

    local url_delete
    url_delete=$(echo "$response" | grep -i 'x-url-delete:' | awk '{print $2}' | tr -d '\r')
    local url
    url=$(echo "$response" | tail -n 1 | tr -d '\r')

    if [ -n "$url" ]; then
        echo -e "\n${GREEN}${BOLD}✔ Upload Successful${RESET}"
        echo -e "  ${BOLD}Link:${RESET}      ${GREEN}${url}${RESET}"
        echo -e "  ${BOLD}Receive:${RESET}   ${BLUE}${COMMAND} receive ${url}${RESET}"
        echo -e "  ${BOLD}Delete:${RESET}    ${RED}${COMMAND} delete ${url_delete}${RESET}"
    fi
}

# receive_file_or_directory <arguments...>
#
# Handles the logic for downloading files.
#
receive_file_or_directory() {
    local encryption_key="$TRANSFERSH_ENCRYPTION_KEY"
    local offer_unzip=false
    local url=""
    local destination="."

    # --- Argument Parsing ---
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--key) encryption_key="$2"; shift 2 ;;
            -u|--unzip) offer_unzip=true; shift ;;
            -h|--help) display_help receive; return 0 ;;
            *)
                if [ -z "$url" ]; then url="$1"; else destination="$1"; fi
                shift
                ;;
        esac
    done

    if [ -z "$url" ]; then
        log "ERROR" "No URL specified."
        display_help receive
        return 1
    fi

    local file_name
    file_name=$(basename "$url")

    # --- Decryption Key ---
    if [[ "$file_name" == *.enc ]] && [ -z "$encryption_key" ]; then
        read -sp "Enter decryption key: " encryption_key
        echo
    fi

    # --- Download ---
    log "INFO" "Downloading from $url..."
    local temp_download
    temp_download="$(mktemp)"
    local http_code
    http_code=$(curl_call "$url" -o "$temp_download" -w "%{http_code}" -s)

    if [[ $? -ne 0 || "$http_code" -ne 200 ]]; then
        log "ERROR" "Download failed. HTTP status: $http_code"
        rm "$temp_download"
        return 1
    fi

    # --- Decrypt or Move ---
    local final_path="$destination/$file_name"
    if [ -n "$encryption_key" ]; then
        log "INFO" "Decrypting file..."
        final_path="${final_path%.enc}"
        if ! decrypt_file "$temp_download" "$encryption_key" "$final_path"; then
            log "ERROR" "Decryption failed. Check your key."
            rm "$temp_download"
            return 1
        fi
    else
        mv "$temp_download" "$final_path"
    fi
    rm "$temp_download"

    log "INFO" "File saved to: $final_path"

    # --- Unzip ---
    if [[ "$offer_unzip" == "true" ]] && [[ "$final_path" == *.zip ]]; then
        read -p $'\e[1;35mUnzip the downloaded file? (Y/n): \e[0m' confirm_unzip
        if [[ "${confirm_unzip:-y}" =~ ^[Yy]$ ]]; then
            unzip "$final_path" -d "$destination"
            rm "$final_path"
            log "INFO" "File unzipped and original archive removed."
        fi
    fi
}

# delete_file_or_directory <delete_url>
#
# Deletes a file using its deletion URL.
#
delete_file_or_directory() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        display_help delete
        return 0
    fi
    local delete_url="$1"
    if [ -z "$delete_url" ]; then
        log "ERROR" "No delete URL specified."
        display_help delete
        return 1
    fi
    log "INFO" "Sending delete request to: $delete_url"
    curl_call -X DELETE "$delete_url"
    log "INFO" "Delete request sent."
}

# info_command <url>
#
# Retrieves and displays metadata for a file.
#
info_command() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        display_help info
        return 0
    fi
    local url="$1"
    if [ -z "$url" ]; then
        log "ERROR" "No URL specified."
        display_help info
        return 1
    fi
    log "INFO" "Retrieving metadata for: $url"
    curl_call -I "$url" | \
    awk '/x-remaining-days/ {print "Remaining Days: " $2} /x-remaining-downloads/ {print "Remaining Downloads: " $2} /Content-Length/ {print "File Size (bytes): " $2} /Content-Type/ {print "MIME Type: " $2}'
}

# ==============================================================================
# Main Execution
# ==============================================================================
main() {
    check_requirements

    if [[ $# -eq 0 ]]; then
        display_help
        exit 0
    fi

    # Global options
    if [[ "$1" == "--log-level" ]]; then
        LOG_LEVEL="$2"
        log "INFO" "Log level set to: $LOG_LEVEL"
        shift 2
    fi

    local command="$1"
    shift

    case "$command" in
        send|receive|delete|info)
            "${command}_command" "$@"
            ;;
        -h|--help)
            display_help
            ;;
        *)
            log "ERROR" "Invalid command: $command"
            display_help
            exit 1
            ;;
    esac
}

# Rename functions to avoid conflicts with command names
send_command() { send_file_or_directory "$@"; }
receive_command() { receive_file_or_directory "$@"; }
delete_command() { delete_file_or_directory "$@"; }

main "$@"
