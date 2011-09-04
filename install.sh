#!/bin/sh

#  install.sh
#  ultra43
#
#  Created by msftguy on 9/4/11.
#  Copyright (c) 2011 __MyCompanyName__. All rights reserved.

function bail {
    echo "Bailing: $*"
    exit 1
}

function isInstalled {
    dpkg -l "$1" | grep -e "^i" >/dev/null
}

function isInstalledOK {
    dpkg -l "$1" | grep -e "^ii" >/dev/null
}

function neuter_deb {
    rm -rf /tmp/_deb_
    dpkg -x $1 /tmp/_deb_ || return 1
    dpkg -e $1 /tmp/_deb_/DEBIAN || return 1

    find /tmp/_deb_/DEBIAN/ -not -name control -type f -delete

    dpkg -b /tmp/_deb_ $1 >/dev/null 2>/dev/null
    result=$?
    
    rm -rf /tmp/_deb_

    return $result
}

function neuter_and_install {
    curl $1 -sS -o /tmp/tmp.deb --location || bail "Can't download ultrasn0w"
    test -f /tmp/tmp.deb || bail "Can't download ultrasn0w"

    neuter_deb /tmp/tmp.deb || bail "Couldn't neuter ultrasn0w.deb"

    dpkg -i /tmp/tmp.deb || bail "Ultrasn0w deb install failed"

    rm /tmp/tmp.deb
}

function nuke_ultrasn0w {
    isInstalled ultrasn0w && {
        isInstalled com.msftguy.ultrasn0w-fix && { dpkg -r com.msftguy.ultrasn0w-fix || bail "Couldn't remove ultrasn0w-fixer" ;} 
        rm /private/var/lib/dpkg/info/ultrasn0w.postinst 2>/dev/null
        rm /private/var/lib/dpkg/info/ultrasn0w.postrm 2>/dev/null
        dpkg -r ultrasn0w
        isInstalled ultrasn0w && {
            bail Could not remove ultrasn0w!
        }
    }
    return 0
}

function ensure_plutil {
    isInstalledOK com.ericasadun.utilities || {
        apt-get install com.ericasadun.utilities
        isInstalledOK com.ericasadun.utilities || bail "Could not install com.ericasadun.utilities, need plutil!"
    }
}

function selfdeploy {
    test -z "$1" && {
        echo "Usage: $0 SSH_HOSTNAME [--apt] [--clean] [--nuke] [-v]"
        exit 0
    }
    echo "Deploying to $1"
    self_dir="$(dirname $0)"
    self_name="$(basename $0)"
    host=$1
    scp "$self_dir/build/Debug/ftp/Ultrasn0wFixer.deb" "$self_dir/$self_name" "root@$host:/tmp/" || bail "Can't copy files to destination"
    shift 
    test -n "$verbose" && bash_opt=-x
    ssh "root@$host" bash $bash_opt "/tmp/$self_name" $*
    exit $?
}

saved_args="$*"


# parse args
while [ -n "$1" ];
do 
    test "$1" == "-v" && verbose=1
    test "$1" == "--verbose" && verbose=1
    test "$1" == "--apt" && apt=1
    test "$1" == "--clean" && clean=1
    test "$1" == "--nuke" && {
        nuke=1
        clean=1
    }
    shift;
done

uname -a | grep ARM >/dev/null || selfdeploy $saved_args


ensure_plutil

plist=/System/Library/LaunchDaemons/com.apple.CommCenterClassic.plist

isInstalledOK com.msftguy.ultrasn0w-fix && test -z "$clean" && {
    echo 'Already installed; nothing to do!'
    echo 'Run with --clean to reinstall!'
    exit 0
}

isInstalledOK ultrasn0w || nuke_ultrasn0w

test -n "$clean" && {
    isInstalled ultrasn0w && nuke_ultrasn0w 
    isInstalled mobilesubstrate && { 
        plutil -rmkey EnvironmentVariables $plist >/dev/null

        dpkg -r mobilesubstrate || bail "Couldn't remove mobilesubstrate" ;
    }
}

test -n "$nuke" && {
    echo "All cleaned"
    exit 0
}

echo 'Making sure mobilesubstrate is installed ..'

isInstalled mobilesubstrate || {
    if [ -n "$apt" ];
    then apt-get install mobilesubstrate;
    else neuter_and_install "http://apt.saurik.com/debs/mobilesubstrate_0.9.3367+6.g629fcfa_iphoneos-arm.deb";
    fi
    isInstalled mobilesubstrate || {
        bail Could not install mobilesubstrate!
    }
    plutil -EnvironmentVariables -dict $plist >/dev/null || bail "Plutil failure #1"
    plutil -EnvironmentVariables -DYLD_INSERT_LIBRARIES -string /Library/MobileSubstrate/MobileSubstrate.dylib $plist >/dev/null || bail "Plutil failure #1"
}

echo 'Installing ultrasn0w.deb ..'

neuter_and_install "http://repo666.ultrasn0w.com/ultrasn0w.deb"

echo "Filter = {Executables = (\"CommCenterClassic\");};" > /Library/MobileSubstrate/DynamicLibraries/ultrasn0w.plist

test -f /tmp/Ultrasn0wFixer.deb || bail "Ultrasn0wFixer.deb not found"

echo 'Installing Ultrasn0wFixer.deb ..'

dpkg -i /tmp/Ultrasn0wFixer.deb

echo 'Reloading CommCenterClassic ..'

sleep 5

launchctl unload $plist
launchctl load $plist

echo 'All done!'



