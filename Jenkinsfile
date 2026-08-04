pipeline {
    agent {
        docker {
            image 'docker:24.0-dind' // Provides nested docker build capabilities natively
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        AWS_REGION            = "us-east-1"
        EKS_CLUSTER_NAME      = "shopflow-k8s"
        IMAGE_TAG             = "build-${BUILD_NUMBER}"
        
        // Secured parameters fetched from the Jenkins Core credential store
        AWS_ID                = credentials('GLOBAL_AWS_ACCOUNT_ID')
        SONAR_TOKEN           = credentials('GLOBAL_SONAR_TOKEN')
        
        FRONTEND_REPO         = "shopflow-frontend"
        BACKEND_REPO          = "shopflow-backend"
        REGISTRY              = "${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        stage('Initialize & Clean') {
            steps {
                cleanWs deleteDirs: true, notFailBuild: true
                checkout scm
                sh 'ls -la k8s/'
            }
        }

        stage('SonarQube Quality Scan') {
            steps {
                // Executes multi-language analysis for your Python and JS architecture layers
                sh """
                    sonar-scanner \
                    -Dsonar.token=${SONAR_TOKEN} \
                    -Dsonar.host.url=https://sonarcloud.io \
                    -Dsonar.projectKey=shopflow-enterprise-app \
                    -Dsonar.projectName="Shopflow Enterprise App" \
                    -Dsonar.sources=. \
                    -Dsonar.exclusions=k8s/**,**/node_modules/**,**/dist/**
                """
            }
        }

        stage('Parallel Container Matrix') {
            parallel {
                stage('Build Frontend Web') {
                    steps {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
                            docker build -t ${REGISTRY}/${FRONTEND_REPO}:${IMAGE_TAG} .
                            docker tag ${REGISTRY}/${FRONTEND_REPO}:${IMAGE_TAG} ${REGISTRY}/${FRONTEND_REPO}:build-latest
                            docker push ${REGISTRY}/${FRONTEND_REPO}:${IMAGE_TAG}
                            docker push ${REGISTRY}/${FRONTEND_REPO}:build-latest
                        """
                    }
                }
                stage('Build Backend API') {
                    steps {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
                            docker build -t ${REGISTRY}/${BACKEND_REPO}:${IMAGE_TAG} -f backend.Dockerfile .
                            docker tag ${REGISTRY}/${BACKEND_REPO}:${IMAGE_TAG} ${REGISTRY}/${BACKEND_REPO}:build-latest
                            docker push ${REGISTRY}/${BACKEND_REPO}:${IMAGE_TAG}
                            docker push ${REGISTRY}/${BACKEND_REPO}:build-latest
                        """
                    }
                }
            }
        }

        stage('GitOps Database Migration') {
            steps {
                // Automatically installs a fixed target kubectl client tool inside the runner stage workspace
                sh """
                    curl -LO "https://k8s.io"
                    chmod +x ./kubectl
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    ./kubectl apply -f k8s/migration-job.yaml --namespace lab-shopflow
                """
            }
        }
    }
    
    post {
        failure {
            echo "[ALERT] Pipeline execution failed. Core telemetry hooks active."
        }
    }
}


