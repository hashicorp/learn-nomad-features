#!/usr/bin/env bash

allocIDTemplate=$(cat <<EOH
{{- range . -}}
  {{- if and (eq .TaskGroup "$1") (eq .DesiredStatus "run") (eq .ClientStatus "running") -}}
    {{- .ID -}}
  {{- end -}}
{{- end -}}
EOH
)

allocTemplate=$(cat <<EOH
{{- range .AllocatedResources.Shared.Ports -}}
{{- printf "%v\thttp://%v:%v\n" .Label .HostIP .Value -}}
{{- end -}}
EOH
)

# Get Allocation ID
allocID=$(nomad alloc status -t "${allocIDTemplate}")
allocCount=$(echo "${allocID}" | wc -l | tr -d " ")

if [[ "${allocCount}" != "1" ]]
then
  echo "incorrect alloc count, expected 1"
  exit 1
fi

ports=$(nomad alloc status -t "${allocTemplate}" $allocID)
portsCount=$(echo "${ports}" | wc -l | tr -d " ")

if [[ "${portsCount}" != "1" && "$2" == "" ]]
then
  echo "Found more than one published port."
  echo "${ports}" | awk '{print $1" "$2}' | column -t -s " "
elif [[ "${portsCount}" != "1" && "$2" != "" ]]
then
  echo "${ports}" | grep "$2" | awk '{print $2}'
else
  echo "${ports}" | awk '{print $2}'
fi
