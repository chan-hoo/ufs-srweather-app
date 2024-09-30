help([[
This module loads python environement for running the UFS SRW App on
the NOAA RDHPC machine Hera
]])

whatis([===[Loads libraries needed for running the UFS SRW App on Hera ]===])

prepend_path("MODULEPATH","/contrib/sutils/modulefiles")
load("sutils")

prepend_path("MODULEPATH", "/scratch1/NCEPDEV/nems/role.epic/spack-stack/spack-stack-1.6.0/envs/fms-2024.01/install/modulefiles/Core")

load("stack-intel/2021.5.0")
load("stack-intel-oneapi-mpi/2021.5.1")

load("py-f90nml/1.4.3")
load("py-jinja2/3.0.3")
load("py-numpy/1.22.3")
load("py-pyyaml/6.0")

load("rocoto")
