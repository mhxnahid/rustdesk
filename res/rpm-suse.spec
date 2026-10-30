Name:       citrusviewer
Version:    1.1.9
Release:    0
Summary:    RPM package
License:    GPL-3.0
Requires:   gtk3 libxcb1 libXfixes3 alsa-utils libXtst6 libva2 gstreamer-plugins-base gstreamer-plugin-pipewire
Recommends: libayatana-appindicator3-1 xdotool

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
mkdir -p %{buildroot}/usr/share/citrusviewer/
mkdir -p %{buildroot}/usr/share/citrusviewer/files/
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps/
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps/
install -m 755 $HBB/target/release/citrusviewer %{buildroot}/usr/bin/citrusviewer
install $HBB/libsciter-gtk.so %{buildroot}/usr/share/citrusviewer/libsciter-gtk.so
install $HBB/res/citrusviewer.service %{buildroot}/usr/share/citrusviewer/files/
install $HBB/res/128x128@2x.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/citrusviewer.png
install $HBB/res/scalable.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/citrusviewer.svg
install $HBB/res/citrusviewer.desktop %{buildroot}/usr/share/citrusviewer/files/
install $HBB/res/citrusviewer-link.desktop %{buildroot}/usr/share/citrusviewer/files/

%files
/usr/bin/citrusviewer
/usr/share/citrusviewer/libsciter-gtk.so
/usr/share/citrusviewer/files/citrusviewer.service
/usr/share/icons/hicolor/256x256/apps/citrusviewer.png
/usr/share/icons/hicolor/scalable/apps/citrusviewer.svg
/usr/share/citrusviewer/files/citrusviewer.desktop
/usr/share/citrusviewer/files/citrusviewer-link.desktop

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
    systemctl stop citrusviewer || true
  ;;
esac

%post
cp /usr/share/citrusviewer/files/citrusviewer.service /etc/systemd/system/citrusviewer.service
cp /usr/share/citrusviewer/files/citrusviewer.desktop /usr/share/applications/
cp /usr/share/citrusviewer/files/citrusviewer-link.desktop /usr/share/applications/
systemctl daemon-reload
systemctl enable citrusviewer
systemctl start citrusviewer
update-desktop-database

%preun
case "$1" in
  0)
    # for uninstall
    systemctl stop citrusviewer || true
    systemctl disable citrusviewer || true
    rm /etc/systemd/system/citrusviewer.service || true
  ;;
  1)
    # for upgrade
  ;;
esac

%postun
case "$1" in
  0)
    # for uninstall
    rm /usr/share/applications/citrusviewer.desktop || true
    rm /usr/share/applications/citrusviewer-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
  ;;
esac
