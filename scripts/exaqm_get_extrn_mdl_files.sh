#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHdir/source_util_funcs.sh
source_config_for_task "task_get_extrn_ics|task_get_extrn_lbcs" ${GLOBAL_VAR_DEFNS_FP}
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

This is the ex-script for the task that copies or fetches external model
input data from disk, HPSS, or a URL, and stages them to the
workflow-specified location so that they may be used to generate initial
or lateral boundary conditions for the FV3.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set up variables for call to retrieve_data.py
#
#-----------------------------------------------------------------------
#
if [ "${ICS_OR_LBCS}" = "ICS" ]; then
  if [ ${TIME_OFFSET_HRS} -eq 0 ] ; then
    file_set="anl"
  else
    file_set="fcst"
  fi
  fcst_hrs=${TIME_OFFSET_HRS}
  # Paddy Changes Are Below
  # file_names=${EXTRN_MDL_FILES_ICS[@]}
  file_names_orig=${EXTRN_MDL_FILES_ICS[@]}
  # End Paddy Changes
  if [ ${EXTRN_MDL_NAME} = FV3GFS ] || [ "${EXTRN_MDL_NAME}" == "GDAS" ] ; then
    file_type=$FV3GFS_FILE_FMT_ICS
  fi
  # Paddy Changes Are Below
  # input_file_path=${EXTRN_MDL_SOURCE_BASEDIR_ICS:-$EXTRN_MDL_SYSBASEDIR_ICS}
  input_file_path_orig=${EXTRN_MDL_SOURCE_BASEDIR_ICS:-$EXTRN_MDL_SYSBASEDIR_ICS}
  # End Paddy Changes

