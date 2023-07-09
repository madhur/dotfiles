input=$@
echo $input
res=$(calc "$input")
if [ $? -eq 0 ] 
then 
    result=$(echo $res | sed -e 's/^[[:space:]]*//')
    eww update result="$result"
else 
  exit 0
fi
