#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  if (overlay_window_) {
    DestroyWindow(overlay_window_);
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Register screen overlay method channel
  RegisterScreenOverlayMethodHandler();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterScreenOverlayMethodHandler() {
  screen_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "screen_overlay",
          &flutter::StandardMethodCodec::GetInstance());

  screen_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "showOverlay") {
          auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto markers_it = args->find(flutter::EncodableValue("markers"));
            if (markers_it != args->end()) {
              auto* markers_list = std::get_if<flutter::EncodableList>(&markers_it->second);
              if (markers_list) {
                std::vector<PositionMarker> markers;
                for (const auto& marker : *markers_list) {
                  auto* marker_map = std::get_if<flutter::EncodableMap>(&marker);
                  if (marker_map) {
                    auto x_it = marker_map->find(flutter::EncodableValue("x"));
                    auto y_it = marker_map->find(flutter::EncodableValue("y"));
                    auto name_it = marker_map->find(flutter::EncodableValue("name"));

                    if (x_it != marker_map->end() && y_it != marker_map->end() &&
                        name_it != marker_map->end()) {
                      int x = std::get<int>(x_it->second);
                      int y = std::get<int>(y_it->second);
                      std::string name = std::get<std::string>(name_it->second);
                      markers.push_back(PositionMarker(x, y, name));
                    }
                  }
                }
                ShowScreenOverlay(markers);
                result(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result(flutter::EncodableValue(false));
        } else if (call.method_name() == "hideOverlay") {
          HideScreenOverlay();
          result(flutter::EncodableValue(true));
        } else if (call.method_name() == "getScreenSize") {
          int screen_width = GetSystemMetrics(SM_CXSCREEN);
          int screen_height = GetSystemMetrics(SM_CYSCREEN);

          flutter::EncodableMap size_map = {
            {flutter::EncodableValue("width"), flutter::EncodableValue(screen_width)},
            {flutter::EncodableValue("height"), flutter::EncodableValue(screen_height)},
          };
          result(flutter::EncodableValue(size_map));
        } else {
          result(FlutterError("unknown_method", "Unknown method", nullptr));
        }
      });
}

void FlutterWindow::ShowScreenOverlay(const std::vector<PositionMarker>& markers) {
  // Hide existing overlay if any
  if (overlay_window_) {
    DestroyWindow(overlay_window_);
    overlay_window_ = nullptr;
  }

  current_markers_ = markers;

  // Get screen dimensions
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  // Register window class for overlay
  static const wchar_t* kOverlayClassName = L"FingerLikeOverlay";
  static bool class_registered = false;

  if (!class_registered) {
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = [](HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) -> LRESULT {
      static FlutterWindow* window = nullptr;
      static std::vector<PositionMarker> markers;

      if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCT*>(lParam);
        window = reinterpret_cast<FlutterWindow*>(cs->lpCreateParams);
      }

      switch (msg) {
        case WM_NCCREATE:
          markers = *reinterpret_cast<std::vector<PositionMarker>*>(
              reinterpret_cast<CREATESTRUCT*>(lParam)->lpCreateParams);
          return TRUE;
        case WM_PAINT: {
          PAINTSTRUCT ps;
          HDC hdc = BeginPaint(hwnd, &ps);

          // Fill background with semi-transparent black
          RECT client_rect;
          GetClientRect(hwnd, &client_rect);

          // Create transparent background
          BLENDFUNCTION blend = {AC_SRC_OVER, 0, 80, 0};  // 80/255 alpha for background

          // Draw markers
          for (const auto& marker : markers) {
            // Draw crosshair
            HPEN hPen = CreatePen(PS_SOLID, 1, RGB(255, 0, 0));
            HPEN hOldPen = (HPEN)SelectObject(hdc, hPen);

            // Horizontal line
            MoveToEx(hdc, 0, marker.y, nullptr);
            LineTo(hdc, marker.x - 10, marker.y);
            MoveToEx(hdc, marker.x + 10, marker.y, nullptr);
            LineTo(hdc, 2000, marker.y);

            // Vertical line
            MoveToEx(hdc, marker.x, 0, nullptr);
            LineTo(hdc, marker.x, marker.y - 10);
            MoveToEx(hdc, marker.x, marker.y + 10, nullptr);
            LineTo(hdc, marker.x, 2000);

            SelectObject(hdc, hOldPen);
            DeleteObject(hPen);

            // Draw circle
            HBRUSH hBrush = CreateSolidBrush(RGB(255, 0, 0));
            HPEN hCirclePen = CreatePen(PS_SOLID, 2, RGB(255, 255, 255));
            HBRUSH hOldBrush = (HBRUSH)SelectObject(hdc, hBrush);
            HPEN hOldPen2 = (HPEN)SelectObject(hdc, hCirclePen);

            Ellipse(hdc, marker.x - 10, marker.y - 10, marker.x + 10, marker.y + 10);

            SelectObject(hdc, hOldBrush);
            SelectObject(hdc, hOldPen2);
            DeleteObject(hBrush);
            DeleteObject(hCirclePen);

            // Draw name label background
            int text_length = marker.name.length();
            SIZE text_size;
            GetTextExtentPoint32A(hdc, marker.name.c_str(), text_length, &text_size);

            RECT label_rect = {marker.x + 15, marker.y - 10,
                              marker.x + 15 + text_size.cx + 8, marker.y + 10};
            HBRUSH label_brush = CreateSolidBrush(RGB(33, 150, 243));
            FillRect(hdc, &label_rect, label_brush);
            DeleteObject(label_brush);

            // Draw name label text
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, RGB(255, 255, 255));
            TextOutA(hdc, marker.x + 19, marker.y - 8, marker.name.c_str(), text_length);
          }

          EndPaint(hwnd, &ps);
          return 0;
        }
        case WM_ERASEBKGND:
          return 1;
        case WM_DESTROY:
          PostQuitMessage(0);
          return 0;
        case WM_LBUTTONDBLCLK:
          // Close on double-click
          DestroyWindow(hwnd);
          return 0;
      }
      return DefWindowProc(hwnd, msg, wParam, lParam);
    };

    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = kOverlayClassName;
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wc.style = CS_HREDRAW | CS_VREDRAW;

    if (!RegisterClassW(&wc)) {
      return;
    }
    class_registered = true;
  }

  // Create layered window for overlay
  overlay_window_ = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
      kOverlayClassName,
      L"Position Overlay",
      WS_POPUP,
      0, 0, screen_width, screen_height,
      nullptr, nullptr, GetModuleHandle(nullptr),
      &current_markers_
  );

  if (overlay_window_) {
    // Make window semi-transparent
    SetLayeredWindowAttributes(overlay_window_, 0, 200, LWA_ALPHA);

    // Capture mouse input so we can detect clicks
    ShowWindow(overlay_window_, SW_SHOW);
    UpdateWindow(overlay_window_);

    // Bring to front
    SetForegroundWindow(overlay_window_);
  }
}

void FlutterWindow::HideScreenOverlay() {
  if (overlay_window_) {
    DestroyWindow(overlay_window_);
    overlay_window_ = nullptr;
  }
  current_markers_.clear();
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
