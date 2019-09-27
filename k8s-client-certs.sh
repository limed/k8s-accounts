#!/bin/bash
# Creates a client cert for k8s

set -o errexit

fail() {
    echo "$@"
    exit 1
}

saferm() {
    local file_to_rm="${1}"
    shred -vfz -u -n 10 "${file_to_rm}"
}

gen_cert() {

    local user=${1}
	if [ -z "${user}" ]; then echo "Usage: $FUNCNAME <user>"; exit 1; fi

    cat > "cfssl-${user}.json" <<EOF
{
    "CN": "${user}",
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF
    cfssl genkey "cfssl-${user}.json" | \
        cfssljson -bare "${user}-client"
}

k8s_request_csr() {
    local cert_name="${1}"
    local csr_name="${2}"

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${csr_name}
spec:
  groups:
  - system:authenticated
  request: $(cat "${cert_name}.csr" | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
}

check_prereq() {
    if ! command -v cfssl; then
        fail "Can't find the cfssl tool, please install from https://pkg.cfssl.org/"
    fi

    if ! command -v cfssljson; then
        fail "Can't find the cfssljson tool, please install from https://pkg.cfssl.org/"
    fi

    if ! command -v kubectl; then
        fail "Can't find kubectl tool"
    fi

}

usage() {
    echo -en "Usage: $0 [options] \n\n"
    echo -en "Options: \n"
    echo -en "  -u | --user     User name\n"
    echo -en "  -s | --server   K8S Cluster name, this will also be the context name\n"
    echo -en "  -e | --endpoint K8S Cluster Api endpoint\n"
    echo -en "  -x | --setx     Debug mode\n\n"
}

while [ "$1" != "" ]; do
    case "$1" in
        -x | --debug | --setx )
            set -x
        ;;
        -u | --user)
            export CLUSTER_USER="${2}"
            shift
        ;;
        -r | --role)
            export CLUSTER_ROLE="${2:-view}"
            shift
        ;;
        -s | --server)
            export K8S_CLUSTER="${2}"
            shift
        ;;
        -e | --endpoint)
            export K8S_CLUSTER_ENDPOINT="${2}"
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

cert_name="${CLUSTER_USER}-client"
csr_name="${CLUSTER_USER}-client-csr"
key_name="${CLUSTER_USER}-client-key"
cluster_ca="${K8S_CLUSTER}-ca"

check_prereq

echo
echo "Generating Certificate for user ${CLUSTER_USER}"
gen_cert "${CLUSTER_USER}"

echo
echo "Creating k8s csr"
k8s_request_csr "${cert_name}" "${csr_name}"

echo
echo "Approving signing request"
kubectl certificate approve "${csr_name}"

echo
echo "Downloading certificate"
kubectl get csr "${csr_name}" -o jsonpath='{.status.certificate}' | \
    base64 --decode > "${cert_name}.crt"

echo
echo "Configuring kubeconfig"
kubectl config view --cluster="${K8S_CLUSTER}" -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | \
    base64 --decode > "${cluster_ca}.pem"

kubectl config set-credentials "${CLUSTER_USER}" \
    --client_certificate="${cert_name}.crt" \
    --client-key="${key_name}.pem" \
    --embed-certs=true \
    --kubeconfig="${CLUSTER_USER}-${K8S_CLUSTER}.kubeconfig"

kubectl config set-cluster "${K8S_CLUSTER}" \
    --certificate-authority="${cluster_ca}.pem" \
    --embed-certs=true \
    --server="https://${K8S_CLUSTER_ENDPOINT}" \
    --kubeconfig="${CLUSTER_USER}-${K8S_CLUSTER}.kubeconfig"

kubectl config set-context "${K8S_CLUSTER}" \
    --cluster="${K8S_CLUSTER}" \
    --user="${CLUSTER_USER}" \
    --kubeconfig="${CLUSTER_USER}-${K8S_CLUSTER}.kubeconfig"

kubectl config use-context "${K8S_CLUSTER}" --kubeconfig="${CLUSTER_USER}-${K8S_CLUSTER}.kubeconfig"

echo
echo "Cleaning up"
saferm "cfssl-${CLUSTER_USER}.json"
saferm "${cert_name}.crt"
saferm "${cert_name}.csr"
saferm "${key_name}.pem"
saferm "${cluster_ca}.pem"
kubectl delete csr "${csr_name}"
