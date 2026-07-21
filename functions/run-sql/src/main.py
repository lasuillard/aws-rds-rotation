import sys
import os

import boto3
import psycopg

rds = boto3.client("rds")


def lambda_handler(event, context):
    return True
