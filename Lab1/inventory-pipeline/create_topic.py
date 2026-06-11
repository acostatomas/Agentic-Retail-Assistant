#!/usr/bin/env python3
"""Step 1: create the source Kafka topic on Confluent Platform."""

import os
import sys
from dotenv import load_dotenv
from confluent_kafka.admin import AdminClient, NewTopic


def main():
    load_dotenv()

    bootstrap = os.environ["BOOTSTRAP_SERVERS"]
    topic = os.getenv("TOPIC_NAME", "inventory.transactions")
    partitions = int(os.getenv("TOPIC_PARTITIONS", "1"))
    rf = int(os.getenv("TOPIC_REPLICATION_FACTOR", "1"))
    retention_ms = int(os.getenv("TOPIC_RETENTION_MS", "-1"))

    print(f"Bootstrap: {bootstrap}")
    print(f"Topic: {topic} (partitions={partitions}, rf={rf}, retention.ms={retention_ms})")

    # Build admin client config
    admin_config = {"bootstrap.servers": bootstrap}
    
    # Add SASL authentication if configured
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
        # For SASL_SSL, disable certificate verification (self-signed certs in dev)
        if security_protocol == "SASL_SSL":
            # Skip SSL verification for self-signed certificates
            admin_config["ssl.endpoint.identification.algorithm"] = "none"
            admin_config["enable.ssl.certificate.verification"] = "false"
        print(f"Using SASL authentication with user: {sasl_username}")

    admin = AdminClient(admin_config)

    if topic in admin.list_topics(timeout=10).topics:
        print(f"Topic '{topic}' already exists, skipping create")
        return

    new_topic = NewTopic(
        topic,
        num_partitions=partitions,
        replication_factor=rf,
        config={"retention.ms": str(retention_ms)},
    )
    for t, fut in admin.create_topics([new_topic]).items():
        fut.result()
        print(f"Created topic '{t}'")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Error: {exc}")
        sys.exit(1)
