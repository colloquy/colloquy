#import "NSObjectAdditions.h"

@interface NSScriptObjectSpecifier (NSScriptObjectSpecifierPrivate) // Private Foundation Methods
- (NSAppleEventDescriptor *) _asDescriptor;
@end

#pragma mark -

@interface NSAEDescriptorTranslator : NSObject // Private Foundation Class
+ (id) sharedAEDescriptorTranslator;
- (NSAppleEventDescriptor *) descriptorByTranslatingObject:(id) object ofType:(id) type inSuite:(id) suite;
@end

#pragma mark -

// this is needed to coerce custom classes correctly, they act as a safety net
// if these methods get called on a Foundation/AppKit class we call the built-in NSAppleEventDescriptor converters

@implementation NSObject (NSObjectScriptingAdditions)
- (NSAppleEventDescriptor *) scriptingAnyDescriptor {
	if( [self isMemberOfClass:[NSAppleEventDescriptor class]] ) return (NSAppleEventDescriptor *) self;

	NSLog( @"*** %@ %s", self, _cmd );
	// if this object is custom then we want to return the object specifier
	NSScriptObjectSpecifier *objectSpecifier = [self objectSpecifier];
	if( objectSpecifier ) return [objectSpecifier _asDescriptor];

	// don't coerce Foundation/AppKit types to a string, return the correct NSAppleEventDescriptor for them
	// AppleScript will do the correct coercion later if a string was truley requested
	id descriptor = [[NSAEDescriptorTranslator sharedAEDescriptorTranslator] descriptorByTranslatingObject:self ofType:nil inSuite:nil];
	if( descriptor ) return descriptor;

	// coerce this into a text representation from the description since it wasn't a coercible Foundation/AppKit type
	return [NSAppleEventDescriptor descriptorWithString:[self description]];
}

- (NSAppleEventDescriptor *) scriptingTextDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

/*- (NSAppleEventDescriptor *) scriptingBooleanDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingDateDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingFileDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingIntegerDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingLocationDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingNumberDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingPointDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingRealDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingRecordDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingRectangleDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingSpecifierDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}

- (NSAppleEventDescriptor *) scriptingTypeDescriptor {
	NSLog( @"*** %@ %s", self, _cmd );
	return [self scriptingAnyDescriptor];
}*/
@end