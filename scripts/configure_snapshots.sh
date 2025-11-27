#!/bin/bash
# configure_snapshots.sh
#
# This script configures:
# 1. S3 Snapshot Repository (pointing to Minio)
# 2. ISM Policy 'hot_to_warm_1d' (moves indices to searchable snapshot after 1 day)
# 3. Index Template to apply this policy to 'logs-*' indices
#
# Usage: ./scripts/configure_snapshots.sh

OPENSEARCH_URL="http://localhost:9200"

echo "1. Registering S3 Snapshot Repository..."
curl -X PUT "$OPENSEARCH_URL/_snapshot/s3-repo?pretty" -H 'Content-Type: application/json' -d'
{
  "type": "s3",
  "settings": {
    "bucket": "snapshots",
    "endpoint": "http://minio:9000",
    "protocol": "http",
    "path_style_access": "true",
    "region": "us-east-1"
  }
}
'

echo -e "\n\n2. Creating ISM Policy 'hot_to_warm_1d'..."
# Delete existing policy to avoid version conflicts during development
curl -X DELETE "$OPENSEARCH_URL/_plugins/_ism/policies/hot_to_warm_1d?pretty"

curl -X PUT "$OPENSEARCH_URL/_plugins/_ism/policies/hot_to_warm_1d?pretty" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "description": "Move to searchable snapshot after 1 day",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "warm_snapshot",
            "conditions": {
              "min_index_age": "1d"
            }
          }
        ]
      },
      {
        "name": "warm_snapshot",
        "actions": [
          {
            "snapshot": {
              "repository": "s3-repo",
              "snapshot": "snapshot-{{ctx.index}}-{{ctx.creation_date}}"
            }
          },
          {
            "delete": {}
          }
        ],
        "transitions": []
      }
    ]
  }
}
'

echo -e "\n\n3. Creating/Updating Index Template for 'logs-*'..."
# Note: We append to existing settings or create new.
# This template ensures new indices get the policy.
curl -X PUT "$OPENSEARCH_URL/_index_template/logs_template?pretty" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "plugins.index_state_management.policy_id": "hot_to_warm_1d"
    }
  }
}
'

echo -e "\n\nConfiguration complete."
