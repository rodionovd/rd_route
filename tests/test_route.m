#import <Foundation/Foundation.h>

extern int rd_route(void *function, void *replacement, void **original);

#if !defined(DEBUG)
	#define fprintf(file, format, ...)
#endif


static void* (*orig_strerror)(int) = NULL;
static int   (*orig_computation)(int, int) = NULL;

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

	orig_strerror = NULL;
	int err = 2;
	fprintf(stderr, "Original [strerror(%d)]: %s\n", err, strerror(err));

	rd_route(strerror, my_strerror, NULL);

	assert(0 == strcmp(strerror(err), my_strerror(err)));

	fprintf(stderr, "Routed   [strerror(%d)]: %s\n", err, strerror(err));
	fprintf(stderr, "---------\n");


	orig_computation = NULL;
	int first = 3, second = 9;
	int wanted_result = key_computation(first, second);

	fprintf(stderr, "Original [key_computation(%d, %d)]: %d\n",
		first, second, key_computation(first, second));

	rd_route(key_computation, NSA_computation , (void **)&orig_computation);

	assert(key_computation(first, second) == NSA_computation(first, second));
	assert(orig_computation);
	assert(wanted_result == orig_computation(first, second));

	fprintf(stderr, "Routed   [key_computation(%d, %d)]: %d (but must be == %d)\n",
		first, second, key_computation(first, second),
		orig_computation(first, second));
	fprintf(stderr, "---------\n");


	return 0;
}
