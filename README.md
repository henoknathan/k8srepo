# Shopflow Enterprise Workspace

An enterprise-grade, GitOps-driven deployment framework featuring microservice orchestration, type-safe infrastructure as code (IaC), zero-trust networking, and automated CI/CD pipelines.

---

##  Repository Structure

```text
Shopflow-Enterprise-Workspace/
├── .github/workflows/
│   ├── infra.yaml             # Automated Terraform execution & PR output publisher
│   └── sonar.yaml             # SonarCloud multi-language security SAST scanner
├── k8s/                       # Declarative Cluster Manifests (ArgoCD GitOps Target)
│   ├── namespace.yaml         # Core isolation boundary (lab-shopflow)
│   ├── secret-store.yaml      # Base64 application runtime database credentials
│   ├── shared-storage.yaml    # 10Gi AWS EFS PersistentVolumeClaim mapping
│   ├── mysql.yaml             # StatefulSet DB engine deployment with data persistence
│   ├── migration-job.yaml     # Non-blocking schema migrator utilizing TCP socket probes
│   ├── backend-deployment.yaml # Python/Gunicorn production API microservice deployment
│   ├── frontend-deployment.yaml # Hardened Nginx edge web node web server layout
│   ├── hpa.yaml               # Dual metric (CPU/Memory) Horizontal Pod Autoscaling Behavior
│   ├── network-policy.yaml    # Layer-3/4 Zero-Trust network segment isolation firewall
│   └── ingress.yaml           # Enterprise Application Load Balancer routing profile
├── terraform/                 # Automated Cloud Infrastructure Matrix
│   ├── provider.tf            # AWS provider constraints and remote state hooks
│   ├── main.tf                # Complete definition of AWS EKS, VPC, EFS, and ECR arrays
│   ├── variables.tf           # Type-safe parameter constraints with validation regex blocks
│   └── outputs.tf             # Immutable runtime environment outputs used by the CI pipeline
├── index.html                 # Decoupled Frontend UI engine with live cluster health badges
├── nginx.conf                 # Custom internal path gateway engine with dynamic CoreDNS resolution
├── app.py                     # Multi-worker Python Gunicorn microservice core logic
├── migrate.py                 # Programmatic database schema creator running on DB sockets
├── requirements.txt           # Locked production-grade application library dependency map
├── Dockerfile                 # Ultra-light frontend Nginx container image layout
└── backend.Dockerfile         # Hardened multi-stage multi-user non-root Python
```

---

##  Architecture & Components

* **Infrastructure Automation**: Multi-region AWS EKS, VPC, and EFS provisioning handled natively through Terraform with a secure remote state backend.
* **CI/CD & Security SAST**: GitHub Actions pipeline validating zero-trust network boundaries and enforcing high-standard security profiles using SonarCloud.
* **GitOps Kubernetes Target**: Native ArgoCD tracking over declarative layer-3/4 isolated network topologies, horizontal auto-scalers, and non-blocking database schema micro-migrations.
* **Decoupled Application Stack**: Hardened multi-stage Nginx serving static assets communicating securely with a high-throughput Gunicorn Python backend API.

---

##  Prerequisites

Ensure you have the following CLI tools installed locally before executing initialization workflows:

* **AWS CLI** v2 (Configured with Administrator permissions)
* **Terraform** v1.5.0+
* **kubectl** matched to the cluster minor version
* **Docker** or **Finch** container engines

---

##  Local Setup Instructions

### 1. Configure the Infrastructure (IaC)

Navigate to the IaC root directory and initialize the cloud backend constraints:

```bash
cd terraform/
terraform init
```

Review the structural planning strategy to map potential infrastructure updates:

```bash
terraform plan -out=tfplan.binary
```

Provision the core VPC, AWS EKS cluster boundaries, and network storage targets:

```bash
terraform apply tfplan.binary
```

### 2. Configure Local Kubernetes Orchestration

Extract the immutable output configurations from the active state database to bind your native network context:

```bash
aws eks update-kubeconfig --region (terraform output -raw region) --name (terraform output -raw cluster_name)
```

---

##  Quick-Start Deployment Guide

Deploying the stack relies on the predefined order of dependencies to bypass racing conditions between storage setups and container startup parameters.

### Step 1: Establish Namespaces and RBAC Boundaries
Isolate the networking domain to standard enterprise guardrails:

```bash
kubectl apply -f k8s/namespace.yaml
```

### Step 2: Provision Secrets and Persistent Ingress Layers
Map application credential stores and register the persistent volume bindings for standard network drives:

```bash
kubectl apply -f k8s/secret-store.yaml
kubectl apply -f k8s/shared-storage.yaml
```

### Step 3: Deploy the Persistent Database Engine
Bring up the multi-user storage tier. The system will handle automatic baseline attachment:

```bash
kubectl apply -f k8s/mysql.yaml
```

### Step 4: Run the Non-Blocking Schema Database Migration
Launch the single-run transactional hook to initialize your app arrays without downing standard queries:

```bash
kubectl apply -f k8s/migration-job.yaml
```

### Step 5: Start the Front-End and Back-End Applications
Deploy microservices alongside tracking constraints, ingress gateways, and dynamic autoscaling properties:

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/network-policy.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml
```

---

##  Verification & Health Checking

Monitor your fresh deployment loop inside the target network bounds:

```bash
kubectl get pods -n lab-shopflow -w
```

Retrieve the production application endpoint routed through your Application Load Balancer mapping layer:

```bash
kubectl get ingress -n lab-shopflow
```
