import json

def lambda_handler(event, context):
    print("EVENTHUB EVENT:")
    print(json.dumps(event, indent=2))
    return {"status": "ok"}
