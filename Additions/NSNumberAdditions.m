#import "NSNumberAdditions.h"

@implementation NSNumber (NSNumberAdditions)
+ (NSNumber *) numberWithBytes:(const void *) bytes objCType:(const char *) type {
	if( ! strcmp( type, @encode( char ) ) ) {
		char *val = (char *) bytes;
		return [NSNumber numberWithChar:*val];
	} else if( ! strcmp( type, @encode( unsigned char ) ) ) {
		unsigned char *val = (unsigned char *) bytes;
		return [NSNumber numberWithUnsignedChar:*val];
	} else if( ! strcmp( type, @encode( BOOL ) ) ) {
		BOOL *val = (BOOL *) bytes;
		return [NSNumber numberWithBool:*val];
	} else if( ! strcmp( type, @encode( short ) ) ) {
		short *val = (short *) bytes;
		return [NSNumber numberWithShort:*val];
	} else if( ! strcmp( type, @encode( unsigned short ) ) ) {
		unsigned short *val = (unsigned short *) bytes;
		return [NSNumber numberWithUnsignedShort:*val];
	} else if( ! strcmp( type, @encode( int ) ) ) {
		int *val = (int *) bytes;
		return [NSNumber numberWithInt:*val];
	} else if( ! strcmp( type, @encode( unsigned int ) ) ) {
		unsigned int *val = (unsigned int *) bytes;
		return [NSNumber numberWithUnsignedInt:*val];
	} else if( ! strcmp( type, @encode( long ) ) ) {
		long *val = (long *) bytes;
		return [NSNumber numberWithLong:*val];
	} else if( ! strcmp( type, @encode( unsigned long ) ) ) {
		unsigned long *val = (unsigned long *) bytes;
		return [NSNumber numberWithUnsignedLong:*val];
	} else if( ! strcmp( type, @encode( long long ) ) ) {
		long long *val = (long long *) bytes;
		return [NSNumber numberWithLongLong:*val];
	} else if( ! strcmp( type, @encode( unsigned long long ) ) ) {
		unsigned long long *val = (unsigned long long *) bytes;
		return [NSNumber numberWithUnsignedLongLong:*val];
	} else if( ! strcmp( type, @encode( float ) ) ) {
		float *val = (float *) bytes;
		return [NSNumber numberWithFloat:*val];
	} else if( ! strcmp( type, @encode( double ) ) ) {
		double *val = (double *) bytes;
		return [NSNumber numberWithDouble:*val];
	} else return nil;
}
@end
