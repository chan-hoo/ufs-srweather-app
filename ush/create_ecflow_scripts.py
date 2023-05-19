#!/usr/bin/env python3

import os
import sys
import argparse
from datetime import datetime
from textwrap import dedent

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

def create_ecflow_scripts(exptdir):
    """ Creates ecFlow job cards and definition script in the specific
    experiment directory

    Args:
        exptdir: experiment directory
    Returns:
        Boolean
    """

    print_input_args(locals())

    #import all environment variables
    import_vars()
    
    #
    #-----------------------------------------------------------------------
    #
    # Create ecFlow job cards and definition script in the experiment directory.
    #
    #-----------------------------------------------------------------------
    #
    print_info_msg(f"""
        Creating ecFlow job cards and definition scripts in the specified 
        experiment directory (exptdir):
          exptdir = '{exptdir}'""", verbose=VERBOSE)
    #
    # Set template file path
    #
    ecflow_script_tmpl_fn = "job_card_template.ecf"
    ecflow_script_tmpl_fp = os.path.join(PARMdir, "ecflow/job_cards", ecflow_script_tmpl_fn)

    #
    # Create list of tasks from task groups
    task_aqm_prep = ["nexus_gfs_sfc", "nexus_emission", "nexus_post_split", "fire_emission", "point_source", "aqm_ics_ext", "aqm_ics", "aqm_lbcs"]
    task_aqm_post = ["pre_post_stat", "post_stat_o3", "post_stat_pm25", "bias_correction_o3", "bias_correction_pm25"]
    task_coldstart = ["get_extrn_ics", "get_extrn_lbcs", "make_ics", "make_lbcs", "run_fcst"]
    task_post = ["run_post"]





        ecflow_script_fp = os.path.join(exptdir, ecflow_script_fn)
    #
    #-----------------------------------------------------------------------
    #
    # Create a multiline variable that consists of a yaml-compliant string
    # specifying the values that the jinja variables in the template file.
    #
    #-----------------------------------------------------------------------
    #
        settings = {
          "dt_atmos": DT_ATMOS,
          "print_esmf": PRINT_ESMF,
          "cpl_aqm": CPL_AQM,
          "atm_omp_num_threads": OMP_NUM_THREADS_RUN_FCST,
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
    #
    #-----------------------------------------------------------------------
    #
    # Call a python script to generate the experiment's actual NEMS_CONFIG_FN
    # file from the template file.
    #
    #-----------------------------------------------------------------------
    #
        try:
            fill_jinja_template(["-q", "-u", settings_str, "-t", ecflow_script_tmpl_fp, "-o", ecflow_script_fp])
        except:
            print_err_msg_exit(
                dedent(
                f"""
            Call to python script fill_jinja_template.py to create the ecFlow job cards
            and definition scripts from a jinja2 template failed.  Parameters passed to 
            this script are:
              Full path to template file:
                ecflow_script_tmpl_fp = '{ecflow_script_tmpl_fp}'
              Full path to output script:
                ecflow_script_fp = '{ecflow_script_fp}'
              Namelist settings specified on command line:\n
                settings =\n\n"""
                )
                + settings_str
            )
            return False

    return True

def parse_args(argv):
    """ Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Creates ecFlow job cards and definition script.'
    )

    parser.add_argument("-r", "--exptdir",
                        dest="exptdir",
                        required=True,
                        help="Experiment directory.")

    parser.add_argument("-p", "--path-to-defns",
                        dest="path_to_defns",
                        required=True,
                        help="Path to var_defns file.")

    return parser.parse_args(argv)

if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    cfg = load_shell_config(args.path_to_defns)
    cfg = flatten_dict(cfg)
    import_vars(dictionary=cfg)
    create_ecflow_scripts(
        exptdir=args.exptdir,
    )


