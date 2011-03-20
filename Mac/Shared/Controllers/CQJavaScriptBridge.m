#import "CQJavaScriptBridge.h"

#import <objc/runtime.h>

JSGlobalContextRef JSContextGetGlobalContext(JSContextRef ctx);

static JSValueRef scriptErrorForException(JSContextRef, NSException *);
static JSObjectRef scriptObjectForObject(JSContextRef, id);
static JSValueRef scriptValueForObject(JSContextRef, id);
static JSValueRef scriptValueForValue(JSContextRef, void *, const char *);
static JSObjectRef scriptFunctionObjectForSelectors(JSContextRef, NSHashTable *);
static id objectForScriptValue(JSContextRef, JSValueRef, JSValueRef *);
static bool isBlockedSelector(SEL);

static JSClassRef scriptClassForClass(Class);
static JSClassRef scriptConstructorClassForClass(Class);

static JSClassRef rootScriptClass = NULL;
static JSClassRef scriptFunctionClass = NULL;
static JSClassRef rootConstructorScriptClass = NULL;

static const unsigned numberOfHiddenMethodArguments = 2;
static const unsigned indexOfFirstNonHiddenMethodArgument = 2;

#pragma mark -

MVInline JSValueRef stringScriptValue(JSContextRef context, const char *string) {
	JSStringRef scriptString = JSStringCreateWithUTF8CString(string);
	JSValueRef scriptValue = JSValueMakeString(context, scriptString);
	JSStringRelease(scriptString);

	return scriptValue;
}

static size_t instancesOfCharacterInString(char character, const char *string) {
	if (!string)
		return 0;

	size_t count = 0;
	size_t length = strlen(string);
	for (size_t i = 0; i < length; ++i) {
		if (string[i] == character)
			++count;
	}

	return count;
}

#pragma mark -

static void scriptClassRetain(NSMapTable *table, const void *class) {
	JSClassRetain((JSClassRef)class);
}

static void scriptClassRelease(NSMapTable *table, void *class) {
	if (class == rootScriptClass)
		rootScriptClass = NULL;
	if (class == rootConstructorScriptClass)
		rootConstructorScriptClass = NULL;
	JSClassRelease((JSClassRef)class);
}

MVInline NSMapTable *createScriptClassHashTable() {
	NSMapTableValueCallBacks valueCallbacks = { scriptClassRetain, scriptClassRelease, NULL };
	return NSCreateMapTable(NSNonOwnedPointerOrNullMapKeyCallBacks, valueCallbacks, 0);
}

#pragma mark -

static NSMapTable *scriptClasses() {
	static NSMapTable *classes = nil;
	if (!classes)
		classes = createScriptClassHashTable();
	return classes;
}

static NSMapTable *scriptConstructorClasses() {
	static NSMapTable *classes = nil;
	if (!classes)
		classes = createScriptClassHashTable();
	return classes;
}

#pragma mark -

