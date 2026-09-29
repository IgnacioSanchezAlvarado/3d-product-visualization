# Connecting this demo to the demo-launcher

The demo-launcher starts and stops this demo by changing the capacity of its Amazon
GameLift Streams stream group. `launcher.json` at the repository root describes the demo
(the `gamelift-streams` provider of the launcher's `docs/demos.schema.md`); every
account-specific value in it is a `${demo.3d_product_visualization.<field>}` placeholder
that the launcher resolves from its own gitignored `config.json`. Nothing in this
repository ever holds an account id, role ARN, stream group ARN or deploy id.

Do these steps once, after the guidance has been deployed with
`make -f makefile.aws deploy/main` (see `docs/deploy-runbook.md`).

## 1. Collect the values from the deployment

| Launcher field (`demos.3d_product_visualization.*`) | Where the value comes from |
|---|---|
| `account` | `aws_main_account_id` in `deployment/amazon-gamelift-streams/config/.env` |
| `region` | `aws_main_region` in the same `.env` (the GameLift Streams primary region, for example `us-west-2`) |
| `stream_group_id` | CloudFormation output `GLSStreamGroupId` of stack `pvagls-main-backend-<deploy-id>` (the value is the stream group ARN) |
| `role_arn` | Output `RoleArn` of `DemoLauncherTargetRoleStack`, deployed in step 3 |

`<deploy-id>` is `aws_main_deploy_id` from the same `.env` (default `v-001`). The demo
URL the launcher shows on the card is the output `AppURL` of stack
`pvagls-main-frontend-<deploy-id>`; `launcher.json` records both outputs under
`url_source` and `stream_group_source`.

To read the two outputs in the demo account:

```bash
aws cloudformation describe-stacks --stack-name pvagls-main-backend-<deploy-id> \
  --query "Stacks[0].Outputs[?OutputKey=='GLSStreamGroupId'].OutputValue" --output text \
  --region <aws_main_region> --profile <aws_main_cli_profile>

aws cloudformation describe-stacks --stack-name pvagls-main-frontend-<deploy-id> \
  --query "Stacks[0].Outputs[?OutputKey=='AppURL'].OutputValue" --output text \
  --region <aws_main_region> --profile <aws_main_cli_profile>
```

## 2. Fill the launcher's `config.json`

In the demo-launcher checkout, the block `demos.3d_product_visualization` already exists
in `config.example.json`. Copy it into `config.json` (never committed) and set:

```json
"demos": {
  "3d_product_visualization": {
    "account": "<aws_main_account_id>",
    "region": "<aws_main_region>",
    "role_arn": "<RoleArn output of DemoLauncherTargetRoleStack>",
    "stream_group_id": "<GLSStreamGroupId output of pvagls-main-backend-<deploy-id>>"
  }
}
```

Set `links.demo` of the entry to the `AppURL` value if you want the card to link to the
running demo. Then sync the registry so `demos.json` picks up this repository's
`launcher.json`:

```bash
python3 scripts/sync-registry.py <path-to-this-checkout>
```

## 3. Deploy the target role into the demo account

Start does nothing until the launcher can assume a role in the demo account.
`DemoLauncherTargetRoleStack` is context-gated in the demo-launcher checkout and, for
`target=gamelift-streams`, grants only the stream group capacity calls on this demo's
stream group (see `docs/demos.schema.md`, "adding a demo"):

```bash
npx cdk deploy DemoLauncherTargetRoleStack \
  -c target=gamelift-streams -c demo=3d-product-visualization \
  -c trusted_role_arns=<launcher-role-arn>,<AutostopRoleArn> \
  --profile <aws_main_cli_profile> --region <aws_main_region>
```

`trusted_role_arns` lists the launcher Lambda role and the `AutostopRoleArn` output of the
launcher's main stack. Put the stack's `RoleArn` output into `role_arn` above.

## 4. Verify

In the demo-launcher checkout:

```bash
python3 scripts/demo.py 3d-product-visualization status
```

The command reports the current capacity of the stream group. `start` and `stop` on the
same script change it; the launcher stops the demo automatically after
`max_running_minutes` (120).

## Capacity and cost

`start` in `launcher.json` sets `always_on_capacity_min` to 2 and
`on_demand_capacity_min` to 0, the values `deployment/amazon-gamelift-streams/src/infra.aws/cfn-stacks/backend.ts`
deploys, and `hourly_cost_usd` is 3.00 (1.50 USD per allocated capacity hour, times 2,
from the README cost table). After the first deploy you may lower
`always_on_capacity_min` to 1 in `launcher.json`; set `hourly_cost_usd` to 1.50 in the
same change and rerun the registry sync.
