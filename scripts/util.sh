#!/usr/bin/env bash

# util.sh - Common utilities for GoMicroserviceFramework scripts
# This file should be sourced by all other scripts in the framework

# Strict error handling
# -e: Exit on error
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure
set -euo pipefail

# ANSI color codes (must be defined before error trap uses them)
GREY='\033[0;90m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error trap handler
error_trap() {
    local exit_code=$?
    local line_number=$1
    local bash_lineno=$2
    # Get the script name safely, checking if BASH_SOURCE has enough elements
    local script_name="unknown"
    if [ ${#BASH_SOURCE[@]} -gt 2 ]; then
        script_name=$(basename "${BASH_SOURCE[2]}")
    elif [ ${#BASH_SOURCE[@]} -gt 1 ]; then
        script_name=$(basename "${BASH_SOURCE[1]}")
    fi
    local timestamp=$(date '+%H:%M:%S')
    
    echo -e "${GREY}[${timestamp}][${script_name}:${bash_lineno}]${NC} - ${RED}ERROR:${NC} Command failed with exit code ${exit_code}" >&2
    exit $exit_code
}

# Set up error trap for all scripts
trap 'error_trap $LINENO ${BASH_LINENO[0]}' ERR

# Custom echo function with timestamp and source location
# Usage: lp-echo "Your message here"
lp-echo() {
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    
    # Get the caller information
    local caller_info="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    
    # Extract just the script name from full path
    local script_name=$(basename "$caller_info")
    
    # Format: [HH:mm:ss][script.sh:lineNumber] - message
    echo -e "${GREY}[${timestamp}][${script_name}:${line_number}]${NC} - ${message}"
}

# Error logging function
lp-error() {
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    local caller_info="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    local script_name=$(basename "$caller_info")
    
    echo -e "${GREY}[${timestamp}][${script_name}:${line_number}]${NC} - ${RED}ERROR:${NC} ${message}" >&2
}

# Success logging function
lp-success() {
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    local caller_info="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    local script_name=$(basename "$caller_info")
    
    echo -e "${GREY}[${timestamp}][${script_name}:${line_number}]${NC} - ${GREEN}✓${NC} ${message}"
}

# Warning logging function
lp-warn() {
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    local caller_info="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    local script_name=$(basename "$caller_info")
    
    echo -e "${GREY}[${timestamp}][${script_name}:${line_number}]${NC} - ${YELLOW}WARNING:${NC} ${message}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate service exists
validate_service() {
    local service_name="$1"
    local services_dir="${FRAMEWORK_ROOT}/services"
    
    if [ -z "$service_name" ]; then
        lp-error "Service name is required"
        return 1
    fi
    
    if [ ! -d "${services_dir}/${service_name}" ]; then
        lp-error "Service '${service_name}' not found in ${services_dir}"
        return 1
    fi
    
    return 0
}

# Get Go binary path
get_go_binary() {
    local setup_go_script="${FRAMEWORK_ROOT}/scripts/setup-go.sh"
    local go_root=$("$setup_go_script" 2>/dev/null || echo "")
    
    if [ -z "$go_root" ]; then
        lp-error "Go toolchain not found. Run 'make setup-go' first"
        return 1
    fi
    
    echo "${go_root}/bin/go"
}

# Export common variables
export FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export GOBIN_CACHE="${FRAMEWORK_ROOT}/.gobincache"
export GOBIN="${GOBIN_CACHE}"
