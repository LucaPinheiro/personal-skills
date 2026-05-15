---
name: aws-cli
description: MUST USE when authoring, reviewing, automating, or debugging anything that runs the **AWS Command Line Interface (AWS CLI v2)** — covers the **command-structure contract** (`aws <options> <command> <subcommand> [parameters]`, exclusive-parameter last-value-wins rule, `wait` subcommands), the **two-file configuration model** (`~/.aws/credentials` vs `~/.aws/config`, the `[profile <name>]` prefix that exists in `config` but **not** in `credentials`, default-profile naming `[default]` in both), the **named profile + AWS_PROFILE / AWS_DEFAULT_PROFILE switching** (env var beats config, CLI `--profile` flag beats env var), the **credential resolution order** (CLI args → env vars → assume-role-with-web-identity → SSO → process credentials → shared credentials/config files → container credentials → EC2 instance metadata), the **environment-variable surface** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_PROFILE`, `AWS_DEFAULT_PROFILE`, `AWS_DEFAULT_OUTPUT`, `AWS_PAGER`, `AWS_CA_BUNDLE`, `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, `AWS_ENDPOINT_URL`, `AWS_EC2_METADATA_DISABLED`, `AWS_RETRY_MODE`, `AWS_MAX_ATTEMPTS`, `AWS_CLI_AUTO_PROMPT`, `AWS_CLI_FILE_ENCODING`), the **global flag surface** (`--profile`, `--region`, `--output`, `--query`, `--debug`, `--no-paginate`, `--no-cli-pager`, `--no-verify-ssl`, `--endpoint-url`, `--no-sign-request`, `--color`, `--ca-bundle`, `--cli-read-timeout`, `--cli-connect-timeout`, `--cli-binary-format raw-in-base64-out|base64`), the **output formats** (`json`, `yaml`, `yaml-stream`, `text`, `table`) and **JMESPath `--query`** semantics (`Reservations[].Instances[].[InstanceId,State.Name]`, `length(Buckets)`, projection vs filter, `?Tag` vs `[?Key=='Name']`), the **input-file conventions** (`file://` for text JSON / YAML / templates, `fileb://` for raw binary blobs like Lambda zips and Cognito images, `--cli-input-json` / `--cli-input-yaml` paired with `--generate-cli-skeleton input|output`), the **shorthand-vs-JSON parameter syntax** (`Key=Value,Key2=Value2` collapses for flat maps; structures and lists of maps require JSON via `file://` or quoted single-quoted JSON), the **pagination contract** (server-side iteration is automatic by default, `--no-paginate` to opt out, `--max-items` truncates client-side, `--starting-token` resumes, `--page-size` controls API page size without truncation, `NextToken` re-emerges in output when `--max-items` truncates a page), the **wait/poller subcommands** (`aws ec2 wait instance-running --instance-ids …`, `aws cloudformation wait stack-create-complete --stack-name …`, `aws s3api wait object-exists`, `aws eks wait cluster-active`), the **higher-level vs API-level S3 split** (`aws s3 cp/sync/mv/rm/ls/mb/rb` are convenience wrappers; `aws s3api` is the raw API surface — only `s3api` exposes object-lock / lifecycle / versioning / replication / inventory / object-tagging operations), the **`aws configure` family** (`configure`, `configure set`, `configure get`, `configure list`, `configure list-profiles`, `configure import --csv`, `configure sso`, `configure sso-session`, `configure export-credentials`), the **`aws sso login` / `aws sso logout` lifecycle** (token cache `~/.aws/sso/cache/`, `sso_session` block in config, `sso_start_url`, `sso_region`, `sso_account_id`, `sso_role_name`), the **assume-role flow** (`source_profile` chain, `role_arn`, `external_id`, `mfa_serial`, `duration_seconds`, `role_session_name`; `credential_source = Ec2InstanceMetadata|Environment|EcsContainer` for IRSA / instance-profile chains; `web_identity_token_file` + `role_arn` for IRSA / EKS Pod Identity; `credential_process` for external 1Password / aws-vault / Granted), the **autoprompt** (`AWS_CLI_AUTO_PROMPT=on-partial`, `--cli-auto-prompt`, `--no-cli-auto-prompt`, partial mode triggers only on errors), the **alias system** (`~/.aws/cli/alias`, both subcommand aliases and shell-`!` aliases), the **debug surface** (`--debug` prints wire-level requests including signed headers, never paste verbatim into tickets), the **retry behavior** (`legacy` 3 attempts vs `standard` 3 attempts vs `adaptive` rate-limited 3 attempts; configurable via `retry_mode` config / `AWS_RETRY_MODE` and `max_attempts` / `AWS_MAX_ATTEMPTS`), the **endpoint override surface** (`--endpoint-url` per-call, `endpoint_url` per-service in config, `AWS_ENDPOINT_URL_<SERVICE>`, FIPS endpoints `--region us-east-1 --endpoint-url https://elasticbeanstalk-fips.us-east-1.amazonaws.com`, dual-stack), the **anti-patterns** that bite real teams (long-lived `aws_access_key_id` in `~/.aws/credentials` instead of SSO / IRSA / Identity Center, committing the `credentials` file or its env-var equivalents, sourcing `aws sts assume-role` JSON into `export AWS_ACCESS_KEY_ID=…` shell snippets that miss `AWS_SESSION_TOKEN`, mixing `aws s3 ls` server-side count with `--max-items` truncation, omitting `--no-cli-pager` in CI causing `less` to hang, parsing `--output text` in scripts that the next CLI minor renames a column on, hard-coding `--region us-east-1` instead of accepting `AWS_REGION`, building a wrapper that calls `aws sts get-caller-identity` on every invocation and burns STS rate-limit, treating `--debug` output as safe to paste in a public Slack), the **CI/CD posture** (use OIDC + `aws-actions/configure-aws-credentials` rather than long-lived secrets, `AWS_REGION` from runner env, `--no-cli-pager` always, `--output json` always for jq pipelines, exit-code conventions: 0 success / 1 service error / 2 usage error / 130 user-interrupt / 252 command-not-found / 253 invalid-arg / 254 unrecognised-resource / 255 unhandled-exception). Triggers on phrases — "aws cli", "awscli", "aws-cli", "`aws s3`", "`aws ec2`", "`aws sts`", "`aws iam`", "`aws eks`", "`aws cloudformation`", "`aws configure`", "`aws sso login`", "named profile", "AWS_PROFILE", "credentials file", "aws config file", "assume role cli", "credential_process", "sso_session", "JMESPath query", "--query", "file:// json", "--cli-input-json", "generate-cli-skeleton", "aws cli wait", "aws s3 sync", "s3api", "aws cli pager", "aws cli pagination", "aws cli docker image", "AWS CloudShell". Triggers on file patterns — `**/*.sh` invoking `aws ` (with the trailing space), `**/Makefile` rules calling `aws`, `**/.github/workflows/*.{yml,yaml}` with `run: aws …` or `uses: aws-actions/configure-aws-credentials@*`, `**/Dockerfile` containing `RUN aws ` or `RUN pip install awscli`, `**/.aws/{config,credentials,cli/alias}`, `**/buildspec.yml` (CodeBuild), `**/codebuild-*.yml`, `**/serverless.yml` post-deploy hooks calling `aws`, `**/skaffold.yaml` profiles invoking `aws`, `**/scripts/*aws*.{sh,py}`, `**/azure-pipelines.yml` running aws cli on a Linux agent. Authored from the perspective of a **distinguished AWS Platform Engineer** — emphasises **command-structure discipline, profile + credential resolution literacy, JMESPath competency, fileb:// vs file:// correctness, pagination + waiter literacy, identity-first auth (SSO / IAM Identity Center / IRSA / Pod Identity over long-lived keys), CI hardening (`--no-cli-pager`, `--output json`, OIDC), and the stop-sign that the AWS CLI is a *thin client over SigV4 HTTPS* not a *control plane abstraction* — every command is a SignedRequest you can read with `--debug`**. Sister skill to `addons-and-building-blocks` (cluster bootstrap that consumes `aws eks update-kubeconfig`), `github-actions` (CI auth via `aws-actions/configure-aws-credentials` OIDC), `azure-retail-prices` (analogous public-API discipline applied to a different cloud).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: aws-cli-usage-and-automation
  platform: aws
  stack: aws-cli-v2 + sigv4 + jmespath + odata-shorthand
  cloud: aws-commercial (also GovCloud + China with --region overrides)
  use_cases: ad-hoc-ops, ci-cd-pipelines, makefile-tasks, codebuild-buildspec, github-actions, eks-bootstrap, sso-login, assume-role-chains, jmespath-extracts, s3-sync-jobs, cloudformation-deploys, lambda-invokes
  sister_skills: addons-and-building-blocks, github-actions, azure-retail-prices
  reference_docs:
    - https://docs.aws.amazon.com/cli/
    - https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
    - https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-commandstructure.html
    - https://docs.aws.amazon.com/cli/latest/userguide/cli_code_examples.html
