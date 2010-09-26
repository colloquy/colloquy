#import "NSScriptCommandAdditions.h"

@interface NSScriptObjectSpecifier (NSScriptObjectSpecifierPrivate) // Private Foundation Methods
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
- (NSAppleEventDescriptor *) _asDescriptor;
@end

#pragma mark -

@implementation NSScriptCommand (NSScriptCommandAdditions)
- (id) subjectParameter {
	return [[self subjectSpecifier] objectsByEvaluatingSpecifier];
}

- (NSScriptObjectSpecifier *) subjectSpecifier {
	NSAppleEventDescriptor *subjDesc = [[self appleEvent] attributeDescriptorForKeyword:'subj'];
	return [NSScriptObjectSpecifier _objectSpecifierFromDescriptor:subjDesc inCommandConstructionContext:nil];
}

- (void) setSubjectSpecifier:(NSScriptObjectSpecifier *) subject {
	NSAppleEventDescriptor *subjDesc = [subject _asDescriptor];
	[[self appleEvent] setAttributeDescriptor:subjDesc forKeyword:'subj'];
}

- (BOOL) subjectSupportsCommand {
	NSScriptObjectSpecifier *subjectSpecifier = [self subjectSpecifier];
	NSScriptClassDescription *classDesc = [subjectSpecifier keyClassDescription];
	NSScriptCommandDescription *cmdDesc = [self commandDescription];

	if( ! [classDesc supportsCommand:cmdDesc] ) return NO;

	SEL selector = [classDesc selectorForCommand:cmdDesc];
	if( ! [NSStringFromSelector( selector ) length] ) return NO;

	id subject = [subjectSpecifier objectsByEvaluatingSpecifier];
	if( ! subject ) return NO;

	if( ! [subject isKindOfClass:[NSArray class]] )
		return [subject respondsToSelector:selector];

	return YES;
}

- (id) executeCommandOnSubject {
	NSScriptObjectSpecifier *subjectSpecifier = [self subjectSpecifier];
	NSScriptClassDescription *classDesc = [subjectSpecifier keyClassDescription];
	NSScriptCommandDescription *cmdDesc = [self commandDescription];
	if( [classDesc supportsCommand:cmdDesc] ) {
		SEL selector = [classDesc selectorForCommand:cmdDesc];
		if( ! [NSStringFromSelector( selector ) length] ) return nil;

		id subject = [subjectSpecifier objectsByEvaluatingSpecifier];
		if( ! subject ) return nil;

		// a list of recievers
		if( [subject isKindOfClass:[NSArray class]] ) {
			NSMutableArray *results = [[NSMutableArray allocWithZone:nil] initWithCapacity:[subject count]];
			for( id subj in subject ) {
				id result = nil;
				if( [subj respondsToSelector:selector] )
					result = [subj performSelector:selector withObject:self];
				if( result ) [results addObject:result];
				else [results addObject:[NSNull null]];
			}

			return [results autorelease];
		}

		if( ! [subject respondsToSelector:selector] ) return nil;

		// a single reciever
		return [subject performSelector:selector withObject:self];
	}

	return nil;
}

- (id) evaluatedDirectParameter {
	id param = [self directParameter];
	if( [param isKindOfClass:[NSScriptObjectSpecifier class]] )
		param = [(NSScriptObjectSpecifier *) param objectsByEvaluatingSpecifier];
	return param;
}
@end
