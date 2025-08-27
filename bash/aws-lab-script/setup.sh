#!/usr/bin/env bash
set -euo pipefail

# =========================
# AWS Lab Setup (VPC → Subnets → IGW → NAT → RT → SG → Key → EC2 → Route53 → ALB)
# Target: WSL2 AlmaLinux with awscli v2
# Default region: ap-northeast-2 (Seoul)
# =========================

# ---- Configurable variables (export before running to override) ----
: "${REGION:=ap-northeast-2}"
: "${TAGKEY:=Name}"
: "${TAG_LAB_KEY:=lab}"
: "${TAG_LAB_VAL:=delete}"               # convenience tag for cleanup
: "${VPC_CIDR:=10.0.0.0/16}"
: "${PUB1_CIDR:=10.0.9.0/24}"
: "${PUB2_CIDR:=10.0.10.0/24}"
: "${PRI1_CIDR:=10.0.1.0/24}"
: "${VPC_NAME:=aws-lab-vpc}"
: "${KEY_NAME:=aws-lab-keypair}"
: "${PUBLIC_SG_NAME:=aws-lab-sg-public}"
: "${PRIVATE_SG_NAME:=aws-lab-sg-private}"
: "${ALB_NAME:=aws-lab-alb}"
: "${TG_NAME:=aws-lab-tg}"
: "${HZ_NAME:=example.com}"              # RFC 2606 reserved; use private hosted zone
: "${INSTANCE_TYPE_PUBLIC:=t2.micro}"    # free-tier friendly
: "${INSTANCE_TYPE_PRIVATE:=t2.micro}"
: "${PUBLIC_INSTANCE_NAME:=lab-www1}"
: "${PRIVATE_INSTANCE_NAME:=lab-www3}"
: "${PUBLIC_HTTP_PORT:=80}"

# Availability Zones (ensure they exist in your account/region)
AZ1="${REGION}a"
AZ2="${REGION}c"

# ---- Helpers ----
require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found"; exit 1; }; }
require aws
require jq
require curl

export AWS_PAGER=""

ts() { date '+%Y-%m-%d %H:%M:%S'; }
say() { echo -e "[$(ts)] $*"; }

# Capture summary
SUMMARY_JSON="setup_summary.json"
echo '{}' > "$SUMMARY_JSON"

save() {
  # save key=value into summary json (flat)
  local key="$1"; shift
  local val="$*"
  jq --arg k "$key" --arg v "$val" '. + {($k): $v}' "$SUMMARY_JSON" > "${SUMMARY_JSON}.tmp" && mv "${SUMMARY_JSON}.tmp" "$SUMMARY_JSON"
}

# ---- Start ----
say "Region: $REGION"
aws sts get-caller-identity >/dev/null || { echo "ERROR: AWS credentials not configured. Run 'aws configure' or 'aws configure sso'."; exit 1; }

# ---- VPC ----
say "Creating VPC ($VPC_CIDR)"
VPC_ID="$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=$TAGKEY,Value=$VPC_NAME},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Vpc.VpcId' --output text)"
save VPC_ID "$VPC_ID"

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
say "VPC created: $VPC_ID"

