#!/bin/bash
set -euo pipefail
pass=$1
host=$2
sshpass -f $pass ssh ci@$host.hw.intuicell.com
