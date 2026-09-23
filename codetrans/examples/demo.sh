#!/bin/bash
# ตัวอย่างสำหรับฝึกอ่าน python
name="World"
export COUNT=3

echo "Hello $name"
echo "count = $COUNT"

if [ -f /etc/hostname ]; then
  cat /etc/hostname
fi

for i in 1 2 3; do
  echo "loop $i"
done

greet() {
  echo "Hi there"
}

mkdir -p /tmp/codetrans-demo
touch /tmp/codetrans-demo/a.txt
cp /tmp/codetrans-demo/a.txt /tmp/codetrans-demo/b.txt
ls /tmp/codetrans-demo
rm /tmp/codetrans-demo/b.txt
