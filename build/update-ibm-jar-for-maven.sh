#!/usr/bin/env bash
#
# update-ibm-jar-for-maven.sh
#
# Takes an existing IBM Client JAR and an existing pom.xml,
# embeds the pom.xml + pom.properties into the JAR,
# creates the external Maven .pom file,
# generates md5/sha1 checksums,
# and lays everything out in Maven repository format:
# This is because BOOMI SYNK checks don't allow no license and IBM have
# a packaging problem where they don't include a pom.xml in their
# packaging
# Note we don't do anything to the IBM jar except include a pom.xml so that SYNK passed
# the pom.xml we include is the IBM original one located in maven and due to a packaging error on the IBM side
# they don't include it
# Therefore we are simply fixing an IBM packaging error
#
# output/<groupId-as-path>/<artifactId>/<version>/
#
# Usage:
#   ./update-ibm-jar-for-maven.sh <existing-jar> <pom-xml> <groupId> <artifactId> <version>
#
# Example:
#   ./update-ibm-jar-for-maven.sh ./existing.jar ./pom.xml com.ibm.mq com.ibm.mq.jakarta.client-lic 9.4.5.1
#

set -euo pipefail

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <existing-jar> <pom-xml> <groupId> <artifactId> <version>"
    echo "Example: $0 ./existing.jar ./pom.xml com.ibm.mq com.ibm.mq.jakarta.client-lic 9.4.5.1"
    exit 1
fi

EXISTING_JAR="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
POM_XML="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
GROUP_ID="$3"
ARTIFACT_ID="$4"
VERSION="$5"

if [ ! -f "$EXISTING_JAR" ]; then
    echo "Error: JAR file '$EXISTING_JAR' does not exist."
    exit 1
fi

if [ ! -f "$POM_XML" ]; then
    echo "Error: POM file '$POM_XML' does not exist."
    exit 1
fi

if ! command -v jar >/dev/null 2>&1; then
    echo "Error: 'jar' command not found. Please install a JDK and make sure JAVA_HOME/bin is on PATH."
    exit 1
fi

GROUP_PATH="${GROUP_ID//./\/}"

WORK_DIR="jar-work-${ARTIFACT_ID}-${VERSION}"
OUT_DIR="output/${GROUP_PATH}/${ARTIFACT_ID}/${VERSION}"

JAR_NAME="${ARTIFACT_ID}-${VERSION}.jar"
POM_NAME="${ARTIFACT_ID}-${VERSION}.pom"

MAVEN_META_DIR="META-INF/maven/${GROUP_ID}/${ARTIFACT_ID}"

echo "==> Cleaning previous work folder"
rm -rf "$WORK_DIR"

echo "==> Creating work folder"
mkdir -p "$WORK_DIR"

echo "==> Copying existing JAR to Maven-style name"
cp "$EXISTING_JAR" "${WORK_DIR}/${JAR_NAME}"

cd "$WORK_DIR"

echo "==> Checking whether JAR is signed"
SIGNED_FILES=$(jar tf "$JAR_NAME" | grep -E 'META-INF/.*\.(SF|RSA|DSA)$' || true)

if [ -n "$SIGNED_FILES" ]; then
    echo "WARNING: This JAR appears to be signed."
    echo "The following signature files were found:"
    echo "$SIGNED_FILES"
    echo ""
    echo "Updating a signed JAR usually breaks the signature."
    echo "Removing signature files from updated JAR..."

    if command -v zip >/dev/null 2>&1; then
        zip -d "$JAR_NAME" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' >/dev/null || true
        echo "Signature files removed."
    else
        echo "Error: 'zip' command not found. Cannot remove signature files."
        exit 1
    fi
else
    echo "No JAR signature files found."
fi

echo "==> Creating Maven metadata folder inside JAR structure"
mkdir -p "$MAVEN_META_DIR"

echo "==> Copying provided pom.xml into JAR metadata folder"
cp "$POM_XML" "${MAVEN_META_DIR}/pom.xml"


echo "==> Updating JAR with embedded Maven metadata"
jar uf "$JAR_NAME" "${MAVEN_META_DIR}/pom.xml"

echo "==> Verifying Maven metadata was added to JAR"
jar tf "$JAR_NAME" | grep "META-INF/maven" || {
    echo "Error: Maven metadata was not found inside the updated JAR."
    exit 1
}

cd ..

echo "==> Creating Maven repository output folder"
mkdir -p "$OUT_DIR"

echo "==> Cleaning old files from output folder"
rm -f "${OUT_DIR}/${JAR_NAME}" \
      "${OUT_DIR}/${POM_NAME}" \
      "${OUT_DIR}/${JAR_NAME}.md5" \
      "${OUT_DIR}/${JAR_NAME}.sha1" \
      "${OUT_DIR}/${POM_NAME}.md5" \
      "${OUT_DIR}/${POM_NAME}.sha1"

echo "==> Copying updated JAR to Maven repo layout"
cp "${WORK_DIR}/${JAR_NAME}" "${OUT_DIR}/${JAR_NAME}"

echo "==> Copying provided pom.xml as external Maven .pom"
cp "$POM_XML" "${OUT_DIR}/${POM_NAME}"

echo "==> Generating checksums"

if command -v md5 >/dev/null 2>&1; then
    # macOS
    md5 -q "${OUT_DIR}/${JAR_NAME}" > "${OUT_DIR}/${JAR_NAME}.md5"
    md5 -q "${OUT_DIR}/${POM_NAME}" > "${OUT_DIR}/${POM_NAME}.md5"
else
    # Linux
    md5sum "${OUT_DIR}/${JAR_NAME}" | awk '{print $1}' > "${OUT_DIR}/${JAR_NAME}.md5"
    md5sum "${OUT_DIR}/${POM_NAME}" | awk '{print $1}' > "${OUT_DIR}/${POM_NAME}.md5"
fi

if command -v shasum >/dev/null 2>&1; then
    shasum "${OUT_DIR}/${JAR_NAME}" | awk '{print $1}' > "${OUT_DIR}/${JAR_NAME}.sha1"
    shasum "${OUT_DIR}/${POM_NAME}" | awk '{print $1}' > "${OUT_DIR}/${POM_NAME}.sha1"
else
    sha1sum "${OUT_DIR}/${JAR_NAME}" | awk '{print $1}' > "${OUT_DIR}/${JAR_NAME}.sha1"
    sha1sum "${OUT_DIR}/${POM_NAME}" | awk '{print $1}' > "${OUT_DIR}/${POM_NAME}.sha1"
fi

echo ""
echo "==> Done."
echo ""
echo "Updated JAR:"
echo "  ${OUT_DIR}/${JAR_NAME}"
echo ""
echo "External POM:"
echo "  ${OUT_DIR}/${POM_NAME}"
echo ""
echo "Maven repo layout:"
echo "  ${OUT_DIR}"
echo ""

ls -la "$OUT_DIR"

echo ""
echo "To inspect the updated JAR, run:"
echo "  jar tf ${OUT_DIR}/${JAR_NAME} | grep META-INF/maven"
echo ""
echo "Next step:"
echo "  Copy output/${GROUP_PATH} into your Maven repository project,"
echo "  then commit and push."