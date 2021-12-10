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
tri5_only=false
wip=0.5

echo "run-4-test.sh $@"

. utils/parse_options.sh

if [ $# -ne 0 ]; then
	echo "Usage: $(basename $0) --type (dev10h|dev2h|eval|shadow)"
	exit 1
fi

#This seems to be the only functioning way how to ensure the comple
#set of scripts will exit when sourcing several of them together
#Otherwise, the CTRL-C just terminates the deepest sourced script ?
# Let shell functions inherit ERR trap.  Same as `set -E'.
set -o errtrace 
trap "echo Exited!; exit;" SIGINT SIGTERM

# Set proxy search parameters for the extended lexicon case.
if [ -f data/.extlex ]; then
	proxy_phone_beam=$extlex_proxy_phone_beam
	proxy_phone_nbest=$extlex_proxy_phone_nbest
	proxy_beam=$extlex_proxy_beam
	proxy_nbest=$extlex_proxy_nbest
fi

dataset_segments=${dir##*.}
dataset_dir=data/$dir
dataset_id=$dir
dataset_type=${dir%%.*}
#By default, we want the script to accept how the dataset should be handled,
#i.e. of  what kind is the dataset

if [ -z ${kind} ] ; then
	if [ "$dataset_type" == "dev2h" ] || [ "$dataset_type" == "dev10h" ] ; then
		dataset_kind=supervised
	else
		dataset_kind=unsupervised
	fi
else
	dataset_kind=$kind
fi

if [ -z $dataset_segments ]; then
	echo "You have to specify the segmentation type as well"
	echo "If you are trying to decode the PEM segmentation dir"
	echo "such as data/dev10h, specify dev10h.pem"
	echo "The valid segmentations types are:"
	echo "\tpem   #PEM segmentation"
	echo "\tuem   #UEM segmentation in the CMU database format"
	echo "\tseg   #UEM segmentation (kaldi-native)"
fi

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
	echo "Spawning decoding with SAT models  on" `date`
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
fi

if ! $fast_path ; then
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
fi

####################################################################
## SGMM2 decoding 
## We Include the SGMM_MMI inside this, as we might only have the DNN systems
## trained and not PLP system. The DNN systems build only on the top of tri5 stage
####################################################################
decode=exp/sgmm5/decode_fmllr_${dataset_id}
if [ -f $decode/.done ]; then
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
fi

if ! $fast_path ; then
	local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
		--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
		--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
		"${lmwt_plp_extra_opts[@]}" \
		${dataset_dir} data/lang  exp/sgmm5/decode_fmllr_${dataset_id}
fi

####################################################################
##
## DNN ("compatibility") decoding -- also, just decode the "default" net
##
####################################################################
if [ -f exp/tri6_nnet/.done ]; then
	decode=exp/tri6_nnet/decode_${dataset_id}
	if [ ! -f $decode/.done ]; then
		mkdir -p $decode
		steps/nnet2/decode.sh \
			--minimize $minimize --cmd "$decode_cmd" --nj $my_nj \
			--beam $dnn_beam --lattice-beam $dnn_lat_beam \
			--skip-scoring true "${decode_extra_opts[@]}" \
			--transform-dir exp/tri5/decode_${dataset_id} \
		exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

	touch $decode/.done
	fi
	local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
		--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
		--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
		"${lmwt_dnn_extra_opts[@]}" \
		${dataset_dir} data/lang $decode
fi


####################################################################
##
## DNN (nextgen DNN) decoding
##
####################################################################
decode=exp/tri6a_nnet/decode_${dataset_id}
if [ ! -f $decode/.done ]; then
	mkdir -p $decode
	steps/nnet2/decode.sh \
		--minimize $minimize --cmd "$decode_cmd" --nj $my_nj \
		--beam $dnn_beam --lattice-beam $dnn_lat_beam \
		--skip-scoring true "${decode_extra_opts[@]}" \
		--transform-dir exp/tri5/decode_${dataset_id} \
	exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

	touch $decode/.done
fi

local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
	--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
	--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
	"${lmwt_dnn_extra_opts[@]}" \
	${dataset_dir} data/lang $decode

####################################################################
##
## DNN (ensemble) decoding
##
####################################################################
decode=exp/tri6b_nnet/decode_${dataset_id}
if [ ! -f $decode/.done ]; then
	mkdir -p $decode
	steps/nnet2/decode.sh \
		--minimize $minimize --cmd "$decode_cmd" --nj $my_nj \
		--beam $dnn_beam --lattice-beam $dnn_lat_beam \
		--skip-scoring true "${decode_extra_opts[@]}" \
		--transform-dir exp/tri5/decode_${dataset_id} \
		exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

	touch $decode/.done
fi

local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
	--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
	--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
	"${lmwt_dnn_extra_opts[@]}" \
	${dataset_dir} data/lang $decode

####################################################################
##
## DNN_MPE decoding
##
####################################################################
for epoch in 1 2 3 4; do
	decode=exp/tri6_nnet_mpe/decode_${dataset_id}_epoch$epoch
	if [ ! -f $decode/.done ]; then
		mkdir -p $decode
		steps/nnet2/decode.sh --minimize $minimize \
			--cmd "$decode_cmd" --nj $my_nj --iter epoch$epoch \
			--beam $dnn_beam --lattice-beam $dnn_lat_beam \
			--skip-scoring true "${decode_extra_opts[@]}" \
			--transform-dir exp/tri5/decode_${dataset_id} \
			exp/tri5/graph ${dataset_dir} $decode | tee $decode/decode.log

		touch $decode/.done
	fi

	local/run_kws_stt_task.sh --cer $cer --max-states $max_states \
		--skip-scoring $skip_scoring --extra-kws $extra_kws --wip $wip \
		--cmd "$decode_cmd" --skip-kws $skip_kws --skip-stt $skip_stt  \
		"${lmwt_dnn_extra_opts[@]}" \
		${dataset_dir} data/lang $decode
done

echo "Everything looking good...." 
exit 0
