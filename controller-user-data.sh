#!/bin/bash
set -e

# === Ensure script is run as root ===
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "🧱 Installing base packages..."
apt-get update -y
apt-get install -y curl wget gnupg ca-certificates apt-transport-https git tar software-properties-common

# === Install Java 21 for Jenkins ===
echo "☕ Installing Java 21..."
apt-get install -y openjdk-21-jdk

# === Install Java 8 for Maven ===
echo "☕ Installing Java 8..."
apt-get install -y openjdk-8-jdk

# === Ensure Java 21 is the default system-wide for Jenkins ===
JAVA21_BIN="/usr/lib/jvm/java-1.21.0-openjdk-amd64/bin/java"
if [[ -x "$JAVA21_BIN" ]]; then
  echo "🔧 Setting Java 21 as system default..."
  update-alternatives --install /usr/bin/java java "$JAVA21_BIN" 1100
  update-alternatives --set java "$JAVA21_BIN"
else
  echo "❌ Java 21 binary not found at $JAVA21_BIN"
  exit 1
fi

# === Install Maven ===
echo "📦 Installing Maven..."
apt-get install -y maven

# === Set Maven to use Java 8 (for login shells) ===
echo "🛠️ Configuring Maven to use Java 8..."
tee /etc/profile.d/maven.sh >/dev/null <<'EOF'
export M2_HOME=/usr/share/maven
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$M2_HOME/bin:$JAVA_HOME/bin:$PATH
EOF

chmod 644 /etc/profile.d/maven.sh

# === Add Jenkins APT Repo ===
echo "🔐 Adding Jenkins repository and key..."
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  -o /usr/share/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

# === Install Jenkins ===
echo "🚀 Installing Jenkins..."
apt-get update -y
apt-get install -y jenkins

# === Force Jenkins to use Java 21 explicitly ===
echo "📌 Setting Java 21 in Jenkins default config..."
if grep -q '^JAVA=' /etc/default/jenkins; then
  sed -i 's|^JAVA=.*|JAVA=/usr/lib/jvm/java-1.21.0-openjdk-amd64/bin/java|' /etc/default/jenkins
else
  echo 'JAVA=/usr/lib/jvm/java-1.21.0-openjdk-amd64/bin/java' >> /etc/default/jenkins
fi

# === Enable and start Jenkins ===
echo "🟢 Enabling Jenkins to start on boot..."
systemctl enable jenkins
systemctl restart jenkins

# === Output Jenkins Initial Password ===
echo "🔑 Jenkins Initial Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword || echo "⚠️ Jenkins not fully started yet."

echo "✅ Setup complete. Jenkins should be running on http://<instance-ip>:8080"
