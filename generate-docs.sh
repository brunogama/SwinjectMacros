#!/bin/bash

# Generate DocC documentation for SwinjectMacros

set -e

echo "🔧 Generating Swift symbol graphs..."

# Create output directory
mkdir -p .build/docs

# Generate symbol graph for the main target
swift build --target SwinjectMacros

# Try to generate symbol graph (this may not work with macros)
echo "📚 Building documentation..."

# Convert DocC catalog to static documentation
xcrun docc convert Documentation.docc \
    --fallback-display-name "SwinjectMacros" \
    --fallback-bundle-identifier "com.brunogama.swinjectmacros" \
    --fallback-bundle-version "1.0.1" \
    --output-path .build/docs \
    --emit-digest \
    --transform-for-static-hosting \
    --hosting-base-path "/SwinjectMacros"

echo "✅ Documentation generated successfully!"
echo "📁 Documentation available at: .build/docs/documentation/swinjectmacros"
echo "🌐 Open .build/docs/index.html to view documentation"
