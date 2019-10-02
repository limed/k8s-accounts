## k8s-accounts
Adds "accounts" to k8s using client certificates, there are 2 scripts:

- `k8s-authorization.sh` - Grants view, edit or admin clusterroles to certs
- `k8s-client-certs.sh`	- Generates client cert and will output a kubeconfig file for you

This is useful for clusters that are created by KOPS. So it assumes you have admin access to an
existing cluster, and it assumes that the `KUBECONFIG` environment variable is set. You will also
need cfssl configured for this to work

## Usage

Create a client cert

```bash
# ./k8s-client-certs.sh -u <username> -s <server name> -e <api endpoint>
# ./k8s-authorization.sh -u <username> -r <role: admin | view | edit>
```
