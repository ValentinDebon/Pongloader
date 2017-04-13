#!/bin/bash

echo "assembling"
as -o pongloader.elf asm/pongloader.s --32

if [ $? -ne 0 ]
then
        echo "Error during assembly"
        exit
fi

echo "creating raw bin file"
objcopy -O binary pongloader.elf pongloader.bin

echo "building .img file"
dd if=/dev/zero of=pongloader.img bs=512 count=12
dd conv=notrunc if=pongloader.bin of=pongloader.img
