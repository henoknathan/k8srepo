# 🛠️ Critical Adjustments Explained
#EXPOSE 8080 (Network Alignment): Your original line referenced port 5000 because 
# that was what Flask defaulted to. Since the updated app.py script now explicitly runs on port=8080 to sync with 
# your Nginx upstream proxy config, updating this documentation line ensures clarity for anyone inspecting the 
# image or reading your manifests.
#chown -R 10001:10001 /app (Filesystem Permission Fix): 
# When Docker runs COPY . ., it transfers files from your machine into the container as the default root user. 
# If you immediately switch to USER 10001, your Python runtime might crash or throw permission errors if it tries 
# to write temporary log tracks inside /app. Running a quick chown right before changing users resolves this.
FROM python:3.11-slim AS builder

# PURPOSE: Sets the working directory inside the build stage.
WORKDIR /app

# PURPOSE: Installs OS-level compilers needed to build specific Python C-extensions (like database drivers).
# DETAIL: '--no-install-recommends' stops Ubuntu/Debian from installing unneeded packages. 
# Including 'gcc' and 'python3-dev' ensures tools like 'psycopg2' or cryptography libraries compile properly.
RUN apt-get update && apt-get install -y --no-install-recommends gcc python3-dev

# PURPOSE: Copies only your library definitions file into the container image layer.
# DETAIL: Isolating 'requirements.txt' allows Docker to cache this layer. If you don't add 
# new libraries, Docker skips the expensive download phase during future Jenkins pipeline runs.
COPY requirements.txt .

# PURPOSE: Downloads and builds the Python packages specified in your dependencies file.
# DETAIL: '--user' installs libraries directly into the local user space directory (/root/.local). 
# '--no-cache-dir' blocks pip from storing temporary zip download files, saving build disk space.
RUN pip install --user --no-cache-dir -r requirements.txt

# Phase 2: The Hardened Production Runtime Layer
# Stage 2: Minimalist and Secure Production Runtime
# PURPOSE: Discards heavy compilers (like gcc) and builds a clean, lightweight app image.
# DETAIL: Re-initiates 'python:3.11-slim' to drop all Phase 1 operating system bloat.
FROM python:3.11-slim

# PURPOSE: Defines the production application environment workspace folder root.
WORKDIR /app

# PURPOSE: Extracts only the fully compiled Python packages from the first stage.
# DETAIL: '--from=builder' pulls the clean dependencies folder directly from the builder stage. 
# This leaves the heavy 'gcc' and 'python3-dev' tools completely out of your final image.
COPY --from=builder /root/.local /root/.local

# PURPOSE: Copies your actual application Python script code files into the container.
COPY . .

# PURPOSE: Appends the custom local binaries folder directly to the Linux environment path lookups.
# DETAIL: Ensures the system can find and execute scripts installed via 'pip --user' (like Gunicorn/Uvicorn).
ENV PATH=/root/.local/bin:$PATH

# 🚨 FIXED PORT: CHANGED FROM 5000 TO 8080
# PURPOSE: Informs developers and network plugins that this container processes traffic on Port 8080.
# DETAIL: Maps directly to the 'targetPort: 8080' and 'containerPort: 8080' strings in your k8s manifests.
EXPOSE 8080

# 🚨 FIXED PERMISSIONS: Grant folder ownership before dropping root privileges
# PURPOSE: Ensures the non-root user (10001) has full read/write access to the application files.
# DETAIL: Because files copied by 'COPY . .' default to root ownership, a non-root process may hit 
# permission denied errors if it attempts to write logs or temporary cache structures.
USER root
RUN chown -R 10001:10001 /app

# PURPOSE: ENFORCES LEAST-PRIVILEGE SECURITY (DEVSECOPS CRITICAL)
# DETAIL: By default, containers run as 'root' (User 0). If an attacker breaks your Python API code, 
# root privilege allows them to escape the container and compromise the AWS node. 
# Switching to 'USER 10001' locks down the execution space, stripping out root terminal privileges.
USER 10001

# PURPOSE: Spins up your Python API application script when the Kubernetes container pod boots up.
#CMD ["python", "app.py"]