static NSMapTable *scriptObjects() {
	static NSMapTable *objects = nil;
	if (!objects)
		objects = NSCreateMapTable(NSObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
	return objects;
}

static NSMapTable *scriptConstructorObjects() {
	static NSMapTable *objects = nil;
	if (!objects)
		objects = NSCreateMapTable(NSNonOwnedPointerOrNullMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
	return objects;
}

#pragma mark -

MVInline const char *scriptClassNameForClass(Class class) {
	return class_getName(class);
}

MVInline id objectFromScriptObject(JSContextRef context, JSObjectRef scriptObject) {
	if (!rootScriptClass)
		return nil;
	if (scriptObject && (!context || JSValueIsObjectOfClass(context, scriptObject, rootScriptClass)))
		return JSObjectGetPrivate(scriptObject);
	return nil;
}

MVInline NSHashTable *selectorsFromScriptFunctionObject(JSContextRef context, JSObjectRef scriptObject) {
	if (!scriptFunctionClass)
		return nil;
	if (scriptObject && (!context || JSValueIsObjectOfClass(context, scriptObject, scriptFunctionClass)))
		return JSObjectGetPrivate(scriptObject);
	return nil;
}

MVInline Class classFromScriptConstructorObject(JSContextRef context, JSObjectRef scriptObject) {
	if (!rootConstructorScriptClass)
		return Nil;
	if (scriptObject && (!context || JSValueIsObjectOfClass(context, scriptObject, rootConstructorScriptClass)))
		return JSObjectGetPrivate(scriptObject);
	return Nil;
}

#pragma mark -

struct ObjCPropertyAttributes {
	char *data;
	const char *name;
	const char *type;
	bool readonly;
	enum { Assign, Copy, Retain } operation;
	const char *setter;
	const char *getter;
	const char *ivar;
};

static void parseAttributesForObjCProperty(objc_property_t property, struct ObjCPropertyAttributes *attributes) {
	if (!attributes)
		return;

	bzero(attributes, sizeof(struct ObjCPropertyAttributes));

	if (!property)
		return;

	attributes->data = strdup(property_getAttributes(property));
	attributes->name = property_getName(property);

	char *state = attributes->data;
	char *attribute = NULL;
	while ((attribute = strsep(&state, ","))) {
		switch (*attribute) {
		case 'T':
			// The type for objects can include the class name (e.g '@"NSArray"') and is not what @encode outputs (e.g. '@').
			// The class name part upsets -[NSMethodSignature signatureWithObjCTypes:], so just drop it here.
			if (attribute[1] == '@')
				attributes->type = @encode(id);
			else attributes->type = &attribute[1];
			break;

		case 'G':
			attributes->getter = &attribute[1];
			break;

		case 'S':
			attributes->setter = &attribute[1];
			break;

		case 'V':
			attributes->ivar = &attribute[1];
			break;

		case 'R':
			attributes->readonly = true;
			break;

		case 'C':
			attributes->operation = Copy;
			break;

		case '&':
			attributes->operation = Retain;
			break;
		}
	}
}

MVInline void freeAttributesForObjCProperty(struct ObjCPropertyAttributes *attributes) {
	if (attributes && attributes->data)
		free(attributes->data);

	bzero(attributes, sizeof(struct ObjCPropertyAttributes));
}

#pragma mark -

static SEL defaultSetterSelector(const char *propertyName) {
	if (!propertyName)
		return NULL;

	size_t length = strlen(propertyName);
	char *setterString = alloca(length + 5);

	setterString[0] = 's';
	setterString[1] = 'e';
	setterString[2] = 't';

	memcpy(setterString + 3, propertyName, length);

	setterString[3] = toupper(setterString[3]);

	setterString[length + 3] = ':';
	setterString[length + 4] = '\0';

	return sel_registerName(setterString);
}

static NSHashTable *selectorsMatchingPrefix(Class class, const char *prefix, bool (*isBlocked)(SEL)) {
	if (!class || !prefix)
		return NULL;

	NSHashTable *foundSelectors = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 8);

	while (class) {
		unsigned methodCount = 0;
		Method *methods = class_copyMethodList(class, &methodCount);

		size_t prefixLength = strlen(prefix);

		for (size_t i = 0; i < methodCount; ++i) {
			SEL methodSelector = method_getName(methods[i]);

			if (isBlocked && isBlocked(methodSelector))
				continue;

			if (NSHashGet(foundSelectors, methodSelector))
				continue;

			const char *selectorName = sel_getName(methodSelector);
			if (class_getProperty(class, selectorName))
				continue;

			if (strncmp(prefix, selectorName, prefixLength))
				continue;

			NSHashInsertKnownAbsent(foundSelectors, methodSelector);
		}

		free(methods);

		class = class_getSuperclass(class);
	}

	return [foundSelectors autorelease];
}

static void skipTypeModifiers(const char **objcTypePointer) {
	const char *objcType = *objcTypePointer;

beginning:
	// Skip any type modifiers.
	switch (*objcType++) {
    case 'r': // const
    case 'n': // in
    case 'N': // inout
    case 'o': // out
    case 'O': // bycopy
    case 'R': // byref
    case 'V': // oneway
		// Skip to the next type.
		goto beginning;

	case '\0': // End of type.
	default:
		--objcType;
		break;
	}

	*objcTypePointer = objcType;
}

static bool typesAreEqual(JSType scriptType, const char *objcType) {
	skipTypeModifiers(&objcType);

	switch (scriptType) {
	case kJSTypeUndefined:
	case kJSTypeNull:
		return *objcType == 'v' || !strcmp(objcType, @encode(void *));
	case kJSTypeBoolean:
		// This assumes the 'c' type is a 'BOOL'.
		return *objcType == 'B' || *objcType == 'c';
	case kJSTypeNumber:
		return tolower(*objcType) == 'c' || tolower(*objcType) == 's' || tolower(*objcType) == 'i' || tolower(*objcType) == 'l' || tolower(*objcType) == 'q' || *objcType == 'f' || tolower(*objcType) == 'd';
	case kJSTypeString:
		// This assumes the '@' type is likely a NSString if the script type is a string.
		return *objcType == '*' || *objcType == '@';
	case kJSTypeObject:
		return *objcType == '@';
	}

	return false;
}

#pragma mark -

MVInline bool isGetterMethod(Method method) {
	if (!method)
		return false;

	char returnType = '\0';
	method_getReturnType(method, &returnType, 1);
	return returnType != 'v' && method_getNumberOfArguments(method) == numberOfHiddenMethodArguments; // @encode(void)
}

static void getGetterSelectorAndReturnType(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, id object, char **outReturnType, SEL *outGetterSelector) {
	Class class = [object class];

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	char *returnType = NULL;
	SEL getterSelector = NULL;

	objc_property_t property = class_getProperty(class, propertyNameString);
	if (property) {
		struct ObjCPropertyAttributes propertyAttributes;
		parseAttributesForObjCProperty(property, &propertyAttributes);

		getterSelector = sel_registerName(propertyAttributes.getter ? propertyAttributes.getter : propertyAttributes.name);
		returnType = strdup(propertyAttributes.type);

		freeAttributesForObjCProperty(&propertyAttributes);
	}

	if (!getterSelector) {
		Method method = class_getInstanceMethod(class, sel_registerName(propertyNameString));
		if (!isGetterMethod(method))
			return;

		getterSelector = method_getName(method);
		returnType = method_copyReturnType(method);
	}

	NSCAssert(getterSelector, @"getterSelector should be defined");
	NSCAssert(returnType, @"returnType should be defined");
	if (!getterSelector || !returnType)
		return;

	if (outReturnType)
		*outReturnType = returnType;

	if (outGetterSelector)
		*outGetterSelector = getterSelector;
}

#pragma mark -

MVInline bool isSetterMethod(Method method) {
	if (!method)
		return false;

	char returnType = '\0';
	method_getReturnType(method, &returnType, 1);
	return returnType == 'v' && method_getNumberOfArguments(method) == (numberOfHiddenMethodArguments + 1); // @encode(void)
}

static void getSetterSelectorAndArgumentType(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, id object, SEL *outSetterSelector, char **outArgumentType, bool *outReadOnly) {
	Class class = [object class];

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	SEL setterSelector = NULL;
	char *argumentType = NULL;

	objc_property_t property = class_getProperty(class, propertyNameString);
	if (property) {
		struct ObjCPropertyAttributes propertyAttributes;
		parseAttributesForObjCProperty(property, &propertyAttributes);

		if (propertyAttributes.readonly) {
			if (outReadOnly)
				*outReadOnly = true;
			freeAttributesForObjCProperty(&propertyAttributes);
			return;
		}

		setterSelector = propertyAttributes.setter ? sel_registerName(propertyAttributes.setter) : defaultSetterSelector(propertyAttributes.name);
		argumentType = strdup(propertyAttributes.type);

		freeAttributesForObjCProperty(&propertyAttributes);
	}

	if (!setterSelector) {
		Method method = class_getInstanceMethod(class, defaultSetterSelector(propertyNameString));
		if (!isSetterMethod(method))
			return;

		setterSelector = method_getName(method);
		argumentType = method_copyArgumentType(method, 2);
	}

	NSCAssert(setterSelector, @"setterSelector should be defined");
	NSCAssert(argumentType, @"argumentType should be defined");
	if (!setterSelector || !argumentType)
		return;

	if (isBlockedSelector(setterSelector))
		return;

	if (outArgumentType)
		*outArgumentType = argumentType;

	if (outSetterSelector)
		*outSetterSelector = setterSelector;
}

#pragma mark -

static bool isBlockedSelector(SEL selector) {
	if (!selector)
		return true;

	static NSHashTable *blockedSelectors = nil;
	if (!blockedSelectors) {
		blockedSelectors = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 8);

		NSHashInsertKnownAbsent(blockedSelectors, @selector(alloc));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(allocWithZone:));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(autorelease));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(dealloc));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(finalize));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(new));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(release));
		NSHashInsertKnownAbsent(blockedSelectors, @selector(retain));
	}

	return NSHashGet(blockedSelectors, selector) ? true : false;
}

enum ArgumentCountRequirement { DontRequireExactArgumentCount, RequireExactArgumentCount };
enum ArgumentTypeRequirement { DontRequireExactArgumentTypes, RequireSomeExactArgumentTypes, RequireAllExactArgumentTypes };

