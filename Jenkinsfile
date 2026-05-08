pipeline {
    agent { label 'master-node' }
    environment {
        AWS_ID     = "514497148354"
        AWS_REGION = "us-east-1"
        REGISTRY   = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
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
                    // Login once before starting parallel builds to save time
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                    
                    parallel(
                        "Frontend": {
                            script {
                                def frontendImg = docker.build("${REGISTRY}/frontend-repo:latest", "./FRONTEND")
                                frontendImg.push()
                            }
                        },
                        "Backend": {
                            script {
                                def backendImg = docker.build("${REGISTRY}/backend-repo:latest", "./BACKEND")
                                backendImg.push()
                            }
                        }
                    )
                }
            }
        }
        
        stage('Deploy') {
            steps {
                // Deploys your combined manifest with DB secrets
                sh "kubectl apply -f k8s/"
            }
        }
    }

    post {
        always {
            script {
                echo "Cleaning up workspace and Docker layers..."
                // Removes unused images and build cache to save disk space
                sh "docker image prune -f"
                cleanWs()
            }
        }
        success {
            echo "Pipeline completed successfully! Frontend is live on the LoadBalancer."
        }
        failure {
            echo "Pipeline failed. Check the logs above for Docker or Kubectl errors."
        }
    }
}
