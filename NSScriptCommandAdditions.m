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

- (id) evaluatedDirectParameter {
	id param = [self directParameter];
	if( [param isKindOfClass:[NSScriptObjectSpecifier class]] )
		param = [(NSScriptObjectSpecifier *) param objectsByEvaluatingSpecifier];
	return param;
}
@end
