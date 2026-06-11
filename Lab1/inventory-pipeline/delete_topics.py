#!/usr/bin/env python3
"""Cleanup script: delete Kafka topics and ksqlDB objects."""

import os
import sys
import time
import requests
from dotenv import load_dotenv
from confluent_kafka.admin import AdminClient


def delete_ksqldb_objects():
    """Delete ksqlDB stream and table."""
    load_dotenv()
    
    ksqldb_endpoint = os.environ["KSQLDB_ENDPOINT"]
    stream_name = os.getenv("KSQL_STREAM_NAME", "inventory_transactions")
    table_name = os.getenv("KSQL_TABLE_NAME", "inventory_availability")
    
    # Get authentication credentials
    ksql_username = os.getenv("KSQLDB_USERNAME")
    ksql_password = os.getenv("KSQLDB_PASSWORD")
    auth = (ksql_username, ksql_password) if ksql_username and ksql_password else None
    
    print(f"ksqlDB endpoint: {ksqldb_endpoint}")
    if auth:
        print(f"Using authentication with user: {ksql_username}")
    
    headers = {"Content-Type": "application/vnd.ksql.v1+json; charset=utf-8"}
    
    # Drop table first (depends on stream)
    print(f"Dropping ksqlDB table: {table_name}")
    try:
        response = requests.post(
            f"{ksqldb_endpoint}/ksql",
            headers=headers,
            json={"ksql": f"DROP TABLE IF EXISTS {table_name} DELETE TOPIC;"},
            auth=auth,
            timeout=30
        )
        if response.status_code == 200:
            print(f"  ✓ Table '{table_name}' dropped")
        else:
            print(f"  ⚠ Table drop response: {response.status_code} - {response.text[:200]}")
    except Exception as e:
        print(f"  ⚠ Error dropping table: {e}")
    
    time.sleep(2)
    
    # Drop stream
    print(f"Dropping ksqlDB stream: {stream_name}")
    try:
        response = requests.post(
            f"{ksqldb_endpoint}/ksql",
            headers=headers,
            json={"ksql": f"DROP STREAM IF EXISTS {stream_name} DELETE TOPIC;"},
            auth=auth,
            timeout=30
        )
        if response.status_code == 200:
            print(f"  ✓ Stream '{stream_name}' dropped")
        else:
            print(f"  ⚠ Stream drop response: {response.status_code} - {response.text[:200]}")
    except Exception as e:
        print(f"  ⚠ Error dropping stream: {e}")


def delete_kafka_topics():
    """Delete Kafka topics."""
    load_dotenv()
    
    bootstrap = os.environ["BOOTSTRAP_SERVERS"]
    topic_name = os.getenv("TOPIC_NAME", "inventory.transactions")
    derived_topic = os.getenv("DERIVED_TOPIC_NAME", "inventory.availability")
    
    print(f"Bootstrap: {bootstrap}")
    
    # Build admin client config with authentication
    admin_config = {"bootstrap.servers": bootstrap}
    
    sasl_username = os.getenv("KAFKA_SASL_USERNAME")
    sasl_password = os.getenv("KAFKA_SASL_PASSWORD")
    security_protocol = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
    sasl_mechanism = os.getenv("KAFKA_SASL_MECHANISM", "PLAIN")
    
    if sasl_username and sasl_password:
        admin_config.update({
            "security.protocol": security_protocol,
            "sasl.mechanism": sasl_mechanism,
            "sasl.username": sasl_username,
            "sasl.password": sasl_password,
        })
        if security_protocol == "SASL_SSL":
            admin_config["ssl.endpoint.identification.algorithm"] = "none"
            admin_config["enable.ssl.certificate.verification"] = "false"
        print(f"Using SASL authentication with user: {sasl_username}")
    
    admin = AdminClient(admin_config)
    
    # List existing topics
    existing_topics = admin.list_topics(timeout=10).topics
    topics_to_delete = []
    
    if topic_name in existing_topics:
        topics_to_delete.append(topic_name)
    
    if derived_topic in existing_topics:
        topics_to_delete.append(derived_topic)
    
    if not topics_to_delete:
        print("No topics to delete")
        return
    
    print(f"Deleting topics: {', '.join(topics_to_delete)}")
    
    # Delete topics
    fs = admin.delete_topics(topics_to_delete, operation_timeout=30)
    
    for topic, f in fs.items():
        try:
            f.result()
            print(f"  ✓ Deleted topic '{topic}'")
        except Exception as e:
            print(f"  ⚠ Error deleting topic '{topic}': {e}")


def main():
    print("=" * 70)
    print("CLEANUP: Deleting ksqlDB objects and Kafka topics")
    print("=" * 70)
    print()
    
    # Step 1: Delete ksqlDB objects (they depend on topics)
    print("Step 1: Deleting ksqlDB objects...")
    try:
        delete_ksqldb_objects()
    except Exception as e:
        print(f"Warning: Error during ksqlDB cleanup: {e}")
    
    print()
    time.sleep(3)
    
    # Step 2: Delete Kafka topics
    print("Step 2: Deleting Kafka topics...")
    try:
        delete_kafka_topics()
    except Exception as e:
        print(f"Error during topic cleanup: {e}")
        sys.exit(1)
    
    print()
    print("=" * 70)
    print("✓ Cleanup completed")
    print("=" * 70)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Fatal error: {exc}")
        sys.exit(1)

# Made with Bob
