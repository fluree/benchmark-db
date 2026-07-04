# Amazon Neptune — DBLP-core setup & load

Neptune is a **managed** service, so it doesn't follow the "apt-get install engine,
load, serve natively" pattern of the other engines. Instead you:

1. Provision a Neptune cluster (one `db.r8g.xlarge` writer = **4 vCPU / 32 GB**, matching
   the Fluree box) **in the same VPC** as the benchmark EC2 boxes.
2. Stage the DBLP-core data in S3 as **gzip-split N-Triples** (the loader parallelizes
   across files, not within one file).
3. Drive the **bulk loader** from an in-VPC client and read the load time from the
   loader status API (`overallStatus.totalTimeSpent`).

The matched **Fluree** run is the existing [`fluree.md`](fluree.md) /
[`dblp-core-fluree.sh`](../bootstrap/dblp-core-fluree.sh) flow, launched on an
EC2 **`r8g.xlarge`** (4c/32 GB, ARM) instead of `m7a.4xlarge` — same size as the
Neptune instance. Install via the **official installer** (`labs.flur.ee`), which ships a
prebuilt `aarch64-unknown-linux-gnu` binary — **v4.1.0** is current and is what installs:

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/fluree/db/releases/latest/download/fluree-db-cli-installer.sh | sh
```

No source build on ARM required.

> **Why no "same physical box".** Neptune can't be co-located with Fluree — it's a
> managed cluster with decoupled storage. "Same machine" here means **same instance
> size** (4c/32 GB): Neptune on its `db.r8g.xlarge`, Fluree on an EC2 `r8g.xlarge`.
> A single EC2 `r8g.xlarge` serves double duty: it runs the native Fluree benchmark
> **and** acts as the in-VPC client that drives the Neptune loader + queries (Neptune's
> endpoint is not publicly reachable).

---

## What's measured

| Metric | Fluree | Neptune |
|---|---|---|
| Load wall-clock | `SECONDS` around `fluree create` | loader `overallStatus.totalTimeSpent` (s) |
| Records loaded | `COUNT(*)` after import | loader `totalRecords` − `totalDuplicates` |
| Throughput | records / load time | records / load time |
| Peak RAM | RSS sampled during import | n/a (managed; CloudWatch `FreeableMemory` only, not comparable) |

`totalTimeSpent` is parse + insert time and **excludes** the S3 file-list fetch, so it's
the closest apples-to-apples to Fluree's import wall-clock. We also record the outer
wall-clock (submit → `LOAD_COMPLETED`) as a sanity bound.

---

## One-time infrastructure (provisioning)

All commands use the harness defaults: profile `fluree-dev`, region `us-east-1`, the
benchmark VPC behind `subnet-0da8167f5eab42c69` / `sg-08f885d356d61376d`. Adjust to taste.

> ⚠️ **These create billable, not-instantly-reversible AWS resources** (a Neptune
> cluster, an IAM role, an S3 gateway endpoint). Tear them down after the run
> (see *Teardown*). Estimated cost: `db.r8g.xlarge` ≈ **$0.58/hr** + storage/IO.

```bash
AWS="aws --profile fluree-dev"
REGION=us-east-1
VPC_ID=$($AWS ec2 describe-subnets --subnet-ids subnet-0da8167f5eab42c69 \
          --query 'Subnets[0].VpcId' --output text)

# 1. IAM role Neptune assumes to read S3 -------------------------------------
cat > /tmp/neptune-trust.json <<'JSON'
{ "Version":"2012-10-17","Statement":[{"Effect":"Allow",
  "Principal":{"Service":"rds.amazonaws.com"},"Action":"sts:AssumeRole"}]}
JSON
$AWS iam create-role --role-name NeptuneBenchLoadS3 \
     --assume-role-policy-document file:///tmp/neptune-trust.json
$AWS iam attach-role-policy --role-name NeptuneBenchLoadS3 \
     --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
ROLE_ARN=$($AWS iam get-role --role-name NeptuneBenchLoadS3 --query 'Role.Arn' --output text)

# 2. S3 gateway VPC endpoint (lets Neptune reach S3 without internet) ---------
RT_IDS=$($AWS ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
         --query 'RouteTables[].RouteTableId' --output text)
$AWS ec2 create-vpc-endpoint --vpc-id "$VPC_ID" \
     --service-name "com.amazonaws.$REGION.s3" \
     --route-table-ids $RT_IDS   # skip if one already exists for this VPC

# 3. Neptune subnet group + cluster + instance -------------------------------
SUBNETS=$($AWS ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
          --query 'Subnets[].SubnetId' --output text)
$AWS neptune create-db-subnet-group --db-subnet-group-name bench-neptune \
     --db-subnet-group-description "DBLP bench" --subnet-ids $SUBNETS

