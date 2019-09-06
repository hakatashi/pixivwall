#include <napi.h>
#include <uv.h>
#include <windows.h>

using namespace Napi;

napi_value GetStatus(const Napi::CallbackInfo& info) {
	Napi::Env env = info.Env();

	LPSYSTEM_POWER_STATUS lpSystemPowerStatus;

	// Get current buttery status
	GetSystemPowerStatus(lpSystemPowerStatus);

	// Create local v8 number instance pointing buttery status number
	napi_value localButteryStatusNumber = Napi::Number::New(env, lpSystemPowerStatus->ACLineStatus);

	// Set return value
	return localButteryStatusNumber;
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
	exports.Set(Napi::String::New(env, "get"), Napi::Function::New(env, GetStatus));
	return exports;
}

NODE_API_MODULE(batterystatus, Init)
