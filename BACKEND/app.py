#Why This Architecture Works Flawlessly:The Network Path Flow: Browser requests 
#http://<LoadBalancer-URL>/api/data \(\rightarrow \) Nginx catches it, strips /api, and sends 
#http://backend-service:8080/data down the cluster backplane \(\rightarrow \) Flask catches the request on 
# /data, verifies the database connection, and returns the message response cleanly.Database Cleanup Added: 
# Added conn.close() inside your operational block. Without explicitly closing your open pool connection 
# handlers, your Python API will run out of database worker sockets within minutes during an HPA scale-up event.
from flask import Flask, jsonify
import os
import mysql.connector

app = Flask(__name__)

def get_db_connection():
    # Pulls all connection details dynamically from your K8s environment variables
    return mysql.connector.connect(
        host=os.environ.get("DB_HOST", "mysql-service"),   # Matches your DB_HOST env
        database=os.environ.get("DB_NAME", "shopflow_db"), # Matches your DB_NAME env
        user=os.environ.get("DB_USER"),                   # Pulls securely from db-secret
        password=os.environ.get("DB_PASSWORD")             # Pulls securely from db-secret
    )

# CORRECTED: Changed from '/api/data' to '/data'
# PURPOSE: Nginx strips the '/api' prefix before proxying the request to this container.
@app.route('/data')
def get_data():
    try:
        conn = get_db_connection()
        conn.close() # Good practice: Close the database connection when done to prevent memory leaks
        return jsonify({"message": "Connected to MySQL and Backend successfully!"})
    except Exception as e:
        return jsonify({"message": f"Backend is up, but DB connection error: {str(e)}"})

if __name__ == "__main__":
    # Standard container binding: Listens on all interfaces on containerPort 5000
    app.run(host='0.0.0.0', port=5000)

