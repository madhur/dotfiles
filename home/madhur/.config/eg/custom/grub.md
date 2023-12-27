Generate grub configuration
   sudo grub-mkconfig -o /boot/grub/grub.cfg

Do grub install for UEFI
      sudo grub-install /dev/sda --target=x86_64-efi --efi-directory=/boot/efi/

