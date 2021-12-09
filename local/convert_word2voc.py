import sys

if len(sys.argv) != 2:
    print "Please input only one argument: words.txt"
    print str(sys.argv)
    exit(0)

word_file = sys.argv[1]
with open(word_file, "r") as f:
    content = f.readlines()
    for each in content:
        word = each.split(" ")[0]
        if word == '<eps>' or word == '<s>':
            continue
        print word
