import requests

url = "https://gateway.neuraltrust.ai/chat"
headers = {
    "X-TG-API-Key": "v09L0nmpFhOQbD97MLo0_WRXXs7DtYg8psMk5zBfe_M=",
    "Content-Type": "application/json"
}
payload = {
    "model": "gpt-4o-mini",
    "input": "Hello, how can I help you?"
}

response = requests.post(url, headers=headers, json=payload)
print(response.json())