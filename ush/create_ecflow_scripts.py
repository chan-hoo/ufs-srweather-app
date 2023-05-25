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

        ecflow_script_fp = os.path.join(exptdir, ecflow_script_fn)
        
        settings = {
          "ecf_task_name": DT_ATMOS,
          "ecf_task_walltime": PRINT_ESMF,
          "ecf_task_select": CPL_AQM,
          "sched_native_cmd": SCHED_NATIVE_CMD,
          "exptdir": exptdir,
        }
        settings_str = cfg_to_yaml_str(settings)
    
        print_info_msg(
            dedent(
                f"""
                The variable 'settings' specifying values to be used in the 
            '{ecflow_script_fp}' file has been set as follows:\n
            settings =\n\n"""
            ) 
            + settings_str, 
            verbose=VERBOSE,
        )
        
        # Call a python script to generate the ecFlow job card.
        args = ["-o", ecflow_script_fp,
                "-t", ecflow_script_tmpl_fp,
                "-u", settings_str ]
        if not debug:
            args.append("-q")

        try:
            fill_jinja_template(args)
        except:
            raise Exception(
                dedent(
                f"""
            Call to python script fill_jinja_template.py to create the ecFlow job cards
            and definition scripts from a jinja2 template failed.  Parameters passed to
            this script are:
              Full path to template file:
                ecflow_script_tmpl_fp = '{ecflow_script_tmpl_fp}'
              Full path to output script:
                ecflow_script_fp = '{ecflow_script_fp}'
                """
                )
            )




    return True


if __name__ == "__main__":
    create_ecflow_scripts(global_var_defns_fp)
