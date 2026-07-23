"""
Visitor counter Lambda.

Atomically increments a single counter item in DynamoDB and returns
the new total. Triggered by API Gateway (HTTP API) on every page load
from the frontend.

Deliberately simple: this counts *page loads*, not unique visitors.
A "unique visitor" counter would need cookies or session tracking,
which adds real complexity and privacy considerations for a personal
portfolio site that isn't worth it here — see docs/architecture.md
for the full reasoning.
"""

import json
import os

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
COUNTER_ID = os.environ.get("COUNTER_ID", "visits")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

# Created once per Lambda execution environment (not per invocation) —
# this is a deliberate performance optimization. Cold starts pay this
# cost once; warm invocations reuse the same client/resource.
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    response = table.update_item(
        Key={"id": COUNTER_ID},
        UpdateExpression="ADD #c :incr",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":incr": 1},
        ReturnValues="UPDATED_NEW",
    )

    count = int(response["Attributes"]["count"])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            # API Gateway's own CORS config (set in Terraform) handles
            # this too, but setting it here as well means the response
            # is still correct if this function is ever tested directly
            # via a Lambda Function URL, bypassing API Gateway.
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
        },
        "body": json.dumps({"count": count}),
    }
