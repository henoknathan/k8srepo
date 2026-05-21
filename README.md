# EKS Infrastructure Deployment

Automates the configuration of AWS Elastic Kubernetes Service (EKS) cluster add-ons by integrating the official AWS EKS Helm charts repository for reliable software deployments.

---

## 📖 Introduction for Beginners
In Kubernetes, an **Ingress Controller** acts like a smart traffic cop for your cluster. Instead of exposing every single internal service to the internet (which is expensive and insecure), an Ingress Controller sets up a single entry point (an AWS Application Load Balancer). It reads your configuration and routes external web traffic safely to the correct applications running inside your cluster.

This repository automates the installation of the **AWS Load Balancer Controller** using Helm, the package manager for Kubernetes.

---

## 📋 Prerequisites

Before starting, ensure you have the following tools installed and configured on your machine:
*   **AWS CLI**: The command-line tool to interact with your AWS account. It must be configured with permissions to manage EKS and IAM.
*   **kubectl**: The standard command-line tool used to send commands to Kubernetes clusters. Your local `kubectl` version should match your EKS cluster version.
*   **Helm v3+**: Known as the package manager for Kubernetes. It allows you to install, update, and manage pre-packaged Kubernetes applications called "charts".
*   **eksctl**: A dedicated, official command-line tool built by AWS and Weaveworks specifically for creating and managing infrastructure on EKS easily.

---

## ⚙️ Environment Variables

Environment variables store dynamic text values locally in your terminal session. By defining them once here, you can copy and paste the remaining commands exactly as written without manually changing cluster names or account IDs every time.

Run these commands in your terminal (replace the placeholder values inside the quotes with your actual AWS details):

```bash
# The exact name of your active EKS cluster
export CLUSTER_NAME="your-eks-cluster-name"

# The AWS region where your cluster lives (e.g., us-east-1, eu-west-1)
export AWS_REGION="your-aws-region"

# The Virtual Private Cloud (VPC) ID where your EKS cluster nodes are running
export VPC_ID="your-vpc-id"

# Automatically fetches your 12-digit AWS Account ID using the AWS CLI secure token service
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

---

## 🔐 IAM Roles for Service Accounts (IRSA)

**What is IRSA?** In Kubernetes, applications use a "Service Account" to define identity inside the cluster. However, the AWS Load Balancer Controller needs to talk to the actual AWS API to create physical Application Load Balancers in your AWS account. IRSA securely links a Kubernetes Service Account to a real AWS IAM Role, allowing your cluster applications to manage AWS infrastructure without needing to hardcode dangerous AWS secret keys inside the containers.

Follow these steps to set up secure permissions:

1. **Associate the OIDC Provider:**
   Kubernetes uses OpenID Connect (OIDC) to authenticate with AWS. This command tells your EKS cluster to trust AWS IAM for authentication tokens.
   ```bash
   eksctl utils associate-iam-oidc-provider --cluster=${CLUSTER_NAME} --approve --region=${AWS_REGION}
   ```

2. **Download the Official IAM Policy:**
   This downloads a JSON file written by AWS containing the exact list of permissions (like creating targets, managing listeners, and deleting load balancers) the controller needs.
   ```bash
   curl -O https://githubusercontent.com
   ```

3. **Create the IAM Policy in AWS:**
   This uploads the downloaded JSON file to AWS IAM, naming it so it can be attached to our security role.
   ```bash
   aws iam create-policy \
       --policy-name AWSLoadBalancerControllerIAMPolicy \
       --policy-document file://iam_policy.json
   ```

4. **Create the IAM Role and Service Account:**
   This `eksctl` command automates three complex steps at once: it creates an AWS IAM Role, attaches the policy we uploaded in Step 3, and generates a corresponding Kubernetes Service Account named `aws-load-balancer-controller` inside your cluster.
   ```bash
   eksctl create iamserviceaccount \
     --cluster=${CLUSTER_NAME} \
     --namespace=kube-system \
     --name=aws-load-balancer-controller \
     --role-name AmazonEKSLoadBalancerControllerRole \
     --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
     --approve \
     --region=${AWS_REGION}
   ```

---

## 🚀 Installation

Now that permissions are configured, we can download and deploy the application using Helm.

1. **Clone the repository:**
   Download this codebase onto your local machine and navigate into the folder.
   ```bash
   git clone https://github.com
   cd your-repo
   ```

2. **Add the official AWS EKS Helm repository:**
   Helm needs to know where to find the software packages. We point it to the official, secure AWS domain and refresh Helm's local catalog index.
   ```bash
   helm repo add eks https://github.io
   helm repo update
   ```

3. **Install the Chart:**
   This command installs the AWS Load Balancer Controller. We pass the `--set` flags to inject our environment variables into the configuration, and we use `--set serviceAccount.create=false` to force Helm to use the secure IAM service account we already created in the previous step.
   ```bash
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --set clusterName=${CLUSTER_NAME} \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller \
     --set region=${AWS_REGION} \
     --set vpcId=${VPC_ID} \
     -n kube-system
   ```

---

## 🔍 Verification

Always check your work to ensure Kubernetes resources are healthy and running.

1. **Check Helm release status:**
   Verify that your Helm installation reports a status of `deployed`.
   ```bash
   helm list -n kube-system
   ```

2. **Verify controller pods are running:**
   Pods are the actual running containers. The status column should show `Running` and the ready column should show `1/1` or `2/2`.
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

3. **Check deployment logs for errors:**
   If the pods are crashing or showing errors, stream the application logs to read what went wrong behind the scenes.
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
   ```

