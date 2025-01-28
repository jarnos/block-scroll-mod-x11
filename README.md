# block-scroll-mod-x11

*Block a pointer device when a modifier key is pressed after scrolling has started in X11*

This software aims to eliminate the possible side effects of inertial scrolling that can occur when you press a modifier key after scrolling has started. This is supposed to work in operating systems that use [X Window System](https://en.wikipedia.org/wiki/X_Window_System).

## block-scroll-mod-x11-awk.sh
This variant uses POSIX shell (`sh`), AWK (`awk`) and `xinput` utility and some common Unix/Linux utilities to do the job. If you run it without arguments in terminal, usage will be shown.

NOTE: Requires xinput 1.6.4 or newer


