pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        S3_BUCKET = 'photo-frontend-pranit'
        CLOUDFRONT_ID = 'E2BPJRH3GUIOSG'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/pranitpotsure/photo-frontend.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Build React App') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Deploy to S3') {
            steps {
                sh 'aws s3 sync build/ s3://$S3_BUCKET --delete --region $AWS_REGION'
            }
        }

        stage('Invalidate CloudFront Cache') {
            steps {
                sh 'aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"'
            }
        }
    }

    post {
        success { echo '✅ Frontend deployed successfully!' }
        failure { echo '❌ Build failed. Check Jenkins logs.' }
    }
}
