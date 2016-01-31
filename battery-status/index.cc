#include <nan.h>
// windows.h is already included in nan.h

using namespace v8;

void GetStatus(const Nan::FunctionCallbackInfo<Value>& info) {
	LPSYSTEM_POWER_STATUS lpSystemPowerStatus;

	// Get current buttery status
	GetSystemPowerStatus(lpSystemPowerStatus);

	// Create local v8 number instance pointing buttery status number
	Local<Int32> localButteryStatusNumber = Nan::New(lpSystemPowerStatus->ACLineStatus);

	// Set return value
	info.GetReturnValue().Set(localButteryStatusNumber);
}

void Init(Local<Object> exports) {
	exports->Set(Nan::New("get").ToLocalChecked(), Nan::New<FunctionTemplate>(GetStatus)->GetFunction());
}

NODE_MODULE(batterystatus, Init)
