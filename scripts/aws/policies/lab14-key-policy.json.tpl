{
  "Version": "2012-10-17",
  "Id": "lab14-key-policy",
  "Statement": [
    {
      "Sid": "HabilitarPermisosIAMdeLaCuenta",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::__ACCOUNT_ID__:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AdministradoresDeLaClave",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::__ACCOUNT_ID__:user/dev01",
          "arn:aws:iam::__ACCOUNT_ID__:user/dev02"
        ]
      },
      "Action": [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "UsuariosDeLaClave",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::__ACCOUNT_ID__:user/dev01",
          "arn:aws:iam::__ACCOUNT_ID__:user/dev02"
        ]
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "UsuariosDeLaClaveConGrantsDeServiciosAWS",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::__ACCOUNT_ID__:user/dev01",
          "arn:aws:iam::__ACCOUNT_ID__:user/dev02"
        ]
      },
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": "*",
      "Condition": { "Bool": { "kms:GrantIsForAWSResource": "true" } }
    }
  ]
}