elif [ "${ICS_OR_LBCS}" = "LBCS" ]; then
  file_set="fcst"
  first_time=$((TIME_OFFSET_HRS + LBC_SPEC_INTVL_HRS))
  if [ ${#FCST_LEN_CYCL[@]} -gt 1 ]; then
    cyc_mod=$(( ${cyc} - ${DATE_FIRST_CYCL:8:2} ))
    CYCLE_IDX=$(( ${cyc_mod} / ${INCR_CYCL_FREQ} ))
    FCST_LEN_HRS=${FCST_LEN_CYCL[$CYCLE_IDX]}
  fi
  last_time=$((TIME_OFFSET_HRS + FCST_LEN_HRS))
  fcst_hrs="${first_time} ${last_time} ${LBC_SPEC_INTVL_HRS}"
  # Paddy Changes Are Below
  # file_names=${EXTRN_MDL_FILES_LBCS[@]}
  file_names_orig=${EXTRN_MDL_FILES_LBCS[@]}
  # End Paddy Changes

  if [ ${EXTRN_MDL_NAME} = FV3GFS ] || [ "${EXTRN_MDL_NAME}" == "GDAS" ] ; then
    file_type=$FV3GFS_FILE_FMT_LBCS
  fi
  # Paddy Changes Are Below
  # input_file_path=${EXTRN_MDL_SOURCE_BASEDIR_LBCS:-$EXTRN_MDL_SYSBASEDIR_LBCS}
  input_file_path_orig=${EXTRN_MDL_SOURCE_BASEDIR_LBCS:-$EXTRN_MDL_SYSBASEDIR_LBCS}
  # End Paddy Changes
fi

data_stores="${EXTRN_MDL_DATA_STORES}"

yyyymmddhh=${EXTRN_MDL_CDATE:0:10}
yyyy=${yyyymmddhh:0:4}
yyyymm=${yyyymmddhh:0:6}
yyyymmdd=${yyyymmddhh:0:8}
mm=${yyyymmddhh:4:2}
dd=${yyyymmddhh:6:2}
hh=${yyyymmddhh:8:2}

# Paddy Changes Are Below
# Reset the staged file names to match the date of the current cycle
print_info_msg "$VERBOSE" "
(paddy) Cycle date: \'${yyyymmddhh}\'."
print_info_msg "$VERBOSE" "
(paddy) Cycle mm: \'${mm}\'."
print_info_msg "$VERBOSE" "
(paddy) Cycle dd: \'${dd}\'."

mmdd="${mm}${dd}"
print_info_msg "$VERBOSE" "
(paddy) Substituting MMDD into all LBCS and ICS filenames: \'${mmdd}\'."

file_names_modified=()
for file_name in "${file_names_orig[@]}"; do
  # Substitute 'MMDD' with the month and day of the current cycle in each file_name
  print_info_msg "$VERBOSE" "
  (paddy) Original file name: \'${file_name}\'."
  modified_file_name=$(echo "$file_name" | sed "s/MMDD/$mmdd/g")
  print_info_msg "$VERBOSE" "
  (paddy) Modifiled file name: \'${modified_file_name}\'."

  # Add the modified file name to the new array
  file_names+=("$modified_file_name")
done
print_info_msg "$VERBOSE" "
(paddy) Original filenames: \'${file_names_orig}\'."
print_info_msg "$VERBOSE" "
(paddy) Modified filenames: \'${file_names}\'."

# Reset the staged file path to match the date of the current cycle
input_file_path=$(echo "$input_file_path_orig" | sed "s/20200816/2020$mmdd/g")
print_info_msg "$VERBOSE" "
(paddy) Original input path: \'${input_file_path_orig}\'."
print_info_msg "$VERBOSE" "
(paddy) Modified input path: \'${input_file_path}\'."
# End Paddy Changes

# Set to use the pre-defined data paths in the machine file (ush/machine/).
PDYext=${yyyymmdd}
cycext=${hh}

# Set an empty members directory
mem_dir=""

#
#-----------------------------------------------------------------------
#
# if path has space in between it is a command, otherwise
# treat it as a template path
#
#-----------------------------------------------------------------------
#
input_file_path=$(eval echo ${input_file_path})
if [[ $input_file_path = *" "* ]]; then
  input_file_path=$(eval ${input_file_path})
fi

#
#-----------------------------------------------------------------------
#
# Set up optional flags for calling retrieve_data.py
#
#-----------------------------------------------------------------------
#
additional_flags=""


if [ -n "${file_type:-}" ] ; then 
  additional_flags="$additional_flags \
  --file_type ${file_type}"
fi

if [ -n "${file_names:-}" ] ; then
  additional_flags="$additional_flags \
  --file_templates ${file_names[@]}"
fi

if [ -n "${input_file_path:-}" ] ; then
  data_stores="disk $data_stores"
  additional_flags="$additional_flags \
  --input_file_path ${input_file_path}"
fi

if [ $SYMLINK_FIX_FILES = "TRUE" ]; then
  additional_flags="$additional_flags \
  --symlink"
fi

if [ $DO_ENSEMBLE == "TRUE" ] ; then
  mem_dir="/mem{mem:03d}"
  member_list=(1 ${NUM_ENS_MEMBERS})
  additional_flags="$additional_flags \
  --members ${member_list[@]}"
fi
#
#-----------------------------------------------------------------------
#
# Call ush script to retrieve files
#
#-----------------------------------------------------------------------
#
EXTRN_DEFNS="${NET}.${cycle}.${EXTRN_MDL_NAME}.${ICS_OR_LBCS}.${EXTRN_MDL_VAR_DEFNS_FN}.sh"

cmd="
python3 -u ${USHdir}/retrieve_data.py \
  --debug \
  --file_set ${file_set} \
  --config ${PARMdir}/data_locations.yml \
  --cycle_date ${EXTRN_MDL_CDATE} \
  --data_stores ${data_stores} \
  --external_model ${EXTRN_MDL_NAME} \
  --fcst_hrs ${fcst_hrs[@]} \
  --ics_or_lbcs ${ICS_OR_LBCS} \
  --output_path ${EXTRN_MDL_STAGING_DIR}${mem_dir} \
  --summary_file ${EXTRN_DEFNS} \
  $additional_flags"

$cmd
export err=$?
if [ $err -ne 0 ]; then
  message_txt="Call to retrieve_data.py failed with a non-zero exit status.
The command was:
${cmd}
"
  err_exit "${message_txt}"
fi
#
#-----------------------------------------------------------------------
#
# Merge GEFS files
#
#-----------------------------------------------------------------------
#
if [ "${EXTRN_MDL_NAME}" = "GEFS" ]; then
    
    # This block of code sets the forecast hour range based on ICS/LBCS
    if [ "${ICS_OR_LBCS}" = "LBCS" ]; then
        fcst_hrs_tmp=( $fcst_hrs )
        all_fcst_hrs_array=( $(seq ${fcst_hrs_tmp[0]} ${fcst_hrs_tmp[2]} ${fcst_hrs_tmp[1]}) )
    else
        all_fcst_hrs_array=( ${fcst_hrs} )
    fi

    # Loop through ensemble member numbers and forecast hours
    for num in $(seq -f "%02g" ${NUM_ENS_MEMBERS}); do
        sorted_fn=( )
        for fcst_hr in "${all_fcst_hrs_array[@]}"; do
            # Read in filenames from $EXTRN_MDL_FNS and sort them
            base_path="${EXTRN_MDL_STAGING_DIR}/mem`printf %03d $num`"
            filenames_array=`awk -F= '/EXTRN_MDL_FNS/{print $2}' $base_path/${EXTRN_DEFNS}`
            for filename in ${filenames_array[@]}; do
                IFS='.' read -ra split_fn <<< "$filename"
                if [ `echo -n $filename | tail -c 2` == `printf %02d $fcst_hr` ] && [ "${split_fn[1]}" == "t${hh}z" ] ; then
                    if [ "${split_fn[2]}" == 'pgrb2a' ] ; then
                        sorted_fn+=( "$filename" )
                    elif [ "${split_fn[2]}" == 'pgrb2b' ] ; then
                        sorted_fn+=( "$filename" )
                    elif [ "${split_fn[2]}" == "pgrb2af`printf %02d $fcst_hr`" ] ; then
                        sorted_fn+=( "$filename" )
                    elif [ "${split_fn[2]}" == "pgrb2bf`printf %02d $fcst_hr`" ] ; then
                        sorted_fn+=( "$filename" )
                    elif [ "${split_fn[2]}" == "pgrb2af`printf %03d $fcst_hr`" ] ; then
                        sorted_fn+=( "$filename" )
                    elif [ "${split_fn[2]}" == "pgrb2bf`printf %03d $fcst_hr`" ] ; then
                        sorted_fn+=( "$filename" )
                    fi
                fi
            done

            # Define filename lists used to check if files exist
            fn_list_1=( ${sorted_fn[0]} ${sorted_fn[1]}
                       "gep$num.t${hh}z.pgrb2.0p50.f`printf %03d $fcst_hr`" )
            fn_list_2=( ${sorted_fn[2]} ${sorted_fn[3]}
                       "gep$num.t${hh}z.pgrb2`printf %02d $fcst_hr`" )
            fn_list_3=( ${sorted_fn[4]} ${sorted_fn[5]}
                       "gep$num.t${hh}z.pgrb2`printf %03d $fcst_hr`" )
            echo ${fn_list_1[@]}
            fn_lists=( "fn_list_1" "fn_list_2" "fn_list_3" )

            # Look for filenames, if they exist, merge files together
            printf "Looking for files in $base_path\n"
            for fn in "${fn_lists[@]}"; do
                fn_str="$fn[@]"
                fn_array=( "${!fn_str}" )
                if [ -f "$base_path/${fn_array[0]}" ] && [ -f "$base_path/${fn_array[1]}" ]; then
                    printf "Found files: ${fn_array[0]} and ${fn_array[1]} \nCreating new file: ${fn_array[2]}\n"
                    cat $base_path/${fn_array[0]} $base_path/${fn_array[1]} > $base_path/${fn_array[2]}
                    merged_fn+=( "${fn_array[2]}" )
                fi
            done
        done
        # If merge files exist, update the extrn_defn file
        merged_fn_str="( ${merged_fn[@]} )"
        printf "Merged files are: ${merged_fn_str} \nUpdating ${EXTRN_DEFNS}\n\n"
        echo "$(awk -F= -v val="${merged_fn_str}" '/EXTRN_MDL_FNS/ {$2=val} {print}' OFS== $base_path/${EXTRN_DEFNS})" > $base_path/${EXTRN_DEFNS}
        merged_fn=()
        mod_fn_list=()
    done
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

