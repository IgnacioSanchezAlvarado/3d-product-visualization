**Agents never run any command in this document; only the owner does.**

# Deploy runbook

The owner deploys the guidance by hand, once, from a terminal on their own machine. This runbook collects the exact commands from [README.md](../README.md) ("Deployment Steps") and the [Implementation Guide](../deployment/amazon-gamelift-streams/readme.md) in order. Nothing here is improvised. The platform never deploys this repository.

## 1. Before deploying

### Region

Amazon GameLift Streams is available in these regions:

- US East (N. Virginia), `us-east-1`
- US West (Oregon), `us-west-2`
- Europe (Frankfurt), `eu-central-1`
- Asia Pacific (Tokyo), `ap-northeast-1`

This project targets `us-west-2`. The region entered in `config/.env` (`aws_main_region`) must match the `region` field of the launcher config (`launcher.json`), otherwise the demo-launcher cannot find the stream group to start and stop.

### Quotas

Default quotas may limit the number of concurrent streaming sessions. In the [Service Quotas console](https://console.aws.amazon.com/servicequotas/), search for "GameLift Streams" and check, requesting increases where needed:

- maximum concurrent streams per stream group
- maximum applications per account
- maximum stream groups per account

### Prerequisites

The tools listed in README.md "Prerequisites": Node.js `20.10.0` to `20.19.3`, Git, GNU Make, zip, curl, jq and AWS CLI v2, plus an AWS CLI profile with administrative access in the target account (`aws configure`).

## 2. Protect the env file

`deployment/amazon-gamelift-streams/config/.env` is tracked by git and holds the account id once filled in. Before entering real values, tell git to ignore local changes to it so the account id never reaches a commit:

```bash
git update-index --skip-worktree deployment/amazon-gamelift-streams/config/.env
```

To undo later (for example to pull an upstream change to the file), run `git update-index --no-skip-worktree deployment/amazon-gamelift-streams/config/.env`.

## 3. Deploy

Run these from the repository root, in order.

1. **Select Node.js 20** (README pins `20.10.0` to `20.19.3`)

   ```bash
   nvm install 20 && nvm use 20
   ```

2. **Enter the deployment directory**

   ```bash
   cd deployment/amazon-gamelift-streams
   ```

3. **Install global dependencies** (one-time setup)

   ```bash
   make setup
   ```

4. **Install project dependencies**

   ```bash
   make install
   ```

   If this fails, the npm global package directory is not on `PATH`; see the note in the Implementation Guide ("Local Development").

5. **Configure the main stage**

   Edit `config/.env` and set the `main` stage values:

   ```bash
   # AWS CLI profile name (must exist in ~/.aws/credentials)
   aws_main_cli_profile=<your-cli-profile>

   # Your AWS account ID
   aws_main_account_id=<your-account-id>

   # Deployment region (must support Amazon GameLift Streams; this project uses us-west-2)
   aws_main_region=<your-region>

   # Unique deployment identifier
   aws_main_deploy_id=<your-deploy-id>

   # CDK qualifier (must be alphanumeric, max 10 chars)
   aws_main_cdk_qualifier=<your-cdk-qualifier>
   ```

6. **Deploy the complete infrastructure**

   Bootstraps AWS CDK, deploys the CI/CD infrastructure and triggers the deployment pipeline:

   ```bash
   make -f makefile.aws deploy/main
   ```

   > Warning: slow speed ahead. This takes a bit. If CICD fails (and it might), just run the command again until it succeeds.

   Once the stack deployment finishes, open the AWS CodeBuild console and watch the pipeline (it can take a few minutes to start). Wait until CICD finishes before the next step.

7. **Open the website**

   ```bash
   make -f makefile.aws open-website/main
   ```

   The website is restricted by AWS WAF to the public IP you deployed from. If your IP changes, rerun `make -f makefile.aws deploy/main` or update the WAF IP set in the console.

## 4. After deploying

Validate the deployment as the Implementation Guide describes ("Deployment Validation"). Replace `<your-profile>`, `<your-region>` and `<deploy-id>` with the values from `config/.env`.

1. **CloudFormation stacks** are all `CREATE_COMPLETE` or `UPDATE_COMPLETE`:

   ```bash
   aws cloudformation list-stacks \
     --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
     --profile <your-profile> \
     --region <your-region>
   ```

   Expected stacks:

   - `pvagls-main-cdk-toolkit-<deploy-id>` (in both `us-east-1` and your region)
   - `pvagls-main-cicd-<deploy-id>`
   - `pvagls-main-backend-<deploy-id>`
   - `pvagls-main-frontend-waf-<deploy-id>`
   - `pvagls-main-frontend-<deploy-id>`

2. **GameLift Streams application and stream group** are listed:

   ```bash
   aws gameliftstreams list-applications \
     --profile <your-profile> \
     --region <your-region>
   aws gameliftstreams list-stream-groups \
     --profile <your-profile> \
     --region <your-region>
   ```

3. **Four S3 buckets** exist and contain files (application binaries, website assets, CloudFront access logs, application access logs):

   ```bash
   aws s3 ls --profile <your-profile>
   ```

4. **CloudFront distribution** is deployed and enabled:

   ```bash
   aws cloudfront list-distributions \
     --profile <your-profile> \
     --query 'DistributionList.Items[?Comment==`pvagls-main-frontend-<deploy-id>`]'
   ```

Then follow [docs/launcher-setup.md](./launcher-setup.md) for the values to hand to the demo-launcher (stream group id, application id, CloudFront URL, region), so the hub card can start and stop the demo.

## 5. Cleanup

To remove all the AWS infrastructure for the _main_ stage, from `deployment/amazon-gamelift-streams` run:

```bash
make -f makefile.aws destroy/main
```

> Warning: slow speed ahead. This takes a bit. If cleaning up fails (and it might), just run the command again until it succeeds.

## Cost

From the README cost table: the default deployment in US West (Oregon) with moderate usage (100 streaming hours per month) costs approximately:

| AWS service  | Dimensions | Cost [USD] |
| ----------- | ------------ | ------------ |
| Amazon GameLift Streams | 100 streaming hours per month (g4dn.xlarge equivalent) | $ 150.00 |
| Amazon CloudFront | 50 GB data transfer, 100,000 requests | $ 8.50 |
| Amazon S3 | 10 GB storage, 100,000 PUT/GET requests | $ 0.50 |
| AWS Lambda | 1,000,000 invocations, 128 MB memory | $ 0.20 |
| AWS CodeBuild | 100 build minutes per month | $ 1.00 |
| AWS WAF | 1 Web ACL, 2 rules, 100,000 requests | $ 7.00 |
| **Total estimated cost** | | **$ 167.20/month** |

GameLift Streams bills allocated stream group capacity by the hour. Between meetings the demo-launcher sets capacity to zero, so the idle cost is close to the non-streaming rows only.
