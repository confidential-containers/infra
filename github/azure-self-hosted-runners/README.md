# Self-hosted Github Runners with Garm

Those instructions deploy Garm for self-hosted github runners on azure (c)VMs. Garm listens to webhooks from github and spawns VMs on demand.

## Build

```bash
docker build -t garm-azure .
```

## Service

The application is deployed as an [ACI](https://azure.microsoft.com/en-us/products/container-instances) Container Group. It is bootstrapped with an init container which creates an admin user, an initial repository registration, and a pool for the repository. It keeps database state on a Storage Account-backed volume. The app will expose an HTTP/S ports for github webhooks.

### Requirements

- Terraform
- Azure credentials, configured and logged in.
- A github token to manage self-hosted runner registrations, either:
  - A classic token scoped to `public_repo`.
  - A fine-grained token w/ access `read` access to `metadata` and `read,write` access to `administration` of particular repositories.

### Deployment

Create a `tf/terraform.tfvars` file with `github-token=github_pat...` or set it as env `export TF_VAR_github_token=github_pat...`.

```bash
cd tf
terraform apply
```

## Configuration

Configuration of repositories is performed via the bundled `garm-cli` tool. It's available via `az container exec` (the individual parameters might differ depending on the config & deployment):

```bash
$ az container exec -g garm -n garm-kg1ocu --container-name garm --exec-command bash
$ garm-cli profile ls
+-----------------+-----------------------+
| NAME            | BASE URL              |
+-----------------+-----------------------+
| local (current) | http://localhost:9997 |
+-----------------+-----------------------+
```

### Repositories

To configure a repository create a webhook secret:

```bash
$ export WEBHOOK_SECRET="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 24)"
$ garm-cli repository add --credentials garm --name garm-playground --owner mkulke --webhook-secret "$WEBHOOK_SECRET"
+----------------------+--------------------------------------+
| FIELD                | VALUE                                |
+----------------------+--------------------------------------+
| ID                   | d7beb832-6feb-4739-8026-58e7d97d99cb |
| Owner                | mkulke                               |
| Name                 | garm-playground                      |
| Credentials          | garm                                 |
| Pool manager running | false                                |
| Failure reason       |                                      |
+----------------------+--------------------------------------+
```

To react to github workflow events, the application exposes an https endpoint on the internet. You can retrieve the endpoint as `webhook_url` output from the terraform deployment (`terraform output`).

Add this Webhook (e.g. `https://garm-dc6512.eastus.azurecontainer.io/webhooks`) to your repository:
- Set the webhook secret to the value that was configured for the repo.
- Set the webhook `Content-Type` to `application/json`. (Garm will only accept json events)
- Check the box for `Workflow jobs` events.

### Pools

If the `runs-on` label selector of a github action job matches a set of tags (`runs-on: ["self-hosted", "ubuntu"]`) that is configured for a repository's pool, the service attempts to spawn a self-hosted runner.

```bash
$ garm-cli repo ls
+--------------------------------------+--------+-----------------+------------------+------------------+
| ID                                   | OWNER  | NAME            | CREDENTIALS NAME | POOL MGR RUNNING |
+--------------------------------------+--------+-----------------+------------------+------------------+
| d7beb832-6feb-4739-8026-58e7d97d99cb | mkulke | garm-playground | garm             | true             |
+--------------------------------------+--------+-----------------+------------------+------------------+
$ export REPO_ID=d7beb832-6feb-4739-8026-58e7d97d99cb
$ garm-cli pool add \
	--repo "$REPO_ID" \
	--flavor Standard_DC2as_v5 \
	--tags self-hosted,azure-cvm,ubuntu-2204 \
	--enabled true \
	--min-idle-runners 0 \
	--max-runners 4 \
	--extra-specs '{"confidential": true}' \
	--provider-name azure_external \
	--image Canonical:0001-com-ubuntu-confidential-vm-jammy:22_04-lts-cvm:latest
```

## Debugging

You can debug the webhook transmission in Github's console. If the webhook was successfully sent and picked up by Garm, it should spawn an instance. It might take a couple of minutes for the runner to be fully bootstrapped (see timestamps below). Eventually it should register itself w/ a call to `/api/v1/metadata/runner-registration-token` execute the jobs and delete the instance afterwards.

```bash
$ az container logs -g garm -n garm-kg1ocu --container-name garm --follow
2023/06/02 12:57:16 got hook for repo kinvolk/azure-cvm-tooling
2023/06/02 12:57:16 adding new runner with requested tags self-hosted, azure-cvm, ubuntu-2204 in pool e475e34d-05c9-42ea-9a52-bfa74b3ebaee
127.0.0.1 - - [02/Jun/2023:12:57:16 +0000] "POST /webhooks HTTP/1.1" 200 0 "" "GitHub-Hookshot/4200660"
2023/06/02 12:57:19 creating instance garm-Gl1EKldZ6C66 in pool e475e34d-05c9-42ea-9a52-bfa74b3ebaee
2023/06/02 12:57:31 provider returned: {
  "provider_id": "garm-Gl1EKldZ6C66",
  "agent_id": 0,
  "name": "garm-Gl1EKldZ6C66",
  "os_type": "linux",
  "os_name": "22_04-lts-cvm",
  "os_version": "latest",
  "os_arch": "amd64",
  "status": "running",
  "updated_at": "0001-01-01T00:00:00Z",
  "github-runner-group": ""
}
127.0.0.1 - - [02/Jun/2023:13:01:21 +0000] "GET /api/v1/metadata/runner-registration-token/ HTTP/1.1" 200 29 "" "curl/7.81.0"
```
