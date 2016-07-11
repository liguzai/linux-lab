#!/bin/bash

## Enable network bridge support

/enable_net_bridge.sh

## Start NFS kernel server
/restart-nfs-server.sh

## Fire the original /startup.sh

/startup.sh