static SEL bestMatchSelector(NSHashTable *selectors, Class class, JSContextRef context, size_t argumentCount, const JSValueRef arguments[], enum ArgumentCountRequirement countRequirement, enum ArgumentTypeRequirement typeRequirement) {
	SEL bestMatch = NULL;
	size_t numberOfMatchedTypes = 0;

	NSHashEnumerator enumerator = NSEnumerateHashTable(selectors);

	for (SEL selector = NSNextHashEnumeratorItem(&enumerator); selector; selector = NSNextHashEnumeratorItem(&enumerator)) {
		Method method = class_getInstanceMethod(class, selector);
		if (!method)
			continue;

		size_t methodArgumentCount = method_getNumberOfArguments(method) - numberOfHiddenMethodArguments;
		if (countRequirement == RequireExactArgumentCount && argumentCount != methodArgumentCount)
			continue;

		if (countRequirement == DontRequireExactArgumentCount && argumentCount && !methodArgumentCount)
			continue;

		size_t currentNumberOfMatchedTypes = 0;
		size_t minimumArgumentCount = MIN(argumentCount, methodArgumentCount);
		if (typeRequirement != DontRequireExactArgumentTypes && minimumArgumentCount) {
			bool someTypesEqual = false;

			for (size_t i = 0; i < minimumArgumentCount; ++i) {
				JSType scriptType = JSValueGetType(context, arguments[i]);

				char objcType[16];
				method_getArgumentType(method, numberOfHiddenMethodArguments + i, objcType, sizeof(objcType));

				if (typesAreEqual(scriptType, objcType)) {
					someTypesEqual = true;
					++currentNumberOfMatchedTypes;
				} else if (typeRequirement == RequireAllExactArgumentTypes) {
					someTypesEqual = false;
					break;
				}
			}

			if (!someTypesEqual || currentNumberOfMatchedTypes < numberOfMatchedTypes)
				continue;
		}

		if (bestMatch && numberOfMatchedTypes >= currentNumberOfMatchedTypes) {
			// We already have a match, so this second match makes things ambigious.
			bestMatch = NULL;
			break;
		}

		bestMatch = selector;
		numberOfMatchedTypes = currentNumberOfMatchedTypes;
	}

	NSEndHashTableEnumeration(&enumerator);

	return bestMatch;
}

static void convertScriptValue(JSContextRef context, JSValueRef scriptValue, const char *type, JSValueRef *scriptException, void (^handler)(void *value)) {
	skipTypeModifiers(&type);

	switch (*type) {
	case 'B': { // @encode(bool)
		bool booleanValue = JSValueToBoolean(context, scriptValue);
		handler(&booleanValue);
		return;
	}

	case 'c': // @encode(char), @encode(BOOL)
	case 'C': { // @encode(unsigned char)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		short charValue = isnan(doubleValue) ? 0 : doubleValue;
		handler(&charValue);
		return;
	}

	case 's': // @encode(short)
	case 'S': { // @encode(unsigned short)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		short shortValue = isnan(doubleValue) ? 0 : doubleValue;
		handler(&shortValue);
		return;
	}

	case 'i': // @encode(int)
	case 'I': { // @encode(unsigned int)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		int intValue = isnan(doubleValue) ? 0 : doubleValue;
		handler(&intValue);
		return;
	}

	case 'l': // @encode(long)
	case 'L': { // @encode(unsigned long)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		long longValue = isnan(doubleValue) ? 0 : doubleValue;
		handler(&longValue);
		return;
	}

	case 'q': // @encode(long long)
	case 'Q': { // @encode(unsigned long long)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		long long longLongValue = isnan(doubleValue) ? 0 : doubleValue;
		handler(&longLongValue);
		return;
	}

	case 'f': { // @encode(float)
		float floatValue = JSValueToNumber(context, scriptValue, scriptException);
		handler(&floatValue);
		return;
	}

	case 'd': { // @encode(double)
		double doubleValue = JSValueToNumber(context, scriptValue, scriptException);
		handler(&doubleValue);
		return;
	}

	case 'D': { // @encode(long double)
		long double longDoubleValue = JSValueToNumber(context, scriptValue, scriptException);
		handler(&longDoubleValue);
		return;
	}

	case '*': { // @encode(char *)
		JSStringRef scriptString = JSValueToStringCopy(context, scriptValue, scriptException);
		size_t maximumLength = JSStringGetMaximumUTF8CStringSize(scriptString);
		char *stringValue = malloc(maximumLength);

		JSStringGetUTF8CString(scriptString, stringValue, maximumLength);

		handler(&stringValue);

		JSStringRelease(scriptString);
		free(stringValue);
		return;
	}

	case '@': { // @encode(id), @encode(NSObject *), etc.
		// The receiver might not expect the object class we convert to, but we have no way to know.
		id object = objectForScriptValue(context, scriptValue, scriptException);
		handler(&object);
		return;
	}

	default: // Unsupported type.
		return;
	}
}

static JSValueRef callGetterFromScript(id target, SEL getterSelector, const char *returnType, JSContextRef context, JSValueRef* scriptException) {
	if (isBlockedSelector(getterSelector))
		return JSValueMakeUndefined(context);

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:returnType, NULL];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:getterSelector];

	JSValueRef result = NULL;

	@try {
		[invocation invokeWithTarget:target];

		void *returnValue = NULL;
		[invocation getReturnValue:&returnValue];

		result = scriptValueForValue(context, &returnValue, returnType);
	} @catch (NSException *exception) {
		if (scriptException)
			*scriptException = scriptErrorForException(context, exception);

		result = NULL;
	}

	return result;
}

static void callSetterFromScript(id target, SEL setterSelector, const char *argumentType, JSContextRef context, JSValueRef argumentValue, JSValueRef* scriptException) {
	if (isBlockedSelector(setterSelector))
		return;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode(void), argumentType, NULL];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:setterSelector];

	// Tell the invocation to retain the arguments, so the setArgument:: call retains or copies as needed.
	[invocation retainArguments];

	convertScriptValue(context, argumentValue, argumentType, scriptException, ^(void *value) { [invocation setArgument:value atIndex:indexOfFirstNonHiddenMethodArgument]; });

	if (!scriptException || !*scriptException) {
		@try {
			[invocation invokeWithTarget:target];
		} @catch (NSException *exception) {
			if (scriptException)
				*scriptException = scriptErrorForException(context, exception);
		}
	}
}

