# Multi-Tier Enterprise GitOps Platform on AWS EKS

A production-ready, highly available multi-tier application architecture deployed on AWS Elastic Kubernetes Service (EKS). This project demonstrates modern Cloud Native and DevOps engineering practices, utilizing **Infrastructure as Code (IaC)**, **GitOps Continuous Delivery**, **Microservices Containerization**, automated **Horizontal Autoscaling**, cloud-native **Persistent Storage**, and robust **Observability stacks**.

---

## 🏗️ System Architecture Overview

The infrastructure lifecycle is entirely automated and separated into logical operational layers:

```text
[ Traffic: Internet ]
          │
          ▼
   [ AWS ALB Ingress ]
          │
    ┌─────┴────────────────────────┐
    ▼                              ▼
[ Frontend Pods (Nginx) ]   [ Backend Pods (Flask/Python) ]
    │                              │
    ▼ (Shared Storage)             ▼
[ AWS EFS StorageClass ]     [ MySQL StatefulSet ]
```
```mermaid
graph TD
    %% Define Styles
    classDef client fill:#f9f,stroke:#333,stroke-width:2px;
    classDef aws fill:#ff9900,stroke:#333,stroke-width:1px,color:#fff;
    classDef k8s fill:#326ce5,stroke:#333,stroke-width:1px,color:#fff;
    classDef db fill:#00758f,stroke:#333,stroke-width:1px,color:#fff;

    %% Components
    User([🌐 Public Web User]) :::client
    
    subgraph AWS_Cloud [AWS Cloud Infrastructure (Provisioned via Terraform)]
        ALB[🔀 AWS Application Load Balancer] :::aws
        ECR[(📦 Amazon ECR Image Registry)] :::aws
        EFS[(💾 Amazon EFS Shared Storage)] :::aws
        
        subgraph EKS_Cluster [Amazon EKS Cluster]
            Argo[🐙 ArgoCD GitOps Engine] :::k8s
            Ingress[⚡ ALB Ingress Controller] :::k8s
            HPA[📈 Horizontal Pod Autoscaler] :::k8s
            
            subgraph Namespace_App [Application Namespace]
                Frontend[🎨 Frontend Pods <br> Nginx SPA] :::k8s
                Backend[⚙️ Backend Pods <br> Python REST API] :::k8s
                MySQL[(🛢️ MySQL StatefulSet)] :::db
                NetPol{🛡️ Network Policy} :::k8s
            end
            
            subgraph Namespace_Monitoring [Monitoring Namespace]
                Prom[🔥 Prometheus Metrics] :::k8s
                Graf[📊 Grafana Dashboards] :::k8s
            end
        end
    end

    %% Data Flows and Connections
    User -->|HTTP/HTTPS Traffic| ALB
    ALB -->|Routes Requests| Ingress
    Ingress -->|Forwards Web Traffic| Frontend
    Frontend -->|API Requests| Backend
    
    %% Storage and Database Relations
    Frontend -.->|Read/Write Assets| EFS
    Backend -->|Restricted Database Access| NetPol
    NetPol -->|Authorized Queries| MySQL
    
    %% Management Flows
    Argo -->|Continuous Reconcile / GitOps| Namespace_App
    ECR -->|Pulls Docker Images| Frontend
    ECR -->|Pulls Docker Images| Backend
    Prom -->|Scrapes Performance Metrics| Backend
    Graf -->|Queries Data Visuals| Prom
    HPA -->|Monitors CPU & Scales Replicas| Backend
```

1. **Provisioning Layer**: HashiCorp Terraform automates the deployment of the underlying AWS network topologies (VPC, Subnets, Security Groups) and the EKS Cluster.
2. **Delivery Layer (GitOps)**: ArgoCD tracks this repository to continuously synchronize and reconcile the active state of the Kubernetes cluster with our declaration files.
3. **Application Layer**: A containerized two-tier microservices application (Frontend SPA on Nginx + Python Backend) integrated with a persistent MySQL relational database.
4. **Security & Governance Layer**: Network Policies restrict cross-namespace traffic, Dedicated Namespaces isolate workloads, and SonarQube analyzes code quality.
5. **Observability Layer**: Prometheus collects fine-grained performance metrics while Grafana visualizes infrastructure and application health.

---

## 📂 Repository Directory Structure

```text
├── .github/workflows/      # CI/CD pipelines (GitHub Actions)
├── terraform/              # Infrastructure as Code (IaC)
│   ├── main.tf             # Core AWS & EKS resource definitions
│   ├── variables.tf        # Input variable declarations
│   ├── provider.tf         # AWS and Kubernetes provider versions
│   └── outputs.tf          # Managed infrastructure outputs
├── src/                    # Application Source Code
│   ├── frontend/           # Static Frontend SPA
│   │   ├── index.html      # UI entry point
│   │   └── Dockerfile      # Multi-stage Nginx build script
│   └── backend/            # App REST API
│       ├── app.py          # Python application logic
│       └── Dockerfile      # Optimized Python runtime build
├── k8s/                    # Kubernetes Manifests & GitOps Definitions
│   ├── argocd/             # Application controller & sync setups
│   ├── namespace.yaml      # Logical environment isolation
│   ├── deployment.yaml     # Application workload specifications
│   ├── service.yaml        # Internal networking abstractions
│   ├── ingress.yaml        # AWS ALB configuration rules
│   ├── hpa.yaml            # Horizontal Pod Autoscaling limits
│   ├── network-policy.yaml # Least-privilege firewall rules
│   ├── storage/            # Persistent Volume Claims & EFS configurations
│   ├── mysql/              # StatefulSet and initialization scripts
│   └── migration/          # Database schema schema run-once Jobs
└── monitoring/             # Observability Stack Configuration
    ├── prometheus/         # Metrics scraping and alert rules
    └── grafana/            # Operational performance dashboards
```

