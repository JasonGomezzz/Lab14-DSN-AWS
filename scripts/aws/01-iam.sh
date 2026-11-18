#!/usr/bin/env bash
# Paso 1 (capturas 1 y 2 del enunciado): grupos de IAM y usuarios dev01/dev02.
#  - Grupo Developer con AmazonS3FullAccess, AWSKeyManagementServicePowerUser y ReadOnlyAccess
#  - Grupos vacíos Backend_Developer y Frontend_Developer (como en la captura)
#  - Usuarios dev01 y dev02 dentro de Developer
#  - dev03: usuario de contraste con solo lectura de S3 (sin permisos KMS)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"

POLICIES_DEV=(
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
  "arn:aws:iam::aws:policy/ReadOnlyAccess"
)

crear_grupo() {
  aws iam get-group --group-name "$1" >/dev/null 2>&1 \
    || aws iam create-group --group-name "$1" >/dev/null
  echo "grupo OK: $1"
}

crear_usuario() {
  aws iam get-user --user-name "$1" >/dev/null 2>&1 \
    || aws iam create-user --user-name "$1" --tags Key=lab,Value=lab14 >/dev/null
  echo "usuario OK: $1"
}

crear_grupo "$GROUP_DEV"
for g in "${GROUPS_EXTRA[@]}"; do crear_grupo "$g"; done

for p in "${POLICIES_DEV[@]}"; do
  aws iam attach-group-policy --group-name "$GROUP_DEV" --policy-arn "$p"
  echo "política asociada a $GROUP_DEV: ${p##*/}"
done

for u in "${USERS_KMS[@]}"; do
  crear_usuario "$u"
  aws iam add-user-to-group --group-name "$GROUP_DEV" --user-name "$u"
done

crear_usuario "$USER_SIN_KMS"
aws iam attach-user-policy --user-name "$USER_SIN_KMS" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
echo "dev03 con AmazonS3ReadOnlyAccess (sin permisos de KMS)"

{
  echo "# Grupos de usuarios IAM"
  aws iam list-groups --query 'Groups[].GroupName' --output table
  echo "# Políticas del grupo $GROUP_DEV"
  aws iam list-attached-group-policies --group-name "$GROUP_DEV" \
    --query 'AttachedPolicies[].PolicyName' --output table
  echo "# Miembros del grupo $GROUP_DEV"
  aws iam get-group --group-name "$GROUP_DEV" --query 'Users[].UserName' --output table
} | tee "$EVID_DIR/01-iam.txt"
