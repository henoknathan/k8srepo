#Enterprise DevSecOps PipelineThis fully integrated Jenkinsfile handles security scans, 
#quality validations, vulnerability checks, and sequential schema upgrades:
pipeline {
    // Tells Jenkins to run this pipeline on a worker node or master labeled 'master-node'
    //agent { label 'master-node' }
        // =========================================================================
    // UPDATED PIPELINE EXECUTION COMPLIANCE ENGINE
    // =========================================================================
    // OLD MECHANISM: agent { label 'master-node' }
    /**
    Step 2: Containerize the Build AgentPurpose: Using a fixed, static server label like master-node 
    forces pipelines to share the same OS environment. This causes "tool-version drift" 
    (e.g., one job needs Python 3.9, another needs Python 3.11) and risks running out of disk space. 
    Switching to a dynamic Docker agent ensures that every single build executes inside an isolated 
    container that is destroyed immediately after completion. 
    ---(Note: If you run your Jenkins workers natively inside an EKS cluster, you can swap this docker 
    block with a kubernetes pod template block to maximize system performance).
    */
    // NEW MECHANISM: Dynamic Multi-Tool Container Agent Configuration
    // PURPOSE: Guarantees explicit runtime dependencies (aws-cli, kubectl, trivy) 
    // are standardized without bloating or altering physical Jenkins worker nodes.
    agent {
        docker {
            image 'amazon/aws-cli:latest' // Base agent image equipped with AWS operational binaries
            args  '-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/kubectl:/usr/local/bin/kubectl'
            // PURPOSE: Mounts host socket to build nested images and shares kubectl tools inside the runtime
        }
    }
}
    // Global environment variables available across all stages of the pipeline
    // =========================================================================
    // IMPROVEMENTS IN GLOBAL PIPELINE CONFIGURATION
    /**
    Step 1: Parameterize Sensitive Variables Purpose: Hardcoding AWS Account IDs and SonarQube 
    URLs directly in source files leaks internal infrastructure data and causes structural rigidity. 
    By moving these values into Jenkins Global Credentials or Environment Management, you can reuse 
    the exact same Jenkinsfile across staging, QA, and production clusters without editing the file code.
    */
    // =========================================================================
    environment {
        AWS_REGION       = "us-east-1"
        EKS_CLUSTER_NAME = "shopflow-k8s"
        IMAGE_TAG        = "build-${BUILD_NUMBER}"
        PATH             = "/usr/local/bin:${env.PATH}"
        
        // PARAMETERIZED: Fetches variables securely managed by the Jenkins server core
        // PURPOSE: Prevents leaking cloud account layout IDs inside code repositories
        AWS_ID           = credentials('GLOBAL_AWS_ACCOUNT_ID')
        SONAR_SERVER_URL = credentials('GLOBAL_SONAR_SERVER_URL')

        FRONTEND_REPO_NAME    = "frontend-repo"
        BACKEND_REPO_NAME     = "backend-repo"

        
        // Dynamically processes registry using the securely injected ID parameter variable
        REGISTRY         = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        /**
        Improvements & Safety Elements Added:deleteDirs: true: Forces Jenkins to delete entire nested 
        subdirectories (like old node_modules or Python cache folders) instead of just loose root files.
        notFailBuild: true: This is a production safety catch. If a background process on your build server 
        temporarily locks a log file in the workspace, this flag prevents Jenkins from instantly crashing 
        your entire pipeline over a minor file-locking cleanup issue.Directory Verification (ls -la k8s/): 
        Instantly logs the file structure right after checkout. If a developer accidentally renames or 
        deletes the k8s/ folder in a bad commit, the pipeline will catch it immediately here at the very 
        beginning of the run rather than waiting until the deployment stage to fail.
            /**
         * STAGE 1: INITIALIZE & CHECKOUT
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Wipes out the workspace directory and pulls the latest code.
         * CONNECTIONS: Connects to your Source Control Management (SCM) system (GitHub/GitLab).
         * PURPOSE: Cleaning the workspace prevents old compilation files, hidden lockfiles,
         * or cached Docker build layers from interfering with your new enterprise deployment.
         */
        stage('Initialize & Checkout') {
            steps {
                // Wipe the workspace before pulling new code to ensure an unpolluted build state
                cleanWs deleteDirs: true, notFailBuild: true
                
                // Pulls the exact Git commit branch that triggered this specific Jenkins run
                checkout scm
                
                // PURPOSE: Validates that the critical k8s directory and manifests are present
                sh """
                    echo "=== Workspace Sanitized & Code Checkout Complete ==="
                    ls -la k8s/
                """
            }
        }


        /**
         * STAGE 2: SONARQUBE SECURITY SCAN
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs a Static Application Security Testing (SAST) vulnerability scan.
         * CONNECTIONS: Uses the 'sonar-token' credential to authenticate and send source 
         * code metrics from FRONTEND and BACKEND directories over to the SonarQube Server.
         * LEARNING TIP: This checks for code issues, leaked secrets, and bugs *before* 
         * spending time and resources building a broken Docker image.
         */
        /**
         * STAGE 2: SONARQUBE SECURITY SCAN
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs a Static Application Security Testing (SAST) vulnerability scan.
         * CONNECTIONS: Uses predefined Jenkins environment variables to securely connect to SonarQube.
         * LEARNING TIP: Separating sources and excluding dependencies keeps scans fast and accurate.
         */
 stage('SonarQube Security Scan') {
    steps {
        withSonarQubeEnv('SonarQube') {
            sh """
                sonar-scanner \
                -Dsonar.projectKey=shopflow-enterprise-app \
                -Dsonar.projectName="Shopflow Enterprise App" \
                -Dsonar.sources=./frontend,./backend \
                -Dsonar.exclusions=**/node_modules/**,**/dist/** \
                -Dsonar.python.version=3
            """
        }
    }
}

        /**
        This stage uses Jenkins' native parallel execution engine to build your frontend and backend 
        containers at the exact same time. This cuts your total pipeline build duration in half, 
        maximizing efficiency while enforcing strict DevSecOps image tracking tags.
        Critical Architecture Elements Explained:The parallel Syntax Matrix: Instead of waiting for the 
        frontend to finish downloading packages before starting the backend, Jenkins forks the pipeline 
        into two independent threads. This maximizes your build server's CPU and network utilization.
        Relative Workspace Subdirectories (./frontend and ./backend): The docker build commands assume 
        your source code repository is cleanly organized with separate folders for your microservices. 
        If your code lives directly in the root directory, adjust the path strings (e.g., changing ./backend 
        to . -f Dockerfile.backend).Double-Tagging Strategy (${IMAGE_TAG} and latest): We compile the image 
        once with your unique ID and then use docker tag to instantly clone the reference pointer to latest. 
        This avoids running the heavy docker build engine twice, which saves CPU cycles and prevents build 
        drift.Where Does This Fit in Your Pipeline?This stage fits perfectly after your SonarQube Quality 
        Gate (Webhook) stage has passed, and before your Trivy Image Scan & Safety Gate stage executes. 
        This pattern guarantees that your pipeline only wastes cloud compute power building Docker images 
        after the static source code is verified to be safe and secure.

         * STAGE: PARALLEL DOCKER BUILD & TEMPLATE TAGGING
         * -------------------------------------------------------------------------
         * WHAT IT DOES: 
         * 1. Compiles both frontend and backend Dockerfiles simultaneously.
         * 2. Injects the cloud registry path and unique, traceable build variables.
         * 3. Generates a fallback 'latest' pointer reference tag for each repository.
         * 
         * PURPOSE: Speeds up pipeline delivery using asynchronous compilation while 
         * preparing immutable containers ready for secure push into AWS ECR.
         */
        stage('Parallel Docker Compilation') {
            steps {
                // parallel allows independent blocks to execute at the exact same time
                // PURPOSE: Drastically cuts down build execution times by utilizing multi-core worker nodes
                parallel(
                    "Compile Frontend Service": {
                        script {
                            echo "=== Starting Frontend Multi-Stage Build ==="
                            
                            // 1. COMPILE TRACEABLE REVISION FILE
                            // PURPOSE: Builds the static production assets and tags it with the immutable build execution ID
                            // LEARNING TIP: We pass the explicit folder path containing your frontend source and Dockerfile
                            sh "docker build -t ${REGISTRY}/shopflow-frontend:${IMAGE_TAG} ./frontend"
                            
                            // 2. GENERATE MUTABLE 'LATEST' REFERENCE
                            // PURPOSE: Tags the same local image layer hash as 'latest' for secondary tracking hooks
                            sh "docker tag ${REGISTRY}/shopflow-frontend:${IMAGE_TAG} ${REGISTRY}/shopflow-frontend:latest"
                            
                            echo "=== Frontend Image Compilation Verified Complete ==="
                        }
                    },
                    "Compile Backend Service": {
                        script {
                            echo "=== Starting Hardened Backend Multi-Stage Build ==="
                            
                            // 1. COMPILE HARDENED APPLICATION WORKLOAD
                            // PURPOSE: Discards compiler utilities, strips root privileges, and tags with the unique build string
                            sh "docker build -t ${REGISTRY}/shopflow-backend:${IMAGE_TAG} ./backend"
                            
                            // 2. GENERATE MUTABLE 'LATEST' REFERENCE
                            sh "docker tag ${REGISTRY}/shopflow-backend:${IMAGE_TAG} ${REGISTRY}/shopflow-backend:latest"
                            
                            echo "=== Backend Image Compilation Verified Complete ==="
                        }

                    }
                )
            }
        }

        /**
         * STAGE 3: SONARQUBE QUALITY GATE (WEBHOOK)
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Pauses the pipeline and waits for a "PASS" or "FAIL" from SonarQube.
         * CONNECTIONS: Listens for a Webhook callback sent from your SonarQube server.
         * LEARNING TIP: If the Quality Gate fails (e.g., security bugs are found), 
         * `abortPipeline: true` safely stops the build, protecting your cluster.
         */
        stage('SonarQube Quality Gate (Webhook)') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        /**
         * STAGE 4: BUILD CONTAINERS
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Compiles the code into isolated Docker container images on your host.
         * CONNECTIONS: Reads the respective Dockerfiles under 'FRONTEND/' and 'BACKEND/'.
         * LEARNING TIP: We use specific names and pass the unique `IMAGE_TAG` so each 
         * build artifact is traceable back to this exact Jenkins run.
         */
        stage('Build Containers') {
            steps {
                script {
                    frontendImg = docker.build("${REGISTRY}/frontend-repo:${IMAGE_TAG}", "-f FRONTEND/Dockerfile .")
                    backendImg  = docker.build("${REGISTRY}/backend-repo:${IMAGE_TAG}", "-f BACKEND/Dockerfile .")
                }
            }
        }

        /**
        /**
         * STAGE 3.5: TRIVY DEPENDENCY VULNERABILITY GATE
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Pulls image targets and audits open-source third-party software patches.
         * PURPOSE: Aborts the pipeline immediately if a critical security vulnerability 
         * or malware dependency is identified in your app supply chain layers.
         Step 3: Implement Automated Quality Gates & Trivy ChecksPurpose: Security scans 
         are useless if they only record vulnerabilities without stopping broken software. 
         Adding explicit validation checks prevents high-risk security flaws from entering your production 
         cluster.Here is how you inject a multi-layer vulnerability gate right after your SonarQube analysis:
         */
        stage('Trivy Image Scan & Safety Gate') {
            steps {
                script {
                    echo "=== Starting Security Vulnerability Audit via Aquasecurity Trivy ==="
                    
                    // Run vulnerability scans directly against your code libraries before deployment
                    // PURPOSE: Scans base layers and dependencies for known CVE data flaws.
                    // '--exit-code 1' tells Trivy to fail the build if CRITICAL issues are discovered.
                    sh """
                        trivy image \
                        --severity CRITICAL \
                        --exit-code 1 \
                        --ignore-unfixed \
                        ${REGISTRY}/shopflow-backend:${IMAGE_TAG}
                    """
                    
                    echo "=== Supply Chain Security Verification Passed Complete ==="
                }
            }
        }

    }
        /**
        Incorrect Registry Path Binding: The native Jenkins Docker Plugin (frontendImg.push()) 
        does not naturally understand how to interface with an AWS token authenticated via standard shell 
        commands (sh "docker login..."). Because it lacks context, the plugin will attempt to push directly 
        to public Docker Hub by default, triggering an immediate Access Denied error.
        Missing Repository Variable Definitions: Your script references frontendImg and backendImg variables. 
        In the context of our architectural changes—such as moving to an isolated container agent—these 
        variable objects are not defined globally unless explicit docker.build blocks are declared directly 
        inside or preceding this execution block.The Solution: Use Native Shell Commands (sh)Instead of 
        relying on the temperamental Jenkins Docker plugin wrappers (.push()), the enterprise standard is 
        to use raw Docker CLI native shell execution commands.Because you already authenticated your terminal 
        layer using the aws ecr get-login-password pipe, the local shell session is fully authorized. 
        Standard docker push commands will run seamlessly, require fewer plugins, and execute faster.
        */

        /**
         * STAGE 6: PUSH TO AWS ECR
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Authenticates the build runner with AWS and uploads the local Docker images.
         * CONNECTIONS: Connects your isolated container agent to the cloud-hosted AWS ECR Registry.
         * PURPOSE: Pushes both the unique, traceable image tag and the mutable 'latest' tag 
         * to provide build tracking while allowing rapid developer environment updates.
         */
        stage('Push to AWS ECR') {
            steps {
                script {
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        // 1. AUTHENTICATE DAEMON TO CLOUD REGISTRY
                        // PURPOSE: Retrieves a temporary 12-hour session token to pass AWS ECR firewalls safely.
                        echo "=== Authenticating Docker Engine with AWS ECR ==="
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                        
                        // 2. DISPATCH IMMUTABLE AND TRACEABLE IMAGE TAGS
                        // PURPOSE: Delivers the explicit build run iteration tag to your cloud repository.
                        echo "=== Uploading Traceable Application Build Artifacts ==="
                        sh "docker push ${REGISTRY}/shopflow-frontend:${IMAGE_TAG}"
                        sh "docker push ${REGISTRY}/shopflow-backend:${IMAGE_TAG}"
                        
                        // 3. DISPATCH FLUID REGISTRY COPIES
                        // PURPOSE: Overwrites the mutable 'latest' reference pointer so developers can query the fresh deployment easily.
                        echo "=== Syncing Latest Version References ==="
                        sh "docker push ${REGISTRY}/shopflow-frontend:latest"
                        sh "docker push ${REGISTRY}/shopflow-backend:latest"
                        
                        echo "=== Image Registry Sync Complete ==="
                    }
                }
            }
        }

        
        /** 
        The 3 Issues We Must FixThe Image Path Mismatch: Just like your other stages, 
        the sed string is currently looking for backend-repo. We need to change this to your 
        actual ECR repository name: shopflow-backend.The Dynamic Job Name Flaw: Your kubectl wait command 
        looks for a specific dynamic job name format: job/shopflow-db-migration-${BUILD_NUMBER}. 
        However, a standard kubectl apply -f migration-job.yaml command passes a fixed, static name 
        declared inside the file's metadata: name: block. To make this dynamic match work without 
        throwing an "Object not found" error, we must use sed to inject your ${BUILD_NUMBER} into the actual 
        template file name block before applying it.The Cleanup/Idempotency Issue: 
        If a previous build fails or runs a migration, a Kubernetes Job with the same name might still 
        sit in the cluster in a Completed or Failed state. If you try to run kubectl apply over an existing 
        job, Kubernetes will throw a validation error and fail your pipeline. 
        We need to add a safe pre-emptive deletion step.
        */

        /**
         * STAGE: DATABASE MIGRATION
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs an isolated, short-lived Kubernetes Job to update database tables.
         * CONNECTIONS: Authenticates with AWS EKS and triggers the database schema script.
         * PURPOSE: Running migrations as a Kubernetes Job *before* upgrading your apps 
         * ensures that the new columns are available when the new code spins up. If the 
         * migration fails, the pipeline stops here, protecting your running production app.
         */
        stage('Database Migration') {
            steps {
                script {
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        // RE-ESTABLISH HANDSHAKE
                        // PURPOSE: Authenticates kubectl with AWS EKS using temporary tokens.
                        echo "=== Connecting to AWS EKS Cluster ==="
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // 1. DYNAMIC JOB NAME AND IMAGE INJECTION
                        // PURPOSE: Rewrites the static manifest tokens so that every build run creates a uniquely trackable cluster job.
                        // CORRECTED: Swapped 'backend-repo' to your exact 'shopflow-backend' string parameter.
                        echo "=== Customizing Migration Template for Run #${BUILD_NUMBER} ==="
                        sh "sed -i 's|TARGET_BACKEND_IMAGE|${REGISTRY}/shopflow-backend:${IMAGE_TAG}|g' k8s/migration-job.yaml"
                        sh "sed -i 's|TARGET_BUILD_NUMBER|${BUILD_NUMBER}|g' k8s/migration-job.yaml"
                        
                        // 2. IDEMPOTENT WORKSPACE CLEANUP
                        // PURPOSE: Safely clears any existing version of this specific run job from cluster memory if it was retried.
                        // '|| true' guarantees that if the job doesn't exist yet, it won't crash the pipeline step.
                        echo "=== Clearing Legacy Retries ==="
                        sh "kubectl delete job shopflow-db-migration-${BUILD_NUMBER} -n lab-shopflow --ignore-not-found=true || true"
                        
                        // 3. EXECUTE MIGRATION ENGINE JOB
                        // PURPOSE: Triggers your database configuration patch script payload inside the cluster runtime.
                        echo "=== Deploying Database Migration Engine Workload ==="
                        sh "kubectl apply -f k8s/migration-job.yaml"
                        
                        // 4. SYNCHRONOUS VALIDATION GATEWAY
                        // PURPOSE: Halts pipeline progress here until the database reports a clean execution status code of 0.
                        // LEARNING TIP: If your SQL patch contains syntax errors, this step times out, gracefully stopping the deployment.
                        echo "=== Awaiting Migration Completion ==="
                        sh "kubectl wait --for=condition=complete job/shopflow-db-migration-${BUILD_NUMBER} -n lab-shopflow --timeout=120s"
                        
                        echo "=== Database Schema Synchronized Successfully ==="
                    }
                }
            }
        }


        /**
         * STAGE 8: DEPLOY & ROLLOUT VERIFICATION
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Replaces old placeholders, applies configurations, and monitors rollout.
         * CONNECTIONS: Instructs the AWS EKS cluster control plane to start a rolling update.
         * LEARNING TIP: `kubectl rollout status` acts as a crucial safety guard. If the new 
         * containers fail their readiness/liveness health probes within 150 seconds, this 
         * stage drops an error, forcing Jenkins into the `post { failure }` safety block.
         */
        /**
         * STAGE 4: DEPLOY & ROLLOUT VERIFICATION
         * -------------------------------------------------------------------------
         * WHAT IT DOES: 
         * 1. Extracts AWS and Database credentials securely from the Jenkins Store.
         * 2. Dynamically updates image tracking tags inside the unified manifest.
         * 3. Generates a secure Kubernetes Secret directly in cluster memory.
         * 4. Deploys the application workloads and verifies they start up cleanly.
         * 
         * PURPOSE: Executes a secure, zero-downtime automated deployment without ever 
         * exposing infrastructure or database passwords in plain text or Git history.
         */
    /**
    Because we containerized your build environment by introducing a temporary Docker agent 
    (agent { docker { ... } }), your pipeline container does not have a persistent AWS session initialized. 
    If you run kubectl apply without running aws eks update-kubeconfig inside this specific block, 
    your authentication will fail immediately with an Unauthorized or expired token connection error.
    The Updated StageAdd the connection hook right after the withCredentials block opens. 
    This initializes the network bridge to EKS using the isolated credentials before running any manifest 
    updates or cluster dispatches.
    -->Why This Update is Mandatory:Token Handshake Generation: When withCredentials passes your access keys 
    into the environment, aws eks update-kubeconfig uses those active strings to write a temporary 
    configuration file inside the container's .kube/config memory directory.Kubectl Dependency: Without that 
    configuration file, kubectl does not have a destination API server endpoint or security certificate 
    mapping to talk to your shopflow-k8s instance, which causes your pipeline to hang or crash immediately.
    */
    stage('Deploy & Rollout Verification') {
        steps {
            script {
                // SECURE VARIABLE BINDING LAYER
                // PURPOSE: Fetches sensitive keys from Jenkins encrypted storage and maps them to environment variables.
                // LEARNING TIP: These variables only exist during this code block and are masked (****) in build logs.
                withCredentials([
                    [$class: 'UsernamePasswordMultiBinding', 
                     credentialsId: 'aws-eks-creds', 
                     usernameVariable: 'AWS_ACCESS_KEY_ID', 
                     passwordVariable: 'AWS_SECRET_ACCESS_KEY'],
                    
                    usernamePassword(
                     credentialsId: 'DB_CREDENTIALS', 
                     usernameVariable: 'DB_USER', 
                     passwordVariable: 'DB_PASS')
                ]) {
                    
                    // =========================================================================
                    // CRITICAL UPDATE: INITIALIZE AWS AUTHENTICATION SESSION FOR THE DOCKER AGENT
                    // =========================================================================
                    // PURPOSE: Because the pipeline runs inside an isolated container agent, we must 
                    // register the EKS connection endpoint data to generate matching API session tokens.
                    echo "=== Authenticating Session and Connecting to AWS EKS Cluster ==="
                    sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                    
                    // 1. DYNAMIC IMAGE TAG INJECTION (UPDATED FOR UNIFIED DEPLOYMENT FILE)
                    // PURPOSE: Modifies your single unified file to point to the exact ECR images built in this pipeline run.
                    // LEARNING TIP: We target 'deployment.yaml' inside the 'k8s' folder to match your repository directory layout.
                    echo "=== Injecting Live ECR Images into Unified Manifest ==="
                    sh "sed -i 's|TARGET_BACKEND_IMAGE|${REGISTRY}/shopflow-backend:${IMAGE_TAG}|g' k8s/deployment.yaml"
                    sh "sed -i 's|TARGET_FRONTEND_IMAGE|${REGISTRY}/shopflow-frontend:${IMAGE_TAG}|g' k8s/deployment.yaml"
                    
                    // 2. NAMESPACE INITIALIZATION
                    // PURPOSE: Ensures the isolated 'lab-shopflow' logical project space exists before applying resources to it.
                    echo "=== Ensuring Target Namespace Exists ==="
                    sh "kubectl apply -f k8s/namespace.yaml"
                    
                    // 3. IN-MEMORY SECRET GENERATION (DEVSECOPS BEST PRACTICE)
                    // PURPOSE: Creates the 'db-secret' using credentials securely passed from Jenkins.
                    // LEARNING TIP: '--dry-run=client -o yaml | kubectl apply -f -' creates or safely updates the secret without duplicating it or throwing errors.
                    echo "=== Dynamically Generating Kubernetes Database Secret ==="
                    sh "kubectl create secret generic db-secret --from-literal=db-user='${DB_USER}' --from-literal=db-password='${DB_PASS}' -n lab-shopflow --dry-run=client -o yaml | kubectl apply -f -"
                    
                    // 4. UNIFIED CONTAINER DISPATCH
                    // PURPOSE: Deploys all Frontend, Backend, and associated Service resources declared inside your k8s directory.
                    echo "=== Applying Unified Application Cluster Deployments ==="
                    sh "kubectl apply -f k8s/"
                    
                    // 5. ZERO-DOWNTIME ROLLING UPDATE GATEWAY
                    // PURPOSE: Prevents Jenkins from finishing until Kubernetes confirms the new pods passed health checks and are handling live traffic.
                    // LEARNING TIP: If the new code crashes, this step triggers a pipeline failure, letting you know the deployment failed.
                    echo "=== Verifying Zero-Downtime Rolling Update Status ==="
                    sh "kubectl rollout status deployment/backend -n lab-shopflow --timeout=150s"
                    sh "kubectl rollout status deployment/frontend -n lab-shopflow --timeout=150s"
                    
                    echo "=== Enterprise CD Deployment Process Completed Successfully ==="
                }
            }
        }
    }


    /**
     * POST EXECUTION BLOCK
     * -----------------------------------------------------------------------------
     * LEARNING TIP: This runs automatically after the main stages wrap up. It handles 
     * workspace cleanup on success, or triggers protective rollbacks on failure.
     */


        // =========================================================================
    // POST PIPELINE EXECUTIONS: CLEANUP & SELF-HEALING ENGINE
    /**
    Critical DevSecOps Architectures Added:node('master-node') Wrapper: By wrapping your scripts 
    inside a specific node assignment block inside the global post stage, Jenkins exits the clean 
    worker container image and talks directly to the server daemon host engine. This guarantees docker rmi 
    can execute smoothly without complex container nesting configurations.|| true Safety Catch: 
    If your pipeline fails early (for example, during the initial SonarQube SAST check stage), 
    the Docker images don't even exist yet. Without || true, the docker rmi step would fail, 
    masking the real security code error with an unrelated script execution failure.
    */
    // =========================================================================
    post {
        // Always executes at the tail end of the pipeline run, regardless of build status
        // PURPOSE: Frees up cached disk sector bytes on the host server node to prevent Out-Of-Space alerts
        always {
            // We tell Jenkins to explicitly handle host cleanup without being blocked by container agent limitations
            node('master-node') {
                script {
                    echo "=== Initiating System Storage Cleanup Routines ==="
                    
                    // CORRECTED: Mapped target paths to your true ECR repo variables
                    // '|| true' ensures that even if an image was never built, the cleanup command won't break the build status
                    sh "docker rmi ${REGISTRY}/shopflow-frontend:${IMAGE_TAG} || true"
                    sh "docker rmi ${REGISTRY}/shopflow-backend:${IMAGE_TAG} || true"
                    
                    // Prunes dangling untagged system images generated during the process
                    sh "docker image prune -f"
                    
                    // Erases all temporary text artifacts inside the current workspace
                    cleanWs()
                    
                    echo "=== Host Infrastructure Sanitized Successfully ==="
                }
            }
        }
        
        // Executes ONLY if a compilation layer crashes, security gates abort, or EKS timeouts occur
        // PURPOSE: Immediately triggers self-healing rollback routines to keep stable apps online [1]
        failure {
            node('master-node') {
                script {
                    echo "Pipeline failed or EKS deployment timed out! Initiating automated rollback..."
                    
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        // RE-ESTABLISH HANDSHAKE
                        echo "=== Connecting to AWS EKS Cluster to Begin Restoration ==="
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // THE SELF-HEALING MAGIC: Reverts Kubernetes configurations to the previous stable revision history index
                        echo "=== Undoing Current Deployment Attempt Versions ==="
                        sh "kubectl rollout undo deployment/backend -n lab-shopflow"
                        sh "kubectl rollout undo deployment/frontend -n lab-shopflow"
                        
                        // RESTORATION VERIFICATION GATEWAY
                        echo "=== Verifying Cluster Restoration Workload Safety ==="
                        sh "kubectl rollout status deployment/backend -n lab-shopflow --timeout=120s"
                        sh "kubectl rollout status deployment/frontend -n lab-shopflow --timeout=120s"
                        
                        echo "Automated rollback completed successfully. Your previous stable workloads are online."
                    }
                }
            }
        }
    }



