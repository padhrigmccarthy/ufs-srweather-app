help([[
This module loads python environement for running SRW on
the MSU machine Hercules
]])

whatis([===[Loads libraries needed for running SRW on Hercules ]===])

load("contrib")
load("rocoto")

prepend_path("MODULEPATH","/work/noaa/epic/role-epic/contrib/hercules/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate regional_workflow
]===])
end
