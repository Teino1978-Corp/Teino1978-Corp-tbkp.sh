#!/bin/bash
# backup script for incremental backups
tbkp () {
    [[ -z "$1" ]] && ( echo "Usage:";
        echo "tbkp /path/to/dir/"; return 1; )

    fp="$(readlink -f "$1")"; #full path of dir to be used

    if [ -d "$fp" ]; then
        lc="${fp%/*}"; #absolute location to be removed from tar
        bs="$(basename "$fp")"; # basename of dir used in naming
        ct="$(date +%Y%m%d-%H%M)";
        ex="$fp/.tbexclude"; #exclude list recursive
        #sn="$bs-current.snar"; #latest snar filename
        #echo $bs && return 1;

        #write exclude file if not exists
        if [ ! -e "$ex" ]; then
            echo "$bs-initial-*.tar.gz"     >  $ex;
            echo "$bs-incremental-*.tar.gz" >> $ex;
            echo "$bs-*.snar"               >> $ex;
        fi;
        #incremental bkp if last snar exists
        snlist=($(find -type f -iname "$bs-*.snar"));
        if [ ! -z "$snlist" ]; then
            echo "Choose snapshot:";
            echo "[Choose the -current one for only backing up the recentmost change]";
            select opt in ${snlist[*]};
            do
                if [ ! -z "$opt" ]; then break; fi;
                echo "Please choose valid snapshot for backup.";
            done;
            #use this as the snapshot
            sn="$opt"
            echo "Using snapshot from $sn";
            tn="$bs-incremental-$ct.tar.gz"; #name of tar
        else
            #initial bkp
            echo "Making initial backup.";
            tn="$bs-initial-$ct.tar.gz"; #name of tar
            sn="$bs-initial-$ct.snar"; #name of tar
        fi;

        #make l0 backup and write snar file
        tar -cvzpf "$fp/$tn" -C "$lc" "$bs/" --listed-incremental "$fp/$sn" -X "$ex";
        #keep a copy of the most recent snar, used in taking incrementals
        #skip the initial
        [[ "$sn" != "$bs-initial-$ct.snar" ]] && cp "$fp/$sn" "$fp/$bs-incremental-$ct.snar";
        #skip the last used
        [[ "$sn" != "./$bs-lastused.snar" ]] && cp "$fp/$sn" "$fp/$bs-lastused.snar";
    else
        echo "Can only work with a directory.";
    fi;
    #unset fp lc bs ct sn ex tn snlist opt; #no need if not inside .bashrc
    return 0;
}

#restore
trst () {
    [[ -z "$1" ]] && ( echo "To be used with tbkp()."
        echo "Usage:";
        echo "tbkp /path/to/file.tar.gz"; return 1; )

    fp="$(readlink -f "$1")"; #full path of dir to be used

    #if tar.gz valid
    if [ $( tar -tzf "$fp" 1>/dev/null 2>&1 && echo 1) ]; then
        lc="${fp%/*}"; #absolute location to be removed from tar
        bs="$(basename "$fp")"; # basename of dir used in naming

        #if file is an initial backup
        if [ $(echo "$fp" | grep -qi "\-initial\-" && echo 1) ]; then
            echo "Using file $bs as initial backup.";
            inb=$fp;
            #look for incremental backups
            dn="${bs%-initial*}"; #directory name
            inclist=($(find -type f -iname "$dn-incremental-*.tar.gz"));
            #if more than one backup, provide with choice to restore upto a certain point
            if [ ! -z "$inclist" ]; then
                echo "Choose restore point: ";
                select opt in ${inclist[*]};
                do
                    if [ ! -z "$opt" ];then break; fi;
                    echo "Please choose a valid restore point."
                done;
            fi;
            #untar the dir as a new dir in the current dir
            #may create $dn/$dn hierarchy
            tar -xvzpf $inb; 
            if [ ! -z "$inclist" ]; then
                for index in ${!inclist[*]};
                do
                    inf=${inclist[$index]};
                    echo "Untaring $inf"
                    tar --incremental -xvzpf "$lc/$inf";
                    if [ "$inf" == "$opt" ]; then 
                        echo "Restored upto $opt";
                        break;
                    fi;
                done;
            fi;

        #elif file is an incremental backup
        elif [ $(echo "$fp" | grep -qi "\-incremental\-" && echo 1) ]; then
            echo "Looking for the initial backup.";
            #find initial backup
            dn="${bs%-incremental*}"; #directory name
            inb="$(find -type f -iname "$dn-initial-*.tar.gz")";
            #echo $inb
            #if found pass it to ownself as above case.
            if [ ! -z "$inb" ]; then trst "$inb";
            else 
                echo "Cannot find initial backup for $bs.";
                echo "Please check if $dn-initial-<datetime>.tar.gz is in the same directory.";
            fi;

        else
            echo "Need initial backup file to begin restoration.";
        fi;
    else
        echo "Can only work with tar.gz archives.";
    fi;
    #cleanup
    #unset fp lc bs dn inb inclist index opt; #no need if not inside .bashrc
    return 0;
}

#run
[[ -z "$1" ]] && ( echo "Tar based restore script.";
    echo "Usage:";
    echo "bash $0 b[ackup]  /path/to/dir";
    echo "bash $0 r[estore] /path/to/file.tar.gz";
);
if [ "$1" == "b" ]; then shift; tbkp $@; fi;
if [ "$1" == "r" ]; then shift; trst $@; fi;