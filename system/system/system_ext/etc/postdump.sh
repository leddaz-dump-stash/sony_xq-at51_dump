#!/system/bin/sh

# Copyright (C) 2016 Sony Mobile Communications Inc.

src_dir=/data/crashdump
sdcard=/sdcard
target_dir=${sdcard}/CrashDump
crashdata_dir=/data/crashdump/crashdata
partial_tlcore_dir=/data/crashdata
postdumper=/system_ext/bin/post_dumper

variant=`getprop ro.build.type`

get_latest_index()
{
    idx=0
    while [ -e $partial_tlcore_dir/$@$idx ]
    do
        idx=$((idx + 1))
    done

    if [ $idx -ge 10 ]; then
        latest_file=$(ls -t $partial_tlcore_dir | grep -E $@ | head -1)
        idx=${latest_file##*\_}
        idx=$(((idx + 1) % 10))
    fi

    return $idx
}

move_tlcore_system_to_crashdata()
{
    typeset -i num=0
    for s_file in $(ls $@) ; do
        idx=0
        #check any partial tlcore of system dump is present
        if [ "$(ls ${partial_tlcore_dir} | grep -E "tlcore_system_0")" ]; then
            get_latest_index "tlcore_system_0"
            idx=$?
        fi
        echo "Moving $@/$s_file to $partial_tlcore_dir/tlcore_system_0$idx\n"
        cp -a $@/$s_file $partial_tlcore_dir/tlcore_system_0$idx

        if [[ $(getprop persist.odm.systemcrash.ext_soc) == "true" ]]; then
          #Get subsystem number related to 5g modem
          mdm_name=`cat /sys/bus/msm_subsys/devices/subsys$num/name`
          while [ "$mdm_name" != "" ]
          do
             if [ "$mdm_name" == "esoc0" ]; then
               break 1
             fi
             num=$num+1
             mdm_name=`cat /sys/bus/msm_subsys/devices/subsys$num/name`
          done

          #check esoc restart level and copy partial tlcore as tlcore_ext_soc
          if [ $mdm_name == "esoc0" ] && [ "$variant" = "userdebug" ]; then
            mdm_level=`cat /sys/bus/msm_subsys/devices/subsys$num/restart_level`
            if [ $mdm_level == "SYSTEM" ]; then
              cp $@/$s_file $crashdata_dir/tlcore_ext_soc
            fi
          fi
        fi
        if [ $? -eq 0 ] ; then
            rm -r $@/$s_file
        fi
    done
}

move_to_crashdump()
{
    arg=$@
    is_exists=0
    idx=0
    # Rename/move system crash <dumpdir> as <dumpdir_x> incase
    # if already exists in <target_dir> path
    # i.e. <dumpdir_x> can be <dumpdir_1>, <dumpdir_2>..and goes on.
    arg_dir=${arg%_*}
    dir=$arg_dir
    if [ "$(echo $dir | grep -E "crash-")" ]; then
        while [ -e $target_dir/$dir ] && [ ! -e $src_dir/$@/copy.fail ]
        do
            idx=$((idx + 1))
            dir=${arg_dir}_$idx
            is_exists=1
        done
        touch $src_dir/$@/copy.fail
        #Update the dumpstate file if dump is interrupted
        if [ -e $src_dir/$@/dumpstate ]; then
            mv $src_dir/$@/dumpstate $src_dir/$@/dumpstate.fail
        fi
    fi
    if [ -e $src_dir/$@/copy.fail ]; then
        rm -r $target_dir/$dir
    fi
    #Moving from /data/crashdump to /sdcard/CrashDump
    cp -a $src_dir/$@ $target_dir/$dir
    if [ $? -eq 0 ] ; then
        sync
        rm -r $src_dir/$@
        rm -r $target_dir/$dir/copy.fail
    fi
    if [ $is_exists = 1 ]; then
        echo $target_dir/$dir > $src_dir/lastdump
    fi
    echo "$dir"
}

if [ "$variant" = "userdebug" ] ; then
    # At this point encrypted filesystem is accessible. But /sdcard/
    # isn't immediately available. So wait for it.
    for i in $(seq 120); do
        if [ ! -e "${sdcard}/" ] ; then
            log -p i -t postdump "waiting for ${sdcard}/, $i"
            sleep 5
        else
            break
        fi
    done
    if [ ! -e "${target_dir}" ]; then
        mkdir "${target_dir}"
    fi
    if [ -e "${target_dir}" ] && [ -e "${partial_tlcore_dir}" ]; then
        # /sdcard/CrashDump && /data/crashdata
        if [  -e "${src_dir}" ]; then
              for i in $(ls ${src_dir} | grep -E 'crash|lastdump'); do
                   if [ "$i" = "crashdata" ]; then
                       move_tlcore_system_to_crashdata "$src_dir/$i"
                   else
                       path=$(move_to_crashdump $i)
                       if [ "$(echo $path | grep -E "crash-")" ]; then
                         dir=$path
                       fi
                   fi
              done
        fi
        $postdumper
        #copy the ext_soc tlcore into system dump directory
        cp $crashdata_dir/tlcore_ext_soc $target_dir/$dir
        for i in $(ls ${src_dir} | grep -E 'anr|dropbox|log|tombstones|ext_soc'); do
            echo "Deleting dump files in $src_dir/$i/\n"
            rm -r $src_dir/$i/*
        done
        rm $crashdata_dir/tlcore_ext_soc
    fi
fi
