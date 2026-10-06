Replace small case character with upper case
    echo "This is a line of text" | tr 'a' 'A'
    This is A line of text

It works at the character level
    echo "This is a line of text" | tr 'aeio' 'AEIO' 
    ThIs Is A lInE Of tExt

Delete characters
    echo "This is a line of text" | tr -d 'aeio'
    Ths s  ln f txt

Condense characters
    echo "Thiis iis aa liinee oof teeext" | tr -s 'aeio '
    This is a line of text

Work with class of characters
    echo "Thiis iis aa liinee oof teeext" | tr -s '[:lower:]' '[:upper:]'                                                        [☸ eks-pt-v2 (mec)]
    THIS IS A LINE OF TEXT

Delete everything except characters
     echo "This is a line of text" | tr -cd 'aeio'                                                                                [☸ eks-pt-v2 (mec)]
     iiaieoe

Strip out non-digits
    echo "hellow123sdflsdlf213" | tr -cd '[:digit:]'                                                                             [☸ eks-pt-v2 (mec)]
    123213     
