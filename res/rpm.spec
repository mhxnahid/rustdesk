Name:       citrusremoteviewer
Version:    1.5.1
Release:    0
Summary:    RPM package
License:    GPL-3.0
URL:        https://rustdesk.com
Vendor:     mxnwire <info@rustdesk.com>
Requires:   gtk3 libxcb libXfixes alsa-lib libva2 gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3 libxdo

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

%global __python %{__python3}

%install
mkdir -p %{buildroot}/usr/bin/
mkdir -p %{buildroot}/usr/share/citrusremoteviewer/
mkdir -p %{buildroot}/usr/share/citrusremoteviewer/files/
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps/
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps/
install -m 755 $HBB/target/release/citrusremoteviewer %{buildroot}/usr/bin/citrusremoteviewer
install $HBB/libsciter-gtk.so %{buildroot}/usr/share/citrusremoteviewer/libsciter-gtk.so
install $HBB/res/citrusremoteviewer.service %{buildroot}/usr/share/citrusremoteviewer/files/
install $HBB/res/128x128@2x.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/citrusremoteviewer.png
install $HBB/res/scalable.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/citrusremoteviewer.svg
install $HBB/res/citrusremoteviewer.desktop %{buildroot}/usr/share/citrusremoteviewer/files/
install $HBB/res/citrusremoteviewer-link.desktop %{buildroot}/usr/share/citrusremoteviewer/files/

%files
/usr/bin/citrusremoteviewer
/usr/share/citrusremoteviewer/libsciter-gtk.so
/usr/share/citrusremoteviewer/files/citrusremoteviewer.service
/usr/share/icons/hicolor/256x256/apps/citrusremoteviewer.png
/usr/share/icons/hicolor/scalable/apps/citrusremoteviewer.svg
/usr/share/citrusremoteviewer/files/citrusremoteviewer.desktop
/usr/share/citrusremoteviewer/files/citrusremoteviewer-link.desktop
/usr/share/citrusremoteviewer/files/__pycache__/*

%changelog
# let's skip this for now

%pre
# can do something for centos7
case "$1" in
  1)
    # for install
  ;;
  2)
    # for upgrade
    systemctl stop citrusremoteviewer || true
  ;;
esac

%post
cp /usr/share/citrusremoteviewer/files/citrusremoteviewer.service /etc/systemd/system/citrusremoteviewer.service
cp /usr/share/citrusremoteviewer/files/citrusremoteviewer.desktop /usr/share/applications/
cp /usr/share/citrusremoteviewer/files/citrusremoteviewer-link.desktop /usr/share/applications/
systemctl daemon-reload
systemctl enable citrusremoteviewer
systemctl start citrusremoteviewer
update-desktop-database

%preun
case "$1" in
  0)
    # for uninstall
    systemctl stop citrusremoteviewer || true
    systemctl disable citrusremoteviewer || true
    rm /etc/systemd/system/citrusremoteviewer.service || true
  ;;
  1)
    # for upgrade
  ;;
esac

%postun
case "$1" in
  0)
    # for uninstall
    rm /usr/share/applications/citrusremoteviewer.desktop || true
    rm /usr/share/applications/citrusremoteviewer-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
  ;;
esac
