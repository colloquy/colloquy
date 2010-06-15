#import <pthread.h>

#define MVInline static __inline__ __attribute__((always_inline))

#define MVSafeAdoptAssign(var, newExpression) \
{ \
	id old = (var); \
	id new = (newExpression); \
	(var) = new; \
	if (old && old != new) \
		[old release]; \
}

#define MVSafeRetainAssign(var, newExpression) \
{ \
	id old = (var); \
	id new = (newExpression); \
	if (old != new) { \
		(var) = [new retain]; \
		if (old) \
			[old release]; \
	} \
}

#define MVSafeCopyAssign(var, newExpression) \
{ \
	id old = (var); \
	id new = (newExpression); \
	if (old != new) { \
		(var) = [new copyWithZone:nil]; \
		if (old) \
			[old release]; \
	} \
}

#define MVSafeReturn(var) \
	[[var retain] autorelease];

#define MVAssertMainThreadRequired() \
	NSAssert1( pthread_main_np(), @"Method needs to run on the main thread, not %@.", [NSThread currentThread] )

#define MVAssertCorrectThreadRequired(thread) \
	NSAssert2( [NSThread currentThread] == (thread), @"Method needs to run on %@, not %@.", (thread), [NSThread currentThread] )

#define MVWeakFramework(framework) \
static void* framework##Framework(void) \
{ \
	static void *frameworkHandle; \
	if (UNLIKELY(!frameworkHandle)) \
		frameworkHandle = dlopen("/System/Library/Frameworks/" #framework ".framework/" #framework, RTLD_LAZY); \
	if (LIKELY(!!frameworkHandle)) \
		return frameworkHandle; \
	NSCAssert(NO, @"Couldn't dlopen the " #framework " framework."); \
	return NULL; \
}

#define MVWeakLibrary(library) \
static void* library##Framework(void) \
{ \
	static void *libraryHandle; \
	if (UNLIKELY(!libraryHandle)) \
		libraryHandle = dlopen("/usr/lib/lib" #library ".A.dylib", RTLD_LAZY); \
	if (LIKELY(!!libraryHandle)) \
		return libraryHandle; \
	NSCAssert(NO, @"Couldn't dlopen the " #library " library."); \
	return NULL; \
}

#define MVWeakFunction(framework, functionName, resultType, parameterDeclarations, parameterNames, defaultValue) \
resultType functionName parameterDeclarations; \
\
resultType functionName parameterDeclarations \
{ \
	static resultType (*functionPointer) parameterDeclarations; \
	if (UNLIKELY(!functionPointer)) \
		functionPointer = dlsym(framework##Framework(), #functionName); \
	if (LIKELY(!!functionPointer)) \
		return functionPointer parameterNames; \
	NSCAssert(NO, @"Couldn't find " #functionName " in " #framework " framework with dlsym."); \
	return defaultValue; \
}

#define MVWeakVoidFunction(framework, functionName, parameterDeclarations, parameterNames, defaultValue) \
void functionName parameterDeclarations; \
\
void functionName parameterDeclarations \
{ \
	static void (*functionPointer) parameterDeclarations; \
	if (UNLIKELY(!functionPointer)) \
		functionPointer = dlsym(framework##Framework(), #functionName); \
	if (LIKELY(!!functionPointer)) { \
		functionPointer parameterNames; \
		return; \
	} \
	NSCAssert(NO, @"Couldn't find " #functionName " in " #framework " framework with dlsym."); \
}
