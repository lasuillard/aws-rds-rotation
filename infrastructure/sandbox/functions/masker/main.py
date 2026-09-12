import sys
import os

import boto3
import psycopg

secretsmanager = boto3.client("secretsmanager")
rds = boto3.client("rds")


def lambda_handler(event, context):
    db_id = event["dbId"]
    db_password_secret_id = event["dbPasswordSecretId"]

    # Retrieve the current password from Secrets Manager
    current_secret = secretsmanager.get_secret_value(SecretId=db_password_secret_id)
    current_password = current_secret["SecretString"]

    # Get connection details
    db_instance = rds.describe_db_instances(DBInstanceIdentifier=db_id)["DBInstances"][
        0
    ]
    db_host = db_instance["Endpoint"]["Address"]
    db_port = db_instance["Endpoint"]["Port"]
    db_name = db_instance["DBName"]
    db_username = db_instance["MasterUsername"]
    db_password = current_password

    # Run a simple query to verify the connection
    with psycopg.connect(
        host=db_host,
        port=db_port,
        dbname=db_name,
        user=db_username,
        password=db_password,
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")

    return {"ok": True}
