Name:       citrusremoteviewer
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

mkdir -p "%{buildroot}/usr/share/citrusremoteviewer" && cp -r ${HBB}/flutter/build/linux/x64/release/bundle/* -t "%{buildroot}/usr/share/citrusremoteviewer"
mkdir -p "%{buildroot}/usr/bin"
install -Dm 644 $HBB/res/citrusremoteviewer.service -t "%{buildroot}/usr/share/citrusremoteviewer/files"
install -Dm 644 $HBB/res/citrusremoteviewer.desktop -t "%{buildroot}/usr/share/citrusremoteviewer/files"
install -Dm 644 $HBB/res/citrusremoteviewer-link.desktop -t "%{buildroot}/usr/share/citrusremoteviewer/files"
install -Dm 644 $HBB/res/128x128@2x.png "%{buildroot}/usr/share/icons/hicolor/256x256/apps/citrusremoteviewer.png"
install -Dm 644 $HBB/res/scalable.svg "%{buildroot}/usr/share/icons/hicolor/scalable/apps/citrusremoteviewer.svg"

%files
/usr/share/citrusremoteviewer/*
/usr/share/citrusremoteviewer/files/citrusremoteviewer.service
/usr/share/icons/hicolor/256x256/apps/citrusremoteviewer.png
/usr/share/icons/hicolor/scalable/apps/citrusremoteviewer.svg
/usr/share/citrusremoteviewer/files/citrusremoteviewer.desktop
/usr/share/citrusremoteviewer/files/citrusremoteviewer-link.desktop

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
ln -sf /usr/share/citrusremoteviewer/citrusremoteviewer /usr/bin/citrusremoteviewer
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
    rm /usr/bin/citrusremoteviewer || true
    rmdir /usr/lib/citrusremoteviewer || true
    rmdir /usr/local/citrusremoteviewer || true
    rmdir /usr/share/citrusremoteviewer || true
    rm /usr/share/applications/citrusremoteviewer.desktop || true
    rm /usr/share/applications/citrusremoteviewer-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
    rmdir /usr/lib/citrusremoteviewer || true
    rmdir /usr/local/citrusremoteviewer || true
  ;;
esac
