#!/usr/bin/env bash

set -e  # Exit on error

source "$PIKTUR_HOME/.dotfiles/utils.sh"

# Configuration
GITHUB_USER="piktur"
GITHUB_REPO="finance"
export AWS_PROFILE="piktur"
AWS_REGISTRY="${AWS_ECR_REGISTRY_ID:-222634378015}.dkr.ecr.${AWS_REGION:-ap-southeast-2}.amazonaws.com"

PACKAGE_NAME=codiumai/pr-agent

ENVIRONMENT_NAME=production

# Get version from package.json
VERSION=0.2.4

IMAGE_SUFFIX=$GITHUB_USER/$GITHUB_REPO/$ENVIRONMENT_NAME/$PACKAGE_NAME

# Set registry and perform login based on registry type
REGISTRY=$AWS_REGISTRY

# AWS SSO login
aws sso login --profile=production --sso-session=piktur

# Docker login
aws ecr get-login-password --region "$(aws configure get region)" | docker login $AWS_REGISTRY -u AWS --password-stdin

# Create repository if it doesn't exist
aws ecr describe-repositories --repository-names $IMAGE_SUFFIX 2>/dev/null ||
aws ecr create-repository --repository-name $IMAGE_SUFFIX 2>/dev/null

IMAGE_NAME=$REGISTRY/$IMAGE_SUFFIX

# Enable BuildKit
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

log "Building $PACKAGE_NAME v$VERSION..."

docker pull $IMAGE_NAME:serverless

docker build \
    --platform linux/amd64 \
    --progress plain \
    --cache-from $IMAGE_NAME:serverless \
    --tag $IMAGE_NAME:serverless \
    --build-arg LAMBDA_TASK_ROOT=/var/task \
    --file docker/Dockerfile.lambda \
    --push \
    .

docker push $IMAGE_NAME:serverless

# Build the image
log "Build successful!"
log "Tagged: $IMAGE_NAME:serverless"
