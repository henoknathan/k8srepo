from flask import Flask, jsonify
import mysql.connector

app = Flask(__name__)

def get_db_connection():
    # 'mysql' is the DNS name provided by the Kubernetes service
    return mysql.connector.connect(
        host="mysql",
        user="root",
        password="password123",
        database="enterprise_db"
    )

@app.route('/api/data')
def get_data():
    try:
        conn = get_db_connection()
        return jsonify({"message": "Connected to MySQL and Backend!"})
    except Exception as e:
        return jsonify({"message": f"Backend is up, but DB error: {str(e)}"})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
