#!/usr/bin/env bash
# Limpieza total del laboratorio 14. DESTRUCTIVO: ejecútalo solo cuando ya tengas
# las capturas y el informe terminados.
#   bash scripts/aws/99-limpieza.sh --confirmar
# La clave KMS no se borra al instante: queda programada para eliminarse en 7 días
# (mínimo que permite AWS); hasta entonces se puede cancelar con
#   aws kms cancel-key-deletion --key-id <id>
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
set +e

[[ "${1:-}" == "--confirmar" ]] || {
  echo "Esto borrará bucket, usuarios, grupos y la clave KMS del lab14."
  echo "Repite con --confirmar para continuar."; exit 1; }

echo "== Bucket"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3 rm "s3://$BUCKET" --recursive >/dev/null
  aws s3api delete-bucket --bucket "$BUCKET" && echo "bucket eliminado"
fi

echo "== Clave KMS (eliminación programada a 7 días)"
KEY_ID="$(aws kms describe-key --key-id "$KEY_ALIAS" --query KeyMetadata.KeyId --output text 2>/dev/null)"
if [[ -n "$KEY_ID" ]]; then
  aws kms delete-alias --alias-name "$KEY_ALIAS"
  aws kms schedule-key-deletion --key-id "$KEY_ID" --pending-window-in-days 7 \
    --query '{Clave:KeyId,Eliminacion:DeletionDate}' --output table
fi

echo "== IAM"
for u in "${USERS_KMS[@]}" "$USER_SIN_KMS"; do
  aws iam get-user --user-name "$u" >/dev/null 2>&1 || continue
  for k in $(aws iam list-access-keys --user-name "$u" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
    aws iam delete-access-key --user-name "$u" --access-key-id "$k"
  done
  for g in $(aws iam list-groups-for-user --user-name "$u" --query 'Groups[].GroupName' --output text); do
    aws iam remove-user-from-group --user-name "$u" --group-name "$g"
  done
  for p in $(aws iam list-attached-user-policies --user-name "$u" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-user-policy --user-name "$u" --policy-arn "$p"
  done
  aws iam delete-user --user-name "$u" && echo "usuario eliminado: $u"
done
for g in "$GROUP_DEV" "${GROUPS_EXTRA[@]}"; do
  aws iam get-group --group-name "$g" >/dev/null 2>&1 || continue
  for p in $(aws iam list-attached-group-policies --group-name "$g" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-group-policy --group-name "$g" --policy-arn "$p"
  done
  aws iam delete-group --group-name "$g" && echo "grupo eliminado: $g"
done

echo "== Perfiles locales de AWS CLI (se hace copia de seguridad)"
for f in "$HOME/.aws/credentials" "$HOME/.aws/config"; do
  [[ -f "$f" ]] || continue
  cp "$f" "$f.bak-lab14"
  awk '/^\[/ { omitir = ($0 ~ /lab14-dev0[13]\]$/) } !omitir' "$f.bak-lab14" > "$f"
done
echo "perfiles lab14-dev01 y lab14-dev03 quitados (copias: *.bak-lab14)"
