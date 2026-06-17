import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/material.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  VoidCallback? onShow;
  VoidCallback? onExit;

  Future<void> init({
    required VoidCallback onShow,
    required VoidCallback onExit,
  }) async {
    this.onShow = onShow;
    this.onExit = onExit;

    trayManager.addListener(this);

    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('TaskManager');
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '열기',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '종료',
        ),
      ],
    ));
  }

  void destroy() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    onShow?.call();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      onShow?.call();
    } else if (menuItem.key == 'exit') {
      onExit?.call();
    }
  }
}
