#!/usr/bin/env bash
# agent setup (no Jenkins, just Java + Maven + SSH)
# Updated to install Java 21 first, then Java 8, with Maven using Java 8

#!/usr/bin/env bash
set -e

# Run non-interactive everywhere
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

## 1) Update base tools
sudo -E apt-get update -y
sudo -E apt-get install -y curl wget git unzip gnupg apt-transport-https ca-certificates software-properties-common

## 2) Install Java 21 (OpenJDK) - First
sudo -E apt-get install -y openjdk-21-jdk

## 3) Install Java 8 (OpenJDK) - Second
sudo -E apt-get install -y openjdk-8-jdk

## 4) Configure Java alternatives (Java 21 as default for Jenkins agent)
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-openjdk-amd64/bin/java 2100
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java 1080
sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java

## 5) Set system JAVA_HOME to Java 21 (for Jenkins agent)
echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" | sudo tee -a /etc/profile.d/java.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/java.sh
sudo chmod +x /etc/profile.d/java.sh

## 6) Install Maven (from Ubuntu repo)
sudo -E apt-get install -y maven

## 7) Configure Maven to use Java 8 specifically
sudo tee /etc/profile.d/maven.sh >/dev/null <<'EOF'
export M2_HOME=/usr/share/maven
export MAVEN_JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export JAVA_HOME_MAVEN=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$M2_HOME/bin:$PATH
EOF
sudo chmod 644 /etc/profile.d/maven.sh

## 8) Create Maven wrapper script that forces Java 8
sudo tee /usr/local/bin/mvn-java8 >/dev/null <<'EOF'
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
exec /usr/bin/mvn "$@"
EOF
sudo chmod +x /usr/local/bin/mvn-java8

## 9) Override system mvn to use Java 8
sudo tee /etc/profile.d/maven-java8.sh >/dev/null <<'EOF'
# Force Maven to use Java 8
alias mvn='JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 /usr/bin/mvn'
export MAVEN_OPTS="-Djava.home=/usr/lib/jvm/java-8-openjdk-amd64"
EOF
sudo chmod 644 /etc/profile.d/maven-java8.sh

## 10) Show versions for verification
source /etc/profile.d/java.sh
source /etc/profile.d/maven.sh
source /etc/profile.d/maven-java8.sh

echo "=== System Java Version (for Jenkins Agent) ==="
java -version

echo "=== Available Java Versions ==="
sudo update-alternatives --display java

echo "=== Maven Version (should use Java 8) ==="
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 mvn -v

## 11) Create your workspace directory
sudo mkdir -p /tmp/jenkinsdir
sudo chmod -R 777 /tmp/jenkinsdir
cd /tmp

echo "=== Setup Complete ==="
echo "Java 21: /usr/lib/jvm/java-21-openjdk-amd64 (default for Jenkins agent)"
echo "Java 8: /usr/lib/jvm/java-8-openjdk-amd64 (for Maven builds)"
echo "Maven configured to use Java 8"