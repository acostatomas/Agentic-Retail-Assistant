#!/usr/bin/env python3
"""Step 2: create the inventory_transactions stream and the
inventory_availability table on ksqlDB. The CTAS table feeds the
DERIVED_TOPIC_NAME topic with rolling SUM(quantity) per (sku, branch)."""

import os
import sys
import requests
from dotenv import load_dotenv


def submit(endpoint: str, statement: str, auth: tuple = None) -> None:
    one_line = " ".join(statement.split())
    print(f"  > {one_line[:120]}{'...' if len(one_line) > 120 else ''}")
    resp = requests.post(
        f"{endpoint}/ksql",
        headers={"Accept": "application/vnd.ksql.v1+json"},
        json={
            "ksql": statement,
            "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"},
        },
        auth=auth,
        timeout=60,
    )
    if resp.status_code == 200:
        for entry in resp.json():
            status = entry.get("commandStatus", {}).get("status")
            message = entry.get("commandStatus", {}).get("message", "")
            print(f"    -> {entry.get('@type', '?')}: {status} ({message.strip()})")
        return

    body = resp.text
    if "already exists" in body.lower():
        print(f"    -> already exists, skipping")
        return

    raise SystemExit(f"ksqlDB error {resp.status_code}: {body}")


def main():
    load_dotenv()

    endpoint = os.getenv("KSQLDB_ENDPOINT", "http://ksqldb.confluent.svc.cluster.local:8088")
    source_topic = os.getenv("TOPIC_NAME", "inventory.transactions")
    derived_topic = os.getenv("DERIVED_TOPIC_NAME", "inventory.availability")
    stream = os.getenv("KSQL_STREAM_NAME", "inventory_transactions")
    table = os.getenv("KSQL_TABLE_NAME", "inventory_availability")
    
    # Get authentication credentials
    ksql_username = os.getenv("KSQLDB_USERNAME")
    ksql_password = os.getenv("KSQLDB_PASSWORD")
    auth = (ksql_username, ksql_password) if ksql_username and ksql_password else None

    print(f"ksqlDB endpoint: {endpoint}")
    print(f"Source topic:    {source_topic}")
    print(f"Derived topic:   {derived_topic}")
    print(f"Stream:          {stream}")
    print(f"Table:           {table}")
    if auth:
        print(f"Using authentication with user: {ksql_username}")
    print()

    create_stream = f"""
        CREATE STREAM IF NOT EXISTS {stream} (
            sku VARCHAR,
            branch VARCHAR,
            quantity INT
        ) WITH (
            KAFKA_TOPIC='{source_topic}',
            KEY_FORMAT='KAFKA',
            VALUE_FORMAT='JSON'
        );
    """

    create_table = f"""
        CREATE TABLE IF NOT EXISTS {table} WITH (
            KAFKA_TOPIC='{derived_topic}',
            KEY_FORMAT='JSON',
            VALUE_FORMAT='JSON',
            PARTITIONS=1,
            REPLICAS=3
        ) AS
        SELECT
            sku,
            branch,
            SUM(quantity) AS available_quantity
        FROM {stream}
        GROUP BY sku, branch
        EMIT CHANGES;
    """

    print("Creating stream...")
    submit(endpoint, create_stream, auth)
    print("Creating CTAS table...")
    submit(endpoint, create_table, auth)
    print("Done")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Error: {exc}")
        sys.exit(1)