static JSValueRef callMethodFromScript(id target, NSHashTable *selectors, JSContextRef context, size_t argumentCount, const JSValueRef arguments[], JSValueRef* scriptException) {
	if (!target || !selectors || !NSCountHashTable(selectors))
		return NULL;

	SEL selector = NULL;
	if (NSCountHashTable(selectors) == 1) {
		NSHashEnumerator enumerator = NSEnumerateHashTable(selectors);
		selector = NSNextHashEnumeratorItem(&enumerator);
		NSEndHashTableEnumeration(&enumerator);
	} else {
		Class class = [target class];

		selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, RequireExactArgumentCount, RequireAllExactArgumentTypes);
		if (!selector)
			selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, RequireExactArgumentCount, RequireSomeExactArgumentTypes);
		if (!selector)
			selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, RequireExactArgumentCount, DontRequireExactArgumentTypes);
		if (!selector)
			selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, DontRequireExactArgumentCount, RequireAllExactArgumentTypes);
		if (!selector)
			selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, DontRequireExactArgumentCount, RequireSomeExactArgumentTypes);
		if (!selector)
			selector = bestMatchSelector(selectors, class, context, argumentCount, arguments, DontRequireExactArgumentCount, DontRequireExactArgumentTypes);
	}

	if (!selector) {
		// The selectors were ambiguous with the given arguments.
		if (scriptException)
			*scriptException = stringScriptValue(context, "Multiple selectors were found for this function and arguments, making this call ambiguous.");
		return NULL;
	}

	NSMethodSignature *signature = [target methodSignatureForSelector:selector];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:selector];

	// Tell the invocation to retain the arguments, so the setArgument:: call retains or copies as needed.
	[invocation retainArguments];

	size_t methodArgumentCount = [signature numberOfArguments] - numberOfHiddenMethodArguments;
	size_t minimumArgumentCount = MIN(argumentCount, methodArgumentCount);

	for (size_t i = 0; i < minimumArgumentCount; ++i) {
		size_t methodArgumentIndex = i + indexOfFirstNonHiddenMethodArgument;
		convertScriptValue(context, arguments[i], [signature getArgumentTypeAtIndex:methodArgumentIndex], scriptException, ^(void *value) { [invocation setArgument:value atIndex:methodArgumentIndex]; });
		if (scriptException && *scriptException)
			return NULL;
	}

	JSValueRef result = NULL;

	@try {
		[invocation invokeWithTarget:target];

		const char *returnType = [signature methodReturnType];
		if ([signature methodReturnLength]) {
			void *returnValue = alloca([signature methodReturnLength]);
			[invocation getReturnValue:&returnValue];

			result = scriptValueForValue(context, &returnValue, returnType);
		}
	} @catch (NSException *exception) {
		if (scriptException)
			*scriptException = scriptErrorForException(context, exception);

		return NULL;
	}

	return result;
}

#pragma mark -

static void scriptObjectFinalize(JSObjectRef scriptObject) {
	id object = objectFromScriptObject(NULL, scriptObject);

	NSCAssert(object, @"object should not be nil");

	NSMapRemove(scriptObjects(), object);
}

static JSValueRef scriptObjectMethodFunction(JSContextRef context, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* scriptException) {
	if (!argumentCount)
		return JSValueMakeUndefined(context);

	id object = objectFromScriptObject(context, thisObject);
	if (!object)
		return JSValueMakeUndefined(context);

	JSStringRef methodName = JSValueToStringCopy(context, arguments[0], scriptException);
	if (!methodName)
		return JSValueMakeUndefined(context);

	size_t maximumMethodNameStringLength = JSStringGetMaximumUTF8CStringSize(methodName);
	char *methodNameString = alloca(maximumMethodNameStringLength);
	JSStringGetUTF8CString(methodName, methodNameString, maximumMethodNameStringLength);

	JSStringRelease(methodName);

	SEL selector = sel_registerName(methodNameString);

	if (isBlockedSelector(selector))
		return JSValueMakeNull(context);

	if (![object respondsToSelector:selector])
		return JSValueMakeNull(context);

	NSHashTable *selectors = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 8);
	NSHashInsertKnownAbsent(selectors, selector);

	JSObjectRef methodFunction = scriptFunctionObjectForSelectors(context, selectors);

	[selectors release];

	return methodFunction;
}

static bool scriptObjectHasProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName) {
	id object = objectFromScriptObject(context, scriptObject);
	if (!object)
		return false;

	// Return false for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return false;

	SEL getterSelector = NULL;
	getGetterSelectorAndReturnType(context, scriptObject, propertyName, object, NULL, &getterSelector);

	if (getterSelector && !isBlockedSelector(getterSelector))
		return true;

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	return NSCountHashTable(selectorsMatchingPrefix([object class], propertyNameString, isBlockedSelector)) ? true : false;
}

static JSValueRef scriptObjectGetProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, JSValueRef *scriptException) {
	id object = objectFromScriptObject(context, scriptObject);
	if (!object)
		return NULL;

	// Return NULL for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return NULL;

	char *returnType = NULL;
	SEL getterSelector = NULL;
	getGetterSelectorAndReturnType(context, scriptObject, propertyName, object, &returnType, &getterSelector);

	if (getterSelector) {
		JSValueRef result = callGetterFromScript(object, getterSelector, returnType, context, scriptException);

		free(returnType);

		return result;
	}

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	return scriptFunctionObjectForSelectors(context, selectorsMatchingPrefix([object class], propertyNameString, isBlockedSelector));
}

static bool scriptObjectSetProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, JSValueRef value, JSValueRef *scriptException) {
	id object = objectFromScriptObject(context, scriptObject);
	if (!object)
		return false;

	// Return false for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return false;

	SEL setterSelector = NULL;
	char *argumentType = NULL;
	bool readOnly = false;

	getSetterSelectorAndArgumentType(context, scriptObject, propertyName, object, &setterSelector, &argumentType, &readOnly);

	if (readOnly)
		return true;

	if (!setterSelector)
		return false;

	callSetterFromScript(object, setterSelector, argumentType, context, value, scriptException);

	free(argumentType);

	return true;
}

static bool scriptObjectDeleteProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, JSValueRef *scriptException) {
	// Since ObjC can't remove properties like JavaScript just treat 'delete' as setting the property to null.
	return scriptObjectSetProperty(context, scriptObject, propertyName, JSValueMakeNull(context), scriptException);
}

static void scriptObjectGetPropertyNames(JSContextRef context, JSObjectRef scriptObject, JSPropertyNameAccumulatorRef propertyNames) {
	Class class = [objectFromScriptObject(context, scriptObject) class];
	while (class) {
		unsigned propertyCount = 0;
		objc_property_t *properties = class_copyPropertyList(class, &propertyCount);

		for (size_t i = 0; i < propertyCount; ++i) {
			const char *propertyNameString = property_getName(properties[i]);

			// Skip private properties, ones that start with an underscore.
			if (*propertyNameString == '_')
				continue;

			JSStringRef propertyName = JSStringCreateWithUTF8CString(propertyNameString);
			JSPropertyNameAccumulatorAddName(propertyNames, propertyName);
			JSStringRelease(propertyName);
		}

		free(properties);

		// Should include functions/methods here, but it would be hard to filter them since properties are also methods.

		class = class_getSuperclass(class);
	}
}

#pragma mark -

