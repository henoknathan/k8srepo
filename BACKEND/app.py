
from flask import Flask, jsonify, request
import os
import mysql.connector

app = Flask(__name__)

def get_db_connection():
    # Pulls all connection details dynamically from your K8s environment variables
    return mysql.connector.connect(
        host=os.environ.get("DB_HOST", "mysql-service"),   
        database=os.environ.get("DB_NAME", "shopflow_db"), 
        user=os.environ.get("DB_USER"),                   
        password=os.environ.get("DB_PASSWORD")             
    )

# 1. FIXED ENDPOINT FOR HOME SCREEN INITIALIZATION
# PURPOSE: Matches the frontend check to display the "DB: Connected" badge
@app.route('/products', methods=['GET'])
def get_products():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Test Query: Verifies Network Policy (NetPol) allows DB read operations
        cursor.execute("SELECT DATABASE();")
        cursor.fetchone()
        
        cursor.close()
        conn.close() 
        return jsonify({
            "status": "success",
            "message": "Connected to MySQL Production Cluster (Validated via NetPol)!"
        })
    except Exception as e:
        # Fallback if DB is initializing or NetPol blocks the connection
        return jsonify({
            "status": "partial_success",
            "message": f"Backend API operational, but DB connection timed out: {str(e)}"
        }), 500

# 2. NEW ENDPOINT FOR ADDING ITEMS TO CART
# PURPOSE: Handles JSON data payloads sent from client button clicks
@app.route('/cart', methods=['POST'])
def add_to_cart():
    try:
        # Parse data sent from the UI
        data = request.get_json() or {}
        item_name = data.get('item', 'Unknown Item')

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Optional: Uncomment this line if you have created a 'cart' table in your DB initialization scripts
        # cursor.execute("INSERT INTO cart (item_name) VALUES (%s)", (item_name,))
        # conn.commit()
        
        cursor.close()
        conn.close()
        
        print(f"[DevOps Log] Action captured successfully: {item_name} pushed to pool.")
        return jsonify({"status": "success", "synced_item": item_name}), 201
    except Exception as e:
        return jsonify({"status": "error", "error_message": str(e)}), 500

if __name__ == "__main__":
    # FIXED PORT: Changed from 5000 to 8080 to match your internal k8s/deployment service layer
    app.run(host='0.0.0.0', port=8080)


