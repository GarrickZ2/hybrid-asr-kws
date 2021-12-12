generate_keyword=false
data_dir=$1
lang=data/local/dict_nosp

. utils/parse_options.sh

if [ $# -ne 1 ]; then
    echo "You have to provide the dataset dir "
    echo "Usage: ./local/prepare_kws.sh [--generate_keyword false] <data-dir>"
    echo "e.g. : ./local/prepare_kws.sh --generate_keyword false data/dev"
    echo "If you want to generate random keyword, please set --generate_keyword as true"
    echo "If you want to use your own keyword list, please provide ivkwlist.txt and oovkwlist.txt under <data-dir>"
    echo "ivkwlist.txt contains the in-voc keywords and oovkwlist.txt contains the out-of-voc keywords"
    exit 0

if generate_keyword ; then
    echo "Start to generated random detected keyword."
    echo "Including 2000 In-Voc Keyword and 800 Out-of-Voc Keyword"
    echo "This gonna cost some time, please wait..."
    python create_keyword.py $data_dir/text $lang/lexicon.txt $data_dir
fi

echo "Start to prepare the keyword file for $data_dir"
./local/prepare_kws_data.sh $data_dir data/lang_nosp
echo "Done! You can check the content under dir $data_dir/kws $data_dir/iv_kws and $data_dir/oov_kws"