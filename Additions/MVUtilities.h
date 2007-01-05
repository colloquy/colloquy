#import <pthread.h>

#define MVInline static __inline__ __attribute__((always_inline))

MVInline void MVSafeAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = newValue;
	[old release];
}

MVInline void MVSafeRetainAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = [newValue retain];
	[old release];
}

MVInline void MVSafeCopyAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = [newValue copyWithZone:nil];
	[old release];
}

MVInline id MVSafeReturn( id var ) {
	return [[var retain] autorelease];
}

#define MVAssertMainThreadRequired() \
	NSAssert1( pthread_main_np(), @"Method needs to run on the main thread, not %@.", [NSThread currentThread] )

#define MVAssertCorrectThreadRequired(thread) \
	NSAssert2( [NSThread currentThread] == (thread), @"Method needs to run on %@, not %@.", (thread), [NSThread currentThread] )
