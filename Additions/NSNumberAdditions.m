#import "NSNumberAdditions.h"

@implementation NSNumber (NSNumberAdditions)
+ (NSNumber *) numberWithBytes:(const void *) bytes objCType:(const char *) type {
	if( ! strcmp( type, @encode( char ) ) ) {
		char *val = (char *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( unsigned char ) ) ) {
		unsigned char *val = (unsigned char *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( BOOL ) ) ) {
		BOOL *val = (BOOL *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( short ) ) ) {
		short *val = (short *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( unsigned short ) ) ) {
		unsigned short *val = (unsigned short *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( int ) ) ) {
		int *val = (int *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( unsigned ) ) ) {
		unsigned *val = (unsigned *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( long ) ) ) {
		long *val = (long *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( unsigned long ) ) ) {
		unsigned long *val = (unsigned long *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( long long ) ) ) {
		long long *val = (long long *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( unsigned long long ) ) ) {
		unsigned long long *val = (unsigned long long *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( float ) ) ) {
		float *val = (float *) bytes;
		return @(*val);
	} else if( ! strcmp( type, @encode( double ) ) ) {
		double *val = (double *) bytes;
		return @(*val);
	} else return nil;
}
@end
