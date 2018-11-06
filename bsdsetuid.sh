setuid=4
for i1 in 0 1 2 3 4 5 6 7
do
  for i2 in 0 1 2 3 4 5 6 7
  do
    for i3 in 0 1 2 3 4 5 6 7
    do
      echo "Testing permission $setuid$i1$i2$i3"
      find / -perm $setuid$i1$i2$i3
    done
  done
done
