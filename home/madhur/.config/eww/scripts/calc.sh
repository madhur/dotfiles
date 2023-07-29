input="$*"
res=$(calc "$input")
echo $res
if [ $? -eq 0 ] 
then 
    eww update result="$res"
else 
  exit 0
fi
