#!/bin/bash
set -e

CONF=/usr/local/srs/conf/srs.conf

# Auto-detect public IP for WebRTC ICE candidate if not provided
if [ -n "$CANDIDATE_IP" ]; then
    echo "Using CANDIDATE_IP=$CANDIDATE_IP for WebRTC ICE candidate"
    sed -i "s|candidate.*auto_detect;|candidate       $CANDIDATE_IP;|" "$CONF"
elif [ "$AUTO_DETECT_IP" = "true" ]; then
    # Try common metadata endpoints for cloud VMs
    DETECTED_IP=""
    # Azure
    DETECTED_IP=$(curl -sf -H Metadata:true --max-time 2 \
        "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01" 2>/dev/null) || true
    # AWS
    [ -z "$DETECTED_IP" ] && DETECTED_IP=$(curl -sf --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) || true
    # GCP
    [ -z "$DETECTED_IP" ] && DETECTED_IP=$(curl -sf -H "Metadata-Flavor: Google" --max-time 2 \
        "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" 2>/dev/null) || true
    # Generic fallback
    [ -z "$DETECTED_IP" ] && DETECTED_IP=$(curl -sf --max-time 2 https://ifconfig.me 2>/dev/null) || true

    if [ -n "$DETECTED_IP" ]; then
        echo "Auto-detected public IP: $DETECTED_IP"
        sed -i "s|candidate.*auto_detect;|candidate       $DETECTED_IP;|" "$CONF"
    else
        echo "WARNING: Could not auto-detect public IP. WebRTC may not work."
        echo "Set CANDIDATE_IP explicitly if WebRTC connections fail."
    fi
else
    # No IP config provided — default to localhost for local Docker use
    echo "No CANDIDATE_IP set, defaulting to 127.0.0.1 (local mode)"
    sed -i "s|candidate.*auto_detect;|candidate       127.0.0.1;|" "$CONF"
fi

exec /usr/local/srs/objs/srs -c "$CONF"
