#import <Cocoa/Cocoa.h>
#import "NSColorAdditions.h"

@implementation NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) attribute {
	NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"1234567890abcdefABCDEF"];
	NSScanner *scanner = [NSScanner scannerWithString:( [attribute hasPrefix:@"#"] ? [attribute substringFromIndex:1] : attribute )];
	NSString *code = nil;

	if( ! [scanner scanCharactersFromSet:hex intoString:&code] ) return nil;

	if( [code length] == 6 ) { // decode colors like #ffee33
		unsigned int color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( color >> 16 ) & 0xff ) / 255. ) green:( ( ( color >> 8 ) & 0xff ) / 255. ) blue:( ( color & 0xff ) / 255. ) alpha:1.];
	} else if( [code length] == 3 ) {  // decode short-hand colors like #fe3
		unsigned int color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( ( ( color >> 8 ) & 0xf ) << 4 ) | ( ( color >> 8 ) & 0xf ) ) / 255. ) green:( ( ( ( ( color >> 4 ) & 0xf ) << 4 ) | ( ( color >> 4 ) & 0xf ) ) / 255. ) blue:( ( ( ( color & 0xf ) << 4 ) | ( color & 0xf ) ) / 255. ) alpha:1.];
	}

	return nil;
}

+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute {
	NSColor *ret = [self colorWithHTMLAttributeValue:attribute];

	if( ! ret && [attribute hasPrefix:@"rgb"] ) {
		NSCharacterSet *whites = [NSCharacterSet whitespaceCharacterSet];
		BOOL hasAlpha = [attribute hasPrefix:@"rgba"];
		NSScanner *scanner = [NSScanner scannerWithString:attribute];
		[scanner scanCharactersFromSet:whites intoString:nil];
		if( [scanner scanUpToString:@"(" intoString:nil] ) {
			double red = 0., green = 0., blue = 0., alpha = 1.;
			BOOL redPrecent = NO, greenPrecent = NO, bluePrecent = NO;
			[scanner scanString:@"(" intoString:nil];
			[scanner scanCharactersFromSet:whites intoString:nil];
			if( [scanner scanDouble:&red] ) {
				redPrecent = [scanner scanString:@"%" intoString:nil];
				[scanner scanCharactersFromSet:whites intoString:nil];
				[scanner scanString:@"," intoString:nil];
				[scanner scanCharactersFromSet:whites intoString:nil];
				if( [scanner scanDouble:&green] ) {
					greenPrecent = [scanner scanString:@"%" intoString:nil];
					[scanner scanCharactersFromSet:whites intoString:nil];
					[scanner scanString:@"," intoString:nil];
					[scanner scanCharactersFromSet:whites intoString:nil];
					if( [scanner scanDouble:&blue] ) {
						bluePrecent = [scanner scanString:@"%" intoString:nil];
						[scanner scanCharactersFromSet:whites intoString:nil];
						red = MAX( 0., MIN( ( redPrecent ? 100. : 255. ), red ) );
						green = MAX( 0., MIN( ( greenPrecent ? 100. : 255. ), green ) );
						blue = MAX( 0., MIN( ( bluePrecent ? 100. : 255. ), blue ) );
						if( hasAlpha ) {
							[scanner scanString:@"," intoString:nil];
							[scanner scanCharactersFromSet:whites intoString:nil];
							if( [scanner scanDouble:&alpha] ) {
								[scanner scanCharactersFromSet:whites intoString:nil];
								[scanner scanString:@")" intoString:nil];
								alpha = MAX( 0., MIN( 1., alpha ) );
								ret = [self colorWithCalibratedRed:( redPrecent ? red / 100. : red / 255. ) green:( greenPrecent ? green / 100. : green / 255. ) blue:( bluePrecent ? blue / 100. : blue / 255. ) alpha:alpha];
							}
						} else {
							ret = [self colorWithCalibratedRed:( redPrecent ? red / 100. : red / 255. ) green:( greenPrecent ? green / 100. : green / 255. ) blue:( bluePrecent ? blue / 100. : blue / 255. ) alpha:1.];
						}
					}
				}
			}
		}
	} else if( ! ret && [attribute hasPrefix:@"hsl"] ) {
		NSCharacterSet *whites = [NSCharacterSet whitespaceCharacterSet];
		BOOL hasAlpha = [attribute hasPrefix:@"hsla"];
		NSScanner *scanner = [NSScanner scannerWithString:attribute];
		[scanner scanCharactersFromSet:whites intoString:nil];
		if( [scanner scanUpToString:@"(" intoString:nil] ) {
			double hue = 0., saturation = 0., lightness = 0., alpha = 1.;
			[scanner scanString:@"(" intoString:nil];
			[scanner scanCharactersFromSet:whites intoString:nil];
			if( [scanner scanDouble:&hue] ) {
				[scanner scanCharactersFromSet:whites intoString:nil];
				[scanner scanString:@"," intoString:nil];
				[scanner scanCharactersFromSet:whites intoString:nil];
				if( [scanner scanDouble:&saturation] && [scanner scanString:@"%" intoString:nil] ) {
					[scanner scanCharactersFromSet:whites intoString:nil];
					[scanner scanString:@"," intoString:nil];
					[scanner scanCharactersFromSet:whites intoString:nil];
					if( [scanner scanDouble:&lightness] && [scanner scanString:@"%" intoString:nil] ) {
						[scanner scanCharactersFromSet:whites intoString:nil];
						hue = ( ( ( (long) hue % 360 ) + 360 ) % 360 );
						saturation = MAX( 0., MIN( 100., saturation ) );
						lightness = MAX( 0., MIN( 100., lightness ) );
						if( hasAlpha ) {
							[scanner scanString:@"," intoString:nil];
							[scanner scanCharactersFromSet:whites intoString:nil];
							if( [scanner scanDouble:&alpha] ) {
								[scanner scanCharactersFromSet:whites intoString:nil];
								[scanner scanString:@")" intoString:nil];
								alpha = MAX( 0., MIN( 1., alpha ) );
								ret = [self colorWithCalibratedHue:( hue / 360. ) saturation:( saturation / 100. ) brightness:( lightness / 100. ) alpha:alpha];
							}
						} else {
							ret = [self colorWithCalibratedHue:( hue / 360. ) saturation:( saturation / 100. ) brightness:( lightness / 100. ) alpha:1.];
						}
					}
				}
			}
		}
	} else if( ! ret && [attribute hasPrefix:@"transparent"] ) {
		ret = [self clearColor];
	}

	return ret;
}

- (NSString *) HTMLAttributeValue {
	float red = 0., green = 0., blue = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:NULL];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}

- (NSString *) CSSAttributeValue {
	float red = 0., green = 0., blue = 0., alpha = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
	if( alpha < 1. ) return [NSString stringWithFormat:@"rgba(%d,%d,%d,%f)", (int)(red * 255), (int)(green * 255), (int)(blue * 255), alpha];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}
@end