---

## 🛠️ Component Breakdown & Engineering Implementation

### 1. Infrastructure as Code (Terraform)
The infrastructure layer is built modularly with HashiCorp Terraform to ensure immutability and rapid environment replication.
* **`provider.tf`**: Secures state management using an isolated S3 remote backend with DynamoDB locking.
* **`main.tf`**: Configures custom VPC topologies spanning 3 Availability Zones, public/private subnet tagging for optimal AWS ALB discovery, and managed EKS Node Groups.
* **`variables.tf` / `outputs.tf`**: Parameterizes cluster scaling configurations and exports connection endpoints (`cluster_endpoint`, `oidc_provider_arn`).

### 2. Containerization & Registry (Docker & AWS ECR)
Workloads are completely isolated and packaged into secure, minimal container layers.
* **Frontend**: Utilizes a highly optimized lightweight **Nginx** server image to compile and host static files safely.
* **Backend**: Multi-stage **Python** environment running a Flask/FastAPI backend configured with automated database schema migration scripts (`migration/`).
* **AWS ECR**: Immutable image tags prevent runtime drift; image vulnerability scanning is forced on every upload registry action.

### 3. GitOps Continuous Delivery ()
Manual configurations are eliminated. Cluster states are declared declaratively inside the `k8s/argocd/` manifests. ArgoCD continuously monitors this git repository branch, pulling down structural updates and executing zero-downtime, self-healing synchronizations directly against the Kubernetes API server.

### 4. Advanced Kubernetes Orchestration & Security
* **Network Policies**: Implements a zero-trust model. The database tier rejects all internet-facing communication, responding strictly to incoming API calls from authorized backend microservices.
* **Storage Tier (AWS EFS)**: Integrates the EFS CSI Driver to provision persistent, shared network filesystems (`ReadWriteMany`), ensuring application pods preserve static uploads across cross-AZ rescheduling events.
* **Horizontal Pod Autoscaler (HPA)**: Dynamically scales application replicas from `2` to `10` targets processing CPU utilization metrics spikes above 70%.

### 5. Enterprise Code Quality & Observability
* **SonarQube**: Automatically evaluates code pushes for security vulnerabilities, technical debt, and test coverage parameters before staging application release cycles.
* **Prometheus & Grafana**: Collects real-time container metrics (memory footprints, saturation rates, HTTP latencies), displaying actionable operations health dashboards for engineer review.

---

## 🚀 Step-by-Step Deployment Instructions

### Phase 1: Provision Core Infrastructure
1. Initialize and download Terraform plugins:
   ```bash
   cd terraform
   terraform init
   ```
2. Validate configurations and deploy the footprint:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
3. Update your local configuration context to point securely to your new cluster:
   ```bash
   aws eks update-kubeconfig --region \((terraform output -raw aws_region) --name\)(terraform output -raw cluster_name)
   ```

### Phase 2: Build & Push Images to ECR
1. Authenticate your local Docker daemon with your AWS account:
   ```bash
   aws ecr get-login-password --region your-region | docker login --username AWS --password-stdin ://amazonaws.com
   ```
2. Build and push your operational components:
   ```bash
   docker build -t your-repo/frontend:latest ./src/frontend
   docker build -t your-repo/backend:latest ./src/backend
   # (Execute docker tag and docker push sequences to secure your ECR endpoints)
   ```

### Phase 3: Bootstrap GitOps Delivery Engine
1. Deploy the core components of the cluster state machine:
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/argocd/install.yaml
   ```
2. Apply the root application configuration definition to trigger structural resource generation:
   ```bash
   kubectl apply -f k8s/argocd/root-application.yaml
   ```
   *ArgoCD will automatically intercept your specifications, deploying your MySQL StatefulSets, EFS Storage claims, HPA scaling configurations, App Deployments, and your AWS Application Load Balancers.*

---

## 🔍 Verification & Infrastructure Smoke Testing

* **Check GitOps Deployment Health**:
  ```bash
  argocd app get root-application
  ```
* **Verify Workload Distribution**:
  ```bash
  kubectl get all -n your-app-namespace
  ```
* **Retrieve External Web App Endpoint**:
  ```bash
  kubectl get ingress -n your-app-namespace
  ```

---

## 🧽 Teardown & De-provisioning
To cleanly eliminate all provisions and avoid unnecessary cloud billing overhead:
```bash
# 1. Instruct ArgoCD to clean up K8s objects safely
kubectl delete -f k8s/argocd/root-application.yaml

# 2. Obliterate backend core Cloud resources via Terraform 
cd terraform
terraform destroy -auto-approve
```

---

## 📄 License
This architecture framework is configured under the terms of the **MIT License**. Feel free to use, distribute, and modify it within architectural code practices.