# ---- Subnets (2x public for ALB, 1x private) ----
say "Creating subnets"
PUB1_ID="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUB1_CIDR" --availability-zone "$AZ1" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-public-${AZ1}}, {Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Subnet.SubnetId' --output text)"
save PUB1_ID "$PUB1_ID"

PUB2_ID="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUB2_CIDR" --availability-zone "$AZ2" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-public-${AZ2}}, {Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Subnet.SubnetId' --output text)"
save PUB2_ID "$PUB2_ID"

PRI1_ID="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRI1_CIDR" --availability-zone "$AZ1" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-private-${AZ1}}, {Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Subnet.SubnetId' --output text)"
save PRI1_ID "$PRI1_ID"

# Auto-assign public IP on public subnets
aws ec2 modify-subnet-attribute --subnet-id "$PUB1_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB2_ID" --map-public-ip-on-launch

say "Subnets created: $PUB1_ID, $PUB2_ID, $PRI1_ID"

# ---- IGW ----
say "Creating Internet Gateway"
IGW_ID="$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-igw},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)"
save IGW_ID "$IGW_ID"
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
say "IGW attached: $IGW_ID"

# ---- EIP + NAT GW (must be in a PUBLIC subnet) ----
say "Allocating EIP for NAT"
EIP_ALLOC_ID="$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)"
save EIP_ALLOCATION_ID "$EIP_ALLOC_ID"

say "Creating NAT Gateway in $PUB1_ID"
NATGW_ID="$(aws ec2 create-nat-gateway --subnet-id "$PUB1_ID" --allocation-id "$EIP_ALLOC_ID" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-natgw},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'NatGateway.NatGatewayId' --output text)"
save NATGW_ID "$NATGW_ID"

say "Waiting for NAT Gateway to become available (this can take several minutes)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NATGW_ID"
say "NAT Gateway available: $NATGW_ID"

# ---- Route Tables ----
say "Creating and associating Route Tables"
PUB_RTB_ID="$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-public-rtb},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'RouteTable.RouteTableId' --output text)"
save PUB_RTB_ID "$PUB_RTB_ID"

aws ec2 create-route --route-table-id "$PUB_RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUB_RTB_ID" --subnet-id "$PUB1_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUB_RTB_ID" --subnet-id "$PUB2_ID" >/dev/null

PRI_RTB_ID="$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=$TAGKEY,Value=${VPC_NAME}-private-rtb},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'RouteTable.RouteTableId' --output text)"
save PRI_RTB_ID "$PRI_RTB_ID"

aws ec2 create-route --route-table-id "$PRI_RTB_ID" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NATGW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PRI_RTB_ID" --subnet-id "$PRI1_ID" >/dev/null

say "Route tables configured: public=$PUB_RTB_ID, private=$PRI_RTB_ID"

# ---- Security Groups ----
say "Creating Security Groups"
SG_PUB_ID="$(aws ec2 create-security-group --vpc-id "$VPC_ID" \
  --group-name "$PUBLIC_SG_NAME" --description "Public SG (SSH + HTTP from MYIP)" \
  --query 'GroupId' --output text)"
save SG_PUBLIC_ID "$SG_PUB_ID"

SG_PRI_ID="$(aws ec2 create-security-group --vpc-id "$VPC_ID" \
  --group-name "$PRIVATE_SG_NAME" --description "Private SG (intra VPC)" \
  --query 'GroupId' --output text)"
save SG_PRIVATE_ID "$SG_PRI_ID"

MYIP="$(curl -s ifconfig.me)/32 || true"
if [[ "$MYIP" == "/32" || -z "$MYIP" ]]; then
  say "WARN: Could not detect public IP; defaulting to 0.0.0.0/0 for demo (NOT recommended)."
  MYIP="0.0.0.0/0"
fi
save MY_PUBLIC_IP "$MYIP"

aws ec2 authorize-security-group-ingress --group-id "$SG_PUB_ID" \
  --ip-permissions \
  "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MYIP,Description=ssh-from-my-ip}]" \
  "IpProtocol=tcp,FromPort=$PUBLIC_HTTP_PORT,ToPort=$PUBLIC_HTTP_PORT,IpRanges=[{CidrIp=$MYIP,Description=http-from-my-ip}]"

aws ec2 authorize-security-group-ingress --group-id "$SG_PRI_ID" \
  --ip-permissions \
  "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$VPC_CIDR,Description=ssh-from-vpc}]" \
  "IpProtocol=-1,FromPort=-1,ToPort=-1,IpRanges=[{CidrIp=$VPC_CIDR,Description=all-from-vpc}]"

say "Security Groups created: public=$SG_PUB_ID, private=$SG_PRI_ID"

# ---- Key Pair ----
say "Creating Key Pair: $KEY_NAME (PEM saved to current directory)"
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  say "Key pair $KEY_NAME already exists in AWS; skipping create (will NOT overwrite local PEM)."
else
  aws ec2 create-key-pair --key-name "$KEY_NAME" \
    --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
  chmod 400 "${KEY_NAME}.pem"
fi
save KEY_NAME "$KEY_NAME"

# ---- AMI (Amazon Linux 2023 latest) ----
say "Finding latest Amazon Linux 2023 AMI"
AMI_ID="$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'reverse(sort_by(Images,&CreationDate))[:1].ImageId' --output text)"
if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
  echo "ERROR: Could not find AL2023 AMI in $REGION"; exit 1;
fi
save AMI_ID "$AMI_ID"
say "AMI: $AMI_ID"

# ---- EC2 Instances ----
say "Launching public instance ($PUBLIC_INSTANCE_NAME)"
PUB_INST_ID="$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE_PUBLIC" \
  --key-name "$KEY_NAME" --subnet-id "$PUB1_ID" --security-group-ids "$SG_PUB_ID" \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=$TAGKEY,Value=$PUBLIC_INSTANCE_NAME},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Instances[0].InstanceId' --output text)"
save PUBLIC_INSTANCE_ID "$PUB_INST_ID"

say "Launching private instance ($PRIVATE_INSTANCE_NAME)"
PRI_INST_ID="$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE_PRIVATE" \
  --key-name "$KEY_NAME" --subnet-id "$PRI1_ID" --security-group-ids "$SG_PRI_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=$TAGKEY,Value=$PRIVATE_INSTANCE_NAME},{Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL}]" \
  --query 'Instances[0].InstanceId' --output text)"
save PRIVATE_INSTANCE_ID "$PRI_INST_ID"

say "Waiting for instances to be running"
aws ec2 wait instance-running --instance-ids "$PUB_INST_ID" "$PRI_INST_ID"