static void scriptFunctionObjectFinalize(JSObjectRef scriptObject) {
	NSHashTable *selectors = selectorsFromScriptFunctionObject(NULL, scriptObject);

	NSCAssert(selectors, @"selectors should not be nil");

	CFRelease(selectors); // Use CFRelease to work in GC. Retained in scriptFunctionObjectForSelectors.
}

static JSValueRef scriptFunctionObjectCallAsFunction(JSContextRef context, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* scriptException) {
	NSHashTable *selectors = selectorsFromScriptFunctionObject(context, function);

	id target = objectFromScriptObject(context, thisObject);
	if (!target)
		target = classFromScriptConstructorObject(context, thisObject);

	JSValueRef result = callMethodFromScript(target, selectors, context, argumentCount, arguments, scriptException);
	if (!result)
		return JSValueMakeUndefined(context);

	return result;
}

#pragma mark -

static void scriptConstructorObjectFinalize(JSObjectRef scriptObject) {
	Class class = classFromScriptConstructorObject(NULL, scriptObject);

	NSCAssert(class, @"class should not be Nil");

	NSMapRemove(scriptConstructorObjects(), class);
}

static JSObjectRef scriptConstructorObjectCallAsConstructor(JSContextRef context, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef *scriptException) {
	Class class = classFromScriptConstructorObject(context, constructor);
	if (!class)
		return NULL;

	id object = [class alloc];
	NSHashTable *selectors = selectorsMatchingPrefix([object class], "init", isBlockedSelector);

	JSValueRef result = callMethodFromScript(object, selectors, context, argumentCount, arguments, scriptException);
	if (!result) {
		[object release];
		return NULL;
	}

	// Get 'object' again by using objectFromScriptObject since the init method might return another object or nil.
	if ((object = objectFromScriptObject(context, (JSObjectRef)result))) {
		// Release the object to balance the alloc. The script object has an ownership reference.
		NSCAssert([object retainCount] > 1, @"retainCount should be greater than one here");
		[object release];
	}

	return JSValueToObject(context, result, scriptException); // Analyzer warning about a leak of 'object' can be safely ignored.
}

static bool scriptConstructorObjectHasInstance(JSContextRef context, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef *scriptException) {
    return JSValueIsObjectOfClass(context, possibleInstance, scriptClassForClass(classFromScriptConstructorObject(context, constructor)));
}

static bool scriptConstructorObjectHasProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName) {
	Class class = classFromScriptConstructorObject(context, scriptObject);
	if (!class)
		return false;

	// Return false for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return false;

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	Method method = class_getClassMethod(class, sel_registerName(propertyNameString));
	if (isGetterMethod(method) && !isBlockedSelector(method_getName(method)))
		return true;

	return NSCountHashTable(selectorsMatchingPrefix(object_getClass(class), propertyNameString, isBlockedSelector)) ? true : false;
}

static JSValueRef scriptConstructorObjectGetProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, JSValueRef *scriptException) {
	Class class = classFromScriptConstructorObject(context, scriptObject);
	if (!class)
		return NULL;

	// Return NULL for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return NULL;

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	Method method = class_getClassMethod(class, sel_registerName(propertyNameString));
	if (isGetterMethod(method) && !isBlockedSelector(method_getName(method))) {
		SEL getterSelector = method_getName(method);

		char returnType[16];
		method_getReturnType(method, returnType, sizeof(returnType));

		return callGetterFromScript(class, getterSelector, returnType, context, scriptException);
	}

	return scriptFunctionObjectForSelectors(context, selectorsMatchingPrefix(object_getClass(class), propertyNameString, isBlockedSelector));
}

static bool scriptConstructorObjectSetProperty(JSContextRef context, JSObjectRef scriptObject, JSStringRef propertyName, JSValueRef value, JSValueRef *scriptException) {
	Class class = classFromScriptConstructorObject(context, scriptObject);
	if (!class)
		return false;

	// Return false for 'method' so the static function is used.
	if (JSStringIsEqualToUTF8CString(propertyName, "method"))
		return false;

	size_t maximumPropertyNameStringLength = JSStringGetMaximumUTF8CStringSize(propertyName);
	char *propertyNameString = alloca(maximumPropertyNameStringLength);
	JSStringGetUTF8CString(propertyName, propertyNameString, maximumPropertyNameStringLength);

	Method method = class_getClassMethod(class, defaultSetterSelector(propertyNameString));
	if (!isSetterMethod(method) || isBlockedSelector(method_getName(method)))
		return false;

	char argumentType[16];
	method_getArgumentType(method, indexOfFirstNonHiddenMethodArgument, argumentType, sizeof(argumentType));

	callSetterFromScript(class, method_getName(method), argumentType, context, value, scriptException);

	return true;
}

#pragma mark -

static JSClassRef scriptClassForClass(Class class) {
	if (!class)
		return NULL;

	NSCAssert([class isSubclassOfClass:[NSObject class]], @"class needs to inherit from NSObject");

	NSMapTable *classes = scriptClasses();

	JSClassRef scriptClass = NSMapGet(classes, class);
	if (scriptClass)
		return scriptClass;

	JSStaticFunction staticFunctions[] = {
		{ "method", scriptObjectMethodFunction, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum | kJSPropertyAttributeDontDelete },
		{ NULL, NULL, 0 }
	};

	JSClassDefinition classDefinition = kJSClassDefinitionEmpty;
	classDefinition.className = scriptClassNameForClass(class);
	classDefinition.parentClass = scriptClassForClass(class_getSuperclass(class));
	classDefinition.staticFunctions = staticFunctions;
	classDefinition.finalize = scriptObjectFinalize;
    classDefinition.hasProperty = scriptObjectHasProperty;
    classDefinition.getProperty = scriptObjectGetProperty;
    classDefinition.setProperty = scriptObjectSetProperty;
    classDefinition.deleteProperty = scriptObjectDeleteProperty;
    classDefinition.getPropertyNames = scriptObjectGetPropertyNames;

	scriptClass = JSClassCreate(&classDefinition);

	if (class == [NSObject class])
		rootScriptClass = scriptClass;

	NSMapInsertKnownAbsent(classes, class, scriptClass);

	return scriptClass;
}

static JSClassRef scriptConstructorClassForClass(Class class) {
	if (!class)
		return NULL;

	NSCAssert([class isSubclassOfClass:[NSObject class]], @"class needs to inherit from NSObject");

	NSMapTable *classes = scriptConstructorClasses();

	JSClassRef scriptClass = NSMapGet(classes, class);
	if (scriptClass)
		return scriptClass;

	JSClassDefinition classDefinition = kJSClassDefinitionEmpty;
	classDefinition.className = scriptClassNameForClass(class);
	classDefinition.parentClass = scriptConstructorClassForClass(class_getSuperclass(class));
	classDefinition.finalize = scriptConstructorObjectFinalize;
    classDefinition.callAsConstructor = scriptConstructorObjectCallAsConstructor;
    classDefinition.hasInstance = scriptConstructorObjectHasInstance;
	classDefinition.hasProperty = scriptConstructorObjectHasProperty;
	classDefinition.getProperty = scriptConstructorObjectGetProperty;
	classDefinition.setProperty = scriptConstructorObjectSetProperty;

	scriptClass = JSClassCreate(&classDefinition);

	if (class == [NSObject class])
		rootConstructorScriptClass = scriptClass;

	NSMapInsertKnownAbsent(classes, class, scriptClass);

	return scriptClass;
}

