#!/usr/bin/env bash
# Paso 4: comprobar que las políticas de la clave funcionan.
#  - dev01 (usuario de la clave): puede leer la imagen cifrada con KMS
#  - dev03 (solo S3): puede leer data.txt (SSE-S3) pero NO la imagen (SSE-KMS)
# Las claves de acceso de dev01 y dev03 se guardan en perfiles locales de AWS CLI
# (~/.aws/credentials, fuera del repo) y nunca se imprimen.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
set +e

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="$EVID_DIR/04-pruebas-acceso.txt"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

crear_perfil() {  # $1 usuario IAM
  local perfil="lab14-$1"
  if aws configure get aws_access_key_id --profile "$perfil" >/dev/null 2>&1; then return; fi
  local k s
  read -r k s < <(aws iam create-access-key --user-name "$1" \
      --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
  aws configure set aws_access_key_id "$k" --profile "$perfil"
  aws configure set aws_secret_access_key "$s" --profile "$perfil"
  aws configure set region "$AWS_REGION" --profile "$perfil"
  echo "perfil local creado: $perfil"
}

esperar_perfil() {
  for _ in $(seq 1 12); do
    aws sts get-caller-identity --profile "lab14-$1" >/dev/null 2>&1 && return 0
    sleep 5
  done
  echo "El perfil lab14-$1 no quedó activo" >&2; return 1
}

crear_perfil dev01; crear_perfil dev03
esperar_perfil dev01; esperar_perfil dev03

prueba() {  # $1 descripción; resto: comando
  local desc="$1"; shift
  echo; echo "## $desc"
  echo "\$ ${*//$BUCKET/<bucket>}"
  if salida="$("$@" 2>&1)"; then echo "RESULTADO: OK"; else
    echo "RESULTADO: DENEGADO/ERROR"; echo "$salida" | tail -3 | sed "s/$BUCKET/<bucket>/g"
  fi
}

{
echo "# Pruebas de acceso - lab14 ($(date '+%Y-%m-%d %H:%M'))"
echo "dev01 -> $(aws sts get-caller-identity --profile lab14-dev01 --query Arn --output text)"
echo "dev03 -> $(aws sts get-caller-identity --profile lab14-dev03 --query Arn --output text)"

prueba "dev01 lee la imagen cifrada con SSE-KMS" \
  aws s3api get-object --bucket "$BUCKET" --key "$OBJ_IMAGEN" "$TMP/dev01.png" --profile lab14-dev01 --query 'ServerSideEncryption'
prueba "dev03 lee data.txt (SSE-S3)" \
  aws s3api get-object --bucket "$BUCKET" --key "$OBJ_TEXTO" "$TMP/dev03.txt" --profile lab14-dev03 --query 'ServerSideEncryption'
prueba "dev03 intenta leer la imagen cifrada con SSE-KMS" \
  aws s3api get-object --bucket "$BUCKET" --key "$OBJ_IMAGEN" "$TMP/dev03.png" --profile lab14-dev03

echo; echo "# Cifrado directo con la clave (API KMS)"
printf 'secreto-lab14' > "$TMP/plano.txt"
prueba "dev01 cifra con la clave lab14" \
  aws kms encrypt --key-id "$KEY_ALIAS" --plaintext fileb://"$TMP/plano.txt" \
  --query CiphertextBlob --output text --profile lab14-dev01
prueba "dev03 intenta cifrar con la clave lab14" \
  aws kms encrypt --key-id "$KEY_ALIAS" --plaintext fileb://"$TMP/plano.txt" \
  --query CiphertextBlob --output text --profile lab14-dev03

echo; echo "# Ida y vuelta Encrypt/Decrypt con dev01"
aws kms encrypt --key-id "$KEY_ALIAS" --plaintext fileb://"$TMP/plano.txt" \
  --query CiphertextBlob --output text --profile lab14-dev01 | base64 -d > "$TMP/cifrado.bin"
echo "texto cifrado: $(wc -c < "$TMP/cifrado.bin" | tr -d ' ') bytes"
echo "descifrado: $(aws kms decrypt --ciphertext-blob fileb://"$TMP/cifrado.bin" \
  --query Plaintext --output text --profile lab14-dev01 | base64 -d)"

if command -v php >/dev/null && [[ -d "$RAIZ/vendor" ]]; then
  echo; echo "# Script PHP del enunciado (src/ver-imagen.php)"
  for u in dev01 dev03; do
    echo "## PHP con perfil lab14-$u"
    AWS_PROFILE="lab14-$u" S3_BUCKET="$BUCKET" php "$RAIZ/src/ver-imagen.php" > "$TMP/php-$u.out" 2>&1
    if file "$TMP/php-$u.out" | grep -qi 'PNG image'; then
      echo "RESULTADO: OK, devolvió una imagen PNG ($(wc -c < "$TMP/php-$u.out" | tr -d ' ') bytes)"
    else
      echo "RESULTADO: DENEGADO"; head -2 "$TMP/php-$u.out"
    fi
  done
fi
} 2>&1 | tee "$SALIDA"
