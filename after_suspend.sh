sudo systemctl stop NetworkManager
sudo modprobe -r brcmfmac_wcc; sudo modprobe brcmfmac_wcc
sudo modprobe -r brcmfmac; sudo modprobe brcmfmac
sudo systemctl start NetworkManager
sudo modprobe -r hci_bcm4377; sudo modprobe hci_bcm4377
sleep 3
sudo systemctl stop NetworkManager
sudo modprobe -r brcmfmac_wcc; sudo modprobe brcmfmac_wcc
sudo modprobe -r brcmfmac; sudo modprobe brcmfmac
sudo systemctl start NetworkManager
sudo modprobe -r hci_bcm4377; sudo modprobe hci_bcm4377
sudo touchbar --restart
