#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

static constexpr const wchar_t kMutexName[] =
    L"TaskManager_SingleInstance_{052817F2-E157-48D0-BF2A-AFBBC5A06B65}";

static constexpr const wchar_t kWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";

static constexpr const wchar_t kWindowTitle[] = L"taskmanager";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, kMutexName);
  if (hMutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS)
  {
    HWND hWnd = ::FindWindowW(kWindowClassName, nullptr);
    if (hWnd != nullptr)
    {
      ::ShowWindow(hWnd, SW_SHOW);
      if (::IsIconic(hWnd))
      {
        ::ShowWindow(hWnd, SW_RESTORE);
      }
      ::SetForegroundWindow(hWnd);
    }
    ::CloseHandle(hMutex);
    return EXIT_SUCCESS;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size))
  {
    ::CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CloseHandle(hMutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}