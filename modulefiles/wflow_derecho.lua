help([[
This module loads python environement for running the UFS SRW App on
on the CISL machine Derecho (Cray) 
]])

whatis([===[Loads libraries for running the UFS SRW Workflow on Derecho ]===])

load(pathJoin("ncarenv", os.getenv("ncarenv_ver") or "23.06"))

append_path("MODULEPATH","/glade/work/epicufsrt/contrib/derecho/rocoto/modulefiles")
load("rocoto")

unload("python")

prepend_path("MODULEPATH","/glade/work/epicufsrt/contrib/derecho/miniconda3/modulefiles")
--load("set_pythonpath")

--Paddy tried removing this 19 Dec 2023, because of the 'jinja2 no such module' error.
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate workflow_tools
]===])
end

