@interface NSScriptCommand (NSScriptCommandAdditions)
- (id) subjectParameter;
- (NSScriptObjectSpecifier *) subjectSpecifier;
- (BOOL) subjectSupportsCommand;
- (id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end
