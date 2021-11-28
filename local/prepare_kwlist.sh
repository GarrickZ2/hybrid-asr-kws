#!/bin/bash

kws_prep=$1
#specify the subword segmentation or leave it empyt for words

[ -f path.sh ] && . ../path.sh # source the path.
echo $0 "$@"
. ../utils/parse_options.sh
mkdir -p kws_prep
#create kws word lists
if [ ! -f $kws_prep/kwlist.xml ]; then
    echo '<kwlist ecf_filename="ecf.xml" language="English" encoding="UTF-8" compareNormalize="" version="keywords">' > $kws_prep/kwlist.xml
    n=1
    while IFS='' read -r line || [[ -n "$line" ]]; do
        echo '  <kw kwid="'$n'">' >> $kws_prep/kwlist.xml
        echo '    <kwtext>'$line'</kwtext>' >> $kws_prep/kwlist.xml
        echo '  </kw>' >> $kws_prep/kwlist.xml
        n=`expr $n + 1` 
    done < $kws_prep/keyword.txt
    echo '</kwlist>' >> $kws_prep/kwlist.xml
fi
