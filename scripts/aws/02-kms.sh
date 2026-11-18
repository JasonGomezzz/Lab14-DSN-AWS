#!/usr/bin/env bash
# Paso 2 (capturas 5 a 10 del enunciado): clave KMS simétrica "lab14".
#  - Tipo simétrico, origen KMS, clave de una sola región
#  - Administradores de la clave: dev01 y dev02 (con permiso de eliminarla)
#  - Usuarios de la clave: dev01 y dev02 (cifrar/descifrar)
#  - Rotación automática anual activada
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT

if [[ -n "$(key_arn)" ]]; then
  echo "La clave $KEY_ALIAS ya existe: $(key_arn)"
else
  POLICY="$(sed "s/__ACCOUNT_ID__/${ACCOUNT_ID}/g" "$DIR/policies/lab14-key-policy.json.tpl")"

  # IAM es eventualmente consistente: si dev01/dev02 acaban de crearse, la
  # política puede rechazarse unos segundos. Se reintenta.
  for intento in 1 2 3 4 5 6; do
    if KEY_ID="$(aws kms create-key \
        --description "lab14 - clave simétrica EcomSecure" \
        --key-spec SYMMETRIC_DEFAULT --key-usage ENCRYPT_DECRYPT \
        --origin AWS_KMS --no-multi-region \
        --policy "$POLICY" \
        --tags TagKey=lab,TagValue=lab14 \
        --query 'KeyMetadata.KeyId' --output text 2>"$ERR")"; then
      break
    fi
    echo "reintento $intento (propagación de IAM)..."; sleep 8
    [[ $intento -eq 6 ]] && { cat "$ERR"; exit 1; }
  done

  aws kms create-alias --alias-name "$KEY_ALIAS" --target-key-id "$KEY_ID"
  echo "clave creada: $KEY_ID"
fi

KEY_ID="$(aws kms describe-key --key-id "$KEY_ALIAS" --query KeyMetadata.KeyId --output text)"
# La rotación solo acepta el id de la clave, no el alias.
aws kms enable-key-rotation --key-id "$KEY_ID"

{
  echo "# Metadatos de la clave $KEY_ALIAS"
  aws kms describe-key --key-id "$KEY_ALIAS" --query 'KeyMetadata.{Arn:Arn,Estado:KeyState,Uso:KeyUsage,Spec:KeySpec,Origen:Origin,MultiRegion:MultiRegion,Cuenta:AWSAccountId}' --output table
  echo "# Rotación automática"
  aws kms get-key-rotation-status --key-id "$KEY_ID" --output table
  echo "# Política de la clave"
  aws kms get-key-policy --key-id "$KEY_ID" --policy-name default --query Policy --output text
} | tee "$EVID_DIR/02-kms.txt"
