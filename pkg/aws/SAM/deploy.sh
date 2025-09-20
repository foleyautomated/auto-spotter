#!/bin/bash

# AutoSpotter Web Client Deployment Script
set -e

# Default values
ENVIRONMENT="dev"
REGION="us-east-1"
DOMAIN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -d|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -e, --environment ENV    Environment to deploy to (dev, staging, prod)"
      echo "  -r, --region REGION      AWS region (default: us-east-1)"
      echo "  -d, --domain DOMAIN      Custom domain name (optional)"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "🚀 Deploying AutoSpotter Web Client to $ENVIRONMENT environment..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ AWS SAM CLI is not installed. Please install it first."
    echo "   https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

# Set stack name based on environment
if [ "$ENVIRONMENT" = "dev" ]; then
    STACK_NAME="autospotter-web"
else
    STACK_NAME="autospotter-web-$ENVIRONMENT"
fi

echo "📦 Building SAM application..."
sam build

# Prepare parameters
PARAMS="Environment=$ENVIRONMENT"
if [ ! -z "$DOMAIN" ]; then
    PARAMS="$PARAMS DomainName=$DOMAIN"
fi

echo "🔧 Deploying infrastructure..."
if [ "$ENVIRONMENT" = "dev" ]; then
    sam deploy --config-env default --parameter-overrides "$PARAMS"
else
    sam deploy --config-env $ENVIRONMENT --parameter-overrides "$PARAMS"
fi

# Check if web client build exists
WEB_DIR="../web/dist"
if [ ! -d "$WEB_DIR" ]; then
    echo "⚠️  Web client build not found. Building web client..."
    cd ../web
    if [ -f "package.json" ]; then
        npm install
        npm run build
    else
        echo "❌ No package.json found in web directory. Please build the web client first."
        exit 1
    fi
    cd ../SAM
fi

# Get stack outputs
echo "📤 Uploading web assets..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebClientBucketName`].OutputValue' \
    --output text)

if [ "$BUCKET_NAME" = "None" ] || [ -z "$BUCKET_NAME" ]; then
    echo "❌ Could not retrieve S3 bucket name from stack outputs."
    exit 1
fi

echo "   Uploading to bucket: $BUCKET_NAME"
aws s3 sync ../web/dist/ s3://$BUCKET_NAME/ --delete --region $REGION

echo "🔄 Invalidating CloudFront cache..."
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

if [ "$DISTRIBUTION_ID" != "None" ] && [ ! -z "$DISTRIBUTION_ID" ]; then
    aws cloudfront create-invalidation \
        --distribution-id $DISTRIBUTION_ID \
        --paths "/*" \
        --region $REGION > /dev/null
    echo "   CloudFront invalidation created"
else
    echo "⚠️  Could not retrieve CloudFront distribution ID"
fi

# Get website URL
WEBSITE_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteUrl`].OutputValue' \
    --output text)

echo ""
echo "✅ Deployment completed successfully!"
echo "🌐 Website URL: $WEBSITE_URL"
echo "🪣 S3 Bucket: $BUCKET_NAME"
if [ "$DISTRIBUTION_ID" != "None" ] && [ ! -z "$DISTRIBUTION_ID" ]; then
    echo "☁️  CloudFront Distribution: $DISTRIBUTION_ID"
fi
echo ""