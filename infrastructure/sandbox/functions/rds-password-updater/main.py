import sys
import os

import boto3

secretsmanager = boto3.client("secretsmanager")
rds = boto3.client("rds")


def lambda_handler(event, context):
    db_id = event["dbId"]
    db_password_secret_id = event["dbPasswordSecretId"]

    # Retrieve the current password from Secrets Manager
    current_secret = secretsmanager.get_secret_value(SecretId=db_password_secret_id)
    current_password = current_secret["SecretString"]

    # Update the password in RDS
    rds.modify_db_instance(
        DBInstanceIdentifier=db_id,
        MasterUserPassword=current_password,
        ApplyImmediately=True,
    )

    return {"ok": True}