---

# AWS CLI — Distinguished AWS Platform Engineer's Playbook

You are a **distinguished AWS Platform Engineer** writing or reviewing code that drives the **AWS Command Line Interface (AWS CLI v2)** — interactive ops, Makefile glue, CI pipelines, EKS bootstraps, S3 sync jobs, CloudFormation deploys, Lambda invocations, IAM/STS surgery. Your job is to ship CLI usage that is **reproducible, identity-first, paginated to completion, JSON-parsed (never text-scraped), and free of long-lived keys**.

This skill encodes the **AWS CLI contract** (command structure, configuration files, credential resolution, output / query / pagination semantics, file inputs, waiters, retries, endpoints) and the **operational discipline** that turns a one-off `aws s3 ls` into a production caller.

**Non-negotiables encoded in this skill:**

1. **Command structure is positional.** `aws <global-options> <command> <subcommand> [parameters]`. Global options like `--profile`, `--region`, `--output`, `--query`, `--debug`, `--endpoint-url`, `--no-cli-pager` may appear *before or after* the service; service-level operation flags must follow `<command> <subcommand>`. If you specify the same exclusive parameter twice on one invocation, **the last value wins** — silent override with no warning. Reviewer rule: never put `--profile foo` *before* and `--profile bar` *after* the operation in the same command, and never let scripts emit duplicates from `set -x` re-export logic.
2. **There are two config files and they have different syntax.** `~/.aws/credentials` uses `[profilename]`. `~/.aws/config` uses `[profile profilename]` — except for the default profile, which is `[default]` in **both** files. Mixing them up is the single most common "why does my profile not load" bug. Long-lived `aws_access_key_id` / `aws_secret_access_key` go in `credentials`. Region, output, sso_session, source_profile, role_arn, credential_process go in `config`. Override file paths via `AWS_SHARED_CREDENTIALS_FILE` and `AWS_CONFIG_FILE`.
3. **Credential resolution order is fixed and overrides the file you think is loaded.** From highest to lowest priority: (1) command-line `--profile` (and any explicit `--region` / endpoint flag), (2) environment variables (`AWS_ACCESS_KEY_ID`, `AWS_PROFILE`, etc.), (3) `assume-role-with-web-identity` via `AWS_WEB_IDENTITY_TOKEN_FILE` + `AWS_ROLE_ARN` (IRSA / Pod Identity / GitHub OIDC), (4) IAM Identity Center / SSO via `sso_session` cache, (5) `credential_process`, (6) shared `credentials` + `config` profile, (7) ECS / EKS container credentials (`AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` / `_FULL_URI`), (8) EC2 instance metadata (IMDSv2). When a coworker says "the wrong account is being used", mentally walk that list — env vars beating their `[default]` profile is the answer 80% of the time.
4. **Long-lived `aws_access_key_id` keys are an anti-pattern outside emergency break-glass.** The 2026-default identity surface is: AWS IAM Identity Center (`aws sso login` + `sso_session` blocks) for humans, IRSA / EKS Pod Identity (`web_identity_token_file` + `role_arn`) for in-cluster workloads, OIDC federation (`aws-actions/configure-aws-credentials@v4` with `role-to-assume` + `permissions: id-token: write`) for GitHub Actions, EC2 instance profiles for self-managed nodes, ECS task roles for ECS, `credential_process` (1Password CLI, aws-vault, Granted) for laptops that absolutely cannot SSO. If you see `aws_access_key_id = AKIA…` checked into a `credentials` file or a Dockerfile, **flag it first** before any other comment.
5. **`--query` is JMESPath; learn it instead of piping to `grep`.** `aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`]|[0].Value]' --output text` returns a clean three-column table. JMESPath features you must know: projection (`Reservations[].Instances[]`), filter (`[?State.Name=='running']`), pipe (`Buckets | [?contains(Name, 'logs')]`), functions (`length(Buckets)`, `sort_by(Items, &Key)`, `keys(@)`, `values(@)`), and the `@` self-reference. JMESPath is **client-side** — the API still returns everything; the CLI just trims the response. Use it to make output scriptable, not to reduce API load (use `--filters` server-side for that on services that support it, e.g. `aws ec2 describe-instances --filters Name=instance-state-name,Values=running`).
6. **Use `--output json` in scripts. Never parse `--output text`.** `text` output is column-ordered, tab-delimited (mostly), and the column order is *not contractually stable* across CLI minor versions. `aws … --output json | jq -r '...'` is reproducible. `aws … --output text | awk '{print $3}'` will silently break the day a CLI minor adds a column. `table` is for humans, `yaml` and `yaml-stream` are for human-readable dumps and event-stream operations respectively.
7. **`file://` is text, `fileb://` is binary. Pick wrong and you corrupt the payload.** `aws lambda update-function-code --zip-file fileb://function.zip` (binary). `aws cloudformation deploy --template-file file://template.yaml` (text). `aws cognito-idp set-ui-customization --image-file fileb://logo.png` (binary). `--cli-binary-format raw-in-base64-out` (default in v2) means binary parameters in `--cli-input-json` are decoded from base64 before sending — pair it with `fileb://` for the source. Mixing them up: `file://` on a zip uploads UTF-8-decoded garbage; `fileb://` on a JSON template fails to parse server-side.
8. **Always `--no-cli-pager` (or set `AWS_PAGER=""`) in CI.** v2 defaults the pager to `less`. In an interactive TTY that's helpful; in a CI runner the process **hangs forever waiting for input** with no error visible upstream. Either export `AWS_PAGER=""` once at the top of the CI script or pass `--no-cli-pager` on every command. Same goes for any non-TTY automation — Makefiles invoked from `make -j`, Dockerfile RUN steps, post-deploy hooks.
9. **Pagination is automatic by default. `--max-items` is client-side truncation, not server-side.** Most operations transparently iterate `NextToken` for you and emit a single combined JSON document. `--max-items 50` truncates the *output* to 50 items but **re-emits a `NextToken`** in the JSON so you can resume — the API has already paginated past 50. `--page-size` controls the per-API-call request size (useful for slow APIs like `cloudwatch logs filter-log-events` where smaller pages return earlier). `--no-paginate` disables auto-iteration entirely — the CLI returns exactly the first page from the API, NextToken intact, *no client-side merging*. Use `--no-paginate` only when you genuinely want one API page (e.g. polling for "is there at least one event"); for everything else, let the CLI iterate.
10. **`aws s3 …` and `aws s3api …` are different commands.** `aws s3` is the *high-level* surface: `cp`, `sync`, `mv`, `rm`, `ls`, `mb`, `rb`. It does multipart, parallelism, and recursion well. `aws s3api` is the *raw API* surface: object-lock, lifecycle, versioning, replication, inventory, bucket policy, object tagging, presigned URL details, ACL operations beyond canned ACLs. Default to `s3`; reach for `s3api` when you need a feature that doesn't exist in `s3`. Anti-pattern: trying to set object-lock retention via `aws s3 cp` (impossible) — use `aws s3api put-object-retention`.
11. **Waiters exist. Use them instead of polling-loops with `sleep`.** `aws ec2 wait instance-running --instance-ids i-…`, `aws cloudformation wait stack-create-complete --stack-name foo`, `aws s3api wait object-exists --bucket b --key k`, `aws eks wait cluster-active --name c`, `aws lambda wait function-active --function-name f`. Waiters poll the API at the SDK's recommended cadence and exit non-zero when the resource enters a terminal-failure state — far better than `until aws … describe …; do sleep 5; done` loops that have no failure semantics.
12. **`--debug` leaks signed headers and request bodies. Never paste it in a public channel.** `--debug` emits the wire-level signed request including `Authorization: AWS4-HMAC-SHA256 Credential=AKIA…/20260508/us-east-1/sts/aws4_request, SignedHeaders=…, Signature=…`. The `Signature` is short-lived but the `Credential=AKIA…` access-key-id half is permanent. Sanitize with `--debug 2>&1 | grep -v -E '(Authorization|x-amz-security-token|aws_access_key|aws_secret_access)'` or attach the file to a private ticket. Same goes for `aws sts get-session-token` and `aws sts assume-role` JSON output — those contain a 12-hour `SessionToken`.

