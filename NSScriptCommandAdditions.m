#import "NSScriptCommandAdditions.h"

@interface NSScriptObjectSpecifier (NSScriptObjectSpecifierPrivate) // Private Foundation Methods
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
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

- (BOOL) subjectSupportsCommand {
	NSScriptObjectSpecifier *subjectSpecifier = [self subjectSpecifier];
	NSScriptClassDescription *classDesc = [subjectSpecifier keyClassDescription];
	NSScriptCommandDescription *cmdDesc = [self commandDescription];
	BOOL supports = [classDesc supportsCommand:cmdDesc];
	SEL selector = [classDesc selectorForCommand:cmdDesc];
	if( ! [NSStringFromSelector( selector ) length] ) return NO;
	return supports;
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
			id subj = nil, result = nil;
			NSEnumerator *enumerator = [subject objectEnumerator];
			NSMutableArray *results = [NSMutableArray arrayWithCapacity:[subject count]];

			while( ( subj = [enumerator nextObject] ) ) {
				result = [subj performSelector:selector withObject:self];
				if( result ) [results addObject:result];
				else [results addObject:[NSNull null]];
			}

			return results;
		}

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