---

## 🌐 Sample Ingress Implementation

To prove the controller is working, you can deploy a sample application and map an external web address to it. 

1. Save the following content into a file named `sample-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: demo-web-service
  namespace: default
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: ClusterIP
  selector:
    app: demo-web
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-web-ingress
  namespace: default
  annotations:
    # This annotation tells our controller to intercept this file and spin up an AWS Application Load Balancer (ALB)
    kubernetes.io/ingress.class: alb
    # Dictates that the ALB should face the public internet
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Defines the routing rules (Instance mode targets cluster nodes)
    alb.ingress.kubernetes.io/target-type: instance
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo-web-service
                port:
                  number: 80
```

2. Apply the sample file to your cluster:
   ```bash
   kubectl apply -f sample-app.yaml
   ```

3. Retrieve your public URL (it may take 2-3 minutes for AWS to fully provision the load balancer):
   ```bash
   kubectl get ingress demo-web-ingress
   ```
   *Look at the `ADDRESS` field output. Paste that long AWS URL into your web browser to view the default Nginx welcome screen!*

---

## 🧽 Cleanup

Cloud infrastructure costs money when left running. Always tear down your test environments when you are finished practicing.

1. **Delete the sample application & ingress:**
   ```bash
   kubectl delete -f sample-app.yaml
   ```

2. **Uninstall the Helm release:**
   ```bash
   helm uninstall aws-load-balancer-controller -n kube-system
   ```

3. **Delete the IAM Service Account configuration:**
   ```bash
   eksctl delete iamserviceaccount \
     --cluster=${CLUSTER_NAME} \
     --namespace=kube-system \
     --name=aws-load-balancer-controller \
     --region=${AWS_REGION}
   ```

4. **Delete the AWS IAM Policy:**
   ```bash
   aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
   ```

---

## 🛠️ Troubleshooting

### Common Helm Chart Repository Error
If you encounter connection failures or `404 Not Found` errors during the installation setup phase, check your repo URLs. The application commands will fail if you accidentally try using a legacy or incorrect `github.io` root domain instead of the dedicated AWS hosting subdomain.

**Fix:**
```bash
# Manually correct the repository path to the official AWS EKS charts
helm repo add eks https://github.io
helm repo update
```

---

## 📄 License

Distributed under the **MIT License**. This means you are completely free to use, modify, copy, and distribute this code for personal or commercial projects, provided you include the original copyright notice. See the full terms below:

```text
MIT License

Copyright (c) 2026 Your Name / Organization

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
