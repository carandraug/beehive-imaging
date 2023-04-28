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


function get_y_or_n_answer {
    local prompt=$1

    answer=""
    local ntries=0
    until [[ "$answer" == "y" || "$answer" == "n" ]]
    do
        if [[ $ntries -gt 0 ]]
        then
            printf "Answer 'y' or 'n'\n"
        fi
        printf "${prompt} [y/n] "
        read answer
        ((ntries = ntries + 1))
    done
}


function get_alphanumeric_answer {
    local prompt=$1

    answer=""
    local ntries=0
    until [[ "$answer" =~ ^[[:alnum:]]+$ ]]
    do
        if [[ $ntries -gt 0 ]]
        then
            printf "Alphanumeric characters only (no spaces and no emojis)\n"
        fi
        printf "$prompt"
        read answer
        ((ntries = ntries + 1))
    done
}


function get_positive_integer_answer {
    local prompt=$1

    answer=""
    local ntries=0
    until [[ "$answer" -gt 0 ]]
    do
        if [[ $ntries -gt 0 ]]
        then
            printf "Enter a positive integer\n"
        fi
        printf "$prompt"
        read answer
        ((ntries = ntries + 1))
    done
}


function image_until_good {
    local cam_id=$1
    local filepath_prefix=$2

    local is_good="n"
    local img_idx=0
    until [[ $is_good == "y" ]];
    do
        local fpath="${filepath_prefix}-img-${img_idx}.jpg"

        echo "taking image '$fpath'"
        # libcamera-still \
        #     --nopreview \
        #     --camera "$cam_id" \
        #     --output "$fpath"

        ((img_idx = img_idx + 1))
        get_y_or_n_answer "Is '${fpath}' good enough?"
        is_good=$answer
    done
}


function main {
    get_alphanumeric_answer "Experiment name: "
    local experiment=$answer

    while :
    do
        get_alphanumeric_answer "NUC: "
        local nuc=$answer

        get_positive_integer_answer "Number of frames: "
        local nframes=$answer

        local i
        for i in `seq 1 $nframes`;
        do
            printf "Press enter when frame ${i} is in place for imaging."
            read

            local preprefix="${experiment}-${nuc}-frame-${i}"
            image_until_good 0 "${preprefix}-cam-0"
            image_until_good 1 "${preprefix}-cam-1"
        done

        get_y_or_n_answer "More?"
        if [[ "$answer" == "n" ]];
        then
            break
        fi
    done
}

main "$@"
