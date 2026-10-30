Name:       citrusviewer
Version:    1.5.1
Release:    0
Summary:    RPM package
License:    GPL-3.0
URL:        https://rustdesk.com
Vendor:     mxnwire <info@rustdesk.com>
Requires:   gtk3 libxcb1 libXfixes3 alsa-utils libXtst6 libva2 gstreamer-plugins-base gstreamer-plugin-pipewire
Recommends: libayatana-appindicator3-1 xdotool
Provides:   libdesktop_drop_plugin.so()(64bit), libdesktop_multi_window_plugin.so()(64bit), libfile_selector_linux_plugin.so()(64bit), libflutter_custom_cursor_plugin.so()(64bit), libflutter_linux_gtk.so()(64bit), libscreen_retriever_plugin.so()(64bit), libtray_manager_plugin.so()(64bit), liburl_launcher_linux_plugin.so()(64bit), libwindow_manager_plugin.so()(64bit), libwindow_size_plugin.so()(64bit), libtexture_rgba_renderer_plugin.so()(64bit)

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

# %global __python %{__python3}

%install

mkdir -p "%{buildroot}/usr/share/citrusviewer" && cp -r ${HBB}/flutter/build/linux/x64/release/bundle/* -t "%{buildroot}/usr/share/citrusviewer"
mkdir -p "%{buildroot}/usr/bin"
install -Dm 644 $HBB/res/citrusviewer.service -t "%{buildroot}/usr/share/citrusviewer/files"
install -Dm 644 $HBB/res/citrusviewer.desktop -t "%{buildroot}/usr/share/citrusviewer/files"
install -Dm 644 $HBB/res/citrusviewer-link.desktop -t "%{buildroot}/usr/share/citrusviewer/files"
install -Dm 644 $HBB/res/128x128@2x.png "%{buildroot}/usr/share/icons/hicolor/256x256/apps/citrusviewer.png"
install -Dm 644 $HBB/res/scalable.svg "%{buildroot}/usr/share/icons/hicolor/scalable/apps/citrusviewer.svg"

%files
/usr/share/citrusviewer/*
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
ln -sf /usr/share/citrusviewer/citrusviewer /usr/bin/citrusviewer
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
    rm /usr/bin/citrusviewer || true
    rmdir /usr/lib/citrusviewer || true
    rmdir /usr/local/citrusviewer || true
    rmdir /usr/share/citrusviewer || true
    rm /usr/share/applications/citrusviewer.desktop || true
    rm /usr/share/applications/citrusviewer-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
    rmdir /usr/lib/citrusviewer || true
    rmdir /usr/local/citrusviewer || true
  ;;
esac
