def handler(event=None, context=None):
    return {
        "message": "Hello from GitHub Actions"
    }

if __name__ == "__main__":
    print(handler())