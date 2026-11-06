from flask import Flask, request

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, World!'

stores = [
    {
        "name": "My Store",
        "items": [
            {
            "name": "Chair",
            "price": 15.99
            }
        ]
        
    }
]

@app.get('/store') # 'http://127.0.0.1:5000/store'
def get_stores():
    return {"stores": stores}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)