# AFTER: Run with Gunicorn on your synchronized container port (8080)
CMD ["gunicorn", "--workers", "3", "--bind", "0.0.0.0:8080", "app:app"]

#Phase 1: The Compilation & Dependency Building Layer
#Architectural Design Benefits:Severe Vulnerability Mitigation: By stripping out tools like gcc and apt, 
#you severely limit an attacker's ability to compile malicious programs, download scripts, 
#or execute lateral moves inside your EKS cluster if your app code ever handles unsafe inputs.
#Rapid Cluster Auto-scaling: Dropping the building dependencies shrinks the final file footprint by 
#hundreds of megabytes. This allows your Horizontal Pod Autoscaler (HPA) to pull this image from 
#AWS ECR and spin up fresh container instances within seconds during a traffic surge.

# Stage 1: Build dependencies
# PURPOSE: Sets up an isolated environment to compile complex Python wheel extensions.
# DETAIL: 'python:3.11-slim' is a lightweight Debian-based Python image. 
# 'AS builder' benchmarks this stage so it can be referenced by name later.
# FROM python:3.11-slim AS builder

# # PURPOSE: Sets the working directory inside the build stage.
# WORKDIR /app

# # PURPOSE: Installs OS-level compilers needed to build specific Python C-extensions (like database drivers).
# # DETAIL: '--no-install-recommends' stops Ubuntu/Debian from installing unneeded packages. 
# # Including 'gcc' and 'python3-dev' ensures tools like 'psycopg2' or cryptography libraries compile properly.
# RUN apt-get update && apt-get install -y --no-install-recommends gcc python3-dev

# # PURPOSE: Copies only your library definitions file into the container image layer.
# # DETAIL: Isolating 'requirements.txt' allows Docker to cache this layer. If you don't add 
# # new libraries, Docker skips the expensive download phase during future Jenkins pipeline runs.
# COPY requirements.txt .

# # PURPOSE: Downloads and builds the Python packages specified in your dependencies file.
# # DETAIL: '--user' installs libraries directly into the local user space directory (/root/.local). 
# # '--no-cache-dir' blocks pip from storing temporary zip download files, saving build disk space.
# RUN pip install --user --no-cache-dir -r requirements.txt

# #Phase 2: The Hardened Production Runtime Layer
# # Stage 2: Minimalist and Secure Production Runtime
# # PURPOSE: Discards heavy compilers (like gcc) and builds a clean, lightweight app image.
# # DETAIL: Re-initiates 'python:3.11-slim' to drop all Phase 1 operating system bloat.
# FROM python:3.11-slim

# # PURPOSE: Defines the production application environment workspace folder root.
# WORKDIR /app

# # PURPOSE: Extracts only the fully compiled Python packages from the first stage.
# # DETAIL: '--from=builder' pulls the clean dependencies folder directly from the builder stage. 
# # This leaves the heavy 'gcc' and 'python3-dev' tools completely out of your final image.
# COPY --from=builder /root/.local /root/.local

# # PURPOSE: Copies your actual application Python script code files into the container.
# COPY . .

# # PURPOSE: Appends the custom local binaries folder directly to the Linux environment path lookups.
# # DETAIL: Ensures the system can find and execute scripts installed via 'pip --user' (like Gunicorn/Uvicorn).
# ENV PATH=/root/.local/bin:$PATH

# # PURPOSE: Informs developers and network plugins that this container processes traffic on Port 5000.
# # DETAIL: Maps directly to the 'targetPort: 5000' and 'containerPort: 5000' strings in your k8s manifests.
# EXPOSE 5000

# # PURPOSE: ENFORCES LEAST-PRIVILEGE SECURITY (DEVSECOPS CRITICAL)
# # DETAIL: By default, containers run as 'root' (User 0). If an attacker breaks your Python API code, 
# # root privilege allows them to escape the container and compromise the AWS node. 
# # Switching to 'USER 10001' locks down the execution space, stripping out root terminal privileges.
# USER 10001

# # PURPOSE: Spins up your Python API application script when the Kubernetes container pod boots up.
# CMD ["python", "app.py"]