#pragma mark -

static JSValueRef scriptErrorForException(JSContextRef context, NSException *exception) {
	JSStringRef scriptReasonString = JSStringCreateWithCFString((CFStringRef)[exception description]);
	JSValueRef scriptReason = JSValueMakeString(context, scriptReasonString);
	JSStringRelease(scriptReasonString);
	return JSObjectMakeError(context, 1, &scriptReason, NULL);
}

#pragma mark -

static JSObjectRef scriptObjectForObject(JSContextRef context, id object) {
	NSCParameterAssert(object);

	if ([object isKindOfClass:[CQJavaScriptObject class]])
		return [(CQJavaScriptObject *)object object];

	NSMapTable *objects = scriptObjects();

	JSObjectRef scriptObject = NSMapGet(objects, object);
	if (scriptObject)
		return scriptObject;

	JSClassRef scriptClass = scriptClassForClass([object class]);

	NSCAssert(scriptClass, @"scriptClass should not be NULL");
	if (!scriptClass)
		return NULL;

	scriptObject = JSObjectMake(context, scriptClass, object);

	NSCAssert(JSValueIsObjectOfClass(context, scriptObject, rootScriptClass), @"class needs to inherit from NSObject");

	NSMapInsertKnownAbsent(objects, object, scriptObject);

	return scriptObject;
}

static JSValueRef scriptValueForObject(JSContextRef context, id object) {
	if (!object || object == [NSNull null])
		return JSValueMakeNull(context);

	if ([object isKindOfClass:[NSNumber class]]) {
		const char *type = [object objCType];
		if (*type == 'B') // @encode(bool)
			return JSValueMakeBoolean(context, [object boolValue]);
		if (*type == 'c' && ([object boolValue] == YES || [object boolValue] == NO)) // @encode(BOOL)
			return JSValueMakeBoolean(context, [object boolValue]);
		return JSValueMakeNumber(context, [object doubleValue]);
	}

	if ([object isKindOfClass:[NSString class]]) {
		JSStringRef scriptString = JSStringCreateWithCFString((CFStringRef)object);
		JSValueRef scriptStringValue = JSValueMakeString(context, scriptString);
		JSStringRelease(scriptString);
		return scriptStringValue;
	}

	if ([object isKindOfClass:[NSDate class]]) {
		JSValueRef timeValue = JSValueMakeNumber(context, [object timeIntervalSince1970] * 1000.);
		return JSObjectMakeDate(context, 1, &timeValue, NULL);
	}

	if ([object isKindOfClass:[NSException class]])
		return scriptErrorForException(context, object);

	if ([object isKindOfClass:[NSArray class]]) {
		NSUInteger count = [object count];
		BOOL stackAllocated = count < 128;
		JSValueRef *arrayValues = stackAllocated ? alloca(count) : malloc(count);

		NSUInteger i = 0;
		for (id child in object)
			arrayValues[i++] = scriptValueForObject(context, object);

		JSObjectRef array = JSObjectMakeArray(context, count, arrayValues, NULL);

		if (!stackAllocated)
			free(arrayValues);

		return array;
	}

	if ([object isKindOfClass:[NSDictionary class]]) {
        JSObjectRef dictionary = JSObjectMake(context, NULL, NULL);

        for (id key in object) {
			JSStringRef scriptKey = JSStringCreateWithCFString((CFStringRef)([object isKindOfClass:[NSString class]] ? object : [object description]));
			JSValueRef scriptValue = scriptValueForObject(context, [object objectForKey:key]);
            JSObjectSetProperty(context, dictionary, scriptKey, scriptValue, kJSPropertyAttributeNone, 0);
			JSStringRelease(scriptKey);
        }

		return dictionary;
	}

	return scriptObjectForObject(context, object);
}

static JSValueRef scriptValueForValue(JSContextRef context, void *value, const char *type) {
	skipTypeModifiers(&type);

	switch (*type) {
	case 'v': // @encode(void)
		return JSValueMakeUndefined(context);

	case 'B': // @encode(bool)
		return JSValueMakeBoolean(context, *(bool *)value);

	case 'c': // @encode(char), @encode(BOOL)
		// Special case BOOL here, which is a typedef of signed char.
		if (*(BOOL *)value == YES || *(BOOL *)value == NO)
			return JSValueMakeBoolean(context, *(BOOL *)value);
		return JSValueMakeNumber(context, *(signed char *)value);
	case 'C': // @encode(unsigned char)
		return JSValueMakeNumber(context, *(unsigned char *)value);

	case 's': // @encode(short)
		return JSValueMakeNumber(context, *(signed short *)value);
	case 'S': // @encode(unsigned short)
		return JSValueMakeNumber(context, *(unsigned short *)value);

	case 'i': // @encode(int)
		return JSValueMakeNumber(context, *(signed int *)value);
	case 'I': // @encode(unsigned int)
		return JSValueMakeNumber(context, *(unsigned int *)value);

	case 'l': // @encode(long)
		return JSValueMakeNumber(context, *(signed long *)value);
	case 'L': // @encode(unsigned long)
		return JSValueMakeNumber(context, *(unsigned long *)value);

	case 'q': // @encode(long long)
		return JSValueMakeNumber(context, *(signed long long *)value);
	case 'Q': // @encode(unsigned long long)
		return JSValueMakeNumber(context, *(unsigned long long *)value);

	case 'f': // @encode(float)
		return JSValueMakeNumber(context, *(float *)value);

	case 'd': // @encode(double)
		return JSValueMakeNumber(context, *(double *)value);

	case 'D': // @encode(long double)
		return JSValueMakeNumber(context, *(long double *)value);

	case '*': // @encode(char *)
		return stringScriptValue(context, *(char **)value);

	case '@': // @encode(id), @encode(NSObject *), etc.
		return scriptValueForObject(context, *(id *)value);

	default: // Unsupported type.
		break;
	}

	return JSValueMakeUndefined(context);
}

