## FDO MicroShift Demo

1. Run the `0-pre-requisites-osbuild.sh` script to deploy image-builder

```shell
systemctl stop firewalld
systemctl status firewalld
```

2. Run the following command to install and start libvirt and relevant packages:

```shell
dnf install -y libvirt virt-manager virt-install virt-viewer libvirt-client qemu-kvm qemu-img cockpit-machines
systemctl enable --now libvirtd.service
```

3. Add MicroShift and OpenShift packages repositories:

```shell
cd demos/kickstart-microshift
./add-microshift-repos.sh
cd ../..
``

4. Create the RHEL for Edge image with `1-create-image.sh` script and copy the image ID.

```shell
cp demos/kickstart-microshift/blueprint-microshift.toml.example blueprint-microshift.toml
./1-create-image.sh -b blueprint-microshift.toml
```

4. Publish the image with this command (here using IP and port defaults):

```shell
./2-publish-image.sh -x 8091 -i <image-id> -d vda
```

5. Deploy the edge server by starting using UEFI boot and the NIC as the device for the first boot. You will find that the boot will attempt to use PXE boot before UEFI HTTP boot...so you will need to wait a bit until the install begins.


- Run the following command to install the `libvirt` network:

```shell
virsh net-list
virsh net-edit default
virsh net-destroy default
mkdir -p /var/lib/tftpboot
virsh net-start default
```

Note: default network for libvirt as follow:
```xml
<network xmlns:dnsmasq="http://libvirt.org/schemas/network/dnsmasq/1.0">
  <name>default</name>
  <uuid>3a4b328c-f199-476b-bfc6-d79043f07019</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:be:34:21'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <tftp root="/var/lib/tftpboot"/>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <bootp file="pxelinux.0"/>
    </dhcp>
  </ip>
  <dnsmasq:options>
    <dnsmasq:option value="dhcp-vendorclass=set:efi-http,HTTPClient:Arch:00016"/>
    <dnsmasq:option value="dhcp-option-force=tag:efi-http,60,HTTPClient"/>
    <dnsmasq:option value="dhcp-boot=tag:efi-http,&quot;http://192.168.122.1:8091/EFI/BOOT/BOOTX64.EFI&quot;"/>
    <dnsmasq:option value='log-queries'/>
    <dnsmasq:option value='log-dhcp'/>
    <dnsmasq:option value='log-debug'/>
  </dnsmasq:options>
</network>
```

- create VM with virt-install:

```shell
cat >> /etc/libvirt/qemu.conf << EOF
user = "root"
group = "root"
EOF
systemctl restart libvirtd.service
```

```shell
virt-install \
    --name=edge-microshift-fdo-test-1 \
    --disk path=./edge-microshift-fdo-test-1.qcow2,size=20 \
    --ram=2048 \
    --vcpus=2 \
    --os-type=linux \
    --os-variant=rhel9.2 \
    --network=network=default,model=virtio \
    --boot uefi
```

- Log into the VM

```shell
virsh domifaddr edge-microshift-fdo-test-1
ssh admin@${VM_IP} #admin/admin
```

- Check FDO device credencials

```shell
bash-5.1# fdo-owner-tool dump-device-credential /boot/device-credentials
Active: true
Protocol Version: 101
Device Info:
Device GUID: 343a5e10-9476-7758-b503-ae5fa8ec8290
Rendezvous Info:
	- [(DevicePort, [25, 31, 146]), (IPAddress, [68, 10, 73, 130, 147]), (OwnerPort, [25, 31, 146]), (Protocol, [1])]
Public key hash: e1c3a8005c66ac1c50d39b3843852c9bf76c3466dc1811670ac7defbf11a64c90adca6307c079aa39cc646114423efb3 (Sha384)
HMAC and signing key:
	HMAC key: <secret>
	Signing key: <secret>
```

- Check the owner vouchers in FDO server:

```shell
# tree /etc/fdo/stores/
/etc/fdo/stores/
├── manufacturer_keys
├── manufacturing_sessions
├── owner_onboarding_sessions
│   └── jW13FpCh0HDQs0Pio5iZGMdcF_slash_DayOJtCFp8sfd_slash_Q7A=
├── owner_vouchers
│   ├── 23814c43-fe78-33df-11d1-7cf443056fa2
│   ├── 30846083-4e80-9a09-9008-3ba5de840284
│   ├── 343a5e10-9476-7758-b503-ae5fa8ec8290
│   ├── 4de04ea4-a145-dcf4-2fdc-1753b1ce11bb
│   ├── 5caa651f-8e2e-b5c4-02e9-8f2b7df9b861
│   └── 9bb8ea53-1d53-cc16-29ef-3e5d4579a150
├── rendezvous_registered
│   ├── 23814c43-fe78-33df-11d1-7cf443056fa2
│   ├── 30846083-4e80-9a09-9008-3ba5de840284
│   ├── 343a5e10-9476-7758-b503-ae5fa8ec8290
│   ├── 4de04ea4-a145-dcf4-2fdc-1753b1ce11bb
│   ├── 5caa651f-8e2e-b5c4-02e9-8f2b7df9b861
│   └── 9bb8ea53-1d53-cc16-29ef-3e5d4579a150
├── rendezvous_sessions
│   ├── 0aS8vd3x7tsMP6J1nld4IRO_slash_20Pd0i2dyoA_slash_FlVqMyQ=
│   ├── 6kPeqqsnOsK3RpmAlcB1UqwI6Xz9bslOZgnttjWoW4M=
│   ├── 6QMTfFYx3udMG51op46PfU1BFJ+NUi7nlmpJ0FvV11o=
│   ├── awrWuW2tnsx7ksKzD1y0nVQkG+zv8VovoUVvvbTy5uA=
│   ├── dFWov53yNzgYw3kpJQNmUB7dgKaXXwPgjW3CldFVsLE=
│   ├── Hdy1ctFreqviNWosAOsT+H9+6VIu8DMYmWu6lrPnuMQ=
│   ├── XHuJBS9g0t9opdaqcO+LWbT5FGg9+Xtcv4BKr2S5PW0=
│   └── ZKAqnQ7Zc+eyLJHGVKfwesNi7oUkMK3TysXCZrmOtrI=
└── serviceinfo_api_devices
```

- Check logs in VM

```shell
journalctl | grep fdo
```

- Check MicroShift Cluster:

```shell
sudo su
cd 
oc get pod -A
```

- Check MicroShift Cluster is registered to ACM hub
