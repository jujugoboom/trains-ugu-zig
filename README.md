# trains-ugu-zig

A zig rewrite of [trains-ugu](https://git.justincovell.com/jujugoboom/trains-ugu). Currently, with the best stress test I have (setting the whole world to a single texture) it loses about 50% performance compared to C at fullscreen zoomed as far out as possible with debug target, but is roughly comparable to `-O3` when using `ReleaseFast` target.