#include <stdio.h>

/* C preview example. */
static void greet(const char *name) {
  printf("hello, %s\n", name);
}

int main(void) {
  greet("peek");
  return 0;
}
