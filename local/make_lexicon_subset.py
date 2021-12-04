import sys

if len(sys.argv) != 3:
    print "Please input only three arguments: <dataset_text> <original_lexicon>"
    print "e.g get_sub_lexicon.py train_subset/text data/local/lexicon.txt"
    print str(sys.argv)
    exit(0)

input_dir = sys.argv[1]
lexicon_file = sys.argv[2]
lexicon_map = {}
limited_lexicon_set = set()

# get lexicon map
with open(lexicon_file, "r") as f:
    content = f.readlines()
    for data in content:
        data = data.strip()
        key = data.split(" ")[0]
        lexicon_map[key] = data

with open(input_dir, "r") as f:
    content = f.readlines()
    for data in content:
        words = data.strip().split(" ")[1:]
        for each in words:
            limited_lexicon_set.add(each)

for each in limited_lexicon_set:
    if each in lexicon_map.keys():
        print lexicon_map[each]

