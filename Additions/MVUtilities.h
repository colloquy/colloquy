#import <Foundation/NSObjCRuntime.h>

NS_INLINE void MVSafeAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = newValue;
	[old release];
}

NS_INLINE void MVSafeRetainAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = [newValue retain];
	[old release];
}

NS_INLINE void MVSafeCopyAssign( id *var, id newValue ) {
	if( *var == newValue )
		return;
	id old = *var;
	*var = [newValue copyWithZone:nil];
	[old release];
}

NS_INLINE id MVSafeReturn( id var ) {
	return [[var retain] autorelease];
}
