#include <Carbon/Carbon.r>

resource 'scsz' (0, "Scripting Size", purgeable) {
	launchToGetTerminology,
	findAppBySignature,
	alwaysSendSubject,
	reserved, reserved, reserved, reserved,
	reserved, reserved, reserved, reserved,
	reserved, reserved, reserved, reserved,
	reserved,
	minStackSize,
	preferredStackSize,
	maxStackSize,
	minHeapSize,
	preferredHeapSize,
	maxHeapSize
};