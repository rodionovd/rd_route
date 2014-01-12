> **Do not use this code**. It can destroy everthing.
> But if you do, I wish you a luck.

`rd_route` is a tiny library which allows you to change a C functions' implementation (keeping the original ones if you'd like to) in **OS X**'s Mach-O executables.

The source code is based on Landon Fuller's (@landonf) [`libevil`](https://github.com/landonf/libevil_patch) library.

> NOTE: `rd_route` **won't work for iOS**.  You should take a look at  `libevil` instead.


#### Usage


    #include "rd_route.h"

    static char my_strerror(int err)
    {
      return "It's OK";
    }

    . . .

    void *(*original)(int) = NULL;
    int err = 2;
    rd_route(strerror, my_strerror, (void **)&original);

    printf("Error(%d): %s", err, strerror(err));
    // >> "It's OK"
    printf("Error(%d): %s", err, original(err));
    // >> No such file or directory

------


#### Under the hood

`int rd_route(void *function, void *replacement, void **original);`

  1. It remaps an entire macho image, containing the `function` to  override, into a new place in the memory.
  2. The `function`'s implementation is patched with a JMP instruction to the `replacement`.
  3. The `original` pointer (if passed) is set to the remapped location of the `function`.

------

*Dmitry Rodionov, 2014*
*i.am.rodionovd@gmail.com*