PUB_EIP="$(aws ec2 describe-instances --instance-ids "$PUB_INST_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
PUB_PRIV_IP="$(aws ec2 describe-instances --instance-ids "$PUB_INST_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
PRI_PRIV_IP="$(aws ec2 describe-instances --instance-ids "$PRI_INST_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
save PUBLIC_INSTANCE_PUBLIC_IP "$PUB_EIP"
save PUBLIC_INSTANCE_PRIVATE_IP "$PUB_PRIV_IP"
save PRIVATE_INSTANCE_PRIVATE_IP "$PRI_PRIV_IP"

say "Instances up. Public instance IP: $PUB_EIP"

# ---- Route53 Private Hosted Zone ----
say "Creating Route53 Private Hosted Zone: $HZ_NAME"
CALLER_REF="$(date +%s)"
HZ_ID="$(aws route53 create-hosted-zone --name "$HZ_NAME" \
  --vpc "VPCRegion=$REGION,VPCId=$VPC_ID" --hosted-zone-config PrivateZone=true \
  --caller-reference "$CALLER_REF" --query 'HostedZone.Id' --output text)"
save PRIVATE_HOSTED_ZONE_ID "$HZ_ID"

# Create A record "www" -> private instance IP
TMP_RRSET="$(mktemp)"
cat > "$TMP_RRSET" <<JSON
{
  "Comment": "Add A record for www",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "www.${HZ_NAME}",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{"Value": "${PRI_PRIV_IP}"}]
    }
  }]
}
JSON
aws route53 change-resource-record-sets --hosted-zone-id "$HZ_ID" --change-batch "file://$TMP_RRSET" >/dev/null
rm -f "$TMP_RRSET"
say "Route53 private A record www.${HZ_NAME} -> ${PRI_PRIV_IP}"

# ---- ALB (HTTP) with target group ----
say "Creating ALB and Target Group"
ALB_ARN="$(aws elbv2 create-load-balancer --name "$ALB_NAME" \
  --subnets "$PUB1_ID" "$PUB2_ID" --security-groups "$SG_PUB_ID" \
  --tags Key=$TAGKEY,Value=$ALB_NAME Key=$TAG_LAB_KEY,Value=$TAG_LAB_VAL \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
save ALB_ARN "$ALB_ARN"

TG_ARN="$(aws elbv2 create-target-group --name "$TG_NAME" --protocol HTTP --port $PUBLIC_HTTP_PORT \
  --vpc-id "$VPC_ID" --target-type instance \
  --health-check-protocol HTTP --health-check-port traffic-port --health-check-path / \
  --query 'TargetGroups[0].TargetGroupArn' --output text)"
save TARGET_GROUP_ARN "$TG_ARN"

# Register the public instance as a target (can be changed to private instance with NLB etc.)
aws elbv2 register-targets --target-group-arn "$TG_ARN" --targets "Id=$PUB_INST_ID" >/dev/null

LISTENER_ARN="$(aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port $PUBLIC_HTTP_PORT \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN" \
  --query 'Listeners[0].ListenerArn' --output text)"
save LISTENER_ARN "$LISTENER_ARN"

ALB_DNS="$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)"
save ALB_DNS "$ALB_DNS"
say "ALB DNS: http://${ALB_DNS}"

# ---- Final Summary ----
say "Writing summary to $SUMMARY_JSON"
jq . "$SUMMARY_JSON"

cat <<EOF

================= AWS LAB SETUP COMPLETE =================
Region:              $REGION
VPC:                 $VPC_ID  ($VPC_CIDR)
Public subnets:      $PUB1_ID ($PUB1_CIDR in $AZ1), $PUB2_ID ($PUB2_CIDR in $AZ2)
Private subnet:      $PRI1_ID ($PRI1_CIDR in $AZ1)
IGW:                 $IGW_ID
NAT GW:              $NATGW_ID
RTB (public):        $PUB_RTB_ID
RTB (private):       $PRI_RTB_ID
SG (public):         $SG_PUB_ID
SG (private):        $SG_PRI_ID
Key Pair:            $KEY_NAME  (PEM: ./${KEY_NAME}.pem)
AMI (AL2023):        $AMI_ID
Instance (public):   $PUB_INST_ID  PublicIP=$PUB_EIP  PrivateIP=$PUB_PRIV_IP
Instance (private):  $PRI_INST_ID  PrivateIP=$PRI_PRIV_IP
Route53 (private):   $HZ_ID  www.${HZ_NAME} -> ${PRI_PRIV_IP}
ALB:                 $ALB_ARN
Target Group:        $TG_ARN
Listener:            $LISTENER_ARN
ALB URL:             http://${ALB_DNS}
Summary JSON:        $(pwd)/$SUMMARY_JSON
==========================================================

Tips:
- To SSH public instance: ssh -i ${KEY_NAME}.pem ec2-user@${PUB_EIP}
- Place your web content on the public instance to test ALB health checks (/).
- For teardown, delete resources in reverse dependency order (targets/listener -> ALB -> records/HZ -> instances -> SG -> routes/RTB -> NAT/EIP -> IGW -> subnets -> VPC).
EOF
