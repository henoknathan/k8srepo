# Shopflow Enterprise Workspace

An enterprise-grade, GitOps-driven deployment framework featuring microservice orchestration, type-safe infrastructure as code (IaC), zero-trust networking, and automated CI/CD pipelines.

---

## Repository Structure

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
│   └── monitoring-values.yaml
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
### Step 6: Deploy Enterprise Prometheus & Grafana Monitoring Stack
Initialize the observability infrastructure using Helm while binding your persistent storage layers:

```bash
# Add the official community Helm repository
helm repo add prometheus-community https://github.io
helm repo update

# Install the stack into your isolated project namespace
helm upgrade --install kube-monitoring prometheus-community/kube-prometheus-stack \
  --namespace lab-shopflow \
  -f k8s/monitoring-values.yaml
```

---

##  Verification & Health Checking

Monitor your fresh deployment loop inside the target network bounds:

```bash
kubectl get pods -n lab-shopflow -w
```

## 🛠️ Deployment Troubleshooting Checklist

Use this step-by-step diagnostic framework if components fail to transition to the `Running` state or if application components experience traffic-routing failures.

### 1. Pods Stuck in `Pending` State
If any microservice or database pod stays `Pending`, the cluster cannot assign or schedule it to a worker node.

* [ ] **Inspect Scheduling Failures**: Run `kubectl describe pod <pod-name> -n lab-shopflow` and check the **Events** block at the bottom.
* [ ] **Verify EFS PersistentVolumeClaim Binding**: 
  * Run `kubectl get pvc -n lab-shopflow`. 
  * If `shared-storage` is `Pending`, ensure your AWS EFS CSI Driver is installed in the EKS cluster via Terraform.
* [ ] **Check Node Capacity**: Ensure your EKS node group has enough unallocated CPU/Memory to satisfy the resource requests defined in your manifests.

### 2. Pods Stuck in `CrashLoopBackOff`
If pods start but instantly crash, the problem lies within application logic, environment initializations, or missing parameters.

* [ ] **Check Application Runtime Logs**: Run `kubectl logs <pod-name> -n lab-shopflow --previous` to inspect the exit code and error trace of the crashed process.
    
* [ ] **Validate Database Credentials**: Ensure the configuration fields in `k8s/secret-store.yaml` are correctly base64-encoded and precisely match your MySQL deployment variables.
* [ ] **Verify Python Library Bindings**: If `backend-deployment` crashes, verify that `requirements.txt` matches all modules executed inside `app.py`.

### 3. MySQL StatefulSet Connectivity & Schema Migration Failures
Common bottlenecks during the database provisioning loop and TCP socket mapping.

* [ ] **Inspect Volume Mount Permissions**: Check `kubectl logs mysql-0 -n lab-shopflow`. If you see permission errors, ensure your AWS EFS filesystem is mounted with correct POSIX security settings.
* [ ] **Verify `migration-job` Completion**: 
  * The Python backend requires the database schema to exist before handling client operations.
  * Run `kubectl get jobs -n lab-shopflow`. Ensure `migration-job` shows `1/1 SUCCESSFUL`.
* [ ] **Validate CoreDNS Name Resolution**: 
  * If `migrate.py` or `app.py` cannot locate the database host, verify your connection string.
  * The default target inside the cluster should be structural: `mysql.lab-shopflow.svc.cluster.local`.

### 4. Zero-Trust Network & Ingress Routing Errors
Issues relating to `502 Bad Gateway`, `504 Gateway Timeout`, or total packet drops.

* [ ] **Verify Network Isolation Boundaries**: 
  * `k8s/network-policy.yaml` explicitly enforces zero-trust rules.
  * Confirm that the ingress rules specifically permit traffic originating from the Nginx edge namespace/label into the Gunicorn Python API pod ports.
* [ ] **Check Application Port Mapping**: 
  * Ensure `nginx.conf` passes internal proxy traffic to the exact TCP target port configured on `backend-deployment.yaml` (typically port `8000` for Gunicorn).
* [ ] **Inspect AWS ALB Ingress Controller Logs**: If the external endpoint does not generate or returns broad connectivity errors, check the logs of your AWS Load Balancer Controller deployment inside your cluster management namespace.


Retrieve the production application endpoint routed through your Application Load Balancer mapping layer:

```bash
kubectl get ingress -n lab-shopflow
```

