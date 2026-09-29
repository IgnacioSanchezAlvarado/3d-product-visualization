# Project: 3d-product-visualization

_Owner: igsalvar. Started: 2026-09-29. Status: ready to launch._

## Problem
This repository is the owner's GitHub fork of `aws-solutions-library-samples/guidance-for-realtime-3d-product-visualization-on-aws`: a Rust 3D application streamed with Amazon GameLift Streams, a web front end on S3 + CloudFront + WAF + Lambda, all deployed by a CodePipeline that `make -f makefile.aws deploy/main` creates. The owner deploys it once by hand; nothing here is deployed by the platform. What is missing is everything that makes the demo presentable and controllable from the solution hub: showcase content (story, architecture, screenshots), a `launcher.json` so the demo-launcher can start and stop the stream group capacity, a deploy runbook the owner can follow without re-reading three READMEs, and fork hygiene so the fork stays in sync with upstream. Until then the demo either bills GameLift Streams capacity around the clock or is invisible in meetings.

## Target users
- The owner, an AWS solutions architect: deploys the guidance once from the runbook, then starts the demo from the hub a few minutes before a customer meeting and stops it afterwards. Never types a GameLift Streams capacity command again.
- Colleagues and customers browsing the hub: read the story and the architecture, look at screenshots, click "Open the demo" when it is running. They never see AWS resources or costs beyond the hourly figure on the card.
- The platform's agents and QA: add files to this fork, verify them with a script, and never deploy, destroy or touch the AWS account.

