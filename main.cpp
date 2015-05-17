#define UNICODE
#define _UNICODE
#define STRICT
#define STRICT_TYPED_ITEMIDS

#include <windows.h>
#include <Shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>
#include <stdio.h>

#define LOG(format, ...) wprintf(format L"\n", __VA_ARGS__)
#define ERRORED(line) wprintf(L"Error at line %d\n", line)

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
    LPCWSTR paths[] = {
        L"C:\\Users\\hakatashi\\Documents\\GitHub\\pixivwall\\images\\01.jpg",
        L"C:\\Users\\hakatashi\\Documents\\GitHub\\pixivwall\\images\\02.jpg",
        L"C:\\Users\\hakatashi\\Documents\\GitHub\\pixivwall\\images\\03.jpg",
        L"C:\\Users\\hakatashi\\Documents\\GitHub\\pixivwall\\images\\04.jpg",
        L"C:\\Users\\hakatashi\\Documents\\GitHub\\pixivwall\\images\\05.jpg"
    };

    HRESULT hr = CoInitialize(nullptr);
    if (FAILED(hr)) return ERRORED(__LINE__);

    IDesktopWallpaper *pDesktopWallpaper = nullptr;
    hr = CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (FAILED(hr)) return ERRORED(__LINE__);
    ReleaseOnExit releaseDesktopWallpaper(pDesktopWallpaper);

    IShellItemArray *items;
    hr = CreateShellItemArrayFromPaths(5, paths, &items);
    if (FAILED(hr)) return ERRORED(__LINE__);

    hr = pDesktopWallpaper->SetSlideshow(items);
    if (FAILED(hr)) return ERRORED(__LINE__);

    LOG(L"Operation Successfull");

    return 0;
}
