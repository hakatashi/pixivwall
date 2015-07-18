#define UNICODE
#define _UNICODE
#define STRICT
#define STRICT_TYPED_ITEMIDS

#include <windows.h>
#include <winhttp.h>
#include <Shlobj.h>
#include <Shlwapi.h>
#include <Pathcch.h>
#include <shobjidl.h>
#include <wrl/client.h>
#include <stdio.h>

#define LOG(format, ...) wprintf(format L"\n", __VA_ARGS__)
#define ERRORED(line) wprintf(L"Error at line %d\n", line)

#define MAX_IMAGES 256

class CoUninitializeOnExit {
public:
    CoUninitializeOnExit() {}
    ~CoUninitializeOnExit() { CoUninitialize(); }
};

class ReleaseOnExit {
public:
    ReleaseOnExit(IUnknown *p) : m_p(p) {}
    ~ReleaseOnExit() { if (nullptr != m_p) { m_p->Release(); } }
private:
    IUnknown *m_p;
};

// Thanks to http://blogs.msdn.com/b/oldnewthing/archive/2014/03/14/10507794.aspx
HRESULT CreateShellItemArrayFromPaths(UINT ct, LPCWSTR rgt[], IShellItemArray **ppsia) {
    *ppsia = nullptr;

    PIDLIST_ABSOLUTE *rgpidl = new PIDLIST_ABSOLUTE[ct];
    HRESULT hr = rgpidl ? S_OK : E_OUTOFMEMORY;

    if (FAILED(hr)) return ERRORED(__LINE__);

    int cpidl;
    for (cpidl = 0; SUCCEEDED(hr) && cpidl < ct; cpidl++) {
        hr = SHParseDisplayName(rgt[cpidl], nullptr, &rgpidl[cpidl], 0, nullptr);
    }

    if (SUCCEEDED(hr)) {
        hr = SHCreateShellItemArrayFromIDLists(cpidl, rgpidl, ppsia);
    }

    for (int i = 0; i < cpidl; i++) {
        CoTaskMemFree(rgpidl[i]);
    }

    delete[] rgpidl;
    return hr;
}

int _cdecl wmain(int argc, LPCWSTR argv[]) {
    LPCWSTR paths[MAX_IMAGES];

    WCHAR dirname[MAX_PATH];
    GetCurrentDirectory(MAX_PATH, dirname);

    LOG(L"Current directory is %s", dirname);

    for (int i = 1; i < argc; i++) {
        LPWSTR path = new WCHAR[MAX_PATH];

        PathCchCombine(path, MAX_PATH, dirname, argv[i]);
        paths[i - 1] = path;
        LOG(L"Image%02d: %s", i, path);
    }

    // Initialize COM Interface
    HRESULT hr = CoInitialize(nullptr);
    if (FAILED(hr)) return ERRORED(__LINE__);

    // Create instance of IDesktopWallpaper
    IDesktopWallpaper *pDesktopWallpaper = nullptr;
    hr = CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (FAILED(hr)) return ERRORED(__LINE__);
    ReleaseOnExit releaseDesktopWallpaper(pDesktopWallpaper);

    IShellItemArray *items;
    hr = CreateShellItemArrayFromPaths(argc - 1, paths, &items);
    if (FAILED(hr)) return ERRORED(__LINE__);

    hr = pDesktopWallpaper->SetSlideshow(items);
    if (FAILED(hr)) return ERRORED(__LINE__);

    LOG(L"Operation Successfull");

    return 0;
}
