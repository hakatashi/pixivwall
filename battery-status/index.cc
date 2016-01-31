#include <nan.h>

using namespace v8;

void GetStatus(const Nan::FunctionCallbackInfo<Value>& info) {
	info.GetReturnValue().Set(Nan::New("world").ToLocalChecked());
}

void Init(Local<Object> exports) {
	exports->Set(Nan::New("get").ToLocalChecked(), Nan::New<FunctionTemplate>(GetStatus)->GetFunction());
}

NODE_MODULE(batterystatus, Init)
