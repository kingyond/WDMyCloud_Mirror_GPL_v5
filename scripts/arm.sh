dhcp;set serverip 10.0.0.217
tftp 0xa00000 uImage
tftp 0xf00000 uRamdisk
bootm 0xa00000 0xf00000

usb start
fatload usb 0:1 0xa00000 uImage
fatload usb 0:1 0xf00000 uRamdisk
bootm 0xa00000 0xf00000

usb start
bubt u-boot.bin nand usb
reset

usb start
fatload usb 0:1 0x3000000 uImage
fatload usb 0:1 0x4000000 uRamdisk
fatload usb 0:1 0x5000000 image.cfs

nand erase 0x500000 0x500000
nand write 0x3000000 0x500000 0x500000
nand erase 0xa00000 0x500000
nand write 0x4000000 0xa00000 0x500000
nand erase 0xf00000 0xb900000
nand write 0x5000000 0xf00000 0xb900000

usb start
fatload usb 0:1 0x3000000 uImage;nand erase 0x500000 0x500000;nand write 0x3000000 0x500000 0x500000
fatload usb 0:1 0x4000000 uRamdisk;nand erase 0xa00000 0x500000;nand write 0x4000000 0xa00000 0x500000
fatload usb 0:1 0x5000000 image.cfs;nand erase 0xf00000 0xb900000;nand write 0x5000000 0xf00000 0xb900000
reset

nand read 0xa00000 0x500000 0x500000
nand read 0xf00000 0xa00000 0x500000
bootm 0xa00000 0xf00000

tftp -g -r uImage 10.0.0.217
tftp -g -r uRamdisk 10.0.0.217
scp o@10.0.0.217:~/image.cfs ./

dd if=/dev/zero of=/dev/mtdblock1
dd if=uImage of=/dev/mtdblock1

dd if=/dev/zero of=/dev/mtdblock2
dd if=uRamdisk of=/dev/mtdblock2

dd if=/dev/zero of=/dev/mtdblock3
dd if=image.cfs of=/dev/mtdblock3



