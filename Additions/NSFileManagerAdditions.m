#import "NSFileManagerAdditions.h"

#include <mach-o/arch.h>
#include <mach-o/loader.h> 
#include <mach-o/fat.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSFileManager (Additions)
static inline void markArchitectureAsActiveForCPUType(MVArchitectures *architectures, cpu_type_t cpuType, cpu_subtype_t cpuSubtype) {
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
	case CPU_TYPE_ARM:
		switch (cpuSubtype) {
		case CPU_SUBTYPE_ARM_V6:
			(*architectures).armv6 = YES;
			break;
		case CPU_SUBTYPE_ARM_V7:
		case CPU_SUBTYPE_ARM_V7F:
		case CPU_SUBTYPE_ARM_V7K:
			(*architectures).armv7 = YES;
			break;
		default:
			(*architectures).unknown++;
			break;
		}
		break;
	default:
		(*architectures).unknown++;
		break;
}
}

static inline void swapIntsInHeader(uint8_t *bytes, ssize_t length) {
	for (ssize_t i = 0; i < length; i += 4)
		*(uint32_t *)(bytes + i) = OSSwapInt32(*(uint32_t *)(bytes + i));
}

#pragma mark -

- (MVArchitectures) architecturesForBinaryAtPath:(NSString *) path {
	MVArchitectures architectures = { NO, NO, NO, NO, NO, NO, 0 };

	NSFileHandle *executableFile = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData *data = [executableFile readDataOfLength:512];
	[executableFile closeFile];

	if (!data || data.length < 8) {
		architectures.unknown = 1;

		return architectures;
	}

	if (data.length >= sizeof(struct mach_header_64)) {
		uint8_t *bytes = (void *)[data bytes];
		uint32_t magic = *(uint32_t *)bytes;

		if (magic == MH_MAGIC || magic == MH_CIGAM) { // 32-bit, thin
			struct mach_header *header = (struct mach_header *)bytes;

			markArchitectureAsActiveForCPUType(&architectures, header->cputype, header->cpusubtype);
		} else if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) { // 64-bit, thin
			struct mach_header_64 *header = (struct mach_header_64 *)bytes;

			markArchitectureAsActiveForCPUType(&architectures, header->cputype, header->cpusubtype);
		} else if (magic == FAT_MAGIC || magic == FAT_CIGAM) { // fat
			if (magic == FAT_CIGAM)
				swapIntsInHeader(bytes, data.length);

			uint32_t numberOfArchitectures = ((struct fat_header *)bytes)->nfat_arch;
			struct fat_arch *fatArchrchitectures = (struct fat_arch *)(bytes + sizeof(struct fat_header));

			for (uint32_t i = 0; i < numberOfArchitectures; i++) {
				struct fat_arch fatArchitecture = fatArchrchitectures[i];

				markArchitectureAsActiveForCPUType(&architectures, fatArchitecture.cputype, fatArchitecture.cpusubtype);
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
#elif __ARM_ARCH_6__
	return validArchitectures.armv6;
#elif __ARM_ARCH_7__
	return validArchitectures.armv7;
#else
	return validArchitectures.unknown;
#endif
}
@end

NSString *NSStringFromMVArchitectures(MVArchitectures architectures) {
	return [[NSString alloc] initWithFormat:@"(\n\tPPC 32-Bit: %d\n\tPPC 64-Bit: %d\n\tIntel x86: %d\n\tIntel x86_64: %d\n\tArmv6: %d\n\tArmv7: %d\n\tUnknown Architectures: %ld\n)", architectures.ppc32, architectures.ppc64, architectures.x86, architectures.x86_64, architectures.armv6, architectures.armv7, architectures.unknown];
}

NS_ASSUME_NONNULL_END
