#import "JVFontPreviewField.h"

@implementation JVFontPreviewField
- (instancetype) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		_showPointSize = [coder decodeBoolForKey:@"showPointSize"];
		_showFontFace = [coder decodeBoolForKey:@"showFontFace"];
		_actualFont = [coder decodeObjectForKey:@"actualFont"];
	} else {
		[coder decodeValueOfObjCType:@encode( char ) at:&_showPointSize];
		[coder decodeValueOfObjCType:@encode( char ) at:&_showFontFace];
		_actualFont = [coder decodeObject];
	}
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder {
	[super encodeWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		[coder encodeBool:_showPointSize forKey:@"showPointSize"];
		[coder encodeBool:_showFontFace forKey:@"showFontFace"];
		[coder encodeObject:_actualFont forKey:@"actualFont"];
	} else {
		[coder encodeValueOfObjCType:@encode( char ) at:&_showPointSize];
		[coder encodeValueOfObjCType:@encode( char ) at:&_showFontFace];
		[coder encodeObject:_actualFont];
	}
}

- (id <JVFontPreviewFieldDelegate>)delegate {
	return (id <JVFontPreviewFieldDelegate>)[super delegate];
}

- (void)setDelegate:(id <JVFontPreviewFieldDelegate>)anObject {
	[super setDelegate:anObject];
}

- (void) selectFont:(id) sender {
	NSFont *font = [sender convertFont:[self font]];

	if( ! font ) return;

	if( [[self delegate] respondsToSelector:@selector( fontPreviewField:shouldChangeToFont: )] )
		if( ! [[self delegate] fontPreviewField:self shouldChangeToFont:font] ) return;

	[self setFont:font];

	if( [[self delegate] respondsToSelector:@selector( fontPreviewField:didChangeToFont: )] )
		[[self delegate] fontPreviewField:self didChangeToFont:font];
}

- (NSUInteger) validModesForFontPanel:(NSFontPanel *) fontPanel {
	NSUInteger ret = NSFontPanelStandardModesMask;
	if( ! _showPointSize ) ret ^= NSFontPanelSizeModeMask;
	if( ! _showFontFace ) ret ^= NSFontPanelFaceModeMask;
	return ret;
}

- (BOOL) becomeFirstResponder {
	[[NSFontManager sharedFontManager] setSelectedFont:_actualFont isMultiple:NO];
	return YES;
}

- (void) setFont:(NSFont *) font {
	if( ! font ) return;

	_actualFont = font;

	[super setFont:[[NSFontManager sharedFontManager] convertFont:font toSize:11.]];

	NSMutableAttributedString *text = nil;
	if( _showPointSize ) {
		text = [[NSMutableAttributedString alloc] initWithString:[[NSString alloc] initWithFormat:@"%@ %.0f", ( _showFontFace ? [_actualFont displayName] : [_actualFont familyName] ), [_actualFont pointSize]]];
	} else {
		text = [[NSMutableAttributedString alloc] initWithString:( _showFontFace ? [_actualFont displayName] : [_actualFont familyName] )];
	}

	NSMutableParagraphStyle *paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	[paraStyle setMinimumLineHeight:NSHeight( [self bounds] )];
	[paraStyle setMaximumLineHeight:NSHeight( [self bounds] )];
	[text addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange( 0, [text length] )];

	[self setObjectValue:text];
}

- (IBAction) chooseFontWithFontPanel:(id) sender {
	[[NSFontManager sharedFontManager] setAction:@selector( selectFont: )];
	[[self window] makeFirstResponder:self];
	[[NSFontManager sharedFontManager] orderFrontFontPanel:nil];
}

@end