static id objectForScriptValue(JSContextRef context, JSValueRef value, JSValueRef *scriptException) {
	if (!value)
		return nil;

	switch (JSValueGetType(context, value)) {
		case kJSTypeUndefined:
		case kJSTypeNull:
			return nil;

		case kJSTypeBoolean:
			return [NSNumber numberWithBool:JSValueToBoolean(context, value)];

		case kJSTypeNumber:
			return [NSNumber numberWithDouble:JSValueToNumber(context, value, scriptException)];

		case kJSTypeString: {
			JSStringRef scriptString = JSValueToStringCopy(context, value, scriptException);
			NSString *stringObject = NSMakeCollectable(JSStringCopyCFString(NULL, scriptString));
			JSStringRelease(scriptString);
			return [stringObject autorelease];
		}

		case kJSTypeObject: {
			JSObjectRef object = JSValueToObject(context, value, scriptException);

			// Convert dates to NSDate, arrays to NSArray and objects to NSDictionary here.

			id nativeObject = objectFromScriptObject(context, object);
			if (nativeObject)
				return nativeObject;

			return [[[CQJavaScriptObject alloc] initWithScriptObject:object andContext:context] autorelease];
		}
	}

	return nil;
}

#pragma mark -

static JSValueRef scriptFunctionPrototype(JSContextRef context) {
	JSObjectRef dummyFunction = JSObjectMakeFunction(context, NULL, 0, NULL, NULL, NULL, 0, NULL);
	return JSObjectGetPrototype(context, dummyFunction);
}

static JSObjectRef scriptFunctionObjectForSelectors(JSContextRef context, NSHashTable *selectors) {
	if (!selectors || !NSCountHashTable(selectors))
		return NULL;

	if (!scriptFunctionClass) {
		JSClassDefinition classDefinition = kJSClassDefinitionEmpty;
		classDefinition.attributes = kJSClassAttributeNoAutomaticPrototype;
		classDefinition.className = "ObjCMethod";
		classDefinition.finalize = scriptFunctionObjectFinalize;
		classDefinition.callAsFunction = scriptFunctionObjectCallAsFunction;

		scriptFunctionClass = JSClassCreate(&classDefinition);
	}

	CFRetain(selectors); // Use CFRetain to work in GC. Released in scriptFunctionObjectFinalize.

	JSObjectRef function = JSObjectMake(context, scriptFunctionClass, selectors);
	JSObjectSetPrototype(context, function, scriptFunctionPrototype(context));

	return function;
}

#pragma mark -

static JSObjectRef scriptConstructorObjectForClass(JSContextRef context, Class class) {
	NSCParameterAssert(class);

	NSMapTable *objects = scriptConstructorObjects();

	JSObjectRef scriptObject = NSMapGet(objects, class);
	if (scriptObject)
		return scriptObject;

	JSClassRef scriptClass = scriptConstructorClassForClass(class);

	NSCAssert(scriptClass, @"scriptClass should not be NULL");
	if (!scriptClass)
		return NULL;

	scriptObject = JSObjectMake(context, scriptClass, class);

	NSCAssert(JSValueIsObjectOfClass(context, scriptObject, rootConstructorScriptClass), @"class needs to inherit from NSObject");

	NSMapInsertKnownAbsent(objects, class, scriptObject);

	return scriptObject;
}

#pragma mark -

