#!/usr/bin/env bash

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"

if [ $# != 2 ]; then
    echo "Usage: prepare_kws_data.sh <data-dir> <lang-dir>"
    echo "e.g.: prepare_kws_data.sh data/dev10h.seg data/lang_nosp"
    exit 0
fi

in_dir=`utils/make_absolute.sh $1`
lang=`utils/make_absolute.sh $2`
iv_kw_dir=$in_dir/iv_kws
oov_kw_dir=$in_dir/oov_kws

dir_id=${var##*/}

mkdir -p $iv_kw_dir
mkdir -p $oov_kw_dir

# Create the ECF file
if [ ! -f $iv_kw_dir/.ecf.done ]; then
    ./local/create_ecf_file.sh $in_dir/wav.scp $iv_kw_dir/ecf.xml
    cp $iv_kw_dir/ecf.xml $oov_kw_dir/ecf.xml
    touch $iv_kw_dir/.ecf.done
else
    echo "ECF.XML has been created, won't do it again"
    echo "Revome $iv_kw_dir/.ecf.done to do it again"
    echo
fi

# Create the kwlist
if [ ! -f $iv_kw_dir/keyword.txt ]; then
    echo "You can provide your own keywords in keyword.txt in the following format"
    echo "<word1>"
    echo "<word2>"
    echo "<word3>"
    echo "Now we use the template keyword for a quick start"
    cp ./conf/ivkwlist.txt $iv_kw_dir/keyword.txt
    cp ./conf/oovkwlist.txt $oov_kw_dir/keyword.txt
else
    echo "Keywords has been prepared, won't do it again"
    echo "Remove the keyword.txt within $iv_kw_dir to do it again"
    echo
fi

if [ ! -f $iv_kw_dir/.kwlist.done ]; then
    ./local/prepare_kwlist.sh $iv_kw_dir
    ./local/prepare_kwlist.sh $oov_kw_dir
    touch $iv_kw_dir/.kwlist.done
else
    echo "KWLIST has been created, won't do it again"
    echo "Remove $iv_kw_dir/.kwlist.done to do it again"
    echo
fi

# Create RTTM file
if [ ! -f $iv_kw_dir/.rttm.done ]; then
    ./local/create_rttm.sh $dir_id
    cp exp_dev10h.seg/tri5_ali/rttm $oov_kw_dir/rttm
    cp exp_dev10h.seg/tri5_ali/rttm $iv_kw_dir/rttm
    touch $iv_kw_dir/.rttm.done
else
    echo "Has created RTTM file, won't do it again"
    echo "Please remove $iv_kw_dir/.rttm.done and exp_dev10h.seg/"
    echo
fi

# Create hitlist
if [ ! -f $iv_kw_dir/.hitlist.done ]; then
    ./local/create_hitlist.sh $in_dir $lang_dir data/local/lang_nosp exp_dev10h.seg/tri5_ali $iv_kw_dir
    ./local/create_hitlist.sh $in_dir $lang_dir data/local/lang_nosp exp_dev10h.seg/tri5_ali $oov_kw_dir
    touch $iv_kw_dir/.hitlist.done
else
    echo "Has created hitlist file, won't do it again"
    echo "Please remove $iv_kw_dir/.hitlist.done"
    echo
fi

# Setup KWS
if [ ! -f $iv_kw_dir/.prep.done ]; then
    ./local/kws_data_prep.sh $lang $in_dir $iv_kw_dir
    ./local/kws_data_prep.sh $lang $in_dir $oov_kw_dir
    touch $iv_kw_dir/.prep.done
else
    echo "Has finished keyword generation"
    echo "Please remove the $iv_kw_dir/.prep.done to do it again"
    echo
fi

if [ ! -f $iv_kw_dir/.setup.done ]; then
#    ./local/kws_setup.sh \
#    --case_insensitive false\
#    --rttm-file $kw_dir/rttm \
#    $kw_dir/ecf.xml $kw_dir/keyword.txt $lang $in_dir
    touch $iv_kw_dir/.setup.done
fi

echo "Congrats!Data Preparation Finished"
