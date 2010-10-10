#import "NSFileManagerAdditions.h"

#include <mach-o/arch.h>
#include <mach-o/loader.h> 
#include <mach-o/fat.h>

@implementation NSFileManager (Additions)
static inline void markArchitectureAsActiveForCPUType(MVArchitectures *architectures, cpu_type_t cpuType) {
	switch (cpuType) {
	case CPU_TYPE_POWERPC:
		(*architectures).ppc32 = YES;
		break;
	case CPU_TYPE_POWERPC64:
		(*architectures).ppc64 = YES;
		break;
	case CPU_TYPE_X86:
		(*architectures).x86 = YES;
		break;
	case CPU_TYPE_X86_64:
		(*architectures).x86_64 = YES;
		break;
	default:
		(*architectures).unknown++;
		break;
}
}

static inline void swapIntsInHeader(uint8_t *bytes, unsigned length) {
	for (unsigned i = 0; i < length; i += 4)
		*(uint32_t *)(bytes + i) = OSSwapInt32(*(uint32_t *)(bytes + i));
}

#pragma mark -

- (MVArchitectures) architecturesForBinaryAtPath:(NSString *) path {
	MVArchitectures architectures = { NO, NO, NO, NO, 0 };

	NSFileHandle *executableFile = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData *data = [executableFile readDataOfLength:512];
	[executableFile closeFile];

	if (!data || data.length < 8) {
		architectures.unknown = 1;

		return architectures;
	}

	void *bytes = (void *)[data bytes];
	uint32_t magic = *(uint32_t *)bytes;

	if (data.length >= sizeof(struct mach_header_64)) {
		if (magic == MH_MAGIC || magic == MH_CIGAM) { // 32-bit, thin
			struct mach_header *header = (struct mach_header *)bytes;

			markArchitectureAsActiveForCPUType(&architectures, header->cputype);
		} else if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) { // 64-bit, thin
			struct mach_header_64 *header = (struct mach_header_64 *)bytes;

			markArchitectureAsActiveForCPUType(&architectures, header->cputype);
		} else if (magic == FAT_MAGIC || magic == FAT_CIGAM) { // fat
			if (magic == FAT_CIGAM)
				swapIntsInHeader(bytes, data.length);

			NSUInteger numberOfArchitectures = ((struct fat_header *)bytes)->nfat_arch;
			struct fat_arch *fatArchrchitectures = (struct fat_arch *)(bytes + sizeof(struct fat_header));

			for (NSUInteger i = 0; i < numberOfArchitectures; i++) {
				struct fat_arch fatArchitecture = fatArchrchitectures[i];

				markArchitectureAsActiveForCPUType(&architectures, fatArchitecture.cputype);
			}
		} else architectures.unknown++;
	}

	return architectures;
}

#pragma mark -

- (BOOL) canExecutePluginAtPath:(NSString *) pluginPath {
	MVArchitectures validArchitectures = [[NSFileManager defaultManager] architecturesForBinaryAtPath:pluginPath];

#if __ppc__
	return validArchitectures.ppc32;
#elif __ppc64__
	return validArchitectures.ppc64;
#elif __i386__
	return validArchitectures.x86;
#elif __x86_64__
	return validArchitectures.x86_64;
#else
	return validArchitectures.unknown;
#endif
}
@end

NSString *NSStringFromMVArchitectures(MVArchitectures architectures) {
	return [NSString stringWithFormat:@"(\n\tPPC 32-Bit: %d\n\tPPC 64-Bit: %d\n\tIntel x86: %d\n\tIntel x86_64: %d\n\tUnknown Architectures: %d\n)", architectures.ppc32, architectures.ppc64, architectures.x86, architectures.x86_64, architectures.unknown];
}