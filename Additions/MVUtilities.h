#import <pthread.h>

#define MVInline static __inline__ __attribute__((always_inline))

#define MVDefaultController \
{ \
	static dispatch_once_t onceToken; \
	static id sharedInstance = nil; \
	dispatch_once(&onceToken, ^{ \
		sharedInstance = [[self alloc] init]; \
	}); \
	return sharedInstance; \
}

#if !defined(__has_feature) || !__has_feature(objc_arc)
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
		(var) = [new copy]; \
		if (old) \
			[old release]; \
	} \
}

#define MVSafeReturn(var) \
	[[var retain] autorelease];

#define MVAutoreleasedReturn(var) \
	return [var autorelease];

#define MVAutorelease(var) \
	[var autorelease];
#else
#define MVSafeAdoptAssign(var, newExpression) \
{ \
	id new = (newExpression); \
	(var) = new; \
}

#define MVSafeRetainAssign(var, newExpression) \
{ \
	id old = (var); \
	id new = (newExpression); \
	if (old != new) \
		(var) = new; \
}

#define MVSafeCopyAssign(var, newExpression) \
{ \
	id old = (var); \
	id new = (newExpression); \
	if (old != new) \
		(var) = [new copy]; \
}

#define MVSafeReturn(var) \
	(var)

#define MVAutoreleasedReturn(var) \
	return var

#define MVAutorelease(var) \
	(var)
#endif

#define MVAssertMainThreadRequired() \
	NSAssert1( pthread_main_np(), @"Method needs to run on the main thread, not %@.", [NSThread currentThread] )

#define MVAssertCorrectThreadRequired(thread) \
	NSAssert2( [NSThread currentThread] == (thread), @"Method needs to run on %@, not %@.", (thread), [NSThread currentThread] )

#define MVWeakFramework(framework) \
static void* framework##Library(void) \
{ \
	static void *frameworkHandle; \
	if (UNLIKELY(!frameworkHandle)) \
		frameworkHandle = dlopen("/System/Library/Frameworks/" #framework ".framework/" #framework, RTLD_LAZY); \
	if (LIKELY(frameworkHandle)) \
		return frameworkHandle; \
	NSCAssert(NO, @"Couldn't dlopen the " #framework " framework."); \
	return NULL; \
}

#define MVWeakLibrary(library) \
static void* library##Library(void) \
{ \
	static void *libraryHandle; \
	if (UNLIKELY(!libraryHandle)) \
		libraryHandle = dlopen("/usr/lib/lib" #library ".A.dylib", RTLD_LAZY); \
	if (LIKELY(libraryHandle)) \
		return libraryHandle; \
	NSCAssert(NO, @"Couldn't dlopen the " #library " library."); \
	return NULL; \
}

#define MVWeakFunction(library, functionName, resultType, parameterDeclarations, parameterNames, defaultValue) \
static resultType initial_##functionName parameterDeclarations; \
\
resultType (*functionName) parameterDeclarations = initial_##functionName; \
\
static resultType noop_##functionName parameterDeclarations { \
	return defaultValue; \
} \
\
static resultType initial_##functionName parameterDeclarations { \
	resultType (*functionPointer) parameterDeclarations = dlsym(library##Library(), #functionName); \
\
	if (LIKELY(functionPointer)) { \
		functionName = functionPointer; \
	} else { \
		NSCAssert(NO, @"Couldn't find " #functionName " in " #library " library with dlsym."); \
		functionName = noop_##functionName; \
	} \
\
	return functionName parameterNames; \
}

#define MVWeakVoidFunction(library, functionName, parameterDeclarations, parameterNames, defaultValue) \
static void initial_##functionName parameterDeclarations; \
\
void (*functionName) parameterDeclarations = initial_##functionName; \
\
static void noop_##functionName parameterDeclarations { \
	return; \
} \
\
static void initial_##functionName parameterDeclarations { \
	void (*functionPointer) parameterDeclarations = dlsym(library##Library(), #functionName); \
\
	if (LIKELY(functionPointer)) { \
		functionName = functionPointer; \
	} else { \
		NSCAssert(NO, @"Couldn't find " #functionName " in " #library " library with dlsym."); \
		functionName = noop_##functionName; \
	} \
\
	functionName parameterNames; \
}

#define MVAddUnsafeUnretainedAddress(var, index) \
	do { \
		__unsafe_unretained id unsafeVar##var = (var); \
		[invocation setArgument:&unsafeVar##var atIndex:index]; \
	} while (0);

