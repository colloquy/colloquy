@interface NSScriptCommand (NSScriptCommandAdditions)
- (id) subjectParameter;
- (NSScriptObjectSpecifier *) subjectSpecifier;
- (void) setSubjectSpecifier:(NSScriptObjectSpecifier *) subject;
- (BOOL) subjectSupportsCommand;
- (id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end
