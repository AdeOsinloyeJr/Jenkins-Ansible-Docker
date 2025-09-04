pipeline {
  agent any
  options { timestamps() }

  environment {
    // Where Ansible runs the build + push + deploy
    ANSIBLE_HOST = '172.31.26.165'             // <<< update
    ANSIBLE_DIR  = '/home/ubuntu/ansible'            // path on Ansible server for playbooks
    BUILD_DIR    = "/home/ubuntu/ansible/builds/build-${env.BUILD_NUMBER}"

    // Docker Hub
    DOCKER_REPO = 'djatl1/webapp2'                    // <<< update if different
    IMAGE_TAG   = "build-${env.BUILD_NUMBER}"
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

    stage('Ship artifact + Dockerfile to Ansible') {
      steps {
        sshagent(credentials: ['ubuntu']) { // <<< Jenkins SSH cred id to reach Ansible
          sh '''
            set -e
            WAR_LOCAL="webapp/target/webapp.war"
            [ -f "$WAR_LOCAL" ] || { echo "WAR missing"; exit 1; }

            echo "📤 Creating remote build dir on Ansible server..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST} "mkdir -p ${BUILD_DIR}"

            echo "📤 Copying WAR to Ansible server..."
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$WAR_LOCAL" "ubuntu@${ANSIBLE_HOST}:${BUILD_DIR}/webapp.war"

            echo "📝 Writing Dockerfile on Ansible server..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST} "bash -lc 'cat > ${BUILD_DIR}/Dockerfile <<EOF
FROM tomcat:9.0-jdk21-temurin
COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
EOF
'"
          '''
        }
      }
    }

    stage('Build, Push, and Deploy via Ansible') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',         // <<< your DockerHub cred id
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sshagent(credentials: ['ubuntu']) {
            sh '''
              set -e
              # Run Ansible playbook on the Ansible server, passing image + tag + build dir
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${ANSIBLE_HOST} \
                "export ANSIBLE_STDOUT_CALLBACK=yaml DOCKER_USER='${DOCKER_USER}' DOCKER_PASS='${DOCKER_PASS}'; \
                 ansible-playbook ${ANSIBLE_DIR}/deploy.yml \
                   -e docker_repo='${DOCKER_REPO}' \
                   -e docker_tag='${IMAGE_TAG}' \
                   -e build_dir='${BUILD_DIR}'"
            '''
          }
        }
      }
    }
  }

  post {
    failure { echo '❌ FAILURE: Pipeline stopped due to error' }
  }
}
