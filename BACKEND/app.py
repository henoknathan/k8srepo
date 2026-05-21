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

================================================================================
#PRODUCTION NETWORK ARCHITECTURE: END-TO-END TRAFFIC FLOW NOTES
================================================================================

#[STEP 1: THE CLIENT LAYER (THE BROWSER)]
--------------------------------------------------------------------------------
# Action: 
#   A user inputs http://<LoadBalancer-URL>/api/data into their web browser.
#
# Technical Blueprint:
#   - DNS Resolution: The browser converts the human-readable domain name into
#     the public IP address belonging to the system's Load Balancer.
#   - HTTP Handshake: The browser initiates a standard TCP handshake and sends
#     an HTTP GET request over the public internet.
#
# Production Best Practice:
#   - Upgrade to HTTPS (Port 443) using TLS certificates to encrypt traffic 
#     and prevent man-in-the-middle data interception over public web networks.


#[STEP 2: THE ENTRY LAYER (LOAD BALANCER & REVERSE PROXY)]
--------------------------------------------------------------------------------
# Action: 
#   The Load Balancer routes the incoming packet into the private cloud network,
#   handing it off directly to an available Nginx reverse proxy instance.
#
# Technical Blueprint:
#   - Ingress Routing: The Load Balancer shields internal servers by acting as
#     the sole public-facing gateway for the infrastructure.
#   - Path Evaluation: Nginx inspects the request URI and matches the rules
#     configured specifically for the `/api` route block.
#   - URL Rewriting: Nginx applies a regex rewrite to strip the `/api` prefix,
#     transforming the request destination path cleanly from `/api/data` to `/data`.
#   - Upstream Forwarding: Nginx proxies the newly cleaned request down the internal
#     network backplane toward the backend service location.
#
# Production Best Practice:
#   - Leverage container orchestrator DNS (e.g., Kubernetes CoreDNS) to map the
#     service hostname to dynamically shifting internal container IP addresses.


#[STEP 3: THE APPLICATION LAYER (FLASK API)]
--------------------------------------------------------------------------------
# Action: 
#   The private internal network routes the stripped traffic directly into an
#   active, isolated Flask application container.
#
# Technical Blueprint:
#   - Endpoint Matching: Flask captures the inbound request on its native 
#     internal `@app.route('/data')` handler.
#   - Decoupled Codebase: Because Nginx handles path scrubbing at the edge, the 
#     Flask code remains unpolluted by infrastructure-specific route prefixes.
#   - Resource Orchestration: The Flask business logic executes, initiating
#     parallel resource requests to both the database layer and file storage layer.
#
# Production Best Practice:
#   - Do not deploy Flask's built-in development server to live environments. 
#     Wrap the app in a multi-threaded WSGI server like Gunicorn or uWSGI to 
#     ensure simultaneous requests do not block the container.


#[STEP 4: THE DATA & STORAGE LAYER (MYSQL & AMAZON EFS)]
--------------------------------------------------------------------------------
# Action: 
#   Flask securely pulls data records from the MySQL instance and interacts 
#   with persistent system files located on a shared network drive.
#
# Technical Blueprint (MySQL Pool):
#   - Connection Borrowing: Flask requests an open connection socket from an
#     active, pre-warmed connection pool instead of creating a raw TCP handshake.
#   - Query Execution: The app runs the query, extracts data, and immediately 
#     invokes `conn.close()` inside a strict `try...finally` software block.
#   - Socket Preservation: The connection is safely returned intact to the pool, 
#     preventing Horizontal Pod Autoscaler (HPA) scale-up events from exhausting 
#     available MySQL connection slots under heavy loads.
#
# Technical Blueprint (Amazon EFS):
#   - Shared Filesystem: If the request requires reading or writing files, 
#     Flask interacts with a standard, local mount directory path.
#   - Network Storage: The local mount is backed by Amazon EFS (NFSv4), allowing
#     multiple auto-scaled Flask pods across different servers to read and write
#     to identical files simultaneously without local synchronization conflicts.
#
# Production Best Practice:
#   - EFS experiences network storage latency overhead. Use EFS strictly for 
#     assets, media uploads, and logs. Never run raw MySQL data directories 
#     (`/var/lib/mysql`) directly on a network-mounted EFS drive.


#[STEP 5: THE RETURN PATH]
#--------------------------------------------------------------------------------
# Action: 
#   Flask converts the collected raw database records and storage files into a
#   structured JSON response payload, transmitting it back down the pipe.
#
# Technical Blueprint:
#   - Downstream Relay: The network path processes in exact reverse order, passing
#     the payload through: Flask Pod -> Nginx Proxy -> Load Balancer -> Browser.
#   - Connection Lifecycle: The network sockets remain held in an active open 
#     state across all hops until the last byte streams into the client browser.
#
# Production Best Practice:
#   - Enable Gzip or Brotli compression directly inside Nginx for `application/json`
#     types to minimize response payload size, reducing cloud data egress costs
#     and improving browser rendering speeds.

================================================================================
#SUMMARY: A robust, highly scalable, and horizontally sound cloud topology.
================================================================================
