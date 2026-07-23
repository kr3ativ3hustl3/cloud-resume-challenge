"""
Unit tests for the counter Lambda, using botocore's built-in Stubber
to mock the DynamoDB client response — no real AWS calls, no cost,
and critically, no extra dependencies beyond boto3 itself (which you
already have). This avoids pulling in heavier test libraries like
moto, which drags in `cryptography` and requires a native compiler
toolchain that isn't available on every machine.

Run with:
    cd backend/lambda
    pip3 install --user -r tests/requirements.txt
    python3 -m pytest tests/ -v
"""

import json
import os
import sys

import pytest
from botocore.stub import Stubber

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

TEST_TABLE_NAME = "test-counter-table"
TEST_COUNTER_ID = "visits"

os.environ["TABLE_NAME"] = TEST_TABLE_NAME
os.environ["COUNTER_ID"] = TEST_COUNTER_ID
os.environ["ALLOWED_ORIGIN"] = "https://sunsetheard.dev"
# Set explicitly so these tests never depend on the developer's local
# AWS CLI profile or region being configured — they should run
# identically on any machine, with or without AWS credentials at all.
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

import counter  # noqa: E402  (must import after env vars are set above)


def _expected_update_item_params():
    # NOTE: these must be plain Python types, NOT DynamoDB's typed
    # wire format (e.g. {"S": "visits"}). The DynamoDB *resource*
    # interface (as opposed to the low-level client) converts native
    # Python types into that wire format via its own internal hook,
    # but Stubber validates request parameters at an earlier stage,
    # before that conversion runs. The response we hand back below,
    # by contrast, DOES need to be in wire format, since that's what
    # gets deserialized back into native Python types afterward.
    return {
        "TableName": TEST_TABLE_NAME,
        "Key": {"id": TEST_COUNTER_ID},
        "UpdateExpression": "ADD #c :incr",
        "ExpressionAttributeNames": {"#c": "count"},
        "ExpressionAttributeValues": {":incr": 1},
        "ReturnValues": "UPDATED_NEW",
    }


def _stub_response(new_count):
    return {"Attributes": {"count": {"N": str(new_count)}}}


@pytest.fixture
def stubbed_client():
    """Stubs the low-level DynamoDB client that the Table resource
    uses under the hood, so no real AWS call is ever made."""
    stubber = Stubber(counter.table.meta.client)
    stubber.activate()
    yield stubber
    stubber.deactivate()
    stubber.assert_no_pending_responses()


def test_first_invocation_returns_count_1(stubbed_client):
    stubbed_client.add_response(
        "update_item", _stub_response(1), _expected_update_item_params()
    )

    result = counter.handler({}, None)

    assert result["statusCode"] == 200
    assert json.loads(result["body"]) == {"count": 1}


def test_repeated_invocations_increment(stubbed_client):
    stubbed_client.add_response(
        "update_item", _stub_response(1), _expected_update_item_params()
    )
    stubbed_client.add_response(
        "update_item", _stub_response(2), _expected_update_item_params()
    )
    stubbed_client.add_response(
        "update_item", _stub_response(3), _expected_update_item_params()
    )

    counter.handler({}, None)
    counter.handler({}, None)
    result = counter.handler({}, None)

    assert json.loads(result["body"]) == {"count": 3}


def test_response_includes_cors_header(stubbed_client):
    stubbed_client.add_response(
        "update_item", _stub_response(1), _expected_update_item_params()
    )

    result = counter.handler({}, None)

    assert result["headers"]["Access-Control-Allow-Origin"] == "https://sunsetheard.dev"


def test_response_content_type_is_json(stubbed_client):
    stubbed_client.add_response(
        "update_item", _stub_response(1), _expected_update_item_params()
    )

    result = counter.handler({}, None)

    assert result["headers"]["Content-Type"] == "application/json"
