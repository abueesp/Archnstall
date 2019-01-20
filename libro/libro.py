middlepag = raw_input('Introduce: middle page number: ')
impares = raw_input('Introduce uneven page numbers: ')
pares = raw_input('Introduce even page numbers: ')
pares = pares.split()
impares = impares.split()
a=(len (pares))-1
b=(len (impares))-1
print a
print b
if a < b:
	pares.append(' ')
else:
	impares.append(' ')
revpares=''
while a > -1:
        revpares=revpares+", "+str(pares[a])
        a=a-1
zipper=zip(impares, revpares.split())
print ("Reverse portrait mode")
print(' '.join(', '.join(elems) for elems in zipper))


revimpares=''
while b > -1:
        revimpares=revimpares+", "+str(impares[b])
        b=b-1
zipper=zip(pares, revimpares.split())
print ("Portrait mode")
print(' '.join(', '.join(elems) for elems in zipper))
#z=(len (zipper))-1
#revzipper=''
#while z > -1:
#        revzipper=revzipper+" "+str(zipper[z])
#        z=z-1
#print ("Portrait mode")
#print str(' '.join(', '.join(list(elems.split())) for elems in (revzipper.split()))).translate(None, "()'")

lim1=int(middlepag)+1
lim2=int(middlepag)+2
print ('Copy until the pages '+str(lim1)+', '+str(lim2)+' (these two included), and print them on Reverse Portrait and 2 sides. Then, copy the rest of them pages and print them on Portrait and 2 sides. Check the direction of the paper before doing this second round. Normally it will be printed the upper side, to the left, in order 1 - 2 for portrait mode; so you will have to take the papers from the first round and put them down side and with the base looking to the left.')

