@interface NSObject (NSObjectScriptingAdditions)
- (NSAppleEventDescriptor *) scriptingAnyDescriptor;
- (NSAppleEventDescriptor *) scriptingTextDescriptor;
- (NSAppleEventDescriptor *) scriptingBooleanDescriptor;
- (NSAppleEventDescriptor *) scriptingDateDescriptor;
- (NSAppleEventDescriptor *) scriptingFileDescriptor;
- (NSAppleEventDescriptor *) scriptingIntegerDescriptor;
- (NSAppleEventDescriptor *) scriptingLocationDescriptor;
- (NSAppleEventDescriptor *) scriptingNumberDescriptor;
- (NSAppleEventDescriptor *) scriptingPointDescriptor;
- (NSAppleEventDescriptor *) scriptingRealDescriptor;
- (NSAppleEventDescriptor *) scriptingRecordDescriptor;
- (NSAppleEventDescriptor *) scriptingRectangleDescriptor;
- (NSAppleEventDescriptor *) scriptingSpecifierDescriptor;
- (NSAppleEventDescriptor *) scriptingTypeDescriptor;
@end