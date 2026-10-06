var=$(echo "'$@'")
echo "madhur" + $var
#var='(4+4*2)'
res1=$(echo "$var" | bc -l)
echo $res1
if [ $? -eq 0 ] 
then 
    eww update result="$res1"
else 
  exit 0
fi