If a script, Makefile, workflow, or wrapper under review violates any of these, **flag them first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Writing a Makefile that calls `aws eks update-kubeconfig` and `aws s3 sync` | **Yes** |
| Reviewing a GitHub Actions workflow that uses `aws-actions/configure-aws-credentials` + `aws cloudformation deploy` | **Yes** |
| Debugging "the wrong AWS account is being used by my CI step" | **Yes** |
| Authoring a one-shot script to extract running EC2 instance IDs across regions | **Yes** |
| Migrating a team off long-lived keys to AWS IAM Identity Center / SSO | **Yes** |
| Wiring a Lambda invoke + S3 multipart upload from a Dockerfile RUN step | **Yes** |
| Adding `aws cli` autoprompt + alias setup to a developer dotfiles repo | **Yes** |
| Pinning AWS CLI v2 in a CodeBuild image and reviewing the buildspec | **Yes** |
| Choosing between `aws s3 sync` and `aws s3api copy-object` for a workflow | **Yes** |
| Writing Python that imports `boto3` (use the `boto3` SDK skill instead, not this one) | No |
| Writing Terraform `aws_*` resources (use the Terraform skill, not this one) | No |
| Authoring a cdk app (use a CDK-specific skill) | No |

---

## INSTALLATION & FIRST-RUN

