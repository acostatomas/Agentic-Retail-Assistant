#!/usr/bin/env python3
"""Step 3: produce 20 sample inventory transactions across two branches
(DOT Shopping, Unicenter) and six SKUs (3 laptop + 3 mobile brands).

LAPTOP-DELL in Unicenter is deliberately net zero (+10, -4, -6) so that
the derived inventory_availability table shows a sold-out SKU."""

import json
import os
import sys
from dotenv import load_dotenv
from confluent_kafka import Producer


TRANSACTIONS = [
    {"sku": "LAPTOP-DELL-XPS-15", "branch": "Dot Shopping", "quantity": 50, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:00:00Z", "source": "inventory_manager", "reference": "PO-2025-001"},
    {"sku": "LAPTOP-MACBOOK-PRO-16", "branch": "Unicenter", "quantity": 40, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:00:00Z", "source": "inventory_manager", "reference": "PO-2025-002"},
    {"sku": "LAPTOP-HP-SPECTRE-X360", "branch": "Dot Shopping", "quantity": 45, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:00:00Z", "source": "inventory_manager", "reference": "PO-2025-003"},
    {"sku": "MOBILE-IPHONE-17-PRO-MAX", "branch": "Unicenter", "quantity": 80, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:30:00Z", "source": "inventory_manager", "reference": "PO-2025-004"},
    {"sku": "MOBILE-SAMSUNG-S24-ULTRA", "branch": "Dot Shopping", "quantity": 70, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:30:00Z", "source": "inventory_manager", "reference": "PO-2025-005"},
    {"sku": "MOBILE-GOOGLE-PIXEL-8-PRO", "branch": "Unicenter", "quantity": 60, "transaction_type": "ADDITION", "timestamp": "2025-12-29T08:30:00Z", "source": "inventory_manager", "reference": "PO-2025-006"},
    {"sku": "LAPTOP-DELL-XPS-15", "branch": "Dot Shopping", "quantity": -15, "transaction_type": "SALE", "timestamp": "2025-12-29T10:15:00Z", "source": "pos_system", "reference": "SALE-2025-101"},
    {"sku": "LAPTOP-MACBOOK-PRO-16", "branch": "Unicenter", "quantity": -2, "transaction_type": "SALE", "timestamp": "2025-12-29T10:30:00Z", "source": "pos_system", "reference": "SALE-2025-102"},
    {"sku": "MOBILE-IPHONE-17-PRO-MAX", "branch": "Unicenter", "quantity": -5, "transaction_type": "SALE", "timestamp": "2025-12-29T11:00:00Z", "source": "pos_system", "reference": "SALE-2025-103"},
    {"sku": "MOBILE-SAMSUNG-S24-ULTRA", "branch": "Dot Shopping", "quantity": -4, "transaction_type": "SALE", "timestamp": "2025-12-29T11:30:00Z", "source": "pos_system", "reference": "SALE-2025-104"},
    {"sku": "LAPTOP-HP-SPECTRE-X360", "branch": "Dot Shopping", "quantity": -3, "transaction_type": "SALE", "timestamp": "2025-12-29T12:00:00Z", "source": "pos_system", "reference": "SALE-2025-105"},
    {"sku": "MOBILE-GOOGLE-PIXEL-8-PRO", "branch": "Unicenter", "quantity": -3, "transaction_type": "SALE", "timestamp": "2025-12-29T12:30:00Z", "source": "pos_system", "reference": "SALE-2025-106"},
    {"sku": "LAPTOP-DELL-XPS-15", "branch": "Dot Shopping", "quantity": -20, "transaction_type": "SALE", "timestamp": "2025-12-29T14:00:00Z", "source": "pos_system", "reference": "SALE-2025-107"},
    {"sku": "MOBILE-IPHONE-17-PRO-MAX", "branch": "Unicenter", "quantity": 30, "transaction_type": "ADDITION", "timestamp": "2025-12-29T14:30:00Z", "source": "inventory_manager", "reference": "PO-2025-008"},
    {"sku": "LAPTOP-MACBOOK-PRO-16", "branch": "Unicenter", "quantity": -1, "transaction_type": "SALE", "timestamp": "2025-12-29T15:00:00Z", "source": "pos_system", "reference": "SALE-2025-108"},
    {"sku": "MOBILE-SAMSUNG-S24-ULTRA", "branch": "Dot Shopping", "quantity": -6, "transaction_type": "SALE", "timestamp": "2025-12-29T15:30:00Z", "source": "pos_system", "reference": "SALE-2025-109"},
    {"sku": "LAPTOP-HP-SPECTRE-X360", "branch": "Dot Shopping", "quantity": 10, "transaction_type": "ADDITION", "timestamp": "2025-12-29T16:00:00Z", "source": "inventory_manager", "reference": "PO-2025-009"},
    {"sku": "MOBILE-GOOGLE-PIXEL-8-PRO", "branch": "Unicenter", "quantity": -4, "transaction_type": "SALE", "timestamp": "2025-12-29T16:30:00Z", "source": "pos_system", "reference": "SALE-2025-110"},
    {"sku": "LAPTOP-DELL-XPS-15", "branch": "Dot Shopping", "quantity": -15, "transaction_type": "SALE", "timestamp": "2025-12-29T17:00:00Z", "source": "pos_system", "reference": "SALE-2025-111"},
    {"sku": "MOBILE-IPHONE-17-PRO-MAX", "branch": "Unicenter", "quantity": -8, "transaction_type": "SALE", "timestamp": "2025-12-29T17:30:00Z", "source": "pos_system", "reference": "SALE-2025-112"},
]


def main():
    load_dotenv()
    bootstrap = os.environ["BOOTSTRAP_SERVERS"]
    topic = os.getenv("TOPIC_NAME", "inventory.transactions")

    assert len(TRANSACTIONS) == 20, f"expected 20 transactions, got {len(TRANSACTIONS)}"

    print(f"Bootstrap: {bootstrap}")
    print(f"Topic:     {topic}")
    print(f"Messages:  {len(TRANSACTIONS)}")
    print()

    # Build producer config
    producer_config = {"bootstrap.servers": bootstrap}
    
    # Add SASL authentication if configured
    sasl_username = os.getenv("KAFKA_SASL_USERNAME")
    sasl_password = os.getenv("KAFKA_SASL_PASSWORD")
    security_protocol = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
    sasl_mechanism = os.getenv("KAFKA_SASL_MECHANISM", "PLAIN")
    
    if sasl_username and sasl_password:
        producer_config.update({
            "security.protocol": security_protocol,
            "sasl.mechanism": sasl_mechanism,
            "sasl.username": sasl_username,
            "sasl.password": sasl_password,
        })
        if security_protocol == "SASL_SSL":
            # Skip SSL verification for self-signed certificates
            producer_config["ssl.endpoint.identification.algorithm"] = "none"
            producer_config["enable.ssl.certificate.verification"] = "false"
        print(f"Using SASL authentication with user: {sasl_username}")
        print()

    producer = Producer(producer_config)
    delivered, failed = 0, 0

    def on_delivery(err, msg):
        nonlocal delivered, failed
        if err is not None:
            failed += 1
            print(f"  ! delivery failed: {err}")
        else:
            delivered += 1

    for tx in TRANSACTIONS:
        producer.produce(
            topic,
            key=tx["sku"].encode(),
            value=json.dumps(tx).encode(),
            on_delivery=on_delivery,
        )
        producer.poll(0)

    producer.flush(timeout=30)
    print(f"Delivered: {delivered}/{len(TRANSACTIONS)}  (failed: {failed})")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Error: {exc}")
        sys.exit(1)
