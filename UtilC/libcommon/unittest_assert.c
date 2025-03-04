#include "dos.h"
#include "assert.h"


void _ASSERT_TRUE(bool succeedCondition, const char *failMsg, char *file, char *func, int line)
{
	if (!succeedCondition) {
		cprintf("### Assert failed at: %s :: %s :: line %d\n\r    by \"%s\"\n\r\x07", file, func, line, failMsg);
		exit(1);
	}
}

void _ASSERT_EQUAL(uint32_t value, uint32_t expected, const char *failMsg, char *file, char *func, int line)
{
	if (value != expected) {
		cprintf("### Assert failed at: %s :: %s :: line %d\n\r    by \"%s\"\n\r    received:%l expected:%l\n\r\x07", file, func, line, failMsg, value, expected);
		exit(1);
	}
}

void _FAIL(const char *failMsg, char *file, char *func, int line)
{
	cprintf("Fail by '%s'\n\r  at %s :: %s :: line %d\n\r\x07", failMsg, file, func, line);
	exit(1);
}

void _SUCCEED(char *file, char *func)
{
	cprintf("%s :: %s ... OK\n\r", file, func);
}

void _TODO(const char *infoMsg, char *file, char *func)
{
	cprintf("### TODO: %s :: %s [%s]\n\r", file, func, infoMsg);
}
