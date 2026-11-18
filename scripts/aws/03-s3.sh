#!/usr/bin/env bash
# Paso 3 (capturas 3, 4, 11, 12 y 13 del enunciado): bucket S3 y cifrado SSE-KMS.
#  1. Crea el bucket (privado, con acceso público bloqueado)
#  2. Sube data.txt y una imagen con el cifrado por defecto (SSE-S3)
#  3. "Acciones > Editar cifrado del lado del servidor": vuelve a cifrar la imagen
#     con SSE-KMS usando la clave lab14 ("Anular la configuración del bucket")
#     data.txt se deja con SSE-S3 a propósito, para contrastar en las pruebas.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"

KEY_ARN="$(key_arn)"
[[ -n "$KEY_ARN" ]] || { echo "No existe $KEY_ALIAS: ejecuta antes 02-kms.sh" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 1. Bucket
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "El bucket $BUCKET ya existe"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration "LocationConstraint=$AWS_REGION" >/dev/null
  echo "bucket creado: $BUCKET ($AWS_REGION)"
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 2. Objetos de prueba (imagen PNG generada localmente, sin dependencias)
printf 'Dato confidencial de EcomSecure: lab14\n' > "$TMP/$OBJ_TEXTO"
python3 -I - "$TMP/$OBJ_IMAGEN" <<'PY'
import struct, sys, zlib
w, h = 640, 360
filas = bytearray()
for y in range(h):
    filas.append(0)
    for x in range(w):
        filas += bytes((20 + x * 40 // w, 60 + y * 120 // h, 140 + x * 100 // w))
def chunk(tipo, datos):
    c = struct.pack(">I", len(datos)) + tipo + datos
    return c + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(bytes(filas), 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY

aws s3api put-object --bucket "$BUCKET" --key "$OBJ_TEXTO" --body "$TMP/$OBJ_TEXTO" \
  --content-type text/plain >/dev/null
aws s3api put-object --bucket "$BUCKET" --key "$OBJ_IMAGEN" --body "$TMP/$OBJ_IMAGEN" \
  --content-type image/png >/dev/null

estado() {  # imprime el cifrado de un objeto
  aws s3api head-object --bucket "$BUCKET" --key "$1" \
    --query '{Objeto:`'"$1"'`,Cifrado:ServerSideEncryption,ClaveKMS:SSEKMSKeyId,BucketKey:BucketKeyEnabled}' \
    --output table
}

{
  echo "# ANTES de editar el cifrado (valor por defecto del bucket)"
  estado "$OBJ_IMAGEN"
} | tee "$EVID_DIR/03-s3-antes.txt"

# 3. Editar cifrado del lado del servidor: copiar el objeto sobre sí mismo con SSE-KMS
aws s3api copy-object --bucket "$BUCKET" --key "$OBJ_IMAGEN" \
  --copy-source "$BUCKET/$OBJ_IMAGEN" --metadata-directive REPLACE \
  --content-type image/png \
  --server-side-encryption aws:kms --ssekms-key-id "$KEY_ARN" >/dev/null

{
  echo "# DESPUÉS: imagen con SSE-KMS y clave $KEY_ALIAS; data.txt sigue con SSE-S3"
  estado "$OBJ_IMAGEN"
  estado "$OBJ_TEXTO"
  echo "# Objetos del bucket"
  aws s3 ls "s3://$BUCKET/"
} | tee "$EVID_DIR/03-s3-despues.txt"
