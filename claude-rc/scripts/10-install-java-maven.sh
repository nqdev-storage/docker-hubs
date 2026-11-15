#!/usr/bin/env bash
# Cài JDK (Eclipse Temurin) + Apache Maven vào thư mục của user, không cần root.
# Dùng:  10-install-java-maven.sh [all|java|maven]        (mặc định: all)
# Biến:  JAVA_VERSION=17  MAVEN_VERSION=3.9.6  INSTALL_ROOT=/home/node/.local/opt
# Kết quả: $INSTALL_ROOT/java  và  $INSTALL_ROOT/maven  (khớp JAVA_HOME / MAVEN_HOME / PATH trong image)
set -euo pipefail

JAVA_VERSION="${JAVA_VERSION:-17}"
MAVEN_VERSION="${MAVEN_VERSION:-3.9.6}"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.local/opt}"
TARGET="${1:-all}"

log() { echo "[10-install-java-maven] $*"; }

case "$(uname -m)" in
  x86_64 | amd64) ADOPTIUM_ARCH="x64" ;;
  aarch64 | arm64) ADOPTIUM_ARCH="aarch64" ;;
  *) log "Kiến trúc không hỗ trợ: $(uname -m)" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$INSTALL_ROOT"

install_java() {
  if [ -x "$INSTALL_ROOT/java/bin/java" ] && "$INSTALL_ROOT/java/bin/java" -version 2>&1 | grep -q "\"${JAVA_VERSION}\."; then
    log "Java ${JAVA_VERSION} đã có sẵn tại $INSTALL_ROOT/java, bỏ qua"
    return
  fi
  log "Tải Temurin JDK ${JAVA_VERSION} (${ADOPTIUM_ARCH})..."
  local url="https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/${ADOPTIUM_ARCH}/jdk/hotspot/normal/eclipse"
  curl -fsSL --retry 3 -o "$TMP_DIR/jdk.tar.gz" "$url"
  mkdir -p "$TMP_DIR/jdk"
  tar -xzf "$TMP_DIR/jdk.tar.gz" -C "$TMP_DIR/jdk" --strip-components=1
  rm -rf "$INSTALL_ROOT/java"
  mv "$TMP_DIR/jdk" "$INSTALL_ROOT/java"
  log "Đã cài Java vào $INSTALL_ROOT/java"
}

install_maven() {
  if [ -x "$INSTALL_ROOT/maven/bin/mvn" ] && [ -f "$INSTALL_ROOT/maven/lib/maven-core-${MAVEN_VERSION}.jar" ]; then
    log "Maven ${MAVEN_VERSION} đã có sẵn tại $INSTALL_ROOT/maven, bỏ qua"
    return
  fi
  log "Tải Maven ${MAVEN_VERSION}..."
  local base="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  curl -fsSL --retry 3 -o "$TMP_DIR/maven.tar.gz" "$base"
  # Kiểm tra checksum SHA-512 do Apache công bố
  local expected actual
  expected="$(curl -fsSL --retry 3 "${base}.sha512" | awk '{print $1}')"
  actual="$(sha512sum "$TMP_DIR/maven.tar.gz" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    log "Sai checksum SHA-512 của Maven (mong đợi $expected, thực tế $actual)" >&2
    exit 1
  fi
  mkdir -p "$TMP_DIR/maven"
  tar -xzf "$TMP_DIR/maven.tar.gz" -C "$TMP_DIR/maven" --strip-components=1
  rm -rf "$INSTALL_ROOT/maven"
  mv "$TMP_DIR/maven" "$INSTALL_ROOT/maven"
  log "Đã cài Maven vào $INSTALL_ROOT/maven"
}

case "$TARGET" in
  all) install_java; install_maven ;;
  java) install_java ;;
  maven) install_maven ;;
  *) log "Tham số không hợp lệ: $TARGET (dùng: all | java | maven)" >&2; exit 1 ;;
esac

# Chạy bằng đường dẫn đầy đủ để kiểm tra, không phụ thuộc PATH của shell hiện tại
[ -x "$INSTALL_ROOT/java/bin/java" ] && "$INSTALL_ROOT/java/bin/java" -version
[ -x "$INSTALL_ROOT/maven/bin/mvn" ] && JAVA_HOME="$INSTALL_ROOT/java" "$INSTALL_ROOT/maven/bin/mvn" -v
log "Xong. Nếu shell đang mở chưa nhận lệnh, chạy: hash -r"
