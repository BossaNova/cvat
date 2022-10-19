#!/usr/bin/env bash
set -e
declare -a commands=()

terraform_outputs=""
function print_help_and_exit()
{
   read -d -r '' usage_txt <<EOF
USAGE: ${program_name}  [option <argument>]*

Create exports to run the CVAT server

-h | --help print help and exit
-a | --arecord the A record for the server
-d | --dns The DNS name for the server (default bossanova.com)
-s | --secret_id_id The id of the secret_id (default \${arecord}-postgres-password).
-v | --secret_id_version The secret_id version (default 1)
EOF
   if [ -n "${2}" ] ; then
       echo "*******"
       echo "${2} "
       echo "*******"
   fi
   echo "${usage_txt}"
   exit 10
}

terraform_outputs="$(terraform output --json)"

dns_name="bossanova.com"
secret_id_version="1"

while [[ $# -gt 0 ]]
do
    case "$1" in
        -a | --arecord )
            arecord="${2}"
            shift 2
        ;;
        -d | --dns_name)
            dns_name="${2}"
            shift 2
        ;;
        -v | --secret_id_version)
            secret_id_version="${2}"
            shift 2
        ;;
        -s | --secret_id_id)
            secret_id_id="${2}"
            shift 2
        ;;
        -h | --help)
            print_help_and_exit "${program_name}"
        ;;
        *)
            print_help_and_exit "${program_name}", "unknown argument ${1}"
        ;;

    esac
    sleep 1
done
if [ -z "${arecord}" ]; then
    echo "enter the a record name for the server:"
    read -r
    arecord="${REPLY}"
fi
if [ -z "${secret_id}" ]; then
    secret_id="${arecord/./-}-postgres-password"
fi

commands+=("export CVAT_HOST=${arecord}.${dns_name}")
commands+=("export ACME_EMAIL=infosec@bossanova.com")
commands+=("export CVAT_POSTGRES_DBNAME=cvat")
commands+=("export CVAT_POSTGRES_USER=cvat_master")
phost=$(echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep postgres_private_ip | cut -d "," -f 2 | xargs)
commands+=("export CVAT_POSTGRES_HOST=${phost}")
rhost=$(echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep redis_instance_host | cut -d "," -f 2 | xargs)
commands+=("export CVAT_REDIS_HOST=${rhost}")
commands+=("export CVAT_POSTGRES_PASSWORD=\$(gcloud secrets versions access "$secret_id_version" --secret="${secret_id}" --project cloud-run-example-317621)")

compute_host=$(echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep compute_host_name | cut -d "," -f 2 | xargs)
compute_project=$(echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep compute_zone | cut -d "," -f 2 | xargs)
project_id=$(echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep project_id | cut -d "," -f 2 | xargs)
echo "To connect to the host execute:"
echo "gcloud compute ssh \"${compute_host}\" --zone \"$compute_project\" --project \"${project_id}\""
echo "Service account for the VM is:"
echo "${terraform_outputs}" | jq -r 'keys[] as $k | "\($k), \(.[$k] | .value)"' | grep compute_sa | cut -d "," -f 2 | xargs
for value in "${commands[@]}"
do
     echo $value
done
