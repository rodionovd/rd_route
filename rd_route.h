// Copyright © 2014 Dmitry Rodionov i.am.rodionovd@gmail.com
// This work is free. You can redistribute it and/or modify it
// under the terms of the Do What The Fuck You Want To Public License, Version 2,
// as published by Sam Hocevar. See the COPYING file for more details.


#ifndef RD_ROUTE
    #define RD_ROUTE
    int rd_route(void *function, void *replacement, void **original);
    int rd_duplicate_function(void *function, void **duplicate);
#endif


