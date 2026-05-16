"""SES email forwarder.

Triggered when SES drops a new incoming email into the S3 bucket. Reads
the raw MIME, rewrites the From header to a verified sender on
trailcount.io (so SES will accept the outbound send), preserves the
original sender in Reply-To so replies route back correctly, and
forwards via SES SendRawEmail to FORWARD_TO.

Designed for low volume (≤ a few messages/day) and SES sandbox mode —
FORWARD_TO must be a separately-verified SES recipient, and SES will
refuse to send anywhere else until the account leaves sandbox.

Env vars (set in Terraform):
- INCOMING_BUCKET: the S3 bucket that SES writes to
- FORWARD_TO:      destination Gmail
- FORWARD_FROM:    SES-verified sender on trailcount.io
                   (e.g. "TrailCount Forwarder <forwarder@trailcount.io>")
"""

import email
import os
from email.policy import default as default_policy

import boto3

s3 = boto3.client("s3")
ses = boto3.client("ses")

INCOMING_BUCKET = os.environ["INCOMING_BUCKET"]
FORWARD_TO = os.environ["FORWARD_TO"]
FORWARD_FROM = os.environ["FORWARD_FROM"]


def lambda_handler(event, context):
    for record in event.get("Records", []):
        if record.get("eventSource") != "aws:s3":
            continue
        key = record["s3"]["object"]["key"]
        print(f"processing s3://{INCOMING_BUCKET}/{key}")
        raw = s3.get_object(Bucket=INCOMING_BUCKET, Key=key)["Body"].read()
        _forward(raw, key)
    return {"status": "ok"}


def _forward(raw_bytes: bytes, source_key: str) -> None:
    msg = email.message_from_bytes(raw_bytes, policy=default_policy)

    original_from = msg.get("From", "(unknown sender)")
    original_subject = msg.get("Subject", "(no subject)")
    original_to = msg.get("To", "(no To)")

    # Rewrite envelope headers. Keep original From in Reply-To so the
    # recipient can hit Reply and reach the actual sender.
    for header in ("DKIM-Signature", "Sender", "Return-Path", "Reply-To"):
        if header in msg:
            del msg[header]
    msg.replace_header("From", FORWARD_FROM) if "From" in msg else msg.add_header("From", FORWARD_FROM)
    msg.add_header("Reply-To", original_from)
    msg["X-Original-From"] = original_from
    msg["X-Original-To"] = original_to
    msg["X-Forwarded-By"] = "trailcount.io / SES Lambda forwarder"

    print(f"forwarding: from={original_from!r} subject={original_subject!r} -> {FORWARD_TO}")

    # SendRawEmail with our rewritten message. Destinations override the
    # To: header for delivery purposes.
    ses.send_raw_email(
        Source=FORWARD_FROM,
        Destinations=[FORWARD_TO],
        RawMessage={"Data": msg.as_bytes()},
    )
    print(f"forwarded {source_key} ok")
