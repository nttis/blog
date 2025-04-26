+++
title = "Rust, Nix, Zig and cross-compilation"
date = 2025-03-26

[extra]
summary = "An epic saga involving Rust, Nix, Zig and futile attempts to cross-compile."
+++

Let's say I have some Rust code:

```rust
fn main() {
  println!("Hello, world!");
}
```

And I want to cross-compile this code using [Nix](https://nixos.org). No
Docker, no Podman, no [cross](https://github.com/cross-rs/cross). Just raw,
vanilla cross-compilation. How hard could it possibly be?

The rules are:

- The program must be able to run on all the major operating systems. (Linux,
Windows, MacOS, Android through Termux).
- It must be statically linked[^1].
- It must run on the 2 major architectures for each operating
system. (ie. x86_64 and aarch64)

Let's take a look at [Rust's platform support
table](https://doc.rust-lang.org/rustc/platform-support.html). The Tier 1
targets are:

- aarch64-apple-darwin
- aarch64-unknown-linux-gnu
- x86_64-apple-darwin
- x86_64-pc-windows-msvc
- x86_64-unknown-linux-gnu

The Tier 2 targets are:

- aarch64-pc-windows-msvc
- aarch64-linux-android (without host tools)
- x86_64-linux-android (without host tools)

At first glance, this level of support is quite great! All the targets we
care about are either Tier 1 or Tier 2. In theory, this should work seamlessly
with just a `cargo build`.

But let's look a bit closer. One of our rules is `It must be statically
linked`. Except for where we absolutely must (MacOS and Android), we avoid
linking against any system dependencies, including the libc.

And thus we have to exclude all the `-gnu` targets since `glibc`
does not support static linking. Instead, we look at [musl
libc](https://musl.libc.org). These are in Tier 2:

- x86_64-unknown-linux-musl
- aarch64-unknown-linux-musl

All hope is not yet lost. But let's look closer (again), at Windows this time.

You may have noticed that the Windows targets are using the MSVC ABI. This
requires the MSVC headers and toolchain. Visual Studio installations ship
with this toolchain, but we are cross-compiling from Linux, so...

While the MSVC toolchain is standalone and not glued to Visual Studio,
it's *non-free*. You are forbidden from redistributing it. It's *probably*
fine to have a script that downloads the required dependencies straight from
Microsoft, and if you are intending to publish this project, contributors can
use the same script to download dependencies themselves. Technically
you aren't redistributing anything, just a *way* to download the MSVC
toolchain. Projects like [msvc-wine](https://github.com/mstorsjo/msvc-wine)
and [cargo-xwin](https://github.com/rust-cross/cargo-xwin) exist.

However, IANAL, and I would rather not mess with anything legal. If I can
help it, I want to avoid the MSVC ABI. In this case, our other choices are:

- x86_64-pc-windows-gnu (Tier 1!)
- aarch64-pc-windows-gnullvm (Tier 2, without host tools)

Right, let's get started.

## Nix setup

I am using [rust-overlay](https://github.com/oxalica/rust-overlay)
and [naersk](https://github.com/nix-community/naersk) to manage the Rust
toolchain and to facilitate cross-compilation, respectively.

First, we need a Rust toolchain. This can easily be done with `rustup`. In
Nix, we use `rust-overlay` instead.

```nix,linenos
# This is a flake. Most of it was snipped for brevity.
inputs: {
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux"; # We are building on x86_64 Linux
    overlays = [inputs.rust-overlay.overlays.default];
  };

  toolchain = pkgs.rust-bin.stable.latest.minimal.override {
    targets = [
      # Our Linux targets
      "x86_64-unknown-linux-musl"
      "aarch64-unknown-linux-musl"

      # Our Windows targets
      "x86_64-pc-windows-gnu"
      "aarch64-pc-windows-gnullvm"

      # Our MacOS targets
      "x86_64-apple-darwin"
      "aarch64-apple-darwin"

      # Our Android targets
      "x86_64-linux-android"
      "aarch64-linux-android"
    ];
  };

  naersk = pkgs.callPackage inputs.naersk {
    cargo = toolchain;
    rustc = toolchain;
  };
}
```

We now have a latest stable Rust toolchain with all the targets we want to
build for.

## Humble beginnings: cross-compiling to Linux targets

This is, unsurprisingly, the easiest part.

### x86_64-linux

```nix,linenos
naersk.buildPackage {
  src = ./.;
  strictDeps = true;

  nativeBuildInputs = with pkgs; [
    llvmPackages.bintools
  ];

  env = {
    CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUSTFLAGS = "-C target-feature=+crt-static -C linker-flavor=ld.lld";
  };
}
```

Here we are using the LLVM `lld` linker instead of GNU `ld`. We are also
telling Rust to link the C runtime statically with the `+crt-static` flag. Of
course Rust doesn't always respect this as you will see in a later section.

{% note() %}

Using `lld` is not necessary in our scenario, since we are compiling natively
(from `x86_64-linux` to `x86_64-linux`). However if you are compiling from a
different platform (say, `aarch64-linux`), then `lld` is necessary, since GNU
`ld` isn't cross-platform.

{% end %}

This is enough to compile for `x86_64-linux`. A `nix build` will produce a
binary, statically linked for you.

### aarch64-linux

This is, surprisingly, the same as above, bar a few small changes.

```nix,linenos
naersk.buildPackage {
  src = ./.;
  strictDeps = true;

  nativeBuildInputs = with pkgs; [
    llvmPackages.bintools
  ];

  env = {
    CARGO_BUILD_TARGET = "aarch64-unknown-linux-musl";
    CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS = "-C target-feature=+crt-static -C linker-flavor=ld.lld";
  };
}
```

This is where `lld` shines. Rust by default uses GNU `ld` for Linux targets,
but since we are cross-compiling and producing binaries for a different
CPU architecture, `ld` will complain about invalid binary format. `lld`
however Just Works:tm:.

## Cross-compiling to Windows

This is where the real headache starts.

### x86_64-windows

The most popular method to get this to work is:

```nix,linenos
naersk.buildPackage {
  src = ./.;
  strictDeps = true;

  nativeBuildInputs = with pkgs; [
    pkgsCross.mingwW64.stdenv.cc
  ];

  buildInputs = with pkgs; [
    pkgsCross.mingwW64.windows.pthreads
  ];

  env = {
    CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
  };
}
```

For this target, Rust defaults to using `x86_64-w64-mingw32-gcc` as the linker
driver.  Putting the `cc` in `nativeBuildInputs` automatically provides it.

However, the above code doesn't actually work. I don't actually know why. When
I last tried the exact same thing a few weeks ago it all went fine, but
now it just vomits errors about `pthreads` and undefined symbols. I am,
unfortunately, not savvy enough about this problem to fix it.

After some serious head-banging, I came up with an idea: what if we use
[Zig](https://ziglang.org) as the linker instead?

### A short detour on Zig

Zig is a programming language which (as of the time of writing) depends on
LLVM for its codegen.

The kicker about Zig however, is the
fact that the Zig binary [bundles clang with
it](https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html).
This allows it to compile C/C++ code as well as Zig code.

However, the ***real*** kicker about Zig is the fact that it *bundles libc
implementations with it too!*

Normally, the libcs (glibc, musl libc, MinGW, etc.) are shipped to
your machine as *pre-compiled binaries*. These binaries are then linked
(dynamically or statically) into your executables.  This is a huge problem
for cross-compiling (like what we are doing right now). Pre-compiled
binaries were... pre-compiled... for one specific target only. We *cannot*
link these pre-compiled binaries into an executable that was compiled for
a different target!

Zig, instead, had a very funny idea: it bundles the *source code* of multiple
libcs with it, and then ***compiles them on the fly***. This is the reason
why Zig has immensely great support for cross-compilation, as well as
supporting a myriad number of targets.

Using Zig, it is possible to compile the MinGW libc for both `x86_64` and
`aarch64`, which will enable us to cross-compile Rust for Windows!

### Back to cross-compiling

At first, I came up with this derivation:

```nix,linenos
naersk.buildPackage {
  src = ./.;
  strictDeps = true;

  nativeBuildInputs = with pkgs; [
    zig
  ];

  env = {
    CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${pkgs.writers.writeBash "zcc" ''
      zig cc -target x86_64-windows-gnu "$@" # Note how Zig takes a different 'target' than Rust
    ''}";
  };
}
```
If you attempt to run this, you will be met with a curious error:

```bash
error: AccessDenied
```

This is a Zig error. Zig attempts to create a cache in your `$XDG_CACHE_HOME`
to store its compilation results. Inside the Nix sandbox, however, this
behavior is not allowed.  Luckily, we can simply add a hook to make `$HOME`
inside the sandbox writable.

```diff
nativeBuildInputs = with pkgs; [
  zig
+ writableTmpDirAsHomeHook
];
```
Now, if you attempt to build again, you will... get more errors! This time
it's something about `msvcrt`:

```bash
error: unable to find dynamic system library 'msvcrt' using strategy 'no_fallback' [...]
```

For some ungodly reason, Rust always attempts to insert a `-lmsvcrt` into
the linker commands even if we are *not* targeting the MSVC ABI.

To deal with this, we have to intercept the arguments Rust gives us (the
`$@` in the Bash script) and remove any `-lmsvcrt` that appears.

However, since my Bash skill is (un)fortunately very lacking, I decided to
write a Lua script to do it instead.

```nix,linenos
{
  writeLua = filename: content:
    pkgs.writers.makeScriptWriter {
      # This is actually just a Bash script that will call Lune (the Lua runtime)
      interpreter = "${pkgs.bash}/bin/bash";

      # This adds Lune itself into the PATH of the script
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        "${pkgs.lib.makeBinPath [pkgs.lune]}"
      ];
    } "/bin/${filename}" ''
      # This command will invoke Lune, running a script named 'script.luau'
      # and passing it all the arguments this script was given (which will come from Rust)
      lune run ${pkgs.writeText "script.luau" content} -- "$@"
    '';

  windows-linker = writeLua "zcc" ''
    local process = require("@lune/process")
    local fs = require("@lune/fs")

    -- Here we filter out the arguments
    local filtered_args = {}

    for _, v in process.args do
      if v == "-lmsvcrt" then continue end

      -- Rust also asks for a weirdly named "-l:libpthread.a" which Zig does not understand
      -- So we change it into "-lpthread" instead
      if v == "-l:libpthread.a" then
        table.insert(filtered_args, "-lpthread")
        continue
      end

      table.insert(filtered_args, v)
    end

    -- Insert the "cc -target $ZIG_TARGET" into the arguments list
    table.insert(filtered_args, 1, "cc")
    table.insert(filtered_args, 2, "-target")
    table.insert(filtered_args, 3, process.env.ZIG_TARGET)

    -- Spawn a "zig" program with the filtered arguments
    local result = process.spawn("zig", filtered_args)
    if not result.ok then
      error(result.stdout.. "\n".. result.stderr)
    end
  '';
}
```

{% note() %}

If this Lua syntax looks a bit weird to you, it's because it's actually
[Luau](https://luau.org)!  [Lune](https://lune-org.github.io/docs) is, in turn,
a runtime for Luau, similar to Node.js/Bun for JavaScript and Luvit for Lua.

Luau brings some nice additions to Lua (such as that `continue` statement)
and `for` loops without requiring iterators.

{% end %}

Now, to use this in our derivation:

```diff
nativeBuildInputs = with pkgs; [
  zig
  writableTmpDirAsHome
+ windows-linker # We declared the script as 'windows-linker' above
];
```

```diff
env = {
  CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
+ CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "zcc"; # Our script wrote a wrapper called 'zcc', not 'windows-linker'!
+ ZIG_TARGET = "x86_64-windows-gnu";
- CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${pkgs.writers.writeBash "zcc" ''
-   zig cc -target x86_64-windows-gnu "$@" # Note how Zig takes a different 'target' than Rust
- ''}";
};
```

Running the build now will see Cargo hanging for a short while, because
that's *Zig cross-compiling the MinGW libc on the fly!*

Afterwards, it will successfully produce an executable for x86_64 Windows!!

### aarch64-windows

If we had gone with the traditional [MinGW cross-compiler
approach](#x86-64-windows), we would be stuck here, because `nixpkgs` does
not provide an LLVM+MinGW toolchain! There is also no aarch64 MinGW libc
(in nixpkgs).

{% note() %}

This ***may*** not be true. While there is no `pkgs.pkgsCross.mingwW64-aarch64`
or anything similar, there is ***probably*** a way to compile MinGW for `aarch64`
anyway, through the `crossSystem` infrastructure in nixpkgs.

It is likely that you can do something like:

```nix,linenos
{
  pkgsCross = import inputs.nixpkgs {
    system = "x86_64-linux";
    crossSystem = "aarch64-linux";
  };
}
```

and then use it like `pkgsCross.pkgsCross.mingwW64` (probably, I don't know
if this is even a real thing).

However, this attempts to, um, build the entire world, down to the Linux
kernel. So this approach was promptly discarded.

{% end %}

With Zig as our linker, that is not a problem.

```nix,linenos
{
  CARGO_BUILD_TARGET = "aarch64-pc-windows-gnullvm";
  CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_LINKER = "zcc";
  ZIG_TARGET = "aarch64-windows-gnu";
}
```

With the power of Zig, we have successfully cross-compiled binaries for
Windows from Linux!

## Cross-compiling to MacOS

Very surprisingly, MacOS is a breeze to compile to! All it takes is:

```nix,linenos
{
  # --snip--

  nativeBuildInputs = with pkgs; [
    zig
    writableTmpDirAsHomeHook
  ];

  env = {
    CARGO_BUILD_TARGET = "x86_64-apple-darwin";
    CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER = "${pkgs.writers.writeBash "zcc" ''
      zig cc -target x86_64-macos "$@"
    ''}";
  };
}
```

We don't have to use the `zcc`/`windows-linker` script for this because Rust
isn't passing in any unwelcome flags.

This will compile for x86_64 Macs. To compile for Apple Silicon, simply
replace `x86_64` with `aarch64`. It's that simple.

## Cross-compiling to Android

Anything involving Android will require the Android SDK/NDK. Luckily for us, nixpkgs does have the Android SDK!

Let's set it up:

```nix,linenos
{
  androidPackages = pkgs.androidenv.composeAndroidPackages {
    toolsVersion = null;
    buildToolsVersions = []; # We don't need the Android build tools here
    includeNDK = true;
  };

  androidSdk = androidPackages.androidsdk;
}
```

{% note() %}

The Android SDK is *non-free* software and will require you to
accept a license. Nix enforces this by requiring you to declare
`android_sdk.accept_license = true` in your nixpkgs config.

{% end %}

Then, to compile for `x86_64-linux-android`:

```nix,linenos
naersk.buildPackage {
  src = ./.;
  strictDeps = true;

  env = {
    CARGO_BUILD_TARGET = "x86_64-linux-android";
    CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER = "${androidSdk}/libexec/android-sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android35-clang";
  };  
}
```

The Android NDK ships with prebuilt binaries of `clang` for every supported
version of Android. We can directly use it as the linker.

To compile for `aarch64-linux-android`, simply substitute the
`x86_64-linux-android35-clang` with `aarch64-linux-android35-clang` instead!

These binaries can then be run on an Android device through Termux or other
terminal emulators.

## What's beyond?

That was a fun(?) journey. A lot of head-banging/head-scratching/hair-pulling
happened. Now, we have reached the end of a long road... or have we?

The program we have been attempting to cross-compile is a mere simple "Hello,
world!" printer. For any program any more complex than this, things *very*
quickly get out of hands.

In fact, I have gone ahead and copy-pasted the entirety of the [Ratatui
counter app](https://ratatui.rs/tutorials/counter-app/basic-app/) verbatim,
ran `cargo add ratatui crossterm`, and tried to compile for Windows.

It broke. I have no idea why. It *seems* like the `winapi` crate is doing
some funny business, but I cannot say for sure.

The Rust ecosystem has a great dependence on the C/C++ ecosystem, often
hidden out of sight. Crates like `libc`, `openssl`, `sqlite` all pull in
C dependencies.  These are... not really feasible to cross-compile, much
less for so many vastly different targets we want to support. They are also
not really friendly to static linking.

Also, I have no idea why, but Rust loves to ignore the `+crt-static` flag
whenever it deems that it cannot statically link. Try to pull in a single C
dependency and it is very likely the resulting executable will be dynamically
linked instead, despite all your efforts.

I have tried to use the `openssl` crate. Through Nix, I compiled `openssl`
statically and linked against musl libc instead of glibc. This was the entire
Rust program:

```rust,linenos
fn main() {
  println!("{}", openssl::version::version());
}
```

The resulting executable was *dynamically linked*, despite:

- `openssl` being statically linked against musl libc
- `openssl` being set to statically link against the program
- The `+crt-static` flag being set
- The target being `x86_64-unknown-linux-musl`

While this was a nice exercise (in futility), any real world, more practical
applications should probably just use a container and be done with it. Trying
to cross-compile Rust is not a worthy endeavor.

I look forward to the day Rust gets cross-compilation support matching that
of Zig, however.

---

[^1]: The Linux and Windows syscall interfaces are considered stable, so
it's possible to statically link on these platforms. MacOS however requires
linking against its libSystem in all scenarios since its syscall interface
is not stable. Android requires linking against its Bionic libc if you want
to use advanced features like networking.
