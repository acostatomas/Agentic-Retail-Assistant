from get_sku_availability import get_sku_availability

print("=== All inventory ===")
print(get_sku_availability())

print("\n=== Filter by SKU/product ===")
print(get_sku_availability(sku="iPhone"))

print("\n=== Filter by branch ===")
print(get_sku_availability(branch="DOT"))

print("\n=== Out of stock example ===")
print(get_sku_availability(sku="Samsung"))