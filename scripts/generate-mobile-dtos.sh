#!/usr/bin/env bash
set -euo pipefail

# HomeChat Mobile DTO Generation Script
# Generates Kotlin and Swift data classes from the OpenAPI contract.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAILS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${RAILS_ROOT}/.." && pwd)"

API_CONTRACTS_DIR="${RAILS_ROOT}/api-contracts"
OPENAPI_FILE="${API_CONTRACTS_DIR}/openapi.yaml"

# Android output
ANDROID_OUT="${WORKSPACE_ROOT}/homechat-android/app/src/main/java/com/homechat/android/data/remote/generated"
ANDROID_PACKAGE="com.homechat.android.data.remote.generated"

# iOS output
IOS_OUT="${WORKSPACE_ROOT}/homechat-ios/HomeChatIOS/Core/Models/Generated"

# Generator image
GENERATOR_IMAGE="openapitools/openapi-generator-cli:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed."
        exit 1
    fi

    if [ ! -f "$OPENAPI_FILE" ]; then
        log_error "OpenAPI spec not found at $OPENAPI_FILE"
        log_error "Run the Rails swagger generation first or ensure the spec is in place."
        exit 1
    fi
}

# Pull the generator image if needed
ensure_generator() {
    if ! docker image inspect "$GENERATOR_IMAGE" &> /dev/null; then
        log_info "Pulling OpenAPI Generator image..."
        docker pull "$GENERATOR_IMAGE"
    fi
}

# Generate Kotlin data classes for Android
generate_android() {
    log_info "Generating Kotlin DTOs for Android..."

    mkdir -p "$ANDROID_OUT"

    # Use a temporary output directory to avoid polluting the source tree with build files
    local temp_out="${RAILS_ROOT}/tmp/android-generated"
    rm -rf "$temp_out"
    mkdir -p "$temp_out"

    docker run --rm \
        -v "${API_CONTRACTS_DIR}:/local" \
        -v "${temp_out}:/out" \
        "$GENERATOR_IMAGE" generate \
        -i /local/openapi.yaml \
        -g kotlin \
        -o /out \
        --additional-properties=packageName="${ANDROID_PACKAGE}" \
        --additional-properties=serializationLibrary=kotlinx_serialization \
        --additional-properties=dateLibrary=string \
        --additional-properties=enumPropertyNaming=UPPERCASE \
        --additional-properties=modelMutable=false \
        --global-property models,modelDocs=false \
        --skip-validate-spec

    # Copy only the model files to the target directory
    local src_models="${temp_out}/src/main/kotlin/${ANDROID_PACKAGE//.//}"
    if [ -d "$src_models" ]; then
        # The generator places files in a 'models' subpackage; flatten to target dir
        if [ -d "$src_models/models" ]; then
            cp -R "$src_models/models/"* "$ANDROID_OUT/"
            # Fix package declarations from .generated.models to .generated
            find "$ANDROID_OUT" -name "*.kt" -exec perl -pi -e "s/package ${ANDROID_PACKAGE}.models/package ${ANDROID_PACKAGE}/g" {} +
        else
            cp -R "$src_models/"* "$ANDROID_OUT/"
        fi
        log_info "Kotlin models copied to $ANDROID_OUT"
    else
        log_warn "Could not find generated Kotlin models at expected path"
    fi

    # Cleanup temp files
    rm -rf "$temp_out"
}

# Generate Swift Codable models for iOS
generate_ios() {
    log_info "Generating Swift models for iOS..."

    mkdir -p "$IOS_OUT"

    local temp_out="${RAILS_ROOT}/tmp/ios-generated"
    rm -rf "$temp_out"
    mkdir -p "$temp_out"

    docker run --rm \
        -v "${API_CONTRACTS_DIR}:/local" \
        -v "${temp_out}:/out" \
        "$GENERATOR_IMAGE" generate \
        -i /local/openapi.yaml \
        -g swift5 \
        -o /out \
        --additional-properties=responseAs=AsyncAwait \
        --additional-properties=readonlyProperties=true \
        --additional-properties=swiftUseApiNamespace=false \
        --additional-properties=nonPublicApi=false \
        --additional-properties=useJsonEncodable=false \
        --global-property models,modelDocs=false \
        --skip-validate-spec

    # Copy only the model files to the target directory
    local src_models="${temp_out}/OpenAPIClient/Classes/OpenAPIs/Models"
    if [ -d "$src_models" ]; then
        cp -R "$src_models/"* "$IOS_OUT/"
        log_info "Swift models copied to $IOS_OUT"
    else
        # swift5 generator may place files differently
        local alt_path="${temp_out}/Classes/OpenAPIs/Models"
        if [ -d "$alt_path" ]; then
            cp -R "$alt_path/"* "$IOS_OUT/"
            log_info "Swift models copied to $IOS_OUT"
        else
            log_warn "Could not find generated Swift models at expected path"
            log_warn "Checked: $src_models and $alt_path"
        fi
    fi

    # Cleanup temp files
    rm -rf "$temp_out"
}

# Optional: validate the spec
validate_spec() {
    log_info "Validating OpenAPI spec..."
    docker run --rm \
        -v "${API_CONTRACTS_DIR}:/local" \
        "$GENERATOR_IMAGE" validate \
        -i /local/openapi.yaml
}

# Print usage
usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Generate mobile DTOs from the HomeChat OpenAPI contract.

Options:
    -a, --android   Generate only Android (Kotlin) DTOs
    -i, --ios       Generate only iOS (Swift) models
    -v, --validate  Validate the OpenAPI spec before generation
    -h, --help      Show this help message

If no platform flag is provided, both Android and iOS DTOs are generated.
EOF
}

# Main
main() {
    local android_only=false
    local ios_only=false
    local validate=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--android)
                android_only=true
                shift
                ;;
            -i|--ios)
                ios_only=true
                shift
                ;;
            -v|--validate)
                validate=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    check_prerequisites
    ensure_generator

    if [ "$validate" = true ]; then
        validate_spec
    fi

    if [ "$android_only" = true ] && [ "$ios_only" = true ]; then
        log_error "Cannot specify both --android and --ios. Use no flags to generate both."
        exit 1
    fi

    if [ "$android_only" = false ] && [ "$ios_only" = false ]; then
        generate_android
        generate_ios
    elif [ "$android_only" = true ]; then
        generate_android
    else
        generate_ios
    fi

    log_info "DTO generation complete!"
}

main "$@"
