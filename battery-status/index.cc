#include <nan.h>

using namespace v8;

NAN_METHOD(GetStatus) {
	NanScope();
	NanReturnValue(String::New("ok"));
}

void Init(Handle<Object> exports) {
	exports->Set(NanSymbol("get"), FunctionTemplate::New(GetStatus)->GetFunction());
}

NODE_MODULE(batterystatus, Init)
