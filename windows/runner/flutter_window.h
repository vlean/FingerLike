#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <vector>

#include <memory>
#include <string>

#include "win32_window.h"

// 位置标记结构
struct PositionMarker {
  int x;
  int y;
  std::string name;

  PositionMarker(int x, int y, const std::string& name) : x(x), y(y), name(name) {}
};

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel for screen overlay
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> screen_channel_;

  // Overlay window handle
  HWND overlay_window_ = nullptr;
  std::vector<PositionMarker> current_markers_;

  // Screen overlay methods
  void ShowScreenOverlay(const std::vector<PositionMarker>& markers);
  void HideScreenOverlay();
  void RegisterScreenOverlayMethodHandler();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
