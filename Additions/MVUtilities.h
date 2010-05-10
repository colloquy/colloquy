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
