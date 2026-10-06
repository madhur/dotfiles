# xargs

Print 1 to 5
    seq 5 | xargs

Print 1 to 5, tell us the command
    seq 5 | xargs -t


Print 1 to 5 using the placeholder
    seq 5 | xargs  -I {} echo {}

Read the list of files and print manipulated using placeholder
    ls | xargs -I {} echo "/home/madhur/{}"


Make 1000 .txt files
    seq 1000 | xargs -I {} touch {}.txt

Rename files from .txt to .text
    ls | cut -d. -f1 | xargs -I {} mv {}.txt {}.text

Run one command at a time
    seq 5 | xargs -n 1

Max number of processes at the time
     seq 5 | xargs -n 1 -P 2 bash -c 'echo $0; sleep 1'

Read /etc/passwd file
    cut -d: -f1 < /etc/passwd | sort | xargs 