### Install AWS CLI v2 (current major)

The CLI v1 (Python, `pip install awscli`) is **end-of-life on 2025-08-15** for security fixes and **fully deprecated 2026-05-01**. Default to v2 on every new install. v2 is a self-contained binary distribution — no Python dependency.

```bash
# macOS — Homebrew
brew install awscli

# macOS — official package
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Linux x86_64
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
# (Linux aarch64 — replace with awscli-exe-linux-aarch64.zip)

# Windows
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Docker (official Public ECR image)
docker run --rm -it \
  -v ~/.aws:/root/.aws \
  -v $(pwd):/aws \
  public.ecr.aws/aws-cli/aws-cli:latest \
  s3 ls

# AWS CloudShell — preinstalled in the AWS Console; no install required.
```

Verify: `aws --version` → `aws-cli/2.x.x Python/3.x.x …`. Note the *Python* embedded version is part of the bundle — it is not the system Python.

### First-time configuration — pick **exactly one** identity strategy

1. **AWS IAM Identity Center (recommended for humans)** — short-lived, browser-MFA, refreshable.
2. **IRSA / EKS Pod Identity** (recommended for in-cluster workloads) — federated via OIDC, no static keys, scoped to a service account.
3. **OIDC + GitHub Actions** (recommended for CI) — federated via GitHub OIDC, scoped per workflow.
4. **EC2 instance profile / ECS task role** — for self-managed compute.
5. **`credential_process`** (1Password / aws-vault / Granted) — for environments where SSO browser flow is unavailable.
6. **Long-lived `aws configure` keys** — break-glass only, rotated quarterly, stored only in `~/.aws/credentials` with `chmod 600`, **never** committed.

---

## CONFIGURATION FILES — THE TWO-FILE MODEL

### `~/.aws/credentials` (chmod 600, never commit)

Long-lived keys only. Profile names are **bare** (`[default]`, `[ops]`).

```ini
[default]
aws_access_key_id     = AKIA....EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[break-glass]
aws_access_key_id     = AKIA....EMERGENCY
aws_secret_access_key = .....
```

### `~/.aws/config`

Everything else. Profile names are prefixed with `profile ` **except `[default]`**.

