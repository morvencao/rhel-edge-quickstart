#!/bin/bash

MICROSHIFT_BUILD_FROM_SOURCE="${MICROSHIFT_BUILD_FROM_SOURCE:-false}"
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-4.13}"
MICROSHIFT_DEPS_VERSION="${MICROSHIFT_DEPS_VERSION:-${MICROSHIFT_VERSION}}"

baserelease=$(cat /etc/redhat-release  | awk '{print $6}' | awk -F . '{print $1}')
basearch=$(arch)

repo_root_dir="$(git rev-parse --show-toplevel)"
target_dir="/var/repos"

rm -rf ${target_dir} 2>/dev/null || true
mkdir -p ${target_dir}
chmod -R 777 ${target_dir}

dnf update -y
dnf install -y createrepo yum-utils

###### MICROSHIFT REPO

if [ "${MICROSHIFT_BUILD_FROM_SOURCE}" = true ]; then

    dnf install -y golang git rpm-build selinux-policy-devel

    git clone -b release-${MICROSHIFT_VERSION}  https://github.com/openshift/microshift

    cd microshift

    git pull

    echo ""
    echo "This will take some time..."
    echo ""

    make 
    make rpm
    make srpm

    echo ""
    echo "RPMs generated:"

    find _output -name \*.rpm

    echo ""

    ########
    ######## Copy MicroShift RPM packages
    rm -rf ${current_dir}/microshift/scripts/image-builder/_builds/microshift-local 2>/dev/null || true
    cp -TR ${current_dir}/microshift/_output/rpmbuild ${target_dir}/microshift-local
    ########

else

    # sync microshfit packages from released repository
    microshift_repo="microshift-${MICROSHIFT_VERSION}-for-rhel-${baserelease}-${basearch}-rpms"
    sudo tee /etc/yum.repos.d/microshift.repo > /dev/null <<EOF
[${microshift_repo}]
name=MicroShift ${MICROSHIFT_VERSION} ${basearch} RPMs
baseurl=https://mirror.openshift.com/pub/openshift-v4/\${basearch}/microshift/ocp/latest-${MICROSHIFT_VERSION}/el${baserelease}/os/
enabled=1
gpgcheck=0
skip_if_unavailable=0
EOF

    # Sync RPMs to mirror repo
    echo "Downloading MicroShift RPMs into mirror repo"

    ########
    ######## Download microshift local RPM packages
    rm -rf ${target_dir}/microshift-local 2>/dev/null || true
    mkdir -p ${target_dir}/microshift-local
    sudo reposync -n -a ${basearch} -a noarch --download-path ${target_dir}/microshift-local \
        --repo=microshift-${MICROSHIFT_VERSION}-for-rhel-${baserelease}-${basearch}-rpms
fi

# Exit if no RPM packages were found
if [ $(find ${target_dir}/microshift-local -name '*.rpm' | wc -l) -eq 0 ] ; then
    echo "No RPM packages were found at the 'microshift rpms' repository. Exiting..."
    exit 1
fi

# create local microshift repo
chmod -R 777 ${target_dir}/microshift-local
createrepo ${target_dir}/microshift-local > /dev/null

cat <<EOF > microshift-local.toml
id = "microshift-local"
name = "MicroShift Local Repo"
type = "yum-baseurl"
url = "file://${target_dir}/microshift-local/"
check_gpg = false
check_ssl = false
system = false
EOF

sudo composer-cli sources delete microshift-local 2>/dev/null || true
sudo composer-cli sources add microshift-local.toml

###### OPENSHIFT REPO

########
######## Download openshift local RPM packages (noarch for python and selinux packages)
# Sync RPMs to mirror repo
echo "Downloading OpenShift RPMs into mirror repo"
rm -rf ${target_dir}/openshift-local 2>/dev/null || true
mkdir -p ${target_dir}/openshift-local
sudo reposync -n -a ${basearch} -a noarch --download-path ${target_dir}/openshift-local \
    --repo=rhocp-${MICROSHIFT_DEPS_VERSION}-for-rhel-${baserelease}-${basearch}-rpms \
    --repo=fast-datapath-for-rhel-${baserelease}-${basearch}-rpms >/dev/null

# Remove coreos packages to avoid conflicts
find ${target_dir}/openshift-local -name \*coreos\* -exec rm -f {} \;

# Exit if no RPM packages were found
if [ $(find ${target_dir}/openshift-local -name '*.rpm' | wc -l) -eq 0 ] ; then
    echo "No RPM packages were found at the 'rhocp rpms' repository. Exiting..."
    exit 1
fi

createrepo ${target_dir}/openshift-local >/dev/null
########

cat <<EOF > openshift-local.toml
id = "openshift-local"
name = "OpenShift Local Repo"
type = "yum-baseurl"
url = "file://${target_dir}/openshift-local/"
check_gpg = false
check_ssl = false
system = false
EOF

sudo composer-cli sources delete openshift-local 2>/dev/null || true
sudo composer-cli sources add openshift-local.toml

sudo systemctl restart osbuild-composer.service

cd  ${repo_root_dir}