$AWS neptune create-db-cluster --db-cluster-identifier dblp-bench \
     --engine neptune --vpc-security-group-ids sg-08f885d356d61376d \
     --db-subnet-group-name bench-neptune \
     --associated-roles "RoleArn=$ROLE_ARN"

$AWS neptune create-db-instance --db-instance-identifier dblp-bench-1 \
     --db-cluster-identifier dblp-bench --engine neptune \
     --db-instance-class db.r8g.xlarge      # 4 vCPU / 32 GB; r8g = Graviton4, needs Neptune engine >= 1.4.5; drop to db.r6g.xlarge if unavailable

# Wait until available, then grab the writer endpoint:
$AWS neptune wait db-instance-available --db-instance-identifier dblp-bench-1
NEPTUNE_ENDPOINT=$($AWS neptune describe-db-clusters --db-cluster-identifier dblp-bench \
     --query 'DBClusters[0].Endpoint' --output text)
echo "Neptune writer endpoint: $NEPTUNE_ENDPOINT"
```

Notes:
- The cluster's SG (`sg-08f885d356d61376d`) must allow inbound TCP **8182** from the
  benchmark EC2 (same SG → add a self-referencing rule, or allow the subnet CIDR).
- Leave **IAM database authentication off** on this throwaway cluster so the loader and
  queries use plain `curl`. If it's on, swap `curl` for `awscurl --service neptune-db`.

---

## Stage the data in S3 (gzip-split N-Triples)

The published data is one 5 GB gzip (`dblp-2026-06-01.nt.gz`). The loader can't split a
single file across threads, so re-shard it into ~32 gzip chunks under a prefix. Run on
any box with the `.nt.gz` and `aws` (e.g. the benchmark EC2):

```bash
SRC=s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz
DST=s3://fluree-benchmark-data/dblp-core/neptune/        # loader 'source' prefix
aws s3 cp "$SRC" - | pigz -dc \
  | split -n l/32 --filter='pigz > $FILE.nt.gz' - /tmp/dblp-part-
aws s3 cp /tmp/ "$DST" --recursive --exclude '*' --include 'dblp-part-*.nt.gz'
```

(32 chunks ≫ the 4 loader threads on a 4-vCPU box, giving the loader full parallelism
with headroom. `-n l/32` splits on line boundaries so no triple is cut.)

---

## Run the load + measure

From the in-VPC benchmark EC2:

```bash
export NEPTUNE_ENDPOINT=dblp-bench.cluster-xxxx.us-east-1.neptune.amazonaws.com
export NEPTUNE_IAM_ROLE_ARN=arn:aws:iam::<acct>:role/NeptuneBenchLoadS3
export AWS_REGION=us-east-1
export S3_NEPTUNE_SOURCE=s3://fluree-benchmark-data/dblp-core/neptune/
export S3_RESULTS=s3://fluree-benchmark-data/runs/<run-id>/neptune
common/bootstrap/dblp-core-neptune.sh
```

The script POSTs the loader job, polls status to completion, and records
`load_time_s` (= `totalTimeSpent`), `records`, `duplicates`, and outer wall-clock to
`~/results/neptune_load.json`, then pushes to `$S3_RESULTS`. See
[`dblp-core-neptune.sh`](../bootstrap/dblp-core-neptune.sh).

After loading, point the query runner at Neptune for the 105-query suite:

```bash
common/run_benchmark.sh \
  --endpoint "https://$NEPTUNE_ENDPOINT:8182/sparql" \
  --accept text/tab-separated-values \
  -r 3 -w 1 -t 180 -o benchmarks/sparqloscope/reports/dblp-core/engines/neptune.tsv
```

---

## Methodology caveats (carry into the report)

- **Managed, not native/co-located.** Neptune runs on its own managed `db.r8g.xlarge`;
  Fluree on an EC2 `r8g.xlarge` of identical size. Not the same physical box.
- **Loader path is Neptune's native-optimal**, exactly as every other engine got its own
  (Virtuoso chunked TTLP, Blazegraph DataLoader, etc.) — documented per-engine.
- **Dedup differs.** Neptune reports `totalDuplicates`; compare net distinct triples
  (Fluree counts 561,544,658 distinct vs 574,218,804 raw lines).
- **Buffer-pool cache** isn't disableable per-query the way the suite clears other
  engines' caches — note cold-vs-warm state for query runs (as the Oxigraph column does).

---

## Teardown

```bash
AWS="aws --profile fluree-dev"
$AWS neptune delete-db-instance --db-instance-identifier dblp-bench-1 --skip-final-snapshot
$AWS neptune wait db-instance-deleted --db-instance-identifier dblp-bench-1
$AWS neptune delete-db-cluster --db-cluster-identifier dblp-bench --skip-final-snapshot
$AWS neptune delete-db-subnet-group --db-subnet-group-name bench-neptune
# IAM role + S3 endpoint can be left or removed; they cost nothing idle.
```
</content>
