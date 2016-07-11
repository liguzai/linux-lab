#!/bin/bash
#
# Restart nfs server
#

service rpcbind restart
sleep 2
service nfs-kernel-server restart
