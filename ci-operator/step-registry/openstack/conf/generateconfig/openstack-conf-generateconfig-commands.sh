#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

CLUSTER_NAME=$(<"${SHARED_DIR}/CLUSTER_NAME")
OPENSTACK_EXTERNAL_NETWORK="${OPENSTACK_EXTERNAL_NETWORK:-$(<"${SHARED_DIR}/OPENSTACK_EXTERNAL_NETWORK")}"
OPENSTACK_COMPUTE_FLAVOR="${OPENSTACK_COMPUTE_FLAVOR:-$(<"${SHARED_DIR}/OPENSTACK_COMPUTE_FLAVOR")}"

if [[ "${CONFIG_TYPE}" == "fipless" ]]; then
  API_VIP=$(<"${SHARED_DIR}"/API_VIP)
  INGRESS_VIP=$(<"${SHARED_DIR}"/INGRESS_VIP)
else
  LB_FIP_IP=$(<"${SHARED_DIR}"/LB_FIP_IP)
  INGRESS_FIP_IP=$(<"${SHARED_DIR}"/INGRESS_FIP_IP)
fi

PULL_SECRET=$(<"${CLUSTER_PROFILE_DIR}"/pull-secret)
SSH_PUB_KEY=$(<"${CLUSTER_PROFILE_DIR}"/ssh-publickey)

CONFIG="${SHARED_DIR}/install-config.yaml"

case "$CONFIG_TYPE" in
  minimal|fipless)
    ;;
  *)
    echo "No valid install config type specified. Please check CONFIG_TYPE"
    exit 1
    ;;
esac

cat > "${CONFIG}" << EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
metadata:
  name: ${CLUSTER_NAME}
networking:
  networkType: ${NETWORK_TYPE}
EOF
if [[ "${CONFIG_TYPE}" == "fipless" ]]; then
cat >> "${CONFIG}" << EOF
  machineNetwork:
  - cidr: $(<"${SHARED_DIR}"/MACHINESSUBNET_SUBNET_RANGE)
EOF
fi
cat >> "${CONFIG}" << EOF
platform:
  openstack:
    cloud:             ${OS_CLOUD}
    computeFlavor:     ${OPENSTACK_COMPUTE_FLAVOR}
EOF
if [[ "${CONFIG_TYPE}" == "minimal" ]]; then
cat >> "${CONFIG}" << EOF
    externalDNS:
      - 1.1.1.1
      - 1.0.0.1
    lbFloatingIP:      ${LB_FIP_IP}
    ingressFloatingIP: ${INGRESS_FIP_IP}
    externalNetwork:   ${OPENSTACK_EXTERNAL_NETWORK}
EOF
elif [[ "${CONFIG_TYPE}" == "fipless" ]]; then
cat >> "${CONFIG}" << EOF
    machinesSubnet:    $(<"${SHARED_DIR}"/MACHINESSUBNET_SUBNET_ID)
    apiVIP:            ${API_VIP}
    ingressVIP:        ${INGRESS_VIP}
EOF
fi
cat >> "${CONFIG}" << EOF
pullSecret: >
  ${PULL_SECRET}
sshKey: |
  ${SSH_PUB_KEY}
EOF

# Lets  check the syntax of yaml file by reading it.
python -c 'import yaml;
import sys;
data = yaml.safe_load(open(sys.argv[1]))' "${SHARED_DIR}/install-config.yaml"
