#!/bin/bash
# Self-signed certificate generation script for BaseMachina Bridge
# This script generates a self-signed certificate for testing purposes only.
# DO NOT use self-signed certificates in production environments.
#
# Usage:
#   ./generate-cert.sh          # Interactive mode (prompts for overwrite)
#   ./generate-cert.sh -f       # Force mode (overwrites without prompt)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/../certs"
DOMAIN="bridge.example.local"
FORCE=false

# Parse command-line arguments
if [ "$1" = "-f" ] || [ "$1" = "--force" ]; then
  FORCE=true
fi

echo "=========================================="
echo "Self-Signed Certificate Generator"
echo "=========================================="
echo ""
echo "This script will generate:"
echo "  - 2048-bit RSA private key"
echo "  - Self-signed certificate (valid for 365 days)"
echo "  - Certificate chain"
echo ""
echo "Domain: $DOMAIN"
echo "Output directory: $CERTS_DIR"
echo ""

# Create certs directory if it doesn't exist
mkdir -p "$CERTS_DIR"

# Check if certificates already exist
if [ -f "$CERTS_DIR/private-key.pem" ] || [ -f "$CERTS_DIR/certificate.pem" ]; then
  if [ "$FORCE" = true ]; then
    echo "WARNING: Certificate files already exist. Force mode enabled, overwriting..."
    echo ""
  else
    echo "WARNING: Certificate files already exist in $CERTS_DIR"
    echo ""
    read -p "Overwrite existing certificates? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted. No files were modified."
      exit 1
    fi
    echo ""
  fi
fi

echo "Generating certificates..."
echo ""

# Generate private key (2048-bit RSA)
echo "[1/3] Generating 2048-bit RSA private key..."
openssl genrsa -out "$CERTS_DIR/private-key.pem" 2048

# Generate self-signed certificate (valid for 365 days)
echo "[2/3] Generating self-signed certificate (valid for 365 days)..."
openssl req -new -x509 -key "$CERTS_DIR/private-key.pem" \
  -out "$CERTS_DIR/certificate.pem" -days 365 \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=BaseMachina/CN=$DOMAIN"

# Create certificate chain (for self-signed, it's the same as the certificate)
echo "[3/3] Creating certificate chain..."
cp "$CERTS_DIR/certificate.pem" "$CERTS_DIR/certificate-chain.pem"

echo ""
echo "=========================================="
echo "✓ Self-signed certificate generated successfully!"
echo "=========================================="
echo ""
echo "Generated files:"
echo "  - $CERTS_DIR/private-key.pem (Private Key)"
echo "  - $CERTS_DIR/certificate.pem (Certificate)"
echo "  - $CERTS_DIR/certificate-chain.pem (Certificate Chain)"
echo ""
echo "Next steps:"
echo "  1. Import certificate to ACM: Set enable_acm_import = true in terraform.tfvars"
echo "  2. Deploy infrastructure: terraform apply"
echo ""
echo "IMPORTANT NOTES:"
echo "  - Self-signed certificates are for TESTING ONLY"
echo "  - Browsers will show security warnings"
echo "  - Use 'curl -k' to bypass certificate validation"
echo "  - For production, use certificates from a trusted CA"
echo ""