```ini
[default]
region = us-east-1
output = json

# --- IAM Identity Center / SSO ---
[sso-session bebet-sso]
sso_start_url        = https://bebet.awsapps.com/start
sso_region           = us-east-1
sso_registration_scopes = sso:account:access

[profile bebet-prod]
sso_session     = bebet-sso
sso_account_id  = 111122223333
sso_role_name   = AdministratorAccess
region          = us-east-1
output          = json

# --- Assume-role chain off a base profile ---
[profile bebet-billing]
role_arn       = arn:aws:iam::444455556666:role/BillingReadOnly
source_profile = bebet-prod
duration_seconds = 3600

# --- IRSA / Pod Identity (set automatically by EKS pod spec) ---
[profile irsa-pod]
role_arn               = arn:aws:iam::111122223333:role/some-app-role
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/token

# --- EC2 instance metadata as the source ---
[profile ec2-managed]
role_arn          = arn:aws:iam::111122223333:role/managed-role
credential_source = Ec2InstanceMetadata

# --- credential_process (1Password example) ---
[profile op-vault]
credential_process = op read 'op://AWS/bebet/credential_process_json'

# --- Endpoint override for a service (LocalStack example) ---
[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566       # CLI v2.13+

# --- Retry tuning ---
[profile high-throughput]
retry_mode   = adaptive
max_attempts = 10
```

### Path overrides via env vars

| Env var | Default | Purpose |
|---------|---------|---------|
| `AWS_CONFIG_FILE` | `~/.aws/config` | Move the config file (e.g. per-repo) |
| `AWS_SHARED_CREDENTIALS_FILE` | `~/.aws/credentials` | Move the credentials file |
| `AWS_PROFILE` | `default` | Pick a profile for this shell |
| `AWS_DEFAULT_PROFILE` | (legacy) | v1 alias for `AWS_PROFILE` — set both for max compat |
| `AWS_REGION` | from profile | Per-shell region override |
| `AWS_DEFAULT_REGION` | from profile | v1 alias for `AWS_REGION` |
| `AWS_DEFAULT_OUTPUT` | from profile | Per-shell output format override |
| `AWS_PAGER` | `less` (TTY) | `""` to disable; `cat` for plain stdout |
| `AWS_CA_BUNDLE` | system | Custom CA bundle (corporate proxies) |
| `AWS_CLI_AUTO_PROMPT` | `off` | `on` always, `on-partial` on errors |
| `AWS_RETRY_MODE` | `legacy` | `standard` or `adaptive` |
| `AWS_MAX_ATTEMPTS` | 3 (legacy) / 3 (standard) / 3 (adaptive base) | Cap retries |
| `AWS_EC2_METADATA_DISABLED` | unset | `true` to skip IMDS lookup (speeds up off-EC2 invocations) |
| `AWS_ENDPOINT_URL` | unset | Global endpoint override (CLI v2.13+) |
| `AWS_ENDPOINT_URL_<SERVICE>` | unset | Per-service override, e.g. `AWS_ENDPOINT_URL_S3` |
| `AWS_CLI_FILE_ENCODING` | system | Override on Windows when files are UTF-16 |

---

## COMMAND STRUCTURE

```
aws [global-options] <command> <subcommand> [parameters]
```

- `<command>` is usually a service: `s3`, `s3api`, `ec2`, `iam`, `sts`, `lambda`, `cloudformation`, `eks`, `dynamodb`, etc.
- `<subcommand>` is an operation: `describe-instances`, `get-caller-identity`, `update-kubeconfig`, `deploy`.
- Global options: `--profile`, `--region`, `--output`, `--query`, `--debug`, `--no-paginate`, `--no-cli-pager`, `--no-verify-ssl`, `--endpoint-url`, `--no-sign-request`, `--color`, `--ca-bundle`, `--cli-read-timeout`, `--cli-connect-timeout`, `--cli-binary-format`, `--cli-auto-prompt`, `--no-cli-auto-prompt`.

Get help, three depths:

```bash
aws help                           # top-level overview
aws s3 help                        # service-level: lists subcommands
aws s3 cp help                     # operation-level: full flag list
aws help topics                    # listed help topics, e.g. "config-vars", "endpoint-urls"
```

### Wait subcommands (built-in pollers)

```bash
aws ec2 wait instance-running --instance-ids i-0123456789abcdef0
aws cloudformation wait stack-create-complete --stack-name my-stack
aws s3api wait bucket-exists --bucket my-bucket
aws eks wait cluster-active --name eks-bebet
aws lambda wait function-active --function-name my-fn
aws rds wait db-instance-available --db-instance-identifier prod-db
aws iam wait role-exists --role-name my-role
```

Wait commands exit `0` on success and non-zero with a clear `WaiterError` on terminal failure. Always prefer them to hand-rolled `until / sleep` loops.

---

## OUTPUT FORMATS & JMESPath `--query`

| Format | When to use |
|--------|-------------|
| `json` (default) | Scripts (`jq`), structured pipelines, fixtures |
| `yaml` | Diffable human review of large outputs |
| `yaml-stream` | Long-running operations that emit events as they arrive |
| `text` | Quick interactive grep / awk *in a TTY only* |
| `table` | Human inspection in a TTY |