## Experience
1. A visitor opens the hub page `https://hub.igsalvar.people.aws.dev/p/3d-product-visualization` and sees the tagline, the story from the guidance README, the architecture diagram, a screenshot gallery, the repository link and a Start/Stop control reading "stopped" with the hourly cost while running.
2. The owner clicks Start; the launcher raises the stream group capacity from zero to the guidance's minimum, the state goes to "running" and the "Open the demo" button carries the CloudFront URL. A browser session streams the 3D product viewer within a minute.
3. After the meeting the owner clicks Stop (or the launcher's two-hour auto-stop does it): capacity returns to zero, the CDK pipeline and the web front end stay deployed at near-zero idle cost.
4. When the owner wants to deploy from scratch or clean up, `docs/deploy-runbook.md` has the exact commands in order and the exact cleanup, copied from the guidance, never improvised.

## Features
- [must] Showcase content for the hub: `docs/showcase.md` and `docs/showcase/`, following the hub's showcase contract.
  - `docs/showcase.md`: a first section with `tagline:` and `tags:` lines (tags "3D", "streaming", "GameLift Streams", "serverless"); a `## Story` section written from the README's "Why did we build this Guidance?" and "What problem does this Guidance solve?" paragraphs; a `## Architecture` section in markdown that embeds `docs/showcase/architecture.png` and lists the six steps of the README's "Architecture Flow".
  - Architecture diagram: `docs/showcase/architecture.png`, produced from the existing `assets/aws-arch.jpg` with a tool already on the host (ImageMagick or Python Pillow if present). If neither exists, copy the JPG as `docs/showcase/architecture.jpg`, embed that path instead and add a Mermaid block so the hub still renders a diagram.
  - Screenshots in display order: `01-website-placeholder.png` (copy of `deployment/amazon-gamelift-streams/readme/website.png`), `02-app-placeholder.png` (copy of `deployment/placeholder-app/readme/app-1.png`), `03-cicd-placeholder.png` (copy of `deployment/amazon-gamelift-streams/readme/cicd.png`).
  - The `-placeholder` suffix tells QA these are README images, not the running demo. When the owner drops real screenshots into `docs/showcase/`, the placeholders are deleted in the same change.
- [must] `launcher.json` at the repo root following the demo-launcher contract (`~/projects/demo-launcher/docs/demos.schema.md` when it exists, else the fields below), plus `docs/launcher-setup.md` for the owner.
  - Fields: `name` "3d-product-visualization"; `title` "Realtime 3D product visualization on AWS"; `provider` "gamelift-streams"; `region` placeholder `<gamelift-streams-region>`; `keep` = ["CDK pipeline", "web front end (S3, CloudFront, WAF, Lambda)"]; `max_running_minutes` 120.
  - `start` = set the stream group's `always_on_capacity_min` to 2 and `on_demand_capacity_min` to 0, the values the guidance deploys in `deployment/amazon-gamelift-streams/src/infra.aws/cfn-stacks/backend.ts` (neither README states a lower minimum; the owner may lower always-on to 1 after the first deploy). `stop` = both capacities 0.
  - `hourly_cost_usd` 3.00, from the README cost table row "Amazon GameLift Streams, 100 streaming hours per month (g4dn.xlarge equivalent), $150.00": 1.50 USD per allocated capacity hour, times 2 always-on.
  - `url_source` = CloudFormation output `AppURL` of stack `pvagls-main-frontend-<deploy-id>` (export suffix `aws_frontend_website_url_cfn_export_name_suffix` in `config/.env`); `stream_group_id` = CloudFormation output `GLSStreamGroupId` of stack `pvagls-main-backend-<deploy-id>` (an ARN).
  - Every value that exists only after the owner's deploy (stream group ARN, account, region, deploy id) is a `<placeholder>` in the file, never an invented id.
  - `docs/launcher-setup.md` tells the owner exactly which fields to fill after `make -f makefile.aws deploy/main`, where each value comes from (the two stack outputs above, the `.env` stage values), how to verify with the launcher's CLI (`python3 scripts/demo.py 3d-product-visualization status` in the demo-launcher checkout), and that the demo-launcher's `DemoLauncherTargetRoleStack` must be deployed by the owner into the demo account before Start works.
- [must] Deploy runbook for the owner, `docs/deploy-runbook.md`, with the guidance's commands in order and nothing improvised. A line at the top states that agents never run any of these commands.
  - Before deploying: the region choice (GameLift Streams is available in `us-east-1`, `us-west-2`, `eu-central-1`, `ap-northeast-1`; the choice must match `region` in `launcher.json`) and the quota checks from the README "Service limits" section (concurrent streams per stream group, applications per account, stream groups per account, in the Service Quotas console).
  - Commands, in this order: `nvm install 20 && nvm use 20` (README pin 20.10.0 to 20.19.3), `cd deployment/amazon-gamelift-streams`, `make setup`, `make install`, edit `config/.env` for the `main` stage (`aws_main_cli_profile`, `aws_main_account_id`, `aws_main_region`, `aws_main_deploy_id`, `aws_main_cdk_qualifier`), `make -f makefile.aws deploy/main` (rerun if CodeBuild fails, as the README says), then `make -f makefile.aws open-website/main`.
  - After deploying: the four validation steps from the implementation guide (stacks `pvagls-main-cdk-toolkit`, `cicd`, `backend`, `frontend-waf`, `frontend` complete; GameLift Streams application and stream group listed; four S3 buckets; CloudFront distribution enabled), then the values to copy into `launcher.json`.
  - Cleanup copied verbatim from the implementation guide: `make -f makefile.aws destroy/main`, rerun until it succeeds. The README cost table closes the document with its 167.20 USD/month estimate at 100 streaming hours.
- [must] Fork hygiene: upstream sync, `.gitignore` and the verify script that becomes the platform's `verify_cmd`.
  - `scripts/sync-upstream.sh` fetches `upstream` (`aws-solutions-library-samples/guidance-for-realtime-3d-product-visualization-on-aws`, already configured as a remote) and fast-forwards `main` onto `upstream/main`. It refuses to run when the working tree is not clean or when a fast-forward is impossible: it prints the conflicting commits and exits non-zero instead of merging or rebasing. Agents run it only on a clean tree and open a PR to this fork when it changed anything.
  - `.gitignore` keeps the existing Beads lines and adds `node_modules/`, `cdk.out/`, `.beads/` and `deployment/amazon-gamelift-streams/config/.env`. Because upstream tracks that `.env` as a placeholder template, the runbook also tells the owner to run `git update-index --skip-worktree` on it locally before entering real values, so the real account id never reaches a commit.
  - `scripts/verify-showcase.sh` exits 0 when `docs/showcase.md` exists with `tagline:`, `tags:`, `## Story` and `## Architecture`; at least one PNG exists in `docs/showcase/`; `launcher.json` parses with `python3 -m json.tool` and contains the fields listed above; and no file added by this project (`docs/`, `scripts/`, `launcher.json`, `.gitignore`) contains a 12-digit number. Any failure prints which check failed.
- [must] README addition: a short "On the demo hub" section near the top of `README.md` explaining that this fork is shown on the owner's solution hub, that the demo is stopped between meetings (stream group capacity zero, CDK pipeline and web front end kept), that it is started from the hub's card with the hourly cost shown, and that `docs/deploy-runbook.md` and `docs/launcher-setup.md` hold the owner's steps. Nothing else in the README changes.
- [nice] A 20-second GIF of the streamed 3D app, `docs/showcase/04-streaming.gif`, recorded by the owner once the demo runs, for the hub gallery.
- [nice] A Mermaid architecture block in `docs/showcase.md` in addition to the PNG, following the README's six-step flow, so the hub's client-side Mermaid rendering shows a diagram even when images are blocked.

## Constraints
- No secrets, account ids or emails in the repo; `config/.env` is gitignored and skip-worktree'd as described above. Upstream already ships example 12-digit values in `README.md`, `config/.env` and the implementation guide; those upstream lines are left alone and excluded from the check.
- Agents never deploy: no `make -f makefile.aws deploy/*`, `destroy/*`, `start/cicd/*`, no `cdk` and no `aws` write commands. The owner runs the deploy and the cleanup by hand from the runbook. GameLift Streams exists only in `us-east-1`, `us-west-2`, `eu-central-1`, `ap-northeast-1` and quotas must be checked first.
- The Rust application and the CDK code of the guidance are not modified; upstream owns them. This project only adds `docs/`, `docs/showcase/`, `launcher.json`, `scripts/`, the `.gitignore` lines and the README section.
- Pull requests target this fork (`IgnacioSanchezAlvarado/3d-product-visualization`) only, never upstream. `scripts/sync-upstream.sh` only fast-forwards.
- Start and Stop are implemented by the demo-launcher project, not here; this repo only declares the contract in `launcher.json`. The hub is read-only and renders whatever `docs/showcase.md` says.

## Tech stack
Markdown, JSON and bash only; no new dependencies, no build step. Image conversion uses a tool already on the host or falls back to copying the existing JPG. The deployed guidance keeps its own stack (Rust, CDK TypeScript, CodePipeline, GameLift Streams, CloudFront, WAF, Lambda) untouched.

## Success criteria and verification
- On the host, `bash scripts/verify-showcase.sh` exits 0 from the repo root.
- `docs/showcase.md` parses with the hub's contract: a first section with `tagline:` and `tags:` lines, a `## Story` section and a `## Architecture` section that embeds an image present in `docs/showcase/`; at least one PNG in `docs/showcase/` (placeholders count until the owner supplies real screenshots).
- `python3 -m json.tool launcher.json` succeeds and the file contains `name`, `title`, `provider` "gamelift-streams", `region`, `start`, `stop`, `keep`, `hourly_cost_usd` 3.00, `url_source`, `max_running_minutes` 120; unfilled values are `<placeholders>`, not invented ids.
- `https://hub.igsalvar.people.aws.dev/p/3d-product-visualization` shows the story, the architecture image, at least one screenshot and the Start/Stop control reading "stopped". This depends on the solution-hub and demo-launcher projects: while either is not deployed or the launcher does not list this demo, QA reports this criterion as pending, not failed.
- `git grep -E '[0-9]{12}'` over the repository returns only the upstream example lines (`README.md` step 5, `deployment/amazon-gamelift-streams/config/.env` examples, `deployment/amazon-gamelift-streams/readme.md` "AWS Setup") and `Cargo.lock` checksums; nothing in `docs/`, `scripts/`, `launcher.json` or `.gitignore`.
- `bash scripts/sync-upstream.sh` on a clean tree exits 0 (or prints a clear non-zero refusal when a fast-forward is impossible) and never leaves merge markers or a detached HEAD.
- `README.md` contains a section titled "On the demo hub" and no other diff against `upstream/main` outside the additions listed in Features.

## Test accounts and data
- Test identity: the platform's QA identity (`AGP_TEST_USER` / `AGP_TEST_PASSWORD` from the platform's `qa.env`) for the hub page check; the fork itself has no users. QA never starts or stops the demo; it only reads the state.
- Sample inputs: none beyond the files in the repository (`docs/showcase.md`, `docs/showcase/*.png`, `launcher.json`, the two scripts).
- Extra credentials: none.

## Budget
Daily budget: no limit. Total budget: no limit. (Set in the platform's Settings page when needed.)

## Change log
- 2026-09-29: Project enrolled from the owner's deploy note: the fork of the GameLift Streams 3D product visualization guidance gets showcase content for the solution hub, a `launcher.json` for the demo-launcher (Start raises stream group capacity to the deployed minimum, Stop sets it to zero, pipeline and web front end kept), an owner deploy runbook with the guidance's exact commands and cleanup, upstream sync and verify scripts, and a README section; the owner deploys by hand in a GameLift Streams region, agents never deploy.
