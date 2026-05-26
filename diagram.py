from diagrams import Diagram, Cluster, Edge
from diagrams.aws.storage import S3
from diagrams.aws.compute import Lambda
from diagrams.aws.integration import Eventbridge
from diagrams.aws.security import IAM

graph_attrs = {
    "fontsize": "13",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "ortho",
}

node_attrs = {
    "fontsize": "11",
}

with Diagram(
    "AWS Automated Backup System",
    filename="docs/architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attrs,
    node_attr=node_attrs,
):
    scheduler = Eventbridge("EventBridge Scheduler\nDaily 08:00 UTC")

    with Cluster("AWS · us-east-1"):
        fn = Lambda("Lambda\nbackup-confirmation")
        role = IAM("IAM Execution Role\nS3 Read Only")

        with Cluster("S3 Bucket · backup-dev-{suffix}"):
            bucket = S3("Backup Objects\nVersioning Enabled\nNoncurrent: 7d → Glacier")
            lifecycle = S3("Lifecycle Policy\nStandard → IA 30d\nIA → Glacier 90d\nDelete 365d")

    scheduler >> Edge(label="trigger") >> fn
    fn >> Edge(label="assumes") >> role
    role >> Edge(label="IAM: s3:ListBucket") >> bucket
    fn >> Edge(label="ListObjectsV2 (exec role)") >> bucket
    bucket - Edge(style="dashed", label="manages tiers") - lifecycle
