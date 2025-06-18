#!/bin/bash
# This script should be SOURCED to set up the environment.
# This script assumes that you are in the directory containing the cva6-synthesis repository.


INSTALL_DIR=$(cd .. && pwd)
export OPENROAD_FLOW_SCRIPTS="${INSTALL_DIR}/OpenROAD-flow-scripts"
export NANGATE45_LIB_PATH="${OPENROAD_FLOW_SCRIPTS}/flow/platforms/nangate45"
