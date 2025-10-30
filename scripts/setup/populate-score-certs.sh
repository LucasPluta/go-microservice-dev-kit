#!/bin/bash

# populate-score-certs.sh
# Helper script to populate TLS certificates in the Score configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
SCORE_FILE="${SCRIPT_DIR}/score.yaml"

echo "Populating Score.yaml with TLS certificates..."

# Check if certificates exist
if [[ ! -d "${CERTS_DIR}" ]]; then
    echo "Error: Certificates directory not found at ${CERTS_DIR}"
    echo "Please run 'make setup' first to generate certificates"
    exit 1
fi

# Function to base64 encode and escape for YAML
encode_cert() {
    local cert_file="$1"
    if [[ ! -f "${cert_file}" ]]; then
        echo "Error: Certificate file not found: ${cert_file}"
        exit 1
    fi
    # Base64 encode and indent for YAML
    base64 -i "${cert_file}" | sed 's/^/        /'
}

# Create a temporary file with populated certificates
TEMP_SCORE=$(mktemp)

# Read the score.yaml file and replace certificate placeholders
while IFS= read -r line; do
    case "$line" in
        *"# Base64 encoded CA certificate"*)
            echo "      ca-cert.pem: |"
            encode_cert "${CERTS_DIR}/ca-cert.pem"
            ;;
        *"# This should be populated from ./certs/ca-cert.pem"*)
            # Skip this line as it's replaced above
            ;;
        *"# Base64 encoded server certificate"*)
            echo "      server-cert.pem: |"
            encode_cert "${CERTS_DIR}/server-cert.pem"
            ;;
        *"# This should be populated from ./certs/server-cert.pem"*)
            # Skip this line as it's replaced above
            ;;
        *"# Base64 encoded server private key"*)
            echo "      server-key.pem: |"
            encode_cert "${CERTS_DIR}/server-key.pem"
            ;;
        *"# This should be populated from ./certs/server-key.pem"*)
            # Skip this line as it's replaced above
            ;;
        *"# Base64 encoded client certificate"*)
            echo "      client-cert.pem: |"
            encode_cert "${CERTS_DIR}/client-cert.pem"
            ;;
        *"# This should be populated from ./certs/client-cert.pem"*)
            # Skip this line as it's replaced above
            ;;
        *"# Base64 encoded client private key"*)
            echo "      client-key.pem: |"
            encode_cert "${CERTS_DIR}/client-key.pem"
            ;;
        *"# This should be populated from ./certs/client-key.pem"*)
            # Skip this line as it's replaced above
            ;;
        *)
            echo "$line"
            ;;
    esac
done < "${SCORE_FILE}" > "${TEMP_SCORE}"

# Replace the original file
mv "${TEMP_SCORE}" "${SCORE_FILE}"

echo "Score.yaml has been populated with TLS certificates!"
echo ""
echo "Usage:"
echo "  score-compose init --file score.yaml"
echo "  score-compose generate score.yaml"
echo ""
echo "Or with specific environment:"
echo "  export IMAGE_REGISTRY=your-registry.com"
echo "  export IMAGE_TAG=v1.0.0"
echo "  export STORAGE_CLASS=fast-ssd"
echo "  score-compose generate score.yaml"