read -p "Total number of pages: " totalpags
echo "The number of pages is $totalpags"
if [ $(echo $totalpags%4 | bc) == 0 ];
	then
	paginated=$totalpags
fi
if [ $(echo $totalpags%4 | bc) == 1 ];
	then
	paginated=$(echo $totalpags+3 | bc)
fi
if [ $(echo $totalpags%4 | bc) == 2 ];
	then
	paginated=$(echo $totalpags+2 | bc)
fi	
if [ $(echo $totalpags%4 | bc) == 3 ];
	then
	paginated=$(echo $totalpags+1 | bc) 
fi
echo "The number of pages after pagination is $paginated"
middlepag=$(echo $paginated/2 | bc)
echo "The middle part of the book has the page $middlepag"
allpags=$(for i in $(seq 1 $paginated); do echo $i; done)
impares=''
for number in $allpags
	do
	if [ $(echo $number%2 | bc) == 1 ];
		then
		impares=$impares$number
	else
		impares=$impares" "
	fi
done
pares=''
for number in $allpags
	do
	if [ $(echo $number%2 | bc) == 0 ];
		then
		pares=$pares$number
	else
		pares=$pares" "
	fi
done
echo "The uneven pages are: $impares"
echo "The even pages are: $pares"
echo "Now execute python libro.py"
