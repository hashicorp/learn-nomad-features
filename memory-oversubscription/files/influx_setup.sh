#!/bin/bash

# This does almost all of the heavy lifting since the initial org, bucket, and
# user are built using environment variables passed to the container. This step
# does happen as the container comes up, so it delays the creation of
# `influx.env` long enough where you have to gate for it in the 
# `influx_poststart.sh` script. 
echo "Applying template"
influx apply -f /alloc/influx.yaml --force=true

# This file has to be built to pass off the materials necessary for the post-
# start curl container to be able to make the API call to create the scraper.
#   Since the org_id and bucket_id are both dynamically generated during setup
# they too have to be passed so that the nomad_scraper.json.tmpl file's place-
# holders can be replaced with the actual values.
cat <<EOT > /alloc/influx.env
#!/bin/sh

echo "Reading in influx environment variables"
INFLUX_TOKEN=$(influx auth list -u admin --hide-headers | awk '{print $4}')
ORG_ID=$(influx org list --hide-headers | awk '{print $1}')
BUCKET_ID=$(influx bucket list --hide-headers | grep nomad | awk '{print $1}')
DASHBOARD_ID=$(influx dashboards --hide-headers | awk '/Wave Dashboard/ { print $1 }')
EOT

chmod 755 /alloc/influx.env

echo "Setup script complete"
