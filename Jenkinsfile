pipeline {
    agent { label 'master-node' }
    environment {
        AWS_ID     = "514497148354"
        AWS_REGION = "us-east-1"
        REGISTRY   = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        
        stage('Build & Push') {
            parallel {
                stage('Frontend') {
                    steps {
                        script {
                            sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                            def img = docker.build("${REGISTRY}/frontend-repo:latest", "./FRONTEND")
                            img.push()
                        }
                    }
                }
                stage('Backend') {
                    steps {
                        script {
                            sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
                            def img = docker.build("${REGISTRY}/backend-repo:latest", "./BACKEND")
                            img.push()
                        }
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh "kubectl apply -f k8s/"
            }
        }
    }
}
