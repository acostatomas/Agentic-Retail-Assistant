#!/usr/bin/env python3
"""
FastMCP Server for SKU Availability

Demo/local version:
Provides a tool to query SKU availability from a local mock inventory JSON file.

Original workshop version:
The original file queried ksqlDB / Confluent for real-time inventory availability.
A backup can be kept as get_sku_availability_ksqldb_backup.py.
"""

import json
from pathlib import Path
from fastmcp import FastMCP

# Create FastMCP server
mcp = FastMCP("SKU Availability Server")

# Local mock inventory file
BASE_DIR = Path(__file__).resolve().parent
INVENTORY_FILE = BASE_DIR / "inventory_mock.json"


def load_inventory() -> list:
    """
    Load inventory records from the local mock JSON file.

    Returns:
        List of inventory records.
    """
    if not INVENTORY_FILE.exists():
        raise FileNotFoundError(f"Inventory mock file not found: {INVENTORY_FILE}")

    with INVENTORY_FILE.open("r", encoding="utf-8") as file:
        data = json.load(file)

    if not isinstance(data, list):
        raise ValueError("inventory_mock.json must contain a list of inventory records")

    return data


@mcp.tool()
def get_sku_availability(sku: str = "", branch: str = "") -> str:
    """
    Get inventory availability for SKUs across branches.

    This demo implementation uses a local mock inventory dataset.
    It preserves the same MCP tool interface used by the ksqlDB/Confluent version.

    Args:
        sku: Optional SKU or product name filter. Leave empty to get all SKUs.
        branch: Optional branch/store filter. Leave empty to get all branches.

    Returns:
        JSON string with availability records.
    """
    try:
        inventory = load_inventory()

        results = inventory

        # Case-insensitive partial matching by SKU or product name
        if sku:
            sku_query = sku.lower()
            results = [
                item for item in results
                if sku_query in item.get("sku", "").lower()
                or sku_query in item.get("product_name", "").lower()
            ]

        # Case-insensitive partial matching by branch
        if branch:
            branch_query = branch.lower()
            results = [
                item for item in results
                if branch_query in item.get("branch", "").lower()
            ]

        if not results:
            return json.dumps({
                "message": "No inventory records found",
                "results": []
            }, indent=2)

        return json.dumps({
            "source": "local_mock_inventory",
            "results": results
        }, indent=2)

    except Exception as e:
        return json.dumps({
            "error": str(e)
        }, indent=2)


if __name__ == "__main__":
    mcp.run()
