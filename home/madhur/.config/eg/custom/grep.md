#grep

Remove commented lines
    grep -v '^#' file1 file2 file3

Search for text in subfolders
    grep -rnw '.' -e <text>

Search for text in subfolders with context
    grep -C 10 -rnw '.' -e <text>

grep IP addresses
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' <filename>
    
grep IP addresses
    grep -Eo '[0-9]{1,4}' <filename>

grep IP addresses alternate
     grep -Eo '[0-9]{1,8}' <filename>

Search for gz files inside subfolders as well
    zgrep "Exception" $(find . -name "*.gz")
     
