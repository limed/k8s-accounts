## k8s-accounts
Adds "accounts" to k8s using client certificates, there are 2 scripts:

- `k8s-authorization.sh` - Grants view, edit or admin clusterroles to certs
- `k8s-client-certs.sh`	- Generates client cert and will output a kubeconfig file for you

This is useful for clusters that are created by KOPS. So it assumes you have admin access to an
existing cluster, and it assumes that the `KUBECONFIG` environment variable is set. You will also
need cfssl configured for this to work
