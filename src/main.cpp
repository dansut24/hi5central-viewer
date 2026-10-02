#include "app/viewer_app.h"

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>

#include <string>
#include <vector>

namespace {

std::string WideToUtf8(const wchar_t* value) {
    if (!value) return {};
    const int needed = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
    if (needed <= 1) return {};
    std::string out(static_cast<size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value, -1, out.data(), needed, nullptr, nullptr);
    out.resize(static_cast<size_t>(needed - 1));
    return out;
}

} // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    int argc = 0;
    LPWSTR* argvWide = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::vector<std::string> args;
    std::vector<char*> argv;

    if (argvWide && argc > 0) {
        args.reserve(static_cast<size_t>(argc));
        argv.reserve(static_cast<size_t>(argc));
        for (int i = 0; i < argc; ++i) args.push_back(WideToUtf8(argvWide[i]));
        for (auto& arg : args) argv.push_back(arg.data());
        LocalFree(argvWide);
    }

    hi5::ViewerApp app;
    return app.Run(static_cast<int>(argv.size()), argv.empty() ? nullptr : argv.data());
}
#else
int main(int argc, char* argv[]) {
    hi5::ViewerApp app;
    return app.Run(argc, argv);
}
#endif