MVInline void addConstant(JSContextRef context, JSObjectRef object, const char *name, JSValueRef scriptValue) {
	NSCParameterAssert(scriptValue);

	JSStringRef constantName = JSStringCreateWithUTF8CString(name);
	JSObjectSetProperty(context, object, constantName, scriptValue, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
	JSStringRelease(constantName);
}

MVInline void addGlobalConstant(JSContextRef context, const char *name, JSValueRef scriptValue) {
	addConstant(context, JSContextGetGlobalObject(context), name, scriptValue);
}

#pragma mark -

static JSObjectRef propertyFunction(JSContextRef context, JSObjectRef object, const char *propertyName) {
	JSStringRef propertyNameString = JSStringCreateWithUTF8CString(propertyName);
	JSValueRef propertyValue = JSObjectGetProperty(context, object, propertyNameString, NULL);
	JSStringRelease(propertyNameString);

	if (!propertyValue)
		return NULL;

	if (!JSValueIsObject(context, propertyValue))
		return NULL;

	JSObjectRef propertyObject = (JSObjectRef)propertyValue;

	if (!JSObjectIsFunction(context, propertyObject))
		return NULL;

	return propertyObject;
}

MVInline JSValueRef callPropertyFunction(JSContextRef context, JSObjectRef object, const char *propertyName, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	JSObjectRef function = propertyFunction(context, object, propertyName);
	if (!function)
		return NULL;
	return JSObjectCallAsFunction(context, function, object, argumentCount, arguments, exception);
}

#pragma mark -

@implementation CQJavaScriptObject
- (id) initWithScriptObject:(JSObjectRef) object andContext:(JSContextRef) context {
	if (!object || !context) {
		[self release];
		return nil;
	}

	_context = JSGlobalContextRetain(JSContextGetGlobalContext(context));

	if (!_context) {
		[self release];
		return nil;
	}

	_object = object;

	JSValueProtect(_context, _object);

	return self;
}

- (void) dealloc {
	if (_object && _context)
		JSValueUnprotect(_context, _object);

	[super dealloc];
}

- (void) finalize {
	if (_object && _context)
		JSValueUnprotect(_context, _object);

    [super finalize];
}

@synthesize context = _context;
@synthesize object = _object;

static JSValueRef scriptValueForSelector(JSContextRef context, JSObjectRef object, SEL selector) {
	NSString *selectorString = NSStringFromSelector(selector);
	NSRange firstArgumentRange = [selectorString rangeOfString:@":"];
	NSString *selectorFirstPart = firstArgumentRange.location == NSNotFound ? selectorString : [selectorString substringToIndex:firstArgumentRange.location];

	JSStringRef propertyNameString = JSStringCreateWithCFString((CFStringRef)selectorFirstPart);
	if (JSObjectHasProperty(context, object, propertyNameString)) {
		JSValueRef propertyValue = JSObjectGetProperty(context, object, propertyNameString, NULL);
		JSStringRelease(propertyNameString);

		if (propertyValue)
			return propertyValue;
	} else {
		JSStringRelease(propertyNameString);
	}

	JSValueRef selectorValue = stringScriptValue(context, sel_getName(selector));
	JSValueRef methodResult = callPropertyFunction(context, object, "method", 1, &selectorValue, NULL);
	if (methodResult && !JSValueIsUndefined(context, methodResult) && !JSValueIsNull(context, methodResult))
		return methodResult;

	return NULL;
}

static bool isSetterSelector(SEL selector, char **propertyName) {
	NSCParameterAssert(selector);

	if (propertyName)
		*propertyName = NULL;

	const char *selectorString = sel_getName(selector);
	if (!selectorString || strlen(selectorString) <= 3)
		return false;

	if (selectorString[0] != 's' || selectorString[1] != 'e' || selectorString[2] != 't' || !isupper(selectorString[3]))
		return false;

	if (instancesOfCharacterInString(':', selectorString) != 1)
		return false;

	if (!propertyName)
		return true;

	*propertyName = strdup(selectorString + 3);
	(*propertyName)[0] = tolower((*propertyName)[0]);

	// Replace the trailing ':' with a null character.
	(*propertyName)[strlen(*propertyName) - 1] = 0;

	return true;
}

- (BOOL) respondsToSelector:(SEL) selector {
	return scriptValueForSelector(_context, _object, selector) || isSetterSelector(selector, NULL);
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	JSValueRef result = scriptValueForSelector(_context, _object, invocation.selector);
	if (!result) {
		char *propertyName = NULL;
		if (!isSetterSelector(invocation.selector, &propertyName)) {
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%@: unrecognized selector sent to instance %p", NSStringFromSelector(invocation.selector), self] userInfo:nil];
			return;
		}

		NSAssert(propertyName, @"propertyName should not be NULL");

		const char *type = [invocation.methodSignature getArgumentTypeAtIndex:indexOfFirstNonHiddenMethodArgument];

		void *argument = NULL;
		[invocation getArgument:&argument atIndex:indexOfFirstNonHiddenMethodArgument];

		JSValueRef value = scriptValueForValue(_context, &argument, type);

		JSStringRef propertyNameString = JSStringCreateWithUTF8CString(propertyName);
		JSObjectSetProperty(_context, _object, propertyNameString, value, kJSPropertyAttributeNone, NULL);
		JSStringRelease(propertyNameString);

		free(propertyName);
		return;
	}

	if (result && JSValueIsObject(_context, result) && JSObjectIsFunction(_context, (JSObjectRef)result)) {
		JSObjectRef function = (JSObjectRef)result;

		NSAssert(invocation.methodSignature.numberOfArguments >= numberOfHiddenMethodArguments, @"numberOfArguments shouldn't be less than numberOfHiddenMethodArguments");

		NSUInteger numberOfArguments = invocation.methodSignature.numberOfArguments - numberOfHiddenMethodArguments;
		JSValueRef *scriptFunctionArguments = numberOfArguments ? alloca(numberOfArguments) : NULL;

		for (NSUInteger i = 0; i < numberOfArguments; ++i) {
			const char *type = [invocation.methodSignature getArgumentTypeAtIndex:i + indexOfFirstNonHiddenMethodArgument];

			void *argument = NULL;
			[invocation getArgument:&argument atIndex:i + indexOfFirstNonHiddenMethodArgument];

			scriptFunctionArguments[i] = scriptValueForValue(_context, &argument, type);
		}

		result = JSObjectCallAsFunction(_context, function, _object, numberOfArguments, scriptFunctionArguments, NULL);
	}

	if (!result)
		return;

	// Tell the invocation to retain the arguments, so the setReturnValue: call retains or copies as needed.
	[invocation retainArguments];

	convertScriptValue(_context, result, invocation.methodSignature.methodReturnType, NULL, ^(void *value) { [invocation setReturnValue:value]; });
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
	// Try calling the "methodSignature" function on the script object to get the signature.
	JSValueRef selectorValue = stringScriptValue(_context, sel_getName(selector));
	JSValueRef methodSignatureResult = callPropertyFunction(_context, _object, "methodSignature", 1, &selectorValue, NULL);
	if (methodSignatureResult && JSValueIsString(_context, methodSignatureResult)) {
		JSStringRef methodSignatureResultString = JSValueToStringCopy(_context, methodSignatureResult, NULL);

		size_t maximumStringLength = JSStringGetMaximumUTF8CStringSize(methodSignatureResultString);
		char *signatureString = alloca(maximumStringLength);
		JSStringGetUTF8CString(methodSignatureResultString, signatureString, maximumStringLength);

		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:signatureString];

		NSAssert(signature, @"signature should not be nil");
		NSAssert([signature numberOfArguments] == (instancesOfCharacterInString(':', sel_getName(selector)) + numberOfHiddenMethodArguments), @"numberOfArguments should match number of arguments in the selector");

		JSStringRelease(methodSignatureResultString);

		return signature;
	}

	// The script object does not implement "methodSignature" or didn't return a string.
	// Since we have no insight about the argument types, just make everything be an "id".
	// This can be bad in many cases, so the script object should implement "methodSignature".
	NSMutableString *types = [[NSMutableString alloc] initWithString:@"@@:"]; // @encode(id), @encode(id), @encode(SEL)

	size_t argumentCount = instancesOfCharacterInString(':', sel_getName(selector));
	for (size_t i = 0; i < argumentCount; ++i)
		[types appendString:@"@"]; // @encode(id)

	NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:[types UTF8String]];

	NSAssert(signature, @"signature should not be nil");
	NSAssert([signature numberOfArguments] == (argumentCount + numberOfHiddenMethodArguments), @"numberOfArguments should match argumentCount");

	[types release];

	return signature;
}

- (BOOL) isKindOfClass:(Class) class {
    return [[self class] isSubclassOfClass:class];
}

- (BOOL) isMemberOfClass:(Class) class {
    return [self class] == class;
}

- (BOOL) conformsToProtocol:(Protocol *) protocol {
	return [[self class] conformsToProtocol:protocol];
}
@end

#pragma mark -

@implementation CQJavaScriptBridge
+ (JSValueRef) scriptValueForObject:(id) object usingContext:(JSContextRef) context {
	return scriptValueForObject(context, object);
}

+ (id) objectForScriptValue:(JSValueRef) value usingContext:(JSContextRef) context {
	return objectForScriptValue(context, value, NULL);
}

+ (void) addConstructorsInContext:(JSGlobalContextRef) context forClasses:(Class) firstClass, ... {
	NSParameterAssert(context);

	JSObjectRef globalObject = JSContextGetGlobalObject(context);

	va_list classes;
	va_start(classes, firstClass);

	Class currentClass = firstClass;
	if (currentClass) do {
		addConstant(context, globalObject, class_getName(currentClass), scriptConstructorObjectForClass(context, currentClass));
	} while ((currentClass = va_arg(classes, Class)));

	va_end(classes);
}

+ (void) addGlobalConstantInContext:(JSGlobalContextRef) context withName:(const char *) name andStringValue:(NSString *) value {
	NSParameterAssert(context);
	NSParameterAssert(name);
	NSParameterAssert(strlen(name));
	NSParameterAssert(value);

	addGlobalConstant(context, name, scriptValueForValue(context, &value, @encode(NSString *)));
}

+ (void) addGlobalConstantInContext:(JSGlobalContextRef) context withName:(const char *) name andNumberValue:(NSInteger) value {
	NSParameterAssert(context);
	NSParameterAssert(name);
	NSParameterAssert(strlen(name));

	addGlobalConstant(context, name, scriptValueForValue(context, &value, @encode(NSInteger)));
}
@end
