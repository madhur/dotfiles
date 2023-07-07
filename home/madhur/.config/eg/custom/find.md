# find

Find files sorted by modified time across subdirectories
    find -printf "%TY-%Tm-%Td %TT %p\n" | sort -n

Find all the big iso files
    find / -name "*.iso" 2>/dev/null


Remove files
    find . -type f -name "*.txt" | xargs rm    
