#!/usr/bin/env python3
"""
Confluent Kafka Message Producer
Loads sample transactions from JSON file and produces them to Kafka topic
"""

from confluent_kafka import Producer
import json
import sys
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# Configuration from environment variables
config = {
    'bootstrap.servers': os.getenv('BOOTSTRAP_SERVERS'),
    'security.protocol': 'SASL_SSL',
    'sasl.mechanisms': 'PLAIN',
    'sasl.username': os.getenv('KAFKA_API_KEY'),
    'sasl.password': os.getenv('KAFKA_API_SECRET'),
    'client.id': 'inventory-producer'
}

TOPIC_NAME = os.getenv('TOPIC_NAME', 'retail.inventory.transactions')
MESSAGES_FILE = 'sample-transactions.json'

def validate_config():
    """Validate that all required configuration is present"""
    required_vars = ['BOOTSTRAP_SERVERS', 'KAFKA_API_KEY', 'KAFKA_API_SECRET']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print("❌ Error: Missing required environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\nPlease update your .env file with the correct values.")
        return False
    
    if 'xxxxx' in config['bootstrap.servers'] or 'your-kafka-api-key' in str(config['sasl.username']):
        print("❌ Error: Please update .env file with your actual Confluent Cloud credentials")
        return False
    
    return True

def delivery_report(err, msg):
    """Callback for message delivery reports"""
    if err is not None:
        print(f'❌ Message delivery failed: {err}')
    else:
        print(f'✅ Delivered to {msg.topic()} [partition {msg.partition()}] at offset {msg.offset()}')

def produce_messages():
    """Read messages from file and produce to Kafka"""
    
    # Validate configuration
    if not validate_config():
        sys.exit(1)
    
    # Check if messages file exists
    if not Path(MESSAGES_FILE).exists():
        print(f"❌ Error: {MESSAGES_FILE} not found")
        print(f"Current directory: {os.getcwd()}")
        print("Make sure you're in the correct directory: ~/Documents/git/oic-i-agentic-ai-tutorials/confluent-agents/")
        sys.exit(1)
    
    # Create producer
    print("🔗 Connecting to Confluent Cloud...")
    print(f"   Bootstrap Server: {config['bootstrap.servers']}")
    print(f"   Topic: {TOPIC_NAME}\n")
    
    try:
        producer = Producer(config)
        print("✅ Connected successfully!\n")
    except Exception as e:
        print(f"❌ Failed to create producer: {e}")
        sys.exit(1)
    
    # Read and produce messages
    message_count = 0
    error_count = 0
    
    try:
        with open(MESSAGES_FILE, 'r') as f:
            print(f"📄 Reading messages from {MESSAGES_FILE}...\n")
            
            for line_num, line in enumerate(f, 1):
                try:
                    # Parse JSON to validate format
                    msg = json.loads(line.strip())
                    
                    # Produce message
                    producer.produce(
                        TOPIC_NAME,
                        key=msg['sku'].encode('utf-8'),
                        value=line.strip().encode('utf-8'),
                        callback=delivery_report
                    )
                    
                    message_count += 1
                    
                    # Trigger delivery reports
                    producer.poll(0)
                    
                except json.JSONDecodeError as e:
                    print(f"⚠️  Warning: Invalid JSON on line {line_num}: {e}")
                    error_count += 1
                except Exception as e:
                    print(f"⚠️  Warning: Failed to produce message on line {line_num}: {e}")
                    error_count += 1
        
        # Wait for all messages to be delivered
        print(f"\n⏳ Waiting for {message_count} messages to be delivered...")
        producer.flush(timeout=30)
        
        # Summary
        print("\n" + "="*60)
        print("📊 SUMMARY")
        print("="*60)
        print(f"✅ Successfully produced: {message_count} messages")
        if error_count > 0:
            print(f"⚠️  Errors: {error_count}")
        print(f"📍 Topic: {TOPIC_NAME}")
        print("="*60)
        print("\n🎉 Done! Check Confluent Cloud UI to verify messages.")
        
    except FileNotFoundError:
        print(f"❌ Error: {MESSAGES_FILE} not found")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    print("="*60)
    print("🚀 Confluent Kafka Message Producer")
    print("="*60)
    print()
    
    produce_messages()

# Made with Bob
