Shopflow Enterprise: Production-Grade GitOps & DevSecOps E-Commerce Platform

A high-availability, multi-tier web application built using Kubernetes (AWS EKS v1.30) and provisioned natively via Terraform (AWS Module v21.x). This architecture implements a decoupled microservices design—separating an optimized Nginx frontend proxy, a multi-worker Gunicorn Python backend, a stateful MySQL cluster, and a centralized AWS Elastic File System (EFS) core—while maintaining strict Zero-Trust network boundaries and fully automated GitOps delivery.

Architectural Topology Blueprint

               [ Public Internet Edge ]
                          │ (HTTP 80 -> HTTPS 443 Redirect)
                          ▼
            ┌───────────────────────────┐
            │   AWS ALB Ingress Controller │ (TLS Termination / ACM Cert)
            └─────────────┬─────────────┘
                          │ (Internal ClusterIP: 80)
                          ▼
            ┌───────────────────────────┐
            │   shopflow-frontend-svc   │
            └─────────────┬─────────────┘
                          │
                          ▼
            ┌───────────────────────────┐  (Read/Write Media)  ┌───────────────────────┐
            │ Nginx Frontend UI Container│ ──────────────────> │  AWS EFS (NFS 2049)   │
            └─────────────┬─────────────┘                      │  Storage Class: efs-sc│
                          │ (Strip /api -> Proxy Pass: 8080)   └───────────▲───────────┘
                          ▼                                                │
            ┌───────────────────────────┐                                  │ (Shared PVC)
            │      backend-service      │                                  │
            └─────────────┬─────────────┘                                  │
                          │                                                │
       [ Network Policy: Only Allow Frontend ]                             │
                          ▼                                                │
            ┌───────────────────────────┐                                  │
            │ Gunicorn Python API Pods  │                                  │
            └─────────────┬─────────────┘                                  │
                          │ (Port: 3306)                                   │
       [ Network Policy: Only Allow Backend ]                              │
                          ▼                                                │
            ┌───────────────────────────┐                                  │
            │    mysql-service (TCP)    │                                  │
            └─────────────┬─────────────┘                                  │
                          │                                                │
                          ▼                                                │
            ┌───────────────────────────┐                                  │
            │ MySQL 8.0 StatefulSet Pod │ ─────────────────────────────────┘
            └───────────────────────────┘

 Complete Technical Stack Grid
 
 Cloud Infrastructure: AWS (VPC, EKS Managed Node Groups, ECR, EFS, ALB, ACM Certificates).
 
 Infrastructure as Code: Terraform >= v1.5.0 (with AWS Provider ~> v5.39.0 utilizing modern native S3 state file concurrency locking without DynamoDB).
 
 Web Tier / Gateway: Nginx v1.25 (Static compilation caching server + reverse proxy URL re-writing engine).
 
 Application Runtime: Python v3.11-slim running Flask v3.0 managed by Gunicorn v21.2 (3 worker multi-threaded processes).
 
 Data Tier: MySQL v8.0 deployed as a Kubernetes StatefulSet with automated filesystem ownership mapping initialization sequences.
 
 Continuous Integration / Delivery: Jenkins Pipeline (Dynamic Docker-in-Docker agent virtualization) + ArgoCD GitOps (Declarative self-healing automation tracking HEAD).
 
 DevSecOps & Observability: SonarCloud SAST, Kubernetes Network Policies, Prometheus Time-Series Database (TSDB), Grafana Unified Analytics, and Alertmanager Slack integrations.

Repository Directory Matrix

📁 Shopflow-Enterprise-Workspace/
│
├── 📁 .github/workflows/          # GitHub Enterprise Automation Pipelines
│   ├── infra.yaml                 # Automated Terraform execution & PR output publisher
│   └── sonar.yaml                 # SonarCloud multi-language security SAST scanner
│
├── 📁 k8s/                        # Declarative Cluster Manifests (ArgoCD GitOps Target)
│   ├── namespace.yaml             # Core isolation boundary (lab-shopflow)
│   ├── secret-store.yaml          # Base64 application runtime database credentials
│   ├── shared-storage.yaml        # 10Gi AWS EFS PersistentVolumeClaim mapping
│   ├── mysql.yaml                 # StatefulSet DB engine deployment with data persistence
│   ├── migration-job.yaml         # Non-blocking schema migrator utilizing TCP socket probes
│   ├── backend-deployment.yaml    # Python/Gunicorn production API microservice deployment
│   ├── frontend-deployment.yaml   # Hardened Nginx edge web node web server layout
│   ├── hpa.yaml                   # Dual metric (CPU/Memory) Horizontal Pod Autoscaling Behavior
│   ├── network-policy.yaml        # Layer-3/4 Zero-Trust network segment isolation firewall
│   └── ingress.yaml               # Enterprise Application Load Balancer routing profile
│
├── 📁 terraform/                  # Automated Cloud Infrastructure Matrix
│   ├── provider.tf                # AWS provider constraints and remote state hooks
│   ├── main.tf                    # Complete definition of AWS EKS, VPC, EFS, and ECR arrays
│   ├── variables.tf               # Type-safe parameter constraints with validation regex blocks
│   └── outputs.tf                 # Immutable runtime environment outputs used by the CI pipeline
│
├── index.html                     # Decoupled Frontend UI engine with live cluster health badges
├── nginx.conf                     # Custom internal path gateway engine with dynamic CoreDNS resolution
├── app.py                         # Multi-worker Python Gunicorn microservice core logic
├── migrate.py                     # Programmatic database schema creator running on DB sockets
├── requirements.txt               # Locked production-grade application library dependency map
├── Dockerfile                     # Ultra-light frontend Nginx container image layout
├── backend.Dockerfile             # Hardened multi-stage multi-user non-root Python runner layer
├── monitoring-values.yaml         # Global configuration sheet for custom Prometheus/Grafana TSDB stacks
├── alertmanager-values.yaml       # Escaped notification routing manifests with Slack webhooks
├── sonar-project.properties       # Multi-language coverage filtering exclusions manifest
└── Jenkinsfile                    # Unified concurrent orchestration CI build automation script

