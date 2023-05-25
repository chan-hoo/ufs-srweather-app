#!/usr/bin/env python3

import os
import sys
import argparse
from datetime import datetime
from textwrap import dedent
import jinja2 as j2
from jinja2 import meta
import yaml

from python_utils import (
    import_vars, 
    set_env_var, 
    print_input_args, 
    str_to_type,
    print_info_msg, 
    print_err_msg_exit, 
    lowercase, 
    cfg_to_yaml_str,
    load_shell_config,
    flatten_dict,
)

from fill_jinja_template import fill_jinja_template

def create_ecflow_scripts(global_var_defns_fp):
    """ Creates ecFlow job cards and definition script in the specific
    experiment directory."""

    cfg = load_shell_config(global_var_defns_fp)
    cfg = flatten_dict(cfg)
    import_vars(dictionary=cfg)

    #
    #-----------------------------------------------------------------------
    #
    # Create ecFlow job cards and definition script in the experiment directory.
    #
    #-----------------------------------------------------------------------
    #
    print_info_msg(f"""
        Creating ecFlow job cards and definition scripts in the specified 
        experiment directory (EXPTDIR):
          EXPTDIR = '{EXPTDIR}'""", verbose=VERBOSE)
    #
    # Set template file path
    #
    ecflow_script_tmpl_fn = "job_card_template.ecf"
    ecflow_script_tmpl_fp = os.path.join(PARMdir, "wflow/ecflow/job_cards", ecflow_script_tmpl_fn)

    #
    #-----------------------------------------------------------------------
    #
    # Load WFLOW_MANAGE_YAML file (wflow_manage_defns.yaml) into a dictionary
    #
    #-----------------------------------------------------------------------
    #
    with open(WFLOW_MANAGE_YAML_FP, "r") as fn:
        wmgn = yaml.load(fn, Loader=yaml.SafeLoader)

    task_list = list(wmgn["tasks"].keys())
    task_single = [ tsk for tsk in task_list if tsk.startswith('task_') ]
    task_meta = [ tsk for tsk in task_list if tsk.startswith('metatask_') ]
   
    #
    #-----------------------------------------------------------------------
    #
    # create job cards for single tasks
    #
    #-----------------------------------------------------------------------
    #
    for tsk in task_single:

        task_name = tsk.replace('task_',"")
        print_info_msg(f"""Creating ecFlow job card for '{task_name}'...""")
        ecflow_script_fn = f"j{task_name}.ecf"
        ecflow_script_fp = os.path.join(EXPTDIR, "ecf/scripts", ecflow_script_fn)

        task_nnodes = wmgn["tasks"][tsk]["nnodes"]
        task_ppn = wmgn["tasks"][tsk]["ppn"]
        task_walltime = wmgn["tasks"][tsk]["walltime"]

        if "memory" in list(wmgn["tasks"][tsk].keys()):
            task_memory = wmgn["tasks"][tsk]["memory"]
        else:
            task_memory = "2G"

        task_omp_vn = f"OMP_NUM_THREADS_{task_name.upper()}"
        if task_omp_vn in cfg:
            task_omp = cfg[task_omp_vn]
        else:
            task_omp = "1"

        task_ncpus = str(int(task_omp)*int(task_ppn))
        task_select = f"select={task_nnodes}:mpiprocs={task_ppn}:ompthreads={task_omp}:ncpus={task_ncpus}"
       
        settings = {
          "ecf_task_name": task_name,
          "ecf_task_walltime": task_walltime,
          "ecf_task_select": task_select,
          "ecf_task_memory": task_memory,
          "sched_native_cmd": SCHED_NATIVE_CMD,
          "exptdir": EXPTDIR,
        }
        settings_str = cfg_to_yaml_str(settings)
            
        # Call a python script to generate the ecFlow job card.
        args = ["-q",
                "-o", ecflow_script_fp,
                "-t", ecflow_script_tmpl_fp,
                "-u", settings_str ]

        try:
            fill_jinja_template(args)
        except:
            raise Exception(
                dedent(
                f"""Call to create the ecFlow job card for '{task_name}' failed."""
                )
            )




    return True


if __name__ == "__main__":
    create_ecflow_scripts(global_var_defns_fp)
