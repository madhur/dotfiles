# xargs

Print 1 to 5
    seq 5 | xargs  -I {} echo {}


Do Paralellism
    seq 5 | xargs -n 1 -P 2 bash -c 'echo $0; sleep 1'


