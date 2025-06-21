export CVA6_REPO_DIR="${INSTALL_DIR}/cva6"
export HPDCACHE_DIR="${CVA6_REPO_DIR}/core/cache_subsystem/hpdcache"
export LOGFILE_DIR="logs/out-$(date +'%Y-%m-%d_%H-%M-%S')"
export TARGET_CFG=$1
TECH_CFG=$2

# Confirm that OpenROAD-flow-scripts is installed
if [ -z "$OPENROAD_FLOW_SCRIPTS" ]; then
  echo "Error: OPENROAD_FLOW_SCRIPTS is not set." >&2
  exit 1
fi

# If tech is nangate45, confirm that it is installed.
if [ "$TECH_CFG" = "nangate45" ] && [ ! -f "${NANGATE45_LIB_PATH}" ]; then
  echo "Error: TECH_CFG is nangate45, but liberty file was not found." >&2
  exit 1
fi

# Confirm that ys script exists.
YOSYS_CVA6_SCRIPT="$INSTALL_DIR/cva6-synthesis/hw/${TARGET_CFG}_${TECH_CFG}.ys"
if [ ! -f "${YOSYS_CVA6_SCRIPT}" ]; then
  echo "Error: yosys script ${YOSYS_CVA6_SCRIPT} not found." >&2
  exit 1
fi

###############################
# Proceed to script execution #
###############################
mkdir -p $LOGFILE_DIR
yosys -c ${YOSYS_CVA6_SCRIPT}
