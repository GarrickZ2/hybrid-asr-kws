#!/bin/bash 
set -e
set -o pipefail

. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;


dir=dev10h.seg
kind=
data_only=false
fast_path=false
skip_kws=false
skip_stt=false
skip_scoring=false
max_states=150000
extra_kws=true
vocab_kws=false
wip=0.5

. utils/parse_options.sh

if [ $# -ne 1 ]; then
	echo "Usage: $(basename $0) <decode-dataset>"
	echo "e.g. : ./run_decode.sh data/dev"
	echo "Before you use your dataset, please run ./prepare_kws.sh <dataset> first"
	echo "It will prepare all the necessary files for decoding part, it's important for KWS"
	exit 1
fi
dataset_dir=$1

#This seems to be the only functioning way how to ensure the comple
#set of scripts will exit when sourcing several of them together
#Otherwise, the CTRL-C just terminates the deepest sourced script ?
# Let shell functions inherit ERR trap.  Same as `set -E'.
set -o errtrace 
trap "echo Exited!; exit;" SIGINT SIGTERM

dataset_id=${dataset_dir##*/}
dataset_type=${dir%%.*}

#By default, we want the script to accept how the dataset should be handled,
#i.e. of  what kind is the dataset


#The $dataset_type value will be the dataset name without any extrension
eval my_stm_file=$dataset_dir/stm
eval my_ecf_file=$dataset_dir/kws_data/ecf.xml
eval my_kwlist_file=$dataset_dir/kws_data/kwlist.xml
eval my_rttm_file=$dataset_dir/kws_data/rttm
eval my_nj=\$${dataset_type}_nj  #for shadow, this will be re-set when appropriate

my_subset_ecf=false
eval ind=\${${dataset_type}_subset_ecf+x}

if [ "$ind" == "x" ] ; then
	eval my_subset_ecf=\$${dataset_type}_subset_ecf
fi

declare -A my_more_kwlists
eval my_more_kwlist_keys="\${!${dataset_type}_more_kwlists[@]}"
for key in $my_more_kwlist_keys  # make sure you include the quotes there
do
	eval my_more_kwlist_val="\${${dataset_type}_more_kwlists[$key]}"
	my_more_kwlists["$key"]="${my_more_kwlist_val}"
done

echo $my_more_kwlists

#Just a minor safety precaution to prevent using incorrect settings
#The dataset_* variables should be used.
set -e
set -o pipefail
set -u
unset dir
unset kind

nj_max=32

if [ "$nj_max" -lt "$my_nj" ] ; then
	echo "Number of jobs ($my_nj) is too big!"
	echo "The maximum reasonable number of jobs is $nj_max"
	my_nj=$nj_max
fi

####################################################################
##
## FMLLR decoding 
##
####################################################################
decode=exp/tri5/decode_${dataset_id}
if [ ! -f ${decode}/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Decoding with SAT models  on" `date`
	echo ---------------------------------------------------------------------
	utils/mkgraph.sh \
		data/lang_nosp exp/tri5 exp/tri5/graph |tee exp/tri5/mkgraph.log

	mkdir -p $decode
	#By default, we do not care about the lattices for this step -- we just want the transforms
	#Therefore, we will reduce the beam sizes, to reduce the decoding times
	steps/decode_fmllr_extra.sh --skip-scoring false --beam 10 --lattice-beam 4\
		--nj $my_nj --cmd "$decode_cmd" "${decode_extra_opts[@]}"\
		exp/tri5/graph ${dataset_dir} ${decode} |tee ${decode}/decode.log

	touch ${decode}/.done
else
	echo "You have finished decoding on FMLLR"
	echo "You can delete ${decode}/.done to do it again"
	echo
fi

local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
	--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
	--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt \
	"${lmwt_plp_extra_opts[@]}" \
	${dataset_dir} data/lang_nosp ${decode}

local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
	--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
	--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
	"${lmwt_plp_extra_opts[@]}" \
	${dataset_dir} data/lang_nosp ${decode}.si

####################################################################
## SGMM2 decoding 
## We Include the SGMM_MMI inside this, as we might only have the DNN systems
## trained and not PLP system. The DNN systems build only on the top of tri5 stage
####################################################################
decode=exp/sgmm5/decode_fmllr_${dataset_id}
if [ ! -f $decode/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Spawning $decode on" `date`
	echo ---------------------------------------------------------------------
	utils/mkgraph.sh \
		data/lang_nosp exp/sgmm5 exp/sgmm5/graph |tee exp/sgmm5/mkgraph.log

	mkdir -p $decode
	steps/decode_sgmm2.sh --skip-scoring true --use-fmllr true --nj $my_nj \
		--cmd "$decode_cmd" --transform-dir exp/tri5/decode_${dataset_id} "${decode_extra_opts[@]}"\
		exp/sgmm5/graph ${dataset_dir} $decode |tee $decode/decode.log
	touch $decode/.done
else
	echo "You have finished decoding on SGMM2"
	echo "You can delete ${decode}/.done to do it again"
	echo
fi

local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
	--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
	--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
	"${lmwt_plp_extra_opts[@]}" \
	${dataset_dir} data/lang_nosp  exp/sgmm5/decode_fmllr_${dataset_id}

####################################################################
##
## DNN ("compatibility") decoding -- also, just decode the "default" net
##
####################################################################
decode=exp/tri6_nnet/decode_${dataset_id}
if [ -f exp/tri6_nnet/.done ]; then
	if [ ! -f $decode/.done ]; then
		echo ---------------------------------------------------------------------
		echo "Decoding with normal DNN models  on" `date`
		echo ---------------------------------------------------------------------
		mkdir -p $decode
		steps/nnet2/decode.sh \
			--minimize $minimize --cmd "$decode_cmd" --nj $my_nj \
			--beam $dnn_beam --lattice-beam $dnn_lat_beam \
			--skip-scoring false "${decode_extra_opts[@]}" \
			--transform-dir exp/tri5/decode_${dataset_id} \
			exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

		touch $decode/.done
	else
		echo "You have decoded DNN, won't do it again"
		echo "You can delete $decode/.done to decode it again"
		echo
	fi

	local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
		--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
		--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
		"${lmwt_dnn_extra_opts[@]}" \
		${dataset_dir} data/lang_nosp $decode
else
	echo "Won't decode and rescore based on DNN"
	echo "You didn't train a DNN model, you can go to run.sh to train a DNN"
	echo
fi


####################################################################
##
## DNN (ensemble) decoding
##
####################################################################
decode=exp/tri6b_nnet/decode_${dataset_id}
if [ -f exp/tri6b_nnet/.done ]; then
	if [ ! -f $decode/.done ]; then
		echo ---------------------------------------------------------------------
		echo "Decoding with DNN ensemble models  on" `date`
		echo ---------------------------------------------------------------------
		mkdir -p $decode
		steps/nnet2/decode.sh \
			--minimize $minimize --cmd "$decode_cmd" --nj $my_nj \
			--beam $dnn_beam --lattice-beam $dnn_lat_beam \
			--skip-scoring true "${decode_extra_opts[@]}" \
			--transform-dir exp/tri5/decode_${dataset_id} \
			exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

		touch $decode/.done
	else
		echo "You have decoded DNN ensemble, won't do it again"
		echo "You can remove $decode/.done to decode again"
		echo
	fi

	local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
		--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
		--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
		"${lmwt_dnn_extra_opts[@]}" \
		${dataset_dir} data/lang_nosp $decode
else
	echo "Won't decode and rescore based on ensemble DNN"
	echo "You didn't train a ensemble DNN, you can go to run.sh to train it"
	echo
fi

echo "Everything looking good...." 
exit 0