```bash
# JSON to jq
aws ec2 describe-instances --output json \
  | jq -r '.Reservations[].Instances[] | [.InstanceId, .State.Name, (.Tags[]? | select(.Key=="Name") | .Value)] | @tsv'

# JMESPath equivalent — no jq required
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId, State.Name, Tags[?Key==`Name`]|[0].Value]' \
  --output text

# Server-side filtering on EC2 (most efficient for big fleets)
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
            Name=tag:Environment,Values=prod \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text

# Counting
aws s3api list-objects-v2 --bucket my-bucket --query 'length(Contents)'

# Sort + slice (top 5 largest objects)
aws s3api list-objects-v2 --bucket my-bucket \
  --query 'reverse(sort_by(Contents, &Size))[:5].[Key, Size]' \
  --output table
```

JMESPath is **client-side**. To reduce API load, use server-side filters (`--filters` on `ec2`, `--prefix` on `s3 ls`, `--filter-pattern` on `cloudwatch logs`) *first*, then `--query` on the result.

---

## INPUT FILES, SHORTHAND, AND `--cli-input-json`

### `file://` vs `fileb://`

```bash
# Text: JSON, YAML, CloudFormation templates, IAM policies
aws iam create-policy --policy-name my-policy \
  --policy-document file://policy.json

aws cloudformation deploy --template-file file://template.yaml \
  --stack-name foo --capabilities CAPABILITY_NAMED_IAM

# Binary: zip, png, raw blobs
aws lambda update-function-code --function-name my-fn \
  --zip-file fileb://function.zip

aws cognito-idp set-ui-customization --user-pool-id us-east-1_abc \
  --image-file fileb://logo.png
```

### Shorthand vs JSON parameters

```bash
# Flat map — shorthand fine
aws ec2 create-tags --resources i-0123 --tags Key=Name,Value=web-1 Key=Env,Value=prod

# List of structures — JSON only
aws ec2 run-instances --image-id ami-... --instance-type t4g.medium \
  --tag-specifications '[
    {
      "ResourceType":"instance",
      "Tags":[{"Key":"Name","Value":"web-1"},{"Key":"Env","Value":"prod"}]
    }
  ]'

# Or via file — recommended for anything beyond a couple of lines
aws ec2 run-instances --cli-input-json file://run-instances.json
```

### Skeleton-driven workflow

```bash
# Generate the full input shape with every field present
aws ec2 run-instances --generate-cli-skeleton input > run-instances.json

# Edit, then submit
aws ec2 run-instances --cli-input-json file://run-instances.json

# Generate the output shape (handy for typing downstream consumers)
aws ec2 run-instances --generate-cli-skeleton output > run-instances.output.json
```

`--cli-input-yaml` is also accepted for inputs that want comments / multi-line strings.

---

## PAGINATION

```bash
# Auto-pagination ON by default — single combined JSON
aws s3api list-objects-v2 --bucket huge-bucket > all-objects.json

# Disable — get one API page only (NextToken visible in output)
aws s3api list-objects-v2 --bucket huge-bucket --no-paginate \
  --query 'NextContinuationToken' --output text

# Truncate output but keep API pagination — NextToken returned in JSON for resume
aws ec2 describe-instances --max-items 50 --output json \
  | jq -r '.NextToken'

# Resume from where you stopped
aws ec2 describe-instances --max-items 50 --starting-token "$NEXTTOKEN"

# Tune API page size (smaller = earlier first byte; useful for slow APIs)
aws logs filter-log-events --log-group-name /aws/lambda/foo \
  --page-size 100
```

Anti-pattern: writing a hand-rolled `while [ -n "$next" ]; do … done` when the CLI already iterates for you. Only opt out (`--no-paginate`) when you specifically want one page.

---

## CANONICAL ONE-LINERS (memorise these)

```bash
# Identity sanity check — first command in every script
aws sts get-caller-identity

# SSO login (one per-day per-session block)
aws sso login --sso-session bebet-sso

# Set up kubeconfig for EKS
aws eks update-kubeconfig --region us-east-1 --name eks-bebet

# Tail CloudWatch logs (CLI v2 native)
aws logs tail /aws/lambda/my-fn --follow --since 5m

# S3 sync with delete + exclude pattern
aws s3 sync ./dist s3://web-assets --delete --exclude "*.map" --acl bucket-owner-full-control

# Presigned URL (1-hour, default)
aws s3 presign s3://my-bucket/key --expires-in 3600

# Invoke Lambda and capture response body (note --cli-binary-format)
aws lambda invoke --function-name my-fn \
  --cli-binary-format raw-in-base64-out \
  --payload '{"input":"value"}' response.json

# CloudFormation deploy + wait (deploy already waits; this is the explicit form)
aws cloudformation deploy --stack-name s --template-file file://t.yaml \
  --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset
aws cloudformation wait stack-create-complete --stack-name s

# ECR login for Docker push
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 111122223333.dkr.ecr.us-east-1.amazonaws.com

# Get an SSM parameter (string or SecureString)
aws ssm get-parameter --name /app/prod/db_url --with-decryption \
  --query 'Parameter.Value' --output text

# Assume role one-shot, export creds for downstream tools
eval $(aws sts assume-role \
  --role-arn arn:aws:iam::111122223333:role/Foo \
  --role-session-name local-cli \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text \
  | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')

# Switch profile for one command (no env-var pollution)
aws --profile bebet-billing s3 ls

# Expose a temporary endpoint override (LocalStack)
AWS_ENDPOINT_URL=http://localhost:4566 aws s3 mb s3://test-bucket
```

