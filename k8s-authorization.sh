#!/bin/bash

set -o errexit

fail() {
    echo "$@"
    exit 1
}

usage() {
    echo -en "Usage: $0 [options] \n\n"
    echo -en "Options: \n"
    echo -en "  -u | --user     User name\n"
    echo -en "  -r | --role     Roles for K8S, valid values are admin, view & edit [default: view]\n"
    echo -en "  -x | --setx     Debug mode\n\n"
}

check_prereq() {
    if ! command -v kubectl; then
        fail "Can't find kubectl tool"
    fi
}

while [ "$1" != "" ]; do
    case "$1" in
        -x | --debug | --setx )
            set -x
        ;;
        -r | --role)
            export CLUSTER_ROLE="${2:-view}"
            shift
        ;;
        -u | --user)
            export USER="${2}"
            shift
        ;;
        -n | --namespace)
            export NAMESPACE="${2}"
            shift
        ;;
        -h | --help)
            usage
            exit 0
        ;;
        *)
            usage
            exit 0
        ;;
    esac
    shift
done

if [ -z "${KUBECONFIG}" ]; then
    fail "KUBECONFIG environment variable is not set"
fi

if [ "${CLUSTER_ROLE}" != "view" ] && [ "${CLUSTER_ROLE}" != "edit" ] && [ "${CLUSTER_ROLE}" != "admin" ]; then
    fail  "Error ${CLUSTER_ROLE} is not a valid role. Valid roles are admin, edit or view"
fi

kubectl create clusterrolebinding "${USER}-${CLUSTER_ROLE}-role" \
    --user="${USER}"\
    --clusterrole="${CLUSTER_ROLE}"
