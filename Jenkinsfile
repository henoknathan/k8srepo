pipeline {
    agent { label 'master-node' }
    environment {
        AWS_ID           = "514497148354"
        AWS_REGION       = "us-east-1"
        EKS_CLUSTER_NAME = "shopflow-k8s"
        REGISTRY         = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG        = "build-${BUILD_NUMBER}"
        PATH             = "/usr/local/bin:${env.PATH}"
        // SonarQube Global Configurations
        SONAR_SERVER_URL = "http://your-sonarqube-server:9000"
    }
    stages {
        stage('Initialize & Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('SonarQube Security Scan') {
            steps {
                script {
                    // Requires the SonarQube Scanner plugin installed in Jenkins
                    // 'sonar-token' matches the Secret Text ID saved in your Jenkins credentials store
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        withSonarQubeEnv(installationName: 'SonarQube') {
                            // Scans both FRONTEND and BACKEND simultaneously
                            sh """
                                sonar-scanner \
                                -Dsonar.host.url=${SONAR_SERVER_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.projectKey=shopflow-enterprise-app \
                                -Dsonar.projectName="Shopflow Enterprise App" \
                                -Dsonar.sources=FRONTEND,BACKEND \
                                -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/*.spec.js \
                                -Dsonar.python.version=3 \
                                -Dsonar.javascript.node.maxSpace=4096
                            """
                        }
                    }
                    // Optional: Pauses pipeline until SonarQube Webhook calculates passing results
                    // timeout(time: 5, unit: 'MINUTES') {
                    //     waitForQualityGate abortPipeline: true
                    // }
                }
            }
        }

        stage('Build & Push Images') {
            steps {
                script {
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                        
                        parallel(
                            "Frontend Container": {
                                def frontendImg = docker.build("${REGISTRY}/frontend-repo:${IMAGE_TAG}", "-f FRONTEND/Dockerfile .")
                                frontendImg.push()
                                frontendImg.push('latest')
                            },
                            "Backend Container": {
                                def backendImg = docker.build("${REGISTRY}/backend-repo:${IMAGE_TAG}", "-f BACKEND/Dockerfile .")
                                backendImg.push()
                                backendImg.push('latest')
                            }
                        )
                    }
                }
            }
        }
        
        stage('Deploy & Rollout Verification') {
            steps {
                script {
                    withCredentials([[
                        $class: 'UsernamePasswordMultiBinding', 
                        credentialsId: 'aws-eks-creds', 
                        usernameVariable: 'AWS_ACCESS_KEY_ID', 
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // Substitute tag values into the manifests
                        sh "sed -i 's|TARGET_BACKEND_IMAGE|${REGISTRY}/backend-repo:${IMAGE_TAG}|g' k8s/backend.yaml"
                        sh "sed -i 's|TARGET_FRONTEND_IMAGE|${REGISTRY}/frontend-repo:${IMAGE_TAG}|g' k8s/frontend.yaml"
                        
                        // Apply all k8s files including the namespace and network policies
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

    post {
        always {
            script {
                echo "Executing system cleanup routines..."
                sh "docker rmi ${REGISTRY}/frontend-repo:${IMAGE_TAG} || true"
                sh "docker rmi ${REGISTRY}/backend-repo:${IMAGE_TAG} || true"
                sh "docker image prune -f"
                cleanWs()
            }
        }
    }
}