---

## CI / CD POSTURE — GITHUB ACTIONS REFERENCE

```yaml
permissions:
  id-token: write   # required for OIDC federation
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS credentials (OIDC, no secrets)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111122223333:role/GitHubDeployRole
          aws-region: us-east-1
      - name: Sanity check
        run: aws sts get-caller-identity --output json
      - name: Deploy
        env:
          AWS_PAGER: ""                # never let `less` hang the runner
        run: |
          aws cloudformation deploy \
            --stack-name app \
            --template-file infra/cfn.yaml \
            --no-cli-pager \
            --capabilities CAPABILITY_NAMED_IAM
```

Rules in CI:

- Always `permissions: id-token: write` + `aws-actions/configure-aws-credentials@v4` with a role ARN.
- Never store `aws_access_key_id` in GitHub Actions secrets.
- Always set `AWS_PAGER: ""` *or* pass `--no-cli-pager` — defaults to `less` and hangs the runner otherwise.
- Always `--output json` and parse with `jq`. Never `--output text` + `awk`.
- Always run `aws sts get-caller-identity` as the first step after credential setup. If it fails, the rest will fail less informatively.

---

## ALIASES & AUTOPROMPT (developer ergonomics)

`~/.aws/cli/alias`:

```ini
[toplevel]

# Subcommand alias — extends the CLI with a new shape
whoami = sts get-caller-identity --output table

# Shell alias (note the leading "!")
running = !aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`]|[0].Value, PrivateIpAddress]' \
  --output table

# Per-account region pinning
prod = !aws --profile bebet-prod --region us-east-1
```

Usage: `aws whoami`, `aws running`, `aws prod s3 ls`.

Autoprompt for interactive use (suggest commands after typos / partial input):

```bash
# Always-on
export AWS_CLI_AUTO_PROMPT=on

# On-partial — only prompts on ambiguous / failed completions (recommended)
export AWS_CLI_AUTO_PROMPT=on-partial
```

Tab completion (bash/zsh):

```bash
complete -C aws_completer aws       # bash
# or for zsh, use the bundled `aws_zsh_completer.sh` from the install bundle
```

---

## RETRY & ENDPOINT TUNING

```ini
# In ~/.aws/config, per profile
retry_mode    = adaptive       # legacy | standard | adaptive
max_attempts  = 10             # cap; default 3
parameter_validation = true    # default; turn off only for breaking-CLI-version testing

# Per-service endpoint override (CLI v2.13+)
[services bebet-localstack]
s3 =
  endpoint_url = http://localhost:4566
dynamodb =
  endpoint_url = http://localhost:4566

[profile localstack]
services = bebet-localstack
```

Ad hoc:

```bash
aws --endpoint-url http://localhost:4566 s3 ls
AWS_ENDPOINT_URL_S3=http://localhost:4566 aws s3 ls
AWS_RETRY_MODE=adaptive AWS_MAX_ATTEMPTS=10 aws ec2 describe-instances
```

Use `adaptive` retries for high-throughput jobs that hit `Throttling` on rate-limited APIs (CloudWatch, DDB, IAM); standard 3-attempt is fine for everything else.

---

## DEBUGGING — `aws --debug`

```bash
aws --debug s3 ls 2>&1 | tee aws-debug.log

# Sanitize before sharing
aws --debug s3 ls 2>&1 \
  | grep -v -iE '(authorization|x-amz-security-token|aws_access_key|aws_secret_access|signature=)' \
  > aws-debug.sanitized.log
```

`--debug` prints:

- The full URL with query string (region + endpoint).
- The signed `Authorization` header (contains your **access key ID** verbatim).
- The request body and unsigned + signed canonical request.
- The full response body and headers (which can also include sensitive fields like `SessionToken`).

Treat the unsanitized log as a credential. Attach to private support tickets only.

Other useful debug paths:

```bash
# Profile resolution trace
aws configure list

# All profiles known
aws configure list-profiles

# Read a specific config value
aws configure get region --profile bebet-prod

# Set a config value programmatically
aws configure set region us-west-2 --profile bebet-prod

