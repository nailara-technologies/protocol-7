/* setuid (ug+s) wrapper for 'shutdown' shell account */

#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>

int main(void) {
    setuid(0);
    system("/bin/sync");
    system("/bin/sync");
    system("/sbin/poweroff -p -f");
}
