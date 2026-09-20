#include <windows.h>

#include <cstdio>
#include <string>
#include <vector>

namespace {

constexpr int kLauncherError = 21;

std::wstring GetExecutablePath() {
  std::vector<wchar_t> buffer(32768);
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return L"";
  }
  return std::wstring(buffer.data(), length);
}

std::wstring GetParentDirectory(const std::wstring& path) {
  const std::wstring::size_type separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? L"" : path.substr(0, separator);
}

bool IsFile(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

std::wstring FindOnPath(const wchar_t* fileName) {
  const DWORD required = SearchPathW(nullptr, fileName, nullptr, 0, nullptr, nullptr);
  if (required == 0) {
    return L"";
  }

  std::vector<wchar_t> buffer(required + 1);
  const DWORD length = SearchPathW(
      nullptr, fileName, nullptr, static_cast<DWORD>(buffer.size()), buffer.data(), nullptr);
  if (length == 0 || length >= buffer.size()) {
    return L"";
  }
  return std::wstring(buffer.data(), length);
}

// 按 Windows CommandLineToArgvW 规则转义单个参数。
std::wstring QuoteArgument(const std::wstring& argument) {
  const bool needsQuotes = argument.empty() ||
      argument.find_first_of(L" \t\n\v\"") != std::wstring::npos;
  if (!needsQuotes) {
    return argument;
  }

  std::wstring quoted = L"\"";
  size_t backslashCount = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashCount;
      continue;
    }
    if (character == L'\"') {
      quoted.append(backslashCount * 2 + 1, L'\\');
      quoted.push_back(L'\"');
      backslashCount = 0;
      continue;
    }
    quoted.append(backslashCount, L'\\');
    backslashCount = 0;
    quoted.push_back(character);
  }
  quoted.append(backslashCount * 2, L'\\');
  quoted.push_back(L'\"');
  return quoted;
}

void WriteError(const std::wstring& message) {
  const int size = WideCharToMultiByte(
      CP_UTF8, 0, message.c_str(), static_cast<int>(message.size()), nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return;
  }
  std::string utf8(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, message.c_str(), static_cast<int>(message.size()),
                      utf8.data(), size, nullptr, nullptr);
  std::fwrite(utf8.data(), 1, utf8.size(), stderr);
  std::fwrite("\n", 1, 1, stderr);
}

}

int wmain(int argc, wchar_t* argv[]) {
  const std::wstring executablePath = GetExecutablePath();
  if (executablePath.empty()) {
    WriteError(L"calcx: unable to resolve the launcher path");
    return kLauncherError;
  }

  const std::wstring executableDirectory = GetParentDirectory(executablePath);
  const std::wstring scriptPath =
      executableDirectory + L"\\tools\\calcx\\runtime\\calcx.ps1";
  if (!IsFile(scriptPath)) {
    WriteError(L"calcx: runtime script was not found: " + scriptPath);
    return kLauncherError;
  }

  const std::wstring pwshPath = FindOnPath(L"pwsh.exe");
  if (pwshPath.empty()) {
    WriteError(L"calcx: pwsh.exe was not found in PATH");
    return kLauncherError;
  }

  std::vector<std::wstring> arguments = {
      pwshPath, L"-NoLogo", L"-NoProfile", L"-NonInteractive", L"-File", scriptPath};
  for (int index = 1; index < argc; ++index) {
    arguments.emplace_back(argv[index]);
  }

  std::wstring commandLine;
  for (const std::wstring& argument : arguments) {
    if (!commandLine.empty()) {
      commandLine.push_back(L' ');
    }
    commandLine.append(QuoteArgument(argument));
  }
  std::vector<wchar_t> mutableCommandLine(commandLine.begin(), commandLine.end());
  mutableCommandLine.push_back(L'\0');

  STARTUPINFOW startupInfo{};
  startupInfo.cb = sizeof(startupInfo);
  PROCESS_INFORMATION processInfo{};
  const BOOL started = CreateProcessW(
      pwshPath.c_str(), mutableCommandLine.data(), nullptr, nullptr, TRUE, 0, nullptr, nullptr,
      &startupInfo, &processInfo);
  if (!started) {
    WriteError(L"calcx: unable to start pwsh.exe");
    return kLauncherError;
  }

  WaitForSingleObject(processInfo.hProcess, INFINITE);
  DWORD exitCode = kLauncherError;
  if (!GetExitCodeProcess(processInfo.hProcess, &exitCode)) {
    exitCode = kLauncherError;
  }
  CloseHandle(processInfo.hThread);
  CloseHandle(processInfo.hProcess);
  return static_cast<int>(exitCode);
}
