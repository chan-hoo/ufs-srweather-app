#! /bin/bash

# 
#-----------------------------------------------------------------------
# 
# Source the variable definitions file and the bash utility functions.
#   
#-----------------------------------------------------------------------
# 
. $USHdir/source_util_funcs.sh
. ${GLOBAL_VAR_DEFNS_FP}
#   
#-----------------------------------------------------------------------
#     
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#     
#-----------------------------------------------------------------------
#       
{ save_shell_opts; . $USHdir/preamble.sh; } > /dev/null 2>&1
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

This is the ex-script for AQM-MANAGER.
========================================================================"

#-----------------------------------------------------------------------
#
# Set variables used in the script
#
#-----------------------------------------------------------------------

ecflow_sid="${envir}_${NET}"

CDATE="${PDY}${cyc}"
GDATE=$($NDATE -06 $CDATE)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)
NEXTDATE=$($NDATE +06 $CDATE)
NEXTPDY=$(echo $NEXTDATE | cut -c1-8)
NEXTcyc=$(echo $NEXTDATE | cut -c9-10)

CURRENTDAYPDY=$(ecflow_client --query variable /${ecflow_sid}/${NET}/${model_ver}/${gcyc}:PDY)00
NEXTDAYPDY_CDATE=$($NDATE +24 $CURRENTDAYPDY)
NEXTDAYPDY=$(echo $NEXTDAYPDY_CDATE | cut -c1-8)

gefs_check=false
gfs_check=false
if [ "${CPL_AQM}" = "TRUE" ] && [ "${DO_REAL_TIME}" = "TRUE" ]; then
  gefs_fp=$(compath.py ${envir}/gefs/${gefs_ver})/gefs.${NEXTPDY}/${NEXTcyc}/chem/sfcsig/geaer.t${NEXTcyc}z.atmf078.nemsio
  gfs_fp=$(compath.py ${envir}/gfs/${gfs_ver})/gfs.${NEXTPDY}/${NEXTcyc}/atmos/gfs.t${NEXTcyc}z.sfcf078.nc

  [[ -f ${gefs_fp} ]] && gefs_check=true
  [[ -f ${gfs_fp} ]] && gfs_check=true
else
  gefs_check=true
  gfs_check=true
fi

found_required_file_for_next_cycle=false
fcst_job_completed=false

# ecFlow flags
release_next_cycle=NO

h_try=1
while [ $h_try -lt 70 ]; do

  #-----------------------------------------------------------------------
  #
  # Set release_next_cycle event when current cycle fcst restart file exist
  #
  #-----------------------------------------------------------------------

  if [ ! ${found_required_file_for_next_cycle} ]; then
    forecast_RESTART_file=$(ls ${COMIN}/RESTART/*coupler.res|wc -l)
    if [ ${forecast_RESTART_file} -ge 1 ] && [ ${gefs_check} ] && [ ${gfs_check} ]; then
      ecflow_client --event release_next_cycle
      found_required_file_for_next_cycle=true
    fi
  fi

  #-----------------------------------------------------------------------
  #
  # Requeue previous cycle when current forecast job is completed
  #
  #-----------------------------------------------------------------------

  if [ ! ${fcst_job_completed} ]; then
    P_state=$(ecflow_client --query state /${ecflow_sid}/${NET}/${model_ver}/${gcyc})
    e_state=$(ecflow_client --query state /${ecflow_sid}/${NET}/${model_ver}/${cyc}/coldstart/jrun_fcst)
    if [ ${e_state} = "complete" ] && [ ${P_state} = "complete" ]; then
      ecflow_client --event requeue_cycle
      ecflow_client --alter change variable PDY $NEXTDAYPDY /${ecflow_sid}/{NET}/${model_ver}/${gcyc}
      ecflow_client --requeue force /${ecflow_sid}/${NET}/${model_ver}/${gcyc}
      fcst_job_completed=true
    fi
  fi 

  h_try=$((h_try+1))
  if [ ${found_required_file_for_next_cycle} ] && [ ${fcst_job_completed} ]; then
    h_try=99
  else
    sleep 300
  fi
done
if [ $h_try -eq 70 ]; then
  exit 70
fi

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
    print_info_msg "
========================================================================
Successfully ran AQM-MANAGER!!!

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

