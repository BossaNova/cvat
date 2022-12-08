#!/usr/bin/env bash

set -eu -o pipefail
declare -a environments=()
declare -r DEFAULT_ORG_NAME="bossanova.com"
declare -r TF_VAR_billing_id="$(gcloud beta billing accounts list | grep ' Primary Billing account Mark'  | cut -d ' ' -f 1)"
declare -r TF_VAR_bossanova_org="$(gcloud organizations list --format json | jq -r '.[0] | .name' | cut -d '/' -f 2)"

declare -r program_name="$(basename "$0")"
declare -r plan_log_file="tf_plan.log"
env_tag="dev"
organization="${DEFAULT_ORG_NAME}"
qualifier=""
dry_run=""
apply=""

function print_help_and_exit()
{
   read -d -r '' usage_txt <<EOF
USAGE: ${program_name}  [option <argument>]*

Build infrastructure for CVAT server

-h | --help print help and exit
-b | --billing_id <account number> - Google Cloud Billing account used to create resources
-e | --env Environment tag.  Must be dev or prod - default: "${env_tag}"
-o | --org Organization name. Used to look up the organization id.  default: "${organization}"
-q | --qualifier Qualifier used to make unique development environments
-d | --dry_run Dry run just print commands
--apply Run terraform apply
EOF
   if [ -n "${2}" ] ; then
       echo "*******"
       echo "${2} "
       echo "*******"
   fi
   echo "${usage_txt}"
   exit 10
}

function get_workspace()
{
    local __resultvar="${1}"
    local search_value="${2}"
    local search_term="${3}"
    local search_array=(${search_value})
    local __result=""
    for line in "${search_array[@]}"; do
        if [ "${line}" == "${search_term}" ]; then
            __result="${line}"
            break
        fi
    done
    eval "$__resultvar=${__result}"
}

function process_command()
{
    local __dry_run=$1
    local __command=$2
    echo "${__command}"
    if [ ! "${__dry_run}" ]; then
        eval "${__command}"
    fi
}

environments+=("TF_VAR_billing_id")
while [[ $# -gt 0 ]]
do
    case "$1" in
        -e | --env )
            env_tag="${2}"
            shift 2
        ;;
        -o | --org)
            organization="${2}"
            shift 2
        ;;
        -q | --qualifier)
            qualifier="${2}"
            shift 2
        ;;
        -d | --dry_run)
            dry_run=true
            shift 1
        ;;
        --apply)
            apply=true
            shift 1
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
var_file="${env_tag}.tfvars"
if [ -n "${qualifier}" ]; then
    var_file="${env_tag}-${qualifier}.tfvars"
fi
environments+=("TF_VAR_bossanova_org")
if [ -z "${env_tag}" ]; then
     print_help_and_exit "$(basename $0)", "No environment specified"
fi
if [ "${env_tag}" != "dev" ] && [ "${env_tag}" != "prod" ]; then
    print_help_and_exit "${program_name}", "Environment must be dev or prod"
fi
if [ "${env_tag}" == "prod" ] && [ -n "${qualifier}" ]; then
    print_help_and_exit "${program_name}", "Environment prod can not have a qualifier for it"
fi
if [ -n "${qualifier}" ]; then
    workspace="${env_tag}-${qualifier}"
else
    workspace="${env_tag}"
fi
TF_VAR_environment="${env_tag}"
TF_VAR_qualifier="${qualifier}"
environments+=("TF_VAR_environment")
environments+=("TF_VAR_qualifier")
for env in "${environments[@]}"; do
     export ${env}
done
get_workspace found_workspace "$(terraform workspace list)" "${workspace}"

if [ "$(terraform workspace show)" != "${workspace}" ] ; then
    if [ "${workspace}" != "${found_workspace}" ] ; then
       terraform workspace new "${workspace}"
    fi
    terraform workspace select "${workspace}"
fi
echo "Using workspace $(terraform workspace show)"
env | grep -i tf_var

process_command "${dry_run}" "terraform init"
process_command "${dry_run}" "terraform fmt"
process_command "${dry_run}" "terraform validate"
process_command "${dry_run}" "terraform plan --out ${plan_log_file} --var-file=${var_file}"
if [ "${apply}" ]; then
    process_command "${dry_run}" "terraform apply ${plan_log_file}"
fi

