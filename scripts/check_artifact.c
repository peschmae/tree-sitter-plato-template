#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "tree_sitter/parser.h"

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: check-artifact <shared-library>\n");
        return EXIT_FAILURE;
    }

    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "cannot load parser artifact: %s\n", dlerror());
        return EXIT_FAILURE;
    }

    const TSLanguage *(*language)(void) = dlsym(library, "tree_sitter_plato");
    if (!language || language()->abi_version != 15 || language()->symbol_count == 0) {
        fprintf(stderr, "parser artifact has no plato symbol or has an incompatible ABI\n");
        dlclose(library);
        return EXIT_FAILURE;
    }

    if (dlclose(library) != 0) {
        fprintf(stderr, "cannot close parser artifact: %s\n", dlerror());
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
