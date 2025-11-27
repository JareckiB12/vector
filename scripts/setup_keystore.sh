#!/bin/bash
# setup_keystore.sh
#
# This script configures the OpenSearch keystore with S3 credentials required for the repository-s3 plugin.
# It assumes the default 'minioadmin' credentials for the local Minio instance.
#
# Usage: ./scripts/setup_keystore.sh

echo "Configuring OpenSearch Keystore..."

# Install S3 Plugin
echo "Installing repository-s3 plugin..."
docker exec opensearch /usr/share/opensearch/bin/opensearch-plugin install --batch repository-s3
# We need to restart to load the plugin? No, we can add keystore settings first?
# Actually, the error was "unknown secure setting". This implies the plugin MUST be loaded (or at least installed) for the setting to be valid?
# Or maybe just installed is enough?
# If we install, we usually need restart.
# But we can add keystore settings even if plugin is not loaded?
# The error "unknown secure setting" suggests the Keystore validation checks available plugins.
# So we install plugin -> restart -> add keys -> restart?
# Or install plugin -> add keys -> restart?
# Let's try install -> add keys -> restart.
# If "add keys" fails because plugin not loaded, we need intermediate restart.
# But usually keystore is just a file.
# The validation happens when reading the keystore (at startup).
# The `opensearch-keystore add` command might check?
# Let's assume install is enough.

# Add Access Key
echo "Adding s3.client.default.access_key..."
echo "minioadmin" | docker exec -i opensearch /usr/share/opensearch/bin/opensearch-keystore add --stdin --force s3.client.default.access_key

# Add Secret Key
echo "Adding s3.client.default.secret_key..."
echo "minioadmin" | docker exec -i opensearch /usr/share/opensearch/bin/opensearch-keystore add --stdin --force s3.client.default.secret_key

echo "Keystore updated. Restarting OpenSearch container to apply changes..."
docker restart opensearch

echo "Waiting for OpenSearch to be ready..."
until curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"\|"status":"yellow"'; do
  echo "Waiting for OpenSearch..."
  sleep 5
done

echo "OpenSearch is ready and Keystore is configured."
