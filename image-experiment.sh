#!/usr/bin/env bash

## Copyright (C) 2023 David Miguel Susano Pinto <carandraug@gmail.com>
##
## Copying and distribution of this file, with or without modification,
## are permitted in any medium without royalty provided the copyright
## notice and this notice are preserved.  This file is offered as-is,
## without any warranty.

set -o errexit
set -o nounset
set -o pipefail


function zenity_alphanumeric_entry {
    local prompt=$1

    local extra_prompt="(alphanumeric characters only --- no spaces and no emojis)"
    local final_prompt=""
    local answer=""
    local ntries=0
    until [[ "$answer" =~ ^[[:alnum:]]+$ ]]
    do
        if [[ $ntries -eq 0 ]]
        then
            final_prompt="$prompt"
        else
            final_prompt="$prompt $extra_prompt"
        fi
        answer=`zenity --entry --text "$final_prompt"` || true
        ((ntries = ntries + 1))
    done
    printf "$answer"
}


function image_until_good {
    local cam_id=$1
    local filepath_prefix=$2

    local is_good="no"
    local img_idx=0
    until [[ $is_good == "yes" ]];
    do
        local fpath="${filepath_prefix}-img-${img_idx}.jpg"

        echo "taking image '$fpath'"
        # libcamera-still \
        #     --nopreview \
        #     --camera "$cam_id" \
        #     --output "$fpath"
        # gm convert -resize 700x \
        #            "/srv/images/$fpath" \
        #            "/srv/resized-images/resized-$fpath"
        # gpicview "/srv/resized-images/resized-$fpath"

        ((img_idx = img_idx + 1))
        zenity --question \
               --title "Image check" \
               --no-wrap \
               --text "Was '${fpath}' good enough?" \
            && is_good="yes"
    done
}


function main {
    local imager_ssh_destination=$1

    if ! ssh -o PasswordAuthentication=no "$imager_ssh_destination" exit ;
    then
        zenity --error --modal \
               --title "No alternative to password" \
               --no-wrap \
               --text "SSH keys not configured.  Exiting to avoid pain."
        exit 1
    fi

    local experiment=`zenity_alphanumeric_entry "Enter experiment name"`

    while :
    do
        local nuc=`zenity_alphanumeric_entry "Enter NUC"`

        local nframes=""
        while [[ -z "$nframes" ]];
        do
            ## Abuse the question dialog to ensure we get back a
            ## positive integer.  `--switch` removes the OK/cancel
            ## options.
            nframes=`zenity --question --text "Number of frames:" \
                         --switch \
                         --extra-button "1" \
                         --extra-button "2" \
                         --extra-button "3" \
                         --extra-button "4" \
                         --extra-button "5" \
                         --extra-button "6"` || true
        done

        local i
        for i in `seq 1 $nframes`;
        do
            ## Continue even if the window is closed instead of "OK"
            zenity --info --modal \
                   --title "Waiting for frame" \
                   --ok-label "Ready" \
                   --no-wrap \
                   --text "Press 'Ready' when Frame #${i} is in place." \
                || true

            local preprefix="${experiment}-${nuc}-frame-${i}"
            image_until_good 0 "${prefix}-cam-0"
            image_until_good 1 "${prefix}-cam-1"
        done

        zenity --question --modal \
               --no-wrap \
               --text "Another nuc?" \
            || break
    done
}

main "$@"
