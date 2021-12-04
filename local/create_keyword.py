import sys
import random

if len(sys.argv) != 4:
    print "Please input only three arguments: <dataset_text> <lexicon> <output_dir>"
    print "e.g create_keyword.py train_subset/text data/local/lexicon.txt data/local"
    print str(sys.argv)
    # exit(0)

input_dir = sys.argv[1]
lexicon_file = sys.argv[2]
output_dir = sys.argv[3]

ivlist = []
oovlist = []

lexicon_map = {}
with open(lexicon_file, "r") as f:
    content = f.readlines()
    for data in content:
        data = data.strip()
        key = data.split(" ")[0]
        lexicon_map[key] = data


iv_words_map = {}
oov_words_map = {}
with open(input_dir, "r") as f:
    content = f.readlines()
    for data in content:
        words = data.strip().split(" ")[1:]
        for each in words:
            if each in lexicon_map.keys():
                if each in iv_words_map.keys():
                    iv_words_map[each] = iv_words_map[each] + 1
                else:
                    iv_words_map[each] = 1
            else:
                if each in oov_words_map.keys():
                    oov_words_map[each] = oov_words_map[each] + 1
                else:
                    oov_words_map[each] = 1

iv_word_list = sorted(iv_words_map.items(), key=lambda item: item[1])
oov_word_list = sorted(oov_words_map.items(), key=lambda item: item[1])

iv_iter = len(iv_word_list) / 2000
if iv_iter < 2:
    iv_iter = 1
iv_start = 0
while (iv_start+iv_iter) <= len(iv_word_list) and len(ivlist) < 2000:
    select = random.randint(iv_start, iv_start+iv_iter-1)
    ivlist.append(iv_word_list[select][0])
    iv_start = iv_start + iv_iter

oov_iter = len(oov_word_list) / 800
if oov_iter < 2:
    oov_iter = 1
oov_start = 0
while (oov_start+oov_iter) <= len(oov_word_list) and len(oovlist) < 800:
    select = random.randint(oov_start, oov_start+oov_iter-1)
    oovlist.append(oov_word_list[select][0])
    oov_start = oov_start + oov_iter

with open(output_dir+"/ivkwlist.txt", "w") as f:
    for each in ivlist:
        f.write(each)
        f.write('\n')

with open(output_dir+"/oovkwlist.txt", "w") as f:
    for each in oovlist:
        f.write(each)
        f.write('\n')

