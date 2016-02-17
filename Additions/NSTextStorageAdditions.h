// provided for scripting support
@interface NSTextStorage (NSTextStorageAdditions)
@property (copy) NSColor *backgroundColor;

@property (copy) NSString *hyperlink;

@property  BOOL boldState;

@property  BOOL italicState;

@property  BOOL underlineState;

@property (copy) NSArray *styleClasses;

@property (copy) NSString *styleText;

@property (copy) NSString *XHTMLStart;

@property (copy) NSString *XHTMLEnd;

- (NSTextStorage *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;
@end
