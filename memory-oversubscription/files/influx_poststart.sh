#!/bin/sh
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# This script will be run by Nomad before Influx has run the `influx_setup.sh`
# script which creates the `influx.env` file, so it needs to wait for it. Absent
# Consul, Nomad will start the post-start as soon as Docker reports the
# container is running.
#   Environments with Consul and a healthcheck set will probably not need to
# concern them with this because the post-start should not run until the service
# is healthy.
echo "$(date) Waiting for influx.env."
while [ ! -f /alloc/influx.env ]; do sleep 1; done
echo "$(date) Read influx.env"
source /alloc/influx.env

INFLUX_ADDR={{ env "NOMAD_ADDR_influx" }}

echo "$(date) Building link file."
echo "Influx Dashboard Link" >> /alloc/link.txt
echo "http://${INFLUX_ADDR}/orgs/${ORG_ID}/dashboards/${DASHBOARD_ID}?lower=now%28%29%20-%205m" >> /alloc/link.txt
echo "$(date) Done."

echo "$(date) Building scraper template."
sed "s/«orgid»/${ORG_ID}/g;s/«bucketid»/${BUCKET_ID}/g" alloc/nomad_scraper.json.tmpl > alloc/nomad_scraper.json
echo "Done"

echo "$(date) Waiting for Influx..."
dbReady=0
while [ "$dbReady" != "200" ]
do
  dbReady=$(curl -s --HEAD http://${INFLUX_ADDR}/ready | awk '/^HTTP/ {print $2}')
  echo -n $dbReady.
  sleep 1
done
echo "$(date) Influx started."

echo "$(date) Building scraper."
curl -s \
     --request POST http://${INFLUX_ADDR}/api/v2/scrapers \
     --data @/alloc/nomad_scraper.json \
     --header "Authorization: Token ${INFLUX_TOKEN}"
echo ""

exit 0
