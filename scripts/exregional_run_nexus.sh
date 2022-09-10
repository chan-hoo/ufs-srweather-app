#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( $READLINK -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs NEXUS.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "CYCLE_DATE" "NEXUS_WORKDIR" "NEXUS_WORKDIR_INPUT" )
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Set OpenMP variables.
#
#-----------------------------------------------------------------------
#
export KMP_AFFINITY=${KMP_AFFINITY_RUN_NEXUS}
export OMP_NUM_THREADS=${OMP_NUM_THREADS_RUN_NEXUS}
export OMP_STACKSIZE=${OMP_STACKSIZE_RUN_NEXUS}
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
source $USHDIR/source_machine_file.sh
eval ${PRE_TASK_CMDS}

nprocs=$(( NNODES_RUN_NEXUS*PPN_RUN_NEXUS ))

if [ -z "${RUN_CMD_UTILS:-}" ] ; then
  print_err_msg_exit "\
  Run command was not set in machine file. \
  Please set RUN_CMD_UTILS for your platform"
else
  RUN_CMD_UTILS=$(eval echo ${RUN_CMD_UTILS})
  print_info_msg "$VERBOSE" "
  All executables will be submitted with command \'${RUN_CMD_UTILS}\'."
fi

#
#-----------------------------------------------------------------------
#
# Move to the NEXUS working directory
#
#-----------------------------------------------------------------------
#
cd_vrfy ${NEXUS_WORKDIR}
#
#-----------------------------------------------------------------------
#
# Copy the NEXUS config files to the tmp directory  
#
#-----------------------------------------------------------------------
#
cp_vrfy ${EXECDIR}/nexus ${NEXUS_WORKDIR}
cp_vrfy ${ARL_NEXUS_DIR}/config/cmaq/*.rc ${NEXUS_WORKDIR}
cp_vrfy ${NEXUS_FIX_DIR}/${NEXUS_GRID_FN} ${NEXUS_WORKDIR}/grid_spec.nc
#
#-----------------------------------------------------------------------
#
# Get the starting and ending year, month, day, and hour of the emission
# time series.
#
#-----------------------------------------------------------------------
#
mm="${CYCLE_DATE:4:2}"
dd="${CYCLE_DATE:6:2}"
hh="${CYCLE_DATE:8:2}"
yyyymmdd="${CYCLE_DATE:0:8}"
# Note: a timezone offset is used to compute the end date. Consequently,
# the code below will only work for forecast lengths up to 24 hours.
start_date=$( date --utc --date "${yyyymmdd} ${hh}" "+%Y%m%d%H" )
end_date=$( date --utc --date @$(( $( date --utc --date "${yyyymmdd} ${hh}" +%s ) + ${FCST_LEN_HRS} * 3600 )) +%Y%m%d%H )
#
#######################################################################
# This will be the section to set the datasets used in $workdir/NEXUS_Config.rc 
# All Datasets in that file need to be placed here as it will link the files 
# necessary to that folder.  In the future this will be done by a get_nexus_input 
# script
NEI2016="TRUE"
TIMEZONES="TRUE"
CEDS="TRUE"
HTAP2010="TRUE"
OMIHTAP="TRUE"
MASKS="TRUE"
NOAAGMD="TRUE"
SOA="TRUE"
EDGAR="TRUE"
MEGAN="TRUE"
MODIS_XLAI="TRUE"
OLSON_MAP="TRUE"
Yuan_XLAI="TRUE"
GEOS="TRUE"
AnnualScalar="TRUE"

NEXUS_INPUT_BASE_DIR=${NEXUS_INPUT_DIR}
########################################################################

#
#----------------------------------------------------------------------
# 
# modify time configuration file
#
cp_vrfy ${ARL_NEXUS_DIR}/utils/python/nexus_time_parser.py .
echo ${start_date} ${end_date} # ${cyc}
./nexus_time_parser.py -f ${NEXUS_WORKDIR}/HEMCO_sa_Time.rc -s $start_date -e $end_date

#
#---------------------------------------------------------------------
#
# set the root directory to the temporary directory
#
cp_vrfy ${ARL_NEXUS_DIR}/utils/python/nexus_root_parser.py .
./nexus_root_parser.py -f ${NEXUS_WORKDIR}/NEXUS_Config.rc -d ${NEXUS_WORKDIR_INPUT}

#
#----------------------------------------------------------------------
# Get all the files needed (TEMPORARILY JUST COPY FROM THE DIRECTORY)
#
if [ "${NEI2016}" = "TRUE" ]; then #NEI2016
    cp_vrfy ${ARL_NEXUS_DIR}/utils/python/nexus_nei2016_linker.py .
    cp_vrfy ${ARL_NEXUS_DIR}/utils/python/nexus_nei2016_control_tilefix.py .
    mkdir_vrfy -p ${NEXUS_WORKDIR_INPUT}/NEI2016v1
    mkdir_vrfy -p ${NEXUS_WORKDIR_INPUT}/NEI2016v1/v2020-07
    mkdir_vrfy -p ${NEXUS_WORKDIR_INPUT}/NEI2016v1/v2020-07/${mm}
    mkdir_vrfy -p ${NEXUS_WORKDIR_INPUT}/NEI2016v1/v2022-07
    mkdir_vrfy -p ${NEXUS_WORKDIR_INPUT}/NEI2016v1/v2022-07/${mm}
    ./nexus_nei2016_linker.py --src_dir ${NEXUS_INPUT_BASE_DIR} --date ${yyyymmdd} --work_dir ${NEXUS_WORKDIR_INPUT} -v "v2020-07"
    ./nexus_nei2016_linker.py --src_dir ${NEXUS_INPUT_BASE_DIR} --date ${yyyymmdd} --work_dir ${NEXUS_WORKDIR_INPUT} -v "v2022-07"
    ./nexus_nei2016_control_tilefix.py -f NEXUS_Config.rc -d ${yyyymmdd}
fi

if [ "${TIMEZONES}" = "TRUE" ]; then # TIME ZONES
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/TIMEZONES ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${MASKS}" = "TRUE" ]; then # MASKS
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/MASKS ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${CEDS}" = "TRUE" ]; then #CEDS
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/CEDS ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${HTAP2010}" = "TRUE" ]; then #CEDS2014
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/HTAP ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${OMIHTAP}" = "TRUE" ]; then #CEDS2014
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/OMI-HTAP_2019 ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${NOAAGMD}" = "TRUE" ]; then #NOAA_GMD
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/NOAA_GMD ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${SOA}" = "TRUE" ]; then #SOA
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/SOA ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${EDGAR}" = "TRUE" ]; then #EDGARv42
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/EDGARv42 ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${MEGAN}" = "TRUE" ]; then #MEGAN
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/MEGAN ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${OLSON_MAP}" = "TRUE" ]; then #OLSON_MAP
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/OLSON_MAP ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${Yuan_XLAI}" = "TRUE" ]; then #Yuan_XLAI
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/Yuan_XLAI ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${GEOS}" = "TRUE" ]; then #GEOS
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/GEOS_0.5x0.625 ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${AnnualScalar}" = "TRUE" ]; then #ANNUAL_SCALAR
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/AnnualScalar ${NEXUS_WORKDIR_INPUT}/
fi

if [ "${MODIS_XLAI}" = "TRUE" ]; then #MODIS_XLAI
    ln_vrfy -sf ${NEXUS_INPUT_BASE_DIR}/MODIS_XLAI ${NEXUS_WORKDIR_INPUT}/
fi


#
#----------------------------------------------------------------------
#
# Execute NEXUS
#
${RUN_CMD_UTILS} ${EXECDIR}/nexus -c NEXUS_Config.rc -r grid_spec.nc -o NEXUS_Expt_ugly.nc || \
print_err_msg_exit "\
Call to execute nexus standalone for the FV3LAM failed."

#
#-----------------------------------------------------------------------
#
# make nexus output pretty
#
cp_vrfy ${ARL_NEXUS_DIR}/utils/python/make_nexus_output_pretty.py .
./make_nexus_output_pretty.py --src ${NEXUS_WORKDIR}/NEXUS_Expt_ugly.nc --grid ${NEXUS_WORKDIR}/grid_spec.nc -o ${NEXUS_WORKDIR}/NEXUS_Expt_pretty.nc -t ${NEXUS_WORKDIR}/HEMCO_sa_Time.rc

#
#-----------------------------------------------------------------------
#
# run MEGAN NCO script
#
cp_vrfy ${ARL_NEXUS_DIR}/utils/run_nco_combine_ant_bio.sh .
./run_nco_combine_ant_bio.sh NEXUS_Expt_pretty.nc NEXUS_Expt.nc

#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
NEXUS has successfully generated emissions files in netcdf format!!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
