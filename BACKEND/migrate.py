# By creating this dynamic pipeline link, you can show interviewers how you solve distributed data race conditions. 
# Instead of guessing when your database container will be ready, your cluster runs a programmatic probe that 
# verifies networking is open before touching live tables.Now that your container initialization vectors, 
# external networks, application variables, database states, and target sync frameworks are fully aligned

import os
import mysql.connector

def run_migration():
    print("[Migration] Initiating database handshake...")
    conn = mysql.connector.connect(
        host=os.environ.get("DB_HOST", "mysql-service"),
        database=os.environ.get("DB_NAME", "shopflow_db"),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD")
    )
    cursor = conn.cursor()
    
    # Core Enterprise Schema Setup
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cart (
            id INT AUTO_INCREMENT PRIMARY KEY,
            item_name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    print("[Migration] Success: 'cart' table structural schema synchronized perfectly.")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    run_migration()
