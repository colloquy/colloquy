#import <Cocoa/Cocoa.h>
#import "JVFontPreviewField.h"

@implementation JVFontPreviewField
- (void) selectFont:(id) sender {
	NSFont *font = [sender convertFont:[self font]];

	if( [[self delegate] respondsToSelector:@selector( fontPreviewField:shouldChangeToFont: )] )
		if( ! [[self delegate] fontPreviewField:self shouldChangeToFont:font] ) return;

	[self setFont:font];

	if( [[self delegate] respondsToSelector:@selector( fontPreviewField:didChangeToFont: )] )
		[[self delegate] fontPreviewField:self didChangeToFont:font];
}

- (BOOL) becomeFirstResponder {
	[[NSFontManager sharedFontManager] setSelectedFont:_actualFont isMultiple:NO];
	return YES;
}

- (void) setFont:(NSFont *) font {
	[_actualFont autorelease];
	_actualFont = [font retain];

	[super setFont:[NSFont fontWithName:[font fontName] size:11.]];

	NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %.0f", [_actualFont familyName], [_actualFont pointSize]]] autorelease];
	NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];

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
