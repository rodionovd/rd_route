#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
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

__attribute__((noinline))
static int helloworld(const char *world)
{
	if (strlen(world ?: "") == 0) return 0;
	return (42);
}

__attribute__((noinline))
static int whateverworld(const char *world)
{
	if (strlen(world ?: "") == 0) return 0;
	return (12);
}

__attribute__((noinline))
static CFTypeRef RDBundleGetPlugIn(CFBundleRef bundle)
{
	return CFSTR("Nope");
}

__attribute__((noinline))
static int byeworld(const char *world)
{
	if (strlen(world ?: "") == 0) return 0;
	return (666);
}

static void test_rd_route(void);
static void test_rd_route_byname(void);
static void test_rd_duplicate_function(void);

int main(int argc, char const *argv[])
{
	test_rd_route();
	test_rd_route_byname();
	test_rd_duplicate_function();
	return 0;
}

static void test_rd_route(void)
{
	fprintf(stderr, "RUN test [%s]\n", __FUNCTION__);

	void *(*escape_island)(void) = NULL;
	assert(KERN_SUCCESS != rd_route(NULL, NULL, NULL));
	assert(KERN_SUCCESS != rd_route(NULL, NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route(NULL, my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route(NULL, my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route(my_strerror, NULL, NULL));
	assert(KERN_SUCCESS != rd_route(my_strerror, NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route(my_strerror, my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route(my_strerror, my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	char* (*orig_strerror)(int) = NULL;
	int err = 2;
	char *expected_string = strerror(err);
	rd_route(strerror, my_strerror, (void **)&orig_strerror);

	assert(0 == strcmp(strerror(err), my_strerror(err)));
	assert(orig_strerror);
	assert(0 == strcmp(expected_string, orig_strerror(err)));

	int (*orig_computation)(int, int) = NULL;
	int first = 3, second = 9;
	int expected_result = key_computation(first, second);
	rd_route(key_computation, NSA_computation , (void **)&orig_computation);

	assert(key_computation(first, second) == NSA_computation(first, second));
	assert(orig_computation);
	assert(expected_result == orig_computation(first, second));
}


static void test_rd_route_byname(void)
{
	fprintf(stderr, "RUN test [%s]\n", __FUNCTION__);

	void *(*escape_island)(void) = NULL;

	assert(KERN_SUCCESS != rd_route_byname(NULL, NULL, NULL, NULL));
	assert(KERN_SUCCESS != rd_route_byname(NULL, NULL, NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname(NULL, NULL, my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route_byname(NULL, NULL, my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname(NULL, _dyld_get_image_name(0), NULL, NULL));
	assert(KERN_SUCCESS != rd_route_byname(NULL, _dyld_get_image_name(0), NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname(NULL, _dyld_get_image_name(0), my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route_byname(NULL, _dyld_get_image_name(0), my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname("my_strerror", NULL, NULL, NULL));
	assert(KERN_SUCCESS != rd_route_byname("my_strerror", NULL, NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname("my_strerror", NULL, my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route_byname("my_strerror", NULL, my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname("my_strerror", _dyld_get_image_name(0), my_strerror, NULL));
	assert(KERN_SUCCESS != rd_route_byname("my_strerror", _dyld_get_image_name(0), my_strerror, (void **)&escape_island));
	assert(NULL == escape_island);

	assert(KERN_SUCCESS != rd_route_byname("my_strerror", _dyld_get_image_name(0), NULL, NULL));
	assert(KERN_SUCCESS != rd_route_byname("my_strerror", _dyld_get_image_name(0), NULL, (void **)&escape_island));
	assert(NULL == escape_island);

	int (*orig_helloworld)(const char *) = NULL;
	int err = KERN_SUCCESS;
	// this symbol belongs to the first (index=0) loaded image, so this test should fail
	err = rd_route_byname("helloworld", _dyld_get_image_name(1), byeworld, (void **)(&orig_helloworld));
	assert(KERN_SUCCESS != err);
	assert(NULL == orig_helloworld);
	assert(helloworld("World") != byeworld("World"));

	err = KERN_FAILURE;
	err = rd_route_byname("helloworld", _dyld_get_image_name(0), byeworld, (void **)(&orig_helloworld));
	assert(KERN_SUCCESS == err);
	assert(orig_helloworld);
	assert(orig_helloworld("World") == 42);
	assert(helloworld("World") == byeworld("World"));

	int (*orig_whateverworld)(const char *) = NULL;
	err = KERN_FAILURE;
	err = rd_route_byname("whateverworld", NULL, byeworld, (void **)(&orig_whateverworld));
	assert(KERN_SUCCESS == err);
	assert(orig_whateverworld);
	assert(orig_whateverworld("World") == 12);
	assert(whateverworld("World") == byeworld("World"));

	CFTypeRef (*orig_CFBundleGetPlugIn)(CFBundleRef) = NULL;
	err = KERN_FAILURE;
	err = rd_route_byname("CFBundleGetPlugIn", "CoreFoundation", RDBundleGetPlugIn, (void **)&orig_CFBundleGetPlugIn);
	assert(KERN_SUCCESS == err);
	assert(orig_CFBundleGetPlugIn);
	assert(kCFCompareEqualTo == CFStringCompare(CFSTR("Nope"), (CFStringRef)CFBundleGetPlugIn(NULL), 0));

	err = KERN_FAILURE;
	err = rd_route_byname("CFBundleGetPlugIn", "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
		orig_CFBundleGetPlugIn, NULL);
	assert(KERN_SUCCESS == err);

}

static void test_rd_duplicate_function(void)
{
	fprintf(stderr, "RUN test [%s]\n", __FUNCTION__);
}
