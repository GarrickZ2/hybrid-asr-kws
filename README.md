# Code Running Instruction



## Introduction

Zixuan Zhang UNI: zz2888 Date: Dec 16 2021

**Project Title:** Research on incorporating hybrid ASR model to improve KWS-OOV search performance

**Project Summary:**

This is the project code for Columbia University COMS 6998 Fund Speech Recognization. It provides the scripts researching on Keyword-Spotting on TED-LIUM database.

My paper introduce the basic background and main issues of keyword searching, implements LVCSR-KWS model on TED-LIUM data set, and compares and analyzes the effect of proxy search method and Hybrid model method to solve OOV problem. We simulate full language with full Lexicon, limited language with Limited Lexicon (use proxy search and hybrid-asr model), Let me try it in four different ways. We also explore the impact of increasing model complexity on different situations.

**Project Tools:** All the tools are listed in section [Configure Environment](#Configure-Environment). For a brief overview, we used Kaldi, SRILM, Pocolm, Sequitur, SGMM2, Perl, F4DE. Kaldi provides the install scripts for most of tools besides some Perl packages and F4DE. We provide the installation method for every tools in detail.

**Main Scripts:**

We provide 4 executable files in main directory to perform our full project. To simply run these code, follow the instruction in [Quick Start](#Quick-Start)

run.sh : Train model. Detail in section [Train Model](#Train-Model)

prepare_kws.sh: Generate KWS necessary files. Detail in section [Generate KWS Data](#Generate-KWS-Data)

run_decode.sh : Decode the model and perform KWS. Detail in section [Decode Model](#Decode-Model)

clean.sh: Clean all the generated data during the Training, Decoding process. When you want to re-run the model, use this.

**Table of Content:**

1. [Configure Environment](#Configure-Environment)
2. [Quick Start](#Quick-Start)
3. [Train Model](#Train-Model)
4. [Generate KWS Data](#Generate-KWS-Data)
5. [Decode Model](#Decode-Model)
6. [Code Contribution](#Code-Contribution)
7. [Reference](#Reference)

## Configure Environment

### Kaldi Installation

```shell
# Download the Kaldi project from github
git clone https://github.com/kaldi-asr/kaldi

# Suppose the root directroy you download the kaldi project called as KROOT
# Configuration Kaldi following instruction in KROOT/INSTALL
cd KROOT/tools
./extras/check_dependencies.sh
make -j${nproc}

cd KROOT/src
./configure --shared
make depend -j${nproc}
make -j${nproc}
```

### Install SRILM

Under the KROOT/tools/ and run

```bash
./extras/install_srilm.sh <Name> <Organization> <Email>
```

Please provide the name, organization and email, because download SRILM require these information to gain an using license

For example,

```bash
./extras/install_srilm.sh Garrick_Z Columbia_University uni@columbia.edu
```

Then you have to wait it finished. And then please put tools/env.sh in your path to enbale it.

For example put following line in your .bashrc or .zshrc, etc.

```shell
source $KROOT/tools/env.sh
```

And to enbale it, you have to reconfigure your path vairable in your command line, like:

```bash
source ~/.bashrc # If you are using bash
source ~/.zshrc # If you are using zsh
```

### Install pocolm

Besides the default toolkit we install in the above procedure, we also need some additional tools

```shell
cd KROOT/tools
./extras/install_pocolm.sh

source KROOT/tools/env.sh
```

### Install Sequitur

This toolkit is important when we use g2p to generate phones for out-of-vocabulary words

```shell
sudo apt-get install swig
cd KROOT/tools
./extras/install_sequitur.sh

source KROOT/tools/env.sh

cd KROOT/tools/sequitur-g2p
python3 setup.py build
python3 setup.py install
```

### Enable SGMM2

SGMM2 is not a default src file while you install kaldi, so we have to make it manually

```shell
sudo apt-get install icu-devtools
cd KROOT/src/sgmm2bin
make -j${nproc}
```

### Install Perl Package

We have to install some additional package for PERL

```shell
apt-get install libxml-parser-perl                                                                        
apt-get install libexpat1-dev

perl -MCPAN -e 'install XML::Simple' || cpan XML::Simple || cpanm XML::Simple
```

### Install F4DE

We will use F4DE as the process to score the KWS performance.

Detail for install F4DE is in its GitHub : https://github.com/usnistgov/F4DE#setup

## Quick Start

Please install our code under KROOT/egs/tedlium

After finishing environment configuration, to quick start a KWS model, you can directly run the following script:

```shell
./run.sh										#First step: Training the model
./prepare_kws.sh data/dev		#Second Step:Prepare the kws data for score
./run_decode.sh data/dev		#Third Step: Decoding the model and perform score

./clean.sh									#Attention!!! If you want to run with different option, run clean.sh firstly.
														#It will clean all the training and decoding data, please be careful.
```

## Train Model

We provide several options to training different model:

```shell
./run.sh --none_nn [bool] --limited_language [bool] \
				 --limited_lexicon [bool] --hybrid_asr [bool] \
				 --with_gpu [bool] --train_stage [int] --decode [bool]
e.g.:
./run.sh --none_nn false --limited_language true \
				 --limited_lexicon true --hybrid_asr true \
				 --with_gpu true --train_stage 0 --decode false
```

--none_nn : whether train with deep neural network

--limited_language: whether use limited training data to train model

--limited_lexicon: whether use a small lexicon to train model

--hybrid_asr: whether use our hybrid_asr model to handle oov situation

--with_gpu: whether use GPU when you training neural network

--train_stage: when your neural network has been interrupted, you can recover from train_stage

--decode: whether score for every model when you training (slow down the training process)

#### To train a LVCSR-KWS with proxy word on full language:

```shell
./run.sh --none_nn true --with_gpu false
```

#### Train a LVCSR_KWS with proxy word on limited language and lexicon:

```shell
./run.sh --none_nn true --with_gpu false --limited_lexicon true --limited_language true
```

#### Train a LVCSR-KWS with proxy word on limited language and extended lexicon:

```shell
./run.sh --none_nn true --with_gpu false --limited_lexicon false --limited_language true
```

#### Train a LVCSR-KWS with Hybrid-ASR on limited language and lexicon:

```shell
./run.sh --none_nn true --with_gpu false --limited_lexicon true --limited_langauge true --hybrid_asr true
```

#### Train a LVCSR-KWS with Hybrid-ASR on limited language and extended lexicon:

```shell
./run.sh --none_nn true --with_gpu false --limited_lexicon false --limited_language true --hybrid_asr true
```



## Generate KWS Data

We will search kws and score for the performance during the decoding process. So, before decoding, we need to generate keyword data first.

Normally, to perform keyword detection in Kaldi, you should manually prepare three formats files: ecf, kwlist and rttm files. Luckily, I provide a script for you to finish all the process automatically.

```shell
./prepare_kws.sh --generate_keyword [bool] <data-dir>
# --generate_keyword indicated whether you want to generate random keywords
# For example:
./prepare_kws.sh --generate_keyword false data/dev
```

If you select don't generate keywords, then two options will provide for you. If you want to use the example keywords we provide, there is no more actions for you to do.

If you want to use your own keyword list, then you should create two keywords files: inkwlist.txt and oovkwlist.txt

Both them are in a simple format:

```
<word1>
<word2>
<word3>
<word4>
...
<wordn>
```

\<word\> can be a single word or a phrase

You should provide all the in-voc keyword in inkwlist.txt and out-of-voc keyword in oovkwlist.txt. oovkwlist.txt can be none. Then you should place these two files under your \<data-dir\> directory. Then you can simply run the script (if you use our example keyword or your own keyword):

````shell
./prepare_kws.sh <data-dir>
````



## Decode Model

We will decode the model you trained in the first process. If you finished last two processes perfectly, this step would be simple.

This step will automatically detect the model you trained, then try to decode them and perform kws on it.

```shell
./run_decode.sh <data-dir>
# <data-dir> is the dataset you prepare kws data in the last process. For example,
./prepare_kws.sh data/dev
```

## Code Contribution

### Code in Main Directory

1.   run.sh: Rewrite the whole script for tedlium to implement a SGMM (based on PLP feature) model to conduct KWS
2.   prepare_kws.sh: The whole script write by me to help you generate any relevant files for KWS including kwlist, rttm, ecf, etc. You don't have to prepare these files manually anymore.
3.   run_decode.sh: Refer to the decode script under babel script and modify it to fit for our project.
4.   clean.sh: simple clean script to clean training data.

### Code in Local Directory

I write the following new script in local directory for:

1.   convert_word2voc.py [new]
2.   create_ecf_file.sh [new]
3.   create_keyword.py [new]
4.   create_rttm.sh [new]
5.   create_sub_train.sh [new]
6.   prepare_kwlist.sh [new]
7.   prepare_kws_data.sh [new]
8.    run_kws_stt_task.sh [modified]

### Code in Config Directory

Prepare the ivkwslist(in-voc keyword list for tedlium) and oovkwslist(out-of-voc keyword list for tedlium)

## Reference

1.   Rousseau, Anthony \& Deléglise, Paul \& Estève, Yannick. (2014). Enhancing the TED-LIUM Corpus with Selected Data for Language Modeling and More TED Talks. 
2.   Szöke I., Schwarz P., Matějka P., Burget L., Karafiát M., Černocký J. (2005) Phoneme Based Acoustics Keyword Spotting in Informal Continuous Speech. In: Matoušek V., Mautner P., Pavelka T. (eds) Text, Speech and Dialogue. TSD 2005. Lecture Notes in Computer Science, vol 3658. Springer, Berlin, Heidelberg.
3.   P. Motlicek, F. Valente and I. Szoke, "Improving acoustic based keyword spotting using LVCSR lattices," 2012 IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP), 2012, pp. 4413-4416, doi: 10.1109/ICASSP.2012.6288898.
4.   Sun M, Snyder D, Gao Y, et al. Compressed Time Delay Neural Network for Small-Footprint Keyword Spotting[C]//Interspeech. 2017: 3607-3611.
5.   F. Itakura, "Minimum prediction residual principle applied to speech recognition," in IEEE Transactions on Acoustics, Speech, and Signal Processing, vol. 23, no. 1, pp. 67-72, February 1975, doi: 10.1109/TASSP.1975.1162641.
6.   G. Chen, O. Yilmaz, J. Trmal, D. Povey and S. Khudanpur, "Using proxies for OOV keywords in the keyword search task," 2013 IEEE Workshop on Automatic Speech Recognition and Understanding, 2013, pp. 416-421, doi: 10.1109/ASRU.2013.6707766.
7.   OpenKWS13 Keyword Search Evaluation Plan
8.   Weintraub M . LVCSR log-likelihood ratio scoring for keyword spotting[C] International Conference on Acoustics. IEEE, 1995.
9.   G. E. Dahl, T. N. Sainath and G. E. Hinton, "Improving deep neural networks for LVCSR using rectified linear units and dropout," 2013 IEEE International Conference on Acoustics, Speech and Signal Processing, 2013, pp. 8609-8613, doi: 10.1109/ICASSP.2013.6639346.
10.   Y. Zhao and B. Juang, "Stranded Gaussian mixture hidden Markov models for robust speech recognition," 2012 IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP), 2012, pp. 4301-4304, doi: 10.1109/ICASSP.2012.6288870.
11.   M. J. F. Gales, “Maximum likelihood linear transformations for HMM-based speech recognition,” Computer Speech and Language, vol. 12, pp. 75–98, 1998.
12.   R. O. Duda, P. E. Hart, and David G. Stork, “Pattern classification,” in Wiley, November 2000.
13.   R. Gopinath, “Maximum likelihood modeling with Gaussian distributions for classification,” in Proc. IEEE ICASSP, 1998, vol. 2, pp. 661–664.
14.   M.J.F. Gales,Maximum likelihood linear transformations for HMM-based speech recognition,Computer Speech \& Language,Volume 12, Issue 2,1998,Pages 75-98,ISSN 0885-2308
