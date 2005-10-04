#include <Carbon/Carbon.r>

resource 'scsz' (0, "Scripting Size", purgeable) {
	dontLaunchToGetTerminology,
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