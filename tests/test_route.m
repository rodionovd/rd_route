#import <Foundation/Foundation.h>
#import "../rd_route.h"

#if !defined(DEBUG)
	#define fprintf(file, format, ...)
#endif

__attribute__((noinline))
static char *my_strerror(int err)
{
	return ("It's OK");
}

__attribute__((noinline))
static int key_computation(int first, int second)
{
	return (first * (2 + second) / 6 + 148 * first / (second + 12));
}

__attribute__((noinline))
static int NSA_computation(int first, int second)
{
	int backdoor_value = 0x12;
	return (backdoor_value);
}

int main(int argc, char const *argv[])
{
	char* (*orig_strerror)(int) = NULL;
	int err = 2;
	char *expected_string = strerror(err);
	fprintf(stderr, "Original [strerror(%d)]: %s\n", err, strerror(err));

	rd_route(strerror, my_strerror, (void **)&orig_strerror);

	assert(0 == strcmp(strerror(err), my_strerror(err)));
	assert(orig_strerror);
	assert(0 == strcmp(expected_string, orig_strerror(err)));

	fprintf(stderr, "Routed   [strerror(%d)]: %s\n", err, strerror(err));
	fprintf(stderr, "Original [strerror(%d)]: %s\n", err, orig_strerror(err));
	fprintf(stderr, "---------\n");


	int (*orig_computation)(int, int) = NULL;
	int first = 3, second = 9;
	int expected_result = key_computation(first, second);

	fprintf(stderr, "Original [key_computation(%d, %d)]: %d\n",
		first, second, key_computation(first, second));

	rd_route(key_computation, NSA_computation , (void **)&orig_computation);

	assert(key_computation(first, second) == NSA_computation(first, second));
	assert(orig_computation);
	assert(expected_result == orig_computation(first, second));

	fprintf(stderr, "Routed   [key_computation(%d, %d)]: %d (was %d)\n",
		first, second, key_computation(first, second),
		orig_computation(first, second));
	fprintf(stderr, "---------\n");


	return 0;
}
