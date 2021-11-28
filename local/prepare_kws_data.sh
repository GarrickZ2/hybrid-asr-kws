#!/bin/bash

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"


in_dir=`utils/make_absolute.sh $1`
ou_dir=`utils/make_absolute.sh $2`
lang =`utils/make_absolute.sh $3`
kw_dir = $in_dir/kws_data

make -p kw_dir

# Create the ECF file
if [ ! -f $kw_dir/.ecf.done ]; then
    create_ecf_file.sh $in_dir/wav.scp $kw_dir/ecf.xml
    touch $in_dir/.ecf.done
elif
    echo "ECF.XML has been created, won't do it again"
fi

# Create the kwlist
if [ ! -f $kw_dir/keyword.txt ]; then
    echo "You can provide your own keywords in keyword.txt in the following format"
    echo "<word1>"
    echo "<word2>"
    echo "<word3>"
    echo "Now we use the template keyword for a quick start"
    cp ../conf/keyword.txt $kw_dir/keyword.txt
fi

if [ ! -f $in_dir/.kwlist.done ]; then
    prepare_kwlist.sh $kw_dir/keyword.txt
    touch $in_dir/.kwlist.done
fi

# Create RTTM file
if [ ! -f $ou_dir/.rttm.done ]; then
    ali_to_rttm.sh $in_dir $lang $ou_dir
    cp $out_dir/rttm $kw_dir/rttm
    touch $out_dir/.rttm.done
fi

# Setup KWS
if [ ! -f $in_dir/.setup.done ]; then
    kws_data_prep.sh $lang $in_dir $kw_dir

    local/kws_setup.sh \
    --case_insensitive $case_insensitive \
    --rttm-file $ou_dir/rttm \
    $in_dir/ecf.xml $in_dir/keyword.txt $lang $in_dir
    touch $in_dir/.setup.done
fi