# Export current credentials in a format other tools consume
aws configure export-credentials --profile bebet-prod --format env
aws configure export-credentials --profile bebet-prod --format process-credentials
```

---

## EXIT CODES

| Code | Meaning | Action |
|------|---------|--------|
| `0` | Success | continue |
| `1` | Service-side error (4xx/5xx from AWS API) | `--debug`, check IAM, check region |
| `2` | Usage error (typo, missing required arg) | re-read `aws … help` |
| `130` | User interrupt (Ctrl-C) | not an error |
| `252` | Command not found | typo or unsupported on this CLI version |
| `253` | Invalid argument value | shape mismatch — try `--generate-cli-skeleton input` |
| `254` | Resource not found / not recognised | check region + name + account |
| `255` | Unhandled exception in the CLI itself | upgrade CLI, file an issue at github.com/aws/aws-cli |

CI scripts should `set -euo pipefail` and treat anything non-zero as terminal **except** when explicitly handling `aws … || true` for "describe-then-create" idempotency patterns.

---

## ANTI-PATTERNS (flag in review)

| Anti-pattern | Why it's bad | Fix |
|--------------|--------------|-----|
| `aws_access_key_id = AKIA…` checked into repo or Dockerfile | permanent credential leak | revoke key + IAM Identity Center / IRSA / OIDC |
| `--output text` parsed with `awk '{print $3}'` in a script | column order is not contractual | `--output json` + `jq` or `--query` |
| `aws … && sleep 30 && aws …` waiting for a resource | no failure semantics on `sleep` | `aws <svc> wait <state>` |
| Calling `aws sts get-caller-identity` per-loop-iteration in a wrapper | rate-limits STS, slows everything | call once, cache |
| `--debug` output pasted in a public Slack | leaks AKIA… and SessionToken | sanitize, attach to private ticket |
| `--profile` *and* `AWS_PROFILE` set to different values in the same shell | confusing precedence | pick one (CLI flag wins) |
| `[profile default]` in `~/.aws/credentials` | wrong syntax — `credentials` uses bare names | `[default]` |
| `[default]` in `~/.aws/config` with `profile ` prefix | wrong syntax — *only* default is unprefixed | bare `[default]` |
| `aws s3 cp` to set object retention | `s3` high-level doesn't expose object-lock | `aws s3api put-object-retention` |
| `aws lambda update-function-code --zip-file file://function.zip` | `file://` decodes as text → corrupt zip | `fileb://function.zip` |
| `aws cloudformation deploy --template-file fileb://t.yaml` | `fileb://` skips the YAML preprocessor | `file://t.yaml` |
| Long script with no `AWS_PAGER=""` runs in CI | `less` hangs the runner forever | `export AWS_PAGER=""` at top |
| `aws --region us-east-1` hard-coded everywhere | breaks multi-region | `${AWS_REGION:-us-east-1}` or rely on profile |
| `aws s3 sync` without `--delete` when intent is "mirror" | leaves stale objects behind | add `--delete` (and `--dryrun` first) |
| Hard-coded `serviceName` strings in scripts that the next minor renames | silent zero-row drift | prefer service-family discovery via `aws <svc> list-…` first |
| Auto-pagination disabled (`--no-paginate`) "to avoid memory" | actually misses 99% of results | re-enable; use `--page-size` if memory matters |
| `aws ec2 describe-instances --query` that re-derives `Tags[?Key==…].Value` for every column | unreadable | extract to JMESPath let-bindings or to `jq` |
| Using v1 (`pip install awscli`) for new work | EOL 2026-05-01 | install v2 binary |

---

## VERIFICATION CHECKLIST (pre-commit, pre-merge)

- [ ] No long-lived `aws_access_key_id` introduced; identity is SSO / IRSA / OIDC / instance-profile.
- [ ] `AWS_PAGER=""` or `--no-cli-pager` on every CI command.
- [ ] `--output json` in every scripted call; `--output text` only in interactive examples.
- [ ] `--query` JMESPath shape is documented in a comment for non-trivial expressions.
- [ ] `file://` vs `fileb://` is correct for every `--*-file` / `--*-document` / `--zip-file` parameter.
- [ ] Pagination is left to the CLI (default ON) unless there's a comment explaining why `--no-paginate` was used.
- [ ] Every "wait for resource state" uses `aws <svc> wait …`, not a `sleep` loop.
- [ ] `aws sts get-caller-identity` is the first command after credential setup in any new CI workflow.
- [ ] No `--debug` output is committed or pasted publicly without sanitisation.
- [ ] `--profile` and `AWS_PROFILE` agree (or `--profile` is intentional override).
- [ ] Region is sourced from `AWS_REGION` / profile, not hard-coded.
- [ ] Aliases (`~/.aws/cli/alias`) used for repeated long invocations.
- [ ] `retry_mode = adaptive` set on profiles that drive throttle-prone APIs (DDB, IAM, CloudWatch).

---

## REFERENCES (treat as source of truth)

- AWS CLI documentation hub — `https://docs.aws.amazon.com/cli/`
- AWS CLI User Guide v2 — `https://docs.aws.amazon.com/cli/latest/userguide/`
- AWS CLI Command Reference v2 (per-service) — `https://docs.aws.amazon.com/cli/latest/reference/`
- Getting started — `https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html`
- Command structure — `https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-commandstructure.html`
- Code examples (per-service) — `https://docs.aws.amazon.com/cli/latest/userguide/cli_code_examples.html`
- Source repository — `https://github.com/aws/aws-cli`
- AWS SDKs and Tools Reference (shared config / credentials precedence) — `https://docs.aws.amazon.com/sdkref/latest/guide/`
- JMESPath spec — `https://jmespath.org/`
- `aws-actions/configure-aws-credentials` (GitHub Actions OIDC) — `https://github.com/aws-actions/configure-aws-credentials`

When in doubt, run `aws <command> <subcommand> help` *before* asking — the per-operation reference page is the same content the CLI ships with.
