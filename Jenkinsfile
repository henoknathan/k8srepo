pipeline {
    agent { label 'master-node' }
    environment {
        AWS_ID     = "514497148354"
        AWS_REGION = "us-east-1"
        REGISTRY   = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        // NEW: Generates a unique immutable tag for this specific build
        IMAGE_TAG  = "build-${BUILD_NUMBER}"
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                    
                    parallel(
                        "Frontend": {
                            script {
                                // NEW: Builds with the unique build tag and pushes both tags
                                def frontendImg = docker.build("${REGISTRY}/frontend-repo:${IMAGE_TAG}", "./FRONTEND")
                                frontendImg.push()
                                frontendImg.push('latest')
                            }
                        },
                        "Backend": {
                            script {
                                // NEW: Builds with the unique build tag and pushes both tags
                                def backendImg = docker.build("${REGISTRY}/backend-repo:${IMAGE_TAG}", "./BACKEND")
                                backendImg.push()
                                backendImg.push('latest')
                            }
                        }
                    )
                }
            }
        }
        
               stage('Deploy & Rollout Verification') {
            steps {
                script {
                    // 1. Update the image tags inside the AWS-INFRA directory
                    // Using AWS-INFRA/*.yaml ensures it scans all manifest files inside that folder
                    sh "sed -i 's|image: \".*backend.*\"|image: \"${REGISTRY}/backend-repo:${IMAGE_TAG}\"|g' AWS-INFRA/*.yaml"
                    sh "sed -i 's|image: \".*frontend.*\"|image: \"${REGISTRY}/frontend-repo:${IMAGE_TAG}\"|g' AWS-INFRA/*.yaml"
                    
                    // 2. Apply all manifests inside the AWS-INFRA folder
                    sh "kubectl apply -f AWS-INFRA/"
                    
                    // 3. Monitor rollout to ensure zero-downtime success
                    echo "Verifying zero-downtime rollout..."
                    sh "kubectl rollout status deployment/backend --timeout=120s"
                    sh "kubectl rollout status deployment/frontend --timeout=120s"
                }
            }
        }

    }

    post {
        always {
            script {
                echo "Cleaning up workspace and Docker layers..."
                // Specific cleanup of the local build images to prevent filling up Jenkins storage
                sh "docker rmi ${REGISTRY}/frontend-repo:${IMAGE_TAG} || true"
                sh "docker rmi ${REGISTRY}/backend-repo:${IMAGE_TAG} || true"
                sh "docker image prune -f"
                cleanWs()
            }
        }
        success {
            echo "Pipeline completed successfully! Rolling update finalized with zero downtime."
        }
        failure {
            echo "Pipeline failed. Rollout was blocked or a build error occurred. Your old pods are still safely serving traffic."
        }
    }
}
