pipeline {
  agent any
  options { timestamps() }

  environment {
    // 🔧 FILL THESE IN
    ANSIBLE_HOST_IP = '172.31.26.165'           // <-- your Ansible server private IP
    DOCKER_REPO     = 'djatl1/webapp'          // <-- your Docker Hub repo
    IMAGE_TAG       = "build-${env.BUILD_NUMBER}"

    // where on the Ansible server we’ll stage the files
    REMOTE_DROP_DIR = '/home/ubuntu/ci_drop'
  }

  stages {
    stage('Build WAR') {
      steps {
        sh '''
          set -e
          echo "📦 Building WAR with Maven..."
          mvn -B clean package -DskipTests

          WAR_PATH="$(find . -type f -path "*/target/webapp.war" | head -n1)"
          [ -n "$WAR_PATH" ] || { echo "❌ WAR not found"; exit 1; }
          echo "✅ Found WAR at $WAR_PATH"
        '''
        archiveArtifacts artifacts: 'webapp/target/webapp.war', fingerprint: true, onlyIfSuccessful: true
      }
    }

    stage('Stage WAR & Dockerfile on Ansible host') {
      steps {
        sshagent(credentials: ['ubuntu']) {   // 🔑 Jenkins credential ID for SSH key to Ansible host
          sh """
            set -e
            echo "🪄 Preparing Dockerfile locally..."
            cat > Dockerfile <<'EOF'
FROM tomcat:9.0-jdk21-temurin
COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
EOF

            echo "📤 Copying WAR & Dockerfile to Ansible host..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST_IP} "mkdir -p ${REMOTE_DROP_DIR}"

            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              ./webapp/target/webapp.war Dockerfile \
              ubuntu@${ANSIBLE_HOST_IP}:${REMOTE_DROP_DIR}/

            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST_IP} '
              set -e
              ls -lh '"${REMOTE_DROP_DIR}"'/webapp.war '"${REMOTE_DROP_DIR}"'/Dockerfile
              echo "✅ Files are staged on Ansible host."
            '
          """
        }
      }
    }

    stage('Run Ansible Playbook (build image, push, deploy)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sshagent(credentials: ['ubuntu']) {
            // We export env on the remote before calling ansible-playbook
            sh """
              set -e
              echo "🚀 Triggering Ansible playbook on Ansible host..."
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST_IP} '
                set -e
                cd ~/ansible

                # Provide variables to Ansible via extra-vars (best is Vault for secrets in real life)
                ansible-playbook -i inventory.ini deploy.yaml \\
                  -e docker_repo="${DOCKER_REPO}" \\
                  -e image_tag="${IMAGE_TAG}" \\
                  -e drop_dir="${REMOTE_DROP_DIR}" \\
                  -e dockerhub_user="${DOCKER_USER}" \\
                  -e dockerhub_pass="${DOCKER_PASS}"
              '
            """
          }
        }
      }
    }
  }

  post {
    success { echo '✅ Pipeline completed via Ansible build & deploy.' }
    failure { echo '❌ FAILURE: Pipeline stopped due to error' }
  }
}
