#!/usr/bin/env bash
# Variables comunes del laboratorio 14 (AWS KMS + S3). Se carga con `source`.
# Todo es parametrizable por variables de entorno; los valores por defecto
# reproducen el escenario del enunciado (us-east-2, usuarios dev01 y dev02).

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-2}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export ACCOUNT_ID

# El nombre del bucket debe ser único en todo AWS: se deriva del id de cuenta.
export BUCKET="${BUCKET:-ecomsecure-lab14-${ACCOUNT_ID}}"
export KEY_ALIAS="${KEY_ALIAS:-alias/lab14}"

export GROUP_DEV="Developer"
export GROUPS_EXTRA=("Backend_Developer" "Frontend_Developer")
export USERS_KMS=("dev01" "dev02")   # administradores y usuarios de la clave
export USER_SIN_KMS="dev03"          # usuario de contraste: S3 sí, KMS no

export OBJ_IMAGEN="aws-servicios.png"
export OBJ_TEXTO="data.txt"

EVID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/docs/evidencias"
export EVID_DIR
mkdir -p "$EVID_DIR"

# Devuelve el ARN de la clave a partir del alias (vacío si no existe).
key_arn() {
  aws kms describe-key --key-id "$KEY_ALIAS" \
    --query 'KeyMetadata.Arn' --output text 2>/dev/null || true
}