Hardened DevSecOps Production Security Configurations

This project completely isolates application processing nodes by discarding standard generic configurations in favor of hardened production designs:

1. Hardened Multi-Stage Container Layering

The backend utilizes a distinct two-phase Docker-in-Docker build routine. Heavy building tools (gcc, python3-dev) compile requirements in a isolated staging workspace before throwing away all OS-level bloat. The final deployment image contains only the compiled dependencies, dropping execution permissions from root down to USER 10001 to totally prevent host workspace container breakout exploits.

2. Multi-Tier Zero-Trust Firewalls (NetPol)

By default, Kubernetes allows any pod to communicate with any pod. This codebase blocks that completely:

The Frontend Layer accepts public ingress, but cannot connect to the database.

The Backend Layer is isolated from the internet; it only accepts incoming streams wrapped by the Nginx proxy layer on port 8080.

The Database Layer drops all network streams on port 3306 except for explicit targets coming from the Python app containers or dynamic ephemeral Kubernetes migration jobs.

3. Native DNS Tracking Validation

To prevent Nginx from caching single pod IP lookups at boot time and throwing fatal 502 Bad Gateway errors when your pods auto-scale, this nginx.conf implements a native cluster loop resolver mapping to the internal AWS EKS CoreDNS address (10.100.0.10) with a 5-second dynamic TTL check rule.

Execution & Deployment Playbook

To bootstrap this entire multi-tier e-commerce architecture into your corporate AWS account, execute files following this logical lifecycle array:
Phase A: Setup Global AWS Foundations via Terraform
# 1. Access the cloud infrastructure workspace
cd terraform/

# 2. Fire up the vendor binaries and hook into the secure remote bucket state lock
terraform init

# 3. Ensure syntax validations conform perfectly to AWS EKS v21 requirements
terraform validate

# 4. Generate the frozen blueprint file
terraform plan -out=tfplan

# 5. Apply the plan to roll out your complete high-availability cluster grid
terraform apply tfplan

Phase B: Register the Automated ArgoCD GitOps Engine

Once the cluster is up, deploy the declarative application wrapper so ArgoCD can monitor configuration drift, enforce anti-tampering rules, and match your live deployment state to your Git repository automatically:

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/application.yaml --namespace argocd

Phase C: Manual Infrastructure Verification Routing Array

# Check the deployment pipeline logs across the lab namespace
kubectl get all -n lab-shopflow

# Trace the metrics aggregation and dynamic hardware node consumption loops
kubectl top pods -n lab-shopflow

# Extract the assigned external DNS endpoint string of the Application Load Balancer
kubectl get ingress shopflow-ingress -n lab-shopflow

Observability, Alerts & Metrics Automation

This cluster utilizes the kube-prometheus-stack Helm chart paired with custom configuration sheets to monitor system health:
•	Metric Retention & Storage Persistence: Metric data is retained for 30 days. Both Prometheus Time-Series data and custom Grafana user dashboards are saved to a resilient, multi-AZ AWS EFS network drive array, ensuring your data is never lost when monitoring pods restart.
•	Autoscaling Thresholds: The Horizontal Pod Autoscaler (hpa.yaml) implements strict anti-flapping guardrails. It monitors both CPU and Memory limits simultaneously—protecting Gunicorn from unexpected memory leaks by doubling pod counts if memory hits 75% utilization, and waiting 5 minutes after spikes subside before scaling down to prevent system flapping.
•	Proactive Alertmanager Slack Notifications: Alertmanager batches cluster warnings and sends notifications directly to your team's Slack channels using structured, clean templates to help prioritize responses:
