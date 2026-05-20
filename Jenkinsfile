#Enterprise DevSecOps PipelineThis fully integrated Jenkinsfile handles security scans, 
#quality validations, vulnerability checks, and sequential schema upgrades:
pipeline {
    // -----------------------------------------------------------------------------
    // AGENT CONFIGURATION
    // -----------------------------------------------------------------------------
    // WHAT IT DOES: Tells Jenkins where to execute the commands written in this file.
    // LEARNING TIP: Label 'master-node' restricts execution to your specific VMware 
    // Linux VM Master environment where you installed your CLI tools (aws, trivy, kubectl).
    agent { label 'master-node' }
    
    // -----------------------------------------------------------------------------
    // GLOBAL ENVIRONMENT VARIABLES
    // -----------------------------------------------------------------------------
    // WHAT IT DOES: Defines key configuration settings used across multiple stages.
    // LEARNING TIP: Centralizing values here means if your AWS account ID or region 
    // changes, you only have to update it in one single spot.
    environment {
        AWS_ID           = "514497148354"
        AWS_REGION       = "us-east-1"
        EKS_CLUSTER_NAME = "shopflow-k8s"
        
        // Target AWS Elastic Container Registry (ECR) path
        REGISTRY         = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        
        // Generates an immutable, traceable tag for this specific build (e.g., build-42).
        // This ensures every deployment is perfectly auditable back to this exact Jenkins run.
        IMAGE_TAG        = "build-${BUILD_NUMBER}"
        
        // CRITICAL FOR ROCKY/RHEL VM: Appends /usr/local/bin to the execution path.
        // This forces Jenkins to find 'aws', 'trivy v0.70.0', and 'kubectl' without path errors.
        PATH             = "/usr/local/bin:${env.PATH}"
        
        // The URL where your standalone SonarQube Server dashboard is hosted
        SONAR_SERVER_URL = "http://your-sonarqube-server:9000"
    }

    stages {
        /**
         * STAGE 1: INITIALIZE & CHECKOUT
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Wipes out the workspace directory and pulls the latest source code.
         * CONNECTIONS: Connects to your Git Source Control Management (SCM) system (GitHub/GitLab).
         * LEARNING TIP: `cleanWs()` cleans the workspace first. This prevents old, cached 
         * compilation files from previous builds from accidentally breaking your new build.
         */
        stage('Initialize & Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        /**
         * STAGE 2: SONARQUBE SECURITY SCAN
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs a Static Application Security Testing (SAST) vulnerability scan.
         * CONNECTIONS: Uses the 'sonar-token' credential to authenticate and send source 
         * code metrics from FRONTEND and BACKEND directories over to the SonarQube Server.
         * LEARNING TIP: This checks your code files for hardcoded secrets, security bugs, 
         * and bad practices *before* spending time compiling a Docker image.
         */
        stage('SonarQube Security Scan') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        withSonarQubeEnv(installationName: 'SonarQube') {
                            sh """
                                sonar-scanner \
                                -Dsonar.host.url=${SONAR_SERVER_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.projectKey=shopflow-enterprise-app \
                                -Dsonar.projectName="Shopflow Enterprise App" \
                                -Dsonar.sources=FRONTEND,BACKEND \
                                -Dsonar.exclusions=**/node_modules/**,**/dist/** \
                                -Dsonar.python.version=3
                            """
                        }
                    }
                }
            }
        }

        /**
         * STAGE 3: SONARQUBE QUALITY GATE (WEBHOOK)
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Pauses the pipeline and waits for a "PASS" or "FAIL" status from SonarQube.
         * CONNECTIONS: Listens for the free Webhook callback sent back from your SonarQube server.
         * LEARNING TIP: If the Quality Gate fails (e.g., your code introduces new vulnerabilities), 
         * `abortPipeline: true` will instantly stop the build here, blocking insecure apps from moving forward.
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
         * WHAT IT DOES: Compiles the source code into isolated Docker container images on your host.
         * CONNECTIONS: Reads the respective enterprise Dockerfiles under 'FRONTEND/' and 'BACKEND/'.
         * LEARNING TIP: We embed the unique `IMAGE_TAG` right into the local container name, 
         * making it simple to map the local docker registry cache directly to our specific pipeline run.
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
         * STAGE 5: TRIVY VULNERABILITY SCAN
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs a deep image security scan over your freshly compiled local Docker images.
         * CONNECTIONS: Leverages the local 'trivy v0.70.0' binary you manually installed via wget.
         * LEARNING TIP: We use `--exit-code 1` on the backend container. If Trivy finds 
         * any HIGH or CRITICAL operating system or library vulnerabilities, it returns a 
         * failure exit status, forcing Jenkins to crash the build before pushing any bad code to AWS.
         */
        stage('Trivy Vulnerability Scan') {
            steps {
                script {
                    echo "Scanning Frontend Container..."
                    sh "trivy image --exit-code 0 --severity UNKNOWN,LOW,MEDIUM ${REGISTRY}/frontend-repo:${IMAGE_TAG}"
                    
                    echo "Scanning Backend Container for High/Critical Vulnerabilities..."
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${REGISTRY}/backend-repo:${IMAGE_TAG}"
                }
            }
        }

        /**
         * STAGE 6: PUSH TO AWS ECR
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Authenticates Jenkins with AWS and uploads your secure Docker images.
         * CONNECTIONS: Explicitly links your VMware on-premise Master VM to your AWS ECR Registry in the cloud.
         * LEARNING TIP: `aws ecr get-login-password` securely retrieves a temporary access token 
         * that lets the docker client log in without putting hardcoded secrets in scripts. We push 
         * both the unique traceable tag and a 'latest' tag for deployment flexibility.
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
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                        frontendImg.push()
                        frontendImg.push('latest')
                        backendImg.push()
                        backendImg.push('latest')
                    }
                }
            }
        }
        
        /**
         * STAGE 7: DATABASE MIGRATION
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Runs an isolated, short-lived Kubernetes Job to update database tables.
         * CONNECTIONS: Authenticates with AWS EKS and triggers the target schema migration script.
         * LEARNING TIP: Running migrations as a Kubernetes Job *before* upgrading your application 
         * deployments ensures new database tables are fully ready. If the database script fails, 
         * the pipeline aborts right here, protecting your live production cluster from breaking.
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
                        // Dynamically update the local ~/.kube/config file to authenticate with AWS EKS
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // Inject our unique immutable build tag into the migration job template
                        sh "sed -i 's|TARGET_BACKEND_IMAGE|${REGISTRY}/backend-repo:${IMAGE_TAG}|g' k8s/migration-job.yaml"
                        
                        // Apply the migration job manifest and block the pipeline until it finishes successfully
                        sh "kubectl apply -f k8s/migration-job.yaml"
                        echo "Awaiting migration completion..."
                        sh "kubectl wait --for=condition=complete job/shopflow-db-migration-${BUILD_NUMBER} -n lab-shopflow --timeout=120s"
                    }
                }
            }
        }

        /**
         * STAGE 8: DEPLOY & ROLLOUT VERIFICATION
         * -------------------------------------------------------------------------
         * WHAT IT DOES: Replaces placeholder values, applies configurations, and tracks the live rollout.
         * CONNECTIONS: Instructs your AWS EKS cluster plane to execute a zero-downtime rolling update.
         * LEARNING TIP: `kubectl rollout status` acts as our ultimate safety guard. If your new 
         * pods crash, fail their network health probes, or trigger an OOMKilled state within 150 seconds, 
         * this command throws an error, failing the stage and sending Jenkins straight to the failure rescue block.
         */
        stage('Deploy & Rollout Verification') {
            steps {
                script {
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        // Safely substitute the target image placeholders inside your separated deployment manifests
                        sh "sed -i 's|TARGET_BACKEND_IMAGE|${REGISTRY}/backend-repo:${IMAGE_TAG}|g' k8s/backend.yaml"
                        sh "sed -i 's|TARGET_FRONTEND_IMAGE|${REGISTRY}/frontend-repo:${IMAGE_TAG}|g' k8s/frontend.yaml"
                        
                        // Sequence applies namespace, network isolation policies, deployments, services, and anti-flapping HPAs
                        sh "kubectl apply -f k8s/namespace.yaml"
                        sh "kubectl apply -f k8s/"
                        
                        echo "Verifying zero-downtime rolling update status..."
                        sh "kubectl rollout status deployment/backend -n lab-shopflow --timeout=150s"
                        sh "kubectl rollout status deployment/frontend -n lab-shopflow --timeout=150s"
                    }
                }
            }
        }
    }

    // -----------------------------------------------------------------------------
    // POST EXECUTION BLOCK
    // -----------------------------------------------------------------------------
    // WHAT IT DOES: Automatically captures build outcomes to clean up assets or rescue files.
    post {
        // ALWAYS block: Cleans the execution server to maintain server storage space
        always {
            script {
                echo "Executing system cleanup routines..."
                // Removes locally compiled Docker tags so your VMware Master disk doesn't fill up
                sh "docker rmi ${REGISTRY}/frontend-repo:${IMAGE_TAG} || true"
                sh "docker rmi ${REGISTRY}/backend-repo:${IMAGE_TAG} || true"
                sh "docker image prune -f"
                cleanWs()
            }
        }
        
        // FAILURE block: The Automated Rollback Mechanism (Your Production Safety Net)
        // WHAT IT DOES: If any stage fails or the EKS rollout times out, it instantly restores the cluster.
        // LEARNING TIP: Running `kubectl rollout undo` tells EKS to stop running the broken containers, 
        // pull down the previous working image version, and restore network traffic back to normal immediately.
        failure {
            script {
                echo "🚨 Pipeline stage failed or EKS deployment timed out! Initiating automated rollback..."
                withCredentials([[
                    $class: 'UsernamePasswordMultiBinding', 
                    credentialsId: 'aws-eks-creds', 
                    usernameVariable: 'AWS_ACCESS_KEY_ID', 
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                    
                    echo "Undoing current rollout versions..."
                    sh "kubectl rollout undo deployment/backend -n lab-shopflow"
                    sh "kubectl rollout undo deployment/frontend -n lab-shopflow"
                    
                    echo "Verifying cluster restoration safety..."
                    sh "kubectl rollout status deployment/backend -n lab-shopflow --timeout=120s"
                    sh "kubectl rollout status deployment/frontend -n lab-shopflow --timeout=120s"
                    echo "🔒 Automated rollback completed successfully. Your previous stable workloads are online."
                }
            }
        }
    }
